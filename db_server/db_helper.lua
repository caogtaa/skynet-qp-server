
local skynet = require "skynet"
local cjson = require "cjson"
local date = require "date"
local mysql_utils = require "mysql_utils"

-- 封装一些常用操作函数
local M = {}

-- 通过cmd命令操作redis
function M.do_redis(cmd, ...)
    return skynet.call("dbmgr", "lua", "redis_cmd", cmd, ...)
end

-- 多条命令一起执行
-- { { cmd = "rediscmd", key = "key", fvs = { fields, values }, sync_mysql = "update", sync_mysql_condition = { userid = 1 } }, ... }
-- cmd: redis命令 比如set hmset hmget sadd等
-- key: 操作的key
-- fvs: 可以为nil(当使用get等类似命令的时候) 只负责用table.unpack()展开 正确性需要调用者自己保证
-- sync_mysql: 是否需要同步到mysql nil不需要同步 否则可以是"update", "insert", "incrby(见mysql_utils.make_update_incrby_sql)"这3个选项的其中一个
-- sync_mysql_tbname: 数据库的表名
-- sync_mysql_condition: 如果是update或者incrby需要条件语句
-- 返回值: 把cmd的返回值按command_t的顺序依次放入一个table返回
--[[
example:
    local command_t = {}
    local set_cmd = { cmd = "set", key = "keyset", fvs = { "field", "value" }, sync_mysql = "update", sync_mysql_tbname = "tbname" }
    local get_cmd = { cmd = "get", key = "keyset" }
    local hash_mset = { cmd = "hmset", key = "keyhash", fvs = { "field1", "value1", "field2", 2 }, sync_mysql = "insert", sync_mysql_tbname = "tbname" }
    local hash_mget = { cmd = "hmget", key = "keyhash", fvs = { "field1", "field_not_exsit", "field2" }
    local hash_mset2 = { cmd = "hmset", key = "keyhash", fvs = { "field2", 2 }, sync_mysql = "incrby", sync_mysql_tbname = "tbname" }
    table.insert(command_t, set_cmd)
    table.insert(command_t, get_cmd)
    table.insert(command_t, hash_mset)
    table.insert(command_t, hash_mget)
    table.insert(command_t, hash_mset2)
    local result = do_redis_multi_exec(command_t)
    print(result)
    print:
    {
        [1] = "OK",
        [2] = "keyset_value", -- 过期后[2] = nil
        [3] = "OK",
        [4] = {
                [1] = "value1",
                [3] = "2",
        },
        [5] = "OK",
}
]]
function M.do_redis_multi_exec(command_t)
    local sql_t = {}
    M.do_redis("multi")
    for k, v in ipairs(command_t) do
        local fvs = v.fvs
        if fvs then
            M.do_redis(v.cmd, v.key, table.unpack(fvs))
        else
            M.do_redis(v.cmd, v.key)
        end

        if v.sync_mysql then
            if v.sync_mysql == "insert" then
                local insert_t = {}
                for i = 1, #fvs, 2 do
                    insert_t[fvs[i]] = fvs[i + 2]
                end
                table.insert(sql_t, mysql_utils.make_insert_sql(v.sync_mysql_tbname, insert_t))
            elseif v.sync_mysql == "update" and v.sync_mysql_condition then
                local update_t = {}
                for i = 1, #fvs, 2 do
                    update_t[fvs[i]] = fvs[i + 2]
                end
                table.insert(sql_t, mysql_utils.make_update_sql(v.sync_mysql_tbname, update_t, v.sync_mysql_condition))
            elseif v.sync_mysql == "incrby" and v.sync_mysql_condition then
                local update_t = {}
                for i = 1, #fvs, 2 do
                    update_t[fvs[i]] = fvs[i + 2]
                end
                table.insert(sql_t, mysql_utils.make_update_incrby_sql(v.sync_mysql_tbname, update_t, v.sync_mysql_condition))
            end
        end
    end
    local result = M.do_redis("exec")
    if not table.empty(sql_t) then
        mysql_utils.async_write_table(sql_t)
    end
    return result
end

-- 获取账号分数改变的类型和原因
-- 由于是常用 而且基本不会变 保存在本地
local change_type_and_reason_t = {}
local function get_change_type_and_reason(change_type_string)
    local ret = change_type_and_reason_t[change_type_string]
    if ret then
        return ret
    else
        local change_type_reason = M.do_redis("hmget", "config_change_score:c_name:" .. change_type_string, "c_value", "c_string")
        if table.empty(change_type_reason) then
            change_type_reason = { -1, tostring(change_type_string) }
            LOG_ERROR("未知的账号变更类型:" .. change_type_string)
            LOG_ERROR("未知的账号变更类型:" .. debug.traceback())
        end
        change_type_and_reason_t[change_type_string] = change_type_reason
        return change_type_reason
    end
end

-- 插入一条分数变更记录
-- change_type_string:只能是以下的枚举字符串
-- change_origin: 记录来源 可以为nil
-- return 插入的table
--[[
bank_get
bank_save
bank_transfer
bind_phone
exchange
game
register
team_transfer
team_transfer_cancel
]]
function M.insert_log_change_score(change_type_string, change_origin, userid, source_score, change_score, source_bank_score, change_bank_score, kindid, roomid)
    local id = M.do_redis("incr", "log_change_score:__id")
    local change_type_reason = get_change_type_and_reason(change_type_string)
    local now = os.time()
    local insert_t = {
        id = id,
        userid = userid,
        kindid = kindid or 0,
        roomid = roomid or 0,
        source_score = source_score,
        change_score = change_score,
        source_bank_score = source_bank_score,
        change_bank_score = change_bank_score,
        change_type = tonumber(change_type_reason[1]),
        change_reason = change_type_reason[2],
        change_origin = change_origin and tostring(change_origin) or "",
        change_date = os.date("%Y-%m-%d %H:%M:%S", now)
    }
    M.do_redis("zadd", "log_change_score:userid:" .. userid, now, cjson.encode(insert_t))
    local sql = mysql_utils.make_insert_sql("log_change_score", insert_t)
    mysql_utils.async_write(sql)
end

-- 创建一个用户
function M.create_user(nickname, pwd, clubid, gender, mobilephone, ip, device, uuid, register_score, parent_userid)
    -- 生成userid
    local userid = M.do_redis("incr", "__userid")
    userid = tonumber(userid)

    local nowtime = os.date("%Y-%m-%d %H:%M:%S", os.time())
    local gameid = 0
    local ret = M.do_redis("lindex", "config_gameids", userid - 1)
    if ret then
        gameid = tonumber(ret)
    else
        skynet.error("当前用户数超过了预生成的游戏ID，请尽快重新生成")
        LOG_ERROR("当前用户数超过了预生成的游戏ID，请尽快重新生成")
    end

    -- 帐号表
    local insert_t = {
        userid = userid,
        gameid = gameid,
        username = tostring(gameid),
        nickname = nickname,
        password = pwd,
        bank_password = pwd,
        faceid = 0,
        head_img_url = "",
        gender = gender,
        signature = "",
        real_name = "",
        email = "",
        alipay_name = "",
        alipay_account = "",
        bankcard_id = "",
        bankcard_name = "",
        bankcard_addr = "",
        mobilephone = mobilephone,
        vip_level = 0,
        master_level = 0,
        disabled = 0,
        reactivate_date = "1900-01-01 00:00:00",
        is_robot = 0,
        last_login_ip = ip,
        last_login_date = nowtime,
        last_login_device = device,
        last_login_uuid = uuid,
        register_ip = ip,
        register_date = nowtime,
        register_device = device,
        register_uuid = uuid,
        remarks = "",
        channelid = 0,
        type = 0,
        clubids = clubid ~= 0 and tostring(clubid) or "",
        selected_clubid = clubid ~= 0 and tostring(clubid) or ""
    }

    M.do_redis("hmset", "user_account_info:userid:" .. userid, table.tunpack(insert_t))
    M.do_redis("set", "user_account_info:username:" .. insert_t.username, insert_t.userid)
    M.do_redis("set", "user_account_info:gameid:" .. insert_t.gameid, insert_t.userid)
    M.do_redis("set", "user_account_info:mobilephone:" .. insert_t.mobilephone, insert_t.userid)
    M.do_redis("sadd", "user_account_info:userid", userid)
    local sql = mysql_utils.make_insert_sql("user_account_info", insert_t)

    -- 游戏表
    local insert_game_t = {
        userid = userid,
        score = register_score,
        bank_score = 0,
        win_count = 0,
        lost_count = 0,
        draw_count = 0,
        revenue = 0,
        play_time = 0,
        experience = 0,
        recharge_score = 0,
        recharge_times = 0,
        exchange_score = 0,
        exchange_times = 0,
        balance_score = 0,
        today_balance_score = 0,
    }

    M.do_redis("hmset", "user_game_info:userid:" .. userid, table.tunpack(insert_game_t))
    sql = sql .. mysql_utils.make_insert_sql("user_game_info", insert_game_t)

    if parent_userid ~= 0 then
        -- 团队表
        local insert_team_t = {
            userid = userid,
            team_members_count = 0,
            direct_members_count = 0,
            share_ratio = 0,
            month_total_performance = 0,
            month_total_commission = 0,
            today_total_performance = 0,
            today_total_commission = 0,
            today_new_members_count = 0,
            today_new_direct_members_count = 0,
        }
        M.do_redis("hmset", string.format("user_team_info%d:userid:%d", clubid, userid), table.tunpack(insert_team_t))
        sql = sql .. mysql_utils.make_insert_sql("user_team_info" .. clubid, insert_team_t)

        -- 团队绑定关系
        local parent_userids = ""
        if parent_userid ~= 0 then
            parent_userids = M.do_redis("hget", string.format("user_team_bind_info%d:userid:%d", clubid, parent_userid), "parent_userids")
            if parent_userids ~= "" then
                parent_userids = parent_userids .. "," .. parent_userid
            else
                parent_userids = tostring(parent_userid)
            end
        end

        -- 获取邀请码
        local id_invite_code = M.do_redis("lpop", "config_club_invite_code")
        if id_invite_code then
            id_invite_code = string.split(id_invite_code, ",")
            M.do_redis("hmset", "config_club_invite_code:invite_code:" .. id_invite_code[2], "userid", userid, "clubid", clubid)
            sql = sql .. mysql_utils.make_update_sql("config_club_invite_code", { userid = userid, clubid = clubid }, { id = id_invite_code[1] })
        else
            id_invite_code = { 0, 0 }
            skynet.error("邀请码不够了")
            LOG_ERROR("邀请码不够了")
        end

        -- 插入绑定信息
        local insert_team_bind_t = {
            userid = userid,
            invite_code = id_invite_code[2],
            parent_userid = parent_userid,
            parent_gameid = gameid,
            parent_userids = parent_userids,
            direct_userids = "",
            direct_partner_userids = "",
            member_userids = "",
            partner_userids = "",
            insert_date = nowtime
        }
        M.do_redis("hmset", string.format("user_team_bind_info%d:userid:%d", clubid, userid), table.tunpack(insert_team_bind_t))
        M.do_redis("sadd", "user_team_bind_info" .. clubid .. ":userid", userid)
        sql = sql .. mysql_utils.make_insert_sql("user_team_bind_info" .. clubid, insert_team_bind_t)

        -- 更新所有上级的团队信息
        if parent_userids ~= "" then
            local t_parent_userids = string.split(parent_userids, ",")
            -- 更新直属上级的团队信息
            local update_dirct_parent_t = {
                team_members_count = 1,
                direct_members_count = 1,
                today_new_members_count = 1,
                today_new_direct_members_count = 1,
            }
            for k, v in pairs(update_dirct_parent_t) do
                M.do_redis("hincrby", string.format("user_team_info%d:userid:%d", clubid, parent_userid), k, v)
            end
            sql = sql .. mysql_utils.make_update_incrby_sql("user_team_info" .. clubid, update_dirct_parent_t, { userid = parent_userid })

            -- 给直属上级增加直属会员
            local direct_userids = M.do_redis("hget", string.format("user_team_bind_info%d:userid:%d", clubid, parent_userid), "direct_userids")
            if direct_userids == "" then
                direct_userids = tostring(userid)
            else
                direct_userids = direct_userids .. "," .. userid
            end
            local update_parent_directuserids_t = {
                direct_userids = direct_userids,
            }
            M.do_redis("hmset", "user_team_bind_info" .. clubid .. ":userid:" .. parent_userid, table.tunpack(update_parent_directuserids_t))
            sql = sql .. mysql_utils.make_update_sql("user_team_bind_info" .. clubid, update_parent_directuserids_t, { userid = parent_userid })

            -- 移除最后一个 也就是直属上级 剩下的就是间接上级
            table.remove(t_parent_userids)

            -- 更新间接上级的信息
            for _, v in ipairs(t_parent_userids) do
                local update_others_parent_t = {
                    team_members_count = 1,
                    today_new_members_count = 1,
                }
                for k, value in pairs(update_others_parent_t) do
                    M.do_redis("hincrby", string.format("user_team_info%d:userid:%d", clubid, v), k, value)
                end
                sql = sql .. mysql_utils.make_update_incrby_sql("user_team_info" .. clubid, update_others_parent_t, { userid = tonumber(v) })

                -- 给间接上级增加间接会员
                local member_userids = M.do_redis("hget", "user_team_bind_info" .. clubid .. ":userid:" .. v, "member_userids")
                if member_userids == "" then
                    member_userids = tostring(userid)
                else
                    member_userids = member_userids .. "," .. userid
                end
                local update_parent_memberuserids_t = {
                    member_userids = member_userids,
                }
                M.do_redis("hmset", "user_team_bind_info" .. clubid .. ":userid:" .. v, table.tunpack(update_parent_memberuserids_t))
                sql = sql .. mysql_utils.make_update_sql("user_team_bind_info" .. clubid, update_parent_memberuserids_t, { userid = tonumber(v) })
            end
        end
    end

    mysql_utils.async_write(sql)

    return userid, gameid
end

-- 通过userid获取用户账号信息 按...的输入顺序返回值的table
-- example: get_user_account_info_by_userid(1, "nickname", "not_exsit_field", "gameid") return { [1] = "昵称", [2] = nil, [3] = "123654" }
function M.get_user_account_info_by_userid(userid, ...)
    return M.do_redis("hmget", "user_account_info:userid:" .. userid, ...)
end

-- 通过userid更新用户账号信息
-- update_field_value_t: 需要更新的field value对应的table update_field_value_t的key需要调用者保证与mysql的对应 否则更新mysql失败
-- example: update_user_account_info_by_userid(1, { nickname = "新的昵称", mobilephone = "180123456" })
function M.update_user_account_info_by_userid(userid, update_field_value_t)
    if type(update_field_value_t) ~= "table" then
        LOG_ERROR("update_user_account_info_by_userid 的 update_field_value_t 不是一个table")
        return
    end
    local ret = M.do_redis("hmset", "user_account_info:userid:" .. userid, table.tunpack(update_field_value_t))
    local sql = mysql_utils.make_update_sql("user_account_info", update_field_value_t, { userid = userid })
    mysql_utils.async_write(sql)
    return ret
end

-- 通过gameid获取用户账号信息
function M.get_user_account_info_by_gameid(gameid, ...)
    local userid = M.do_redis("get", "user_account_info:gameid:" .. gameid)
    if not userid then
        return {}
    end
    return M.get_user_account_info_by_userid(userid, ...)
end

-- 通过gameid更新用户账号信息
function M.update_user_account_info_by_gameid(gameid, update_field_value_t)
    local userid = M.do_redis("get", "user_account_info:gameid:" .. gameid)
    if not userid then
        LOG_WARNING("update_user_account_info_by_gameid 未找到用户gameid:" .. gameid)
        return
    end
    return M.update_user_account_info_by_userid(userid, update_field_value_t)
end

-- 通过username获取用户账号信息
function M.get_user_account_info_by_username(username, ...)
    local userid = M.do_redis("get", "user_account_info:username:" .. username)
    if not userid then
        return {}
    end
    return M.get_user_account_info_by_userid(userid, ...)
end

-- 通过username更新用户账号信息
function M.update_user_account_info_by_username(username, update_field_value_t)
    local userid = M.do_redis("get", "user_account_info:username:" .. username)
    if not userid then
        LOG_WARNING("update_user_account_info_by_username 未找到用户 username:" .. username)
        return
    end
    return M.update_user_account_info_by_userid(userid, update_field_value_t)
end

-- 通过mobilephone获取用户账号信息
function M.get_user_account_info_by_mobilephone(mobilephone, ...)
    local userid = M.do_redis("get", "user_account_info:mobilephone:" .. mobilephone)
    if not userid then
        return {}
    end
    return M.get_user_account_info_by_userid(userid, ...)
end

-- 通过mobilephone更新用户账号信息
function M.update_user_account_info_by_mobilephone(mobilephone, update_field_value_t)
    local userid = M.do_redis("get", "user_account_info:mobilephone:" .. mobilephone)
    if not userid then
        LOG_WARNING("update_user_account_info_by_mobilephone 未找到用户:" .. mobilephone)
        return
    end
    return M.update_user_account_info_by_userid(userid, update_field_value_t)
end

-- 通过userid获取用户游戏信息
function M.get_user_game_info(userid, ...)
    return M.do_redis("hmget", "user_game_info:userid:" .. userid, ...)
end

-- 通过userid更新用户游戏信息
function M.update_user_game_info(userid, update_field_value_t)
    if type(update_field_value_t) ~= "table" then
        LOG_ERROR("update_user_game_info 的 update_field_value_t 不是一个table")
        return
    end

    local ret = M.do_redis("hmset", "user_game_info:userid:" .. userid, table.tunpack(update_field_value_t))
    local sql = mysql_utils.make_update_sql("user_game_info", update_field_value_t, { userid = userid })
    mysql_utils.async_write(sql)
    return ret
end

-- 更新游戏信息 和上面不同的是 这个是在原基础上加减(+=或者-=)
-- 假设score和bank_score的初始都是100
-- example: incrby_user_game_info(1, { score = 10, bank_score = -50 }) return { [1] = 110, [2] = 50 }
function M.incrby_user_game_info(userid, update_field_value_t)
    --M.do_redis("multi")
    local ret = {}
    for k, v in pairs(update_field_value_t) do
        table.insert(ret, M.do_redis("hincrby", "user_game_info:userid:" .. userid, k, v))
    end
    --local ret = M.do_redis("exec")
    local sql = mysql_utils.make_update_incrby_sql("user_game_info", update_field_value_t, { userid = userid })
    mysql_utils.async_write(sql)
    return ret
end

-- 通过userid和clubid获取用户团队信息
function M.get_user_team_info(userid, clubid, ...)
    return M.do_redis("hmget", string.format("user_team_info%d:userid:%d", clubid, userid), ...)
end

-- 通过userid和clubid更新用户团队信息
function M.update_user_team_info(userid, clubid, update_field_value_t)
    local ret = M.do_redis("hmset", string.format("user_team_info%d:userid:%d", clubid, userid), table.tunpack(update_field_value_t))
    local sql = mysql_utils.make_update_sql("user_team_info" .. clubid, update_field_value_t, { userid = userid })
    mysql_utils.async_write(sql)
    return ret
end

-- 通过userid和clubid更新用户团队信息
-- 用法同incrby_user_game_info
function M.incrby_user_team_info(userid, clubid, update_field_value_t)
    --M.do_redis("multi")
    local ret = {}
    for k, v in pairs(update_field_value_t) do
        table.insert(ret, M.do_redis("hincrby", string.format("user_team_info%d:userid:%d", clubid, userid), k, v))
    end
    --local ret = M.do_redis("exec")
    local sql = mysql_utils.make_update_incrby_sql("user_team_info" .. clubid, update_field_value_t, { userid = userid })
    mysql_utils.async_write(sql)
    return ret
end

-- 通过userid和clubid获取用户团队绑定信息
function M.get_user_team_bind_info(userid, clubid, ...)
    return M.do_redis("hmget", string.format("user_team_bind_info%d:userid:%d", clubid, userid), ...)
end

-- 通过userid和clubid更新用户团队绑定信息
function M.update_user_team_bind_info(userid, clubid, update_field_value_t)
    local ret = M.do_redis("hmset", string.format("user_team_bind_info%d:userid:%d", clubid, userid), table.tunpack(update_field_value_t))
    local sql = mysql_utils.make_update_sql("user_team_bind_info" .. clubid, update_field_value_t, { userid = userid })
    mysql_utils.async_write(sql)
    return ret
end

-- 绑定团队
function M.bind_team(userid, clubid, parent_userid)
    -- 团队绑定关系
    local parent_userids = ""
    local parent_auto_be_partner = false
    local parent_auto_partner_ratio = 0
    if parent_userid ~= 0 then
        local bind_info = M.do_redis("hmget", string.format("user_team_bind_info%d:userid:%d", clubid, parent_userid), "parent_userids", "auto_be_partner", "auto_partner_share_ratio")
        if bind_info[1] ~= "" then
            parent_userids = parent_userids .. "," .. parent_userid
        else
            parent_userids = tostring(parent_userid)
        end
        parent_auto_be_partner = bind_info[2] ~= "0" and true or false
        if parent_auto_be_partner then
            parent_auto_partner_ratio = tonumber(bind_info[3])
        end
    else
        parent_auto_partner_ratio = 50      -- 创建俱乐部默认给50%
    end

    local sql = ""

    -- 获取邀请码
    local id_invite_code = M.do_redis("lpop", "config_club_invite_code")
    if id_invite_code then
        id_invite_code = string.split(id_invite_code, ",")
        M.do_redis("hmset", "config_club_invite_code:invite_code:" .. id_invite_code[2], "userid", userid, "clubid", clubid)
        sql = sql .. mysql_utils.make_update_sql("config_club_invite_code", { userid = userid, clubid = clubid }, { id = id_invite_code[1] })
    else
        id_invite_code = { 0, 0 }
        LOG_ERROR("邀请码不够了")
    end

    -- 更新用户表
    local account_info = M.get_user_account_info_by_userid(userid, "clubids", "gameid")
    local clubids = account_info[1]
    local gameid = account_info[2]
    if clubids == "" then
        clubids = clubids .. clubid
    else
        clubids = clubids .. "," .. clubid
    end
    local update_account_t = {
        clubids = clubids,
        selected_clubid = clubid
    }
    M.do_redis("hmset", "user_account_info:userid:" .. userid, table.tunpack(update_account_t))
    sql = sql .. mysql_utils.make_update_sql("user_account_info", update_account_t, { userid = userid })

    -- 插入团队信息
    local insert_team_t = {
        userid = userid,
        team_members_count = 0,
        direct_members_count = 0,
        share_ratio = parent_auto_partner_ratio,
        month_total_performance = 0,
        month_total_commission = 0,
        today_total_performance = 0,
        today_total_commission = 0,
        today_new_members_count = 0,
        today_new_direct_members_count = 0,
    }
    M.do_redis("hmset", string.format("user_team_info%d:userid:%d", clubid, userid), table.tunpack(insert_team_t))
    sql = sql .. mysql_utils.make_insert_sql("user_team_info" .. clubid, insert_team_t)

    -- 插入绑定信息
    local insert_team_bind_t = {
        userid = userid,
        invite_code = id_invite_code[2],
        auto_be_partner = 0,
        auto_partner_share_ratio = 0,
        parent_userid = parent_userid,
        parent_gameid = gameid,
        parent_userids = parent_userids,
        direct_userids = "",
        direct_partner_userids = "",
        member_userids = "",
        partner_userids = "",
        insert_date = os.date("%Y-%m-%d %H:%M:%S", os.time())
    }
    M.do_redis("hmset", string.format("user_team_bind_info%d:userid:%d", clubid, userid), table.tunpack(insert_team_bind_t))
    M.do_redis("sadd", "user_team_bind_info" .. clubid .. ":userid", userid)
    sql = sql .. mysql_utils.make_insert_sql("user_team_bind_info" .. clubid, insert_team_bind_t)

    -- 更新所有上级的团队信息
    if parent_userids ~= "" then
        local t_parent_userids = string.split(parent_userids, ",")
        -- 更新直属上级的团队信息
        local update_dirct_parent_t = {
            team_members_count = 1,
            direct_members_count = 1,
            today_new_members_count = 1,
            today_new_direct_members_count = 1,
        }
        for k, v in pairs(update_dirct_parent_t) do
            M.do_redis("hincrby", string.format("user_team_info%d:userid:%d", clubid, parent_userid), k, v)
        end
        sql = sql .. mysql_utils.make_update_incrby_sql("user_team_info" .. clubid, update_dirct_parent_t, { userid = parent_userid })

        -- 给直属上级增加 直属会员或者直属合伙人
        local bind_key = parent_auto_be_partner and "direct_partner_userids" or "direct_userids"
        local direct_userids_or_partner_userids = M.do_redis("hget", string.format("user_team_bind_info%d:userid:%d", clubid, parent_userid), bind_key)
        if direct_userids_or_partner_userids == "" then
            direct_userids_or_partner_userids = tostring(userid)
        else
            direct_userids_or_partner_userids = direct_userids_or_partner_userids .. "," .. userid
        end
        local update_parent_direct_t = {}
        update_parent_direct_t[bind_key] = direct_userids_or_partner_userids
        
        M.do_redis("hmset", "user_team_bind_info" .. clubid .. ":userid:" .. parent_userid, table.tunpack(update_parent_direct_t))
        sql = sql .. mysql_utils.make_update_sql("user_team_bind_info" .. clubid, update_parent_direct_t, { userid = parent_userid })

        -- 移除最后一个 也就是直属上级 剩下的就是间接上级
        table.remove(t_parent_userids)

        -- 更新间接上级的信息
        for _, v in ipairs(t_parent_userids) do
            local update_others_parent_t = {
                team_members_count = 1,
                today_new_members_count = 1,
            }
            for k, value in pairs(update_others_parent_t) do
                M.do_redis("hincrby", string.format("user_team_info%d:userid:%d", clubid, v), k, value)
            end
            sql = sql .. mysql_utils.make_update_incrby_sql("user_team_info" .. clubid, update_others_parent_t, { userid = tonumber(v) })

            -- 给间接上级增加间接会员
            local member_userids = M.do_redis("hget", "user_team_bind_info" .. clubid .. ":userid:" .. v, "member_userids")
            if member_userids == "" then
                member_userids = tostring(userid)
            else
                member_userids = member_userids .. "," .. userid
            end
            local update_parent_memberuserids_t = {
                member_userids = member_userids,
            }
            M.do_redis("hmset", "user_team_bind_info" .. clubid .. ":userid:" .. v, table.tunpack(update_parent_memberuserids_t))
            sql = sql .. mysql_utils.make_update_sql("user_team_bind_info" .. clubid, update_parent_memberuserids_t, { userid = tonumber(v) })
        end
    end

    mysql_utils.async_write(sql)
end

-- 获取俱乐部信息
function M.get_club_info(clubid, ...)
    return M.do_redis("hmget", "club_info:clubid:" .. clubid, ...)
end

-- 插入一条提现记录
function M.insert_log_exchange(userid, score, revenue, account, account_name, type)
    local id = M.do_redis("incr", "log_exchange:__id")
    local now = os.time()
    local nowdate = os.date("%Y-%m-%d %H:%M:%S", now)
    local insert_t = {
        id = id,
        userid = userid,
        score = score - revenue,
        revenue = revenue,
        account = account,
        account_name = account_name,
        type = type,
        state = 0,
        reason = "",
        insert_date = nowdate,
        update_date = nowdate
    }

    local json = cjson.encode(insert_t)
    M.do_redis("zadd", "log_exchange:userid:" .. userid, now, json)
    M.do_redis("set", "log_exchange:userid:" .. userid .. ":id:" .. id, json)

    local sql = mysql_utils.make_insert_sql("log_exchange", insert_t)
    mysql_utils.async_write(sql)
end

-- 插入一条进出信息
function M.insert_log_user_inout(userid, kindid, roomid, enter_score, enter_ip, enter_uuid)
    local id = M.do_redis("incr", "log_user_inout:__id")
    local now = os.time()
    local insert_t = {
        id = tonumber(id),
        userid = userid,
        kindid = kindid,
        roomid = roomid,
        enter_score = enter_score,
        enter_ip = enter_ip,
        enter_uuid = enter_uuid,
        enter_date = os.date("%Y-%m-%d %H:%M:%S", now)
    }
    local json = cjson.encode(insert_t)
    M.do_redis("zadd", "log_user_inout:userid:" .. userid, now, json)
    M.do_redis("set", "log_user_inout:userid:" .. userid .. ":id:" .. id, json)

    local sql = mysql_utils.make_insert_sql("log_user_inout", insert_t)
    mysql_utils.async_write(sql)

    return insert_t.id, insert_t.enter_date
end

-- 更新进出信息
function M.update_log_user_inout(userid, inout_index, change_score, revenue, play_time, leave_ip, leave_uuid)
    local ret = M.do_redis("get", "log_user_inout:userid:" .. userid .. ":id:" .. inout_index)
    M.do_redis("zrem", "log_user_inout:userid:" .. userid, ret)
    M.do_redis("del", "log_user_inout:userid:" .. userid .. ":id:" .. inout_index)

    local record = cjson.decode(ret)
    local now = os.time()
    record.leave_date = os.date("%Y-%m-%d %H:%M:%S", now)
    record.leave_ip = leave_ip
    record.leave_uuid = leave_uuid
    record.change_score = change_score
    record.revenue = revenue
    record.play_time = play_time

    local update_t = {
        leave_date = record.leave_date,
        leave_ip = leave_ip,
        leave_uuid = leave_uuid,
        change_score = change_score,
        revenue = revenue,
        play_time = play_time,
    }

    local json = cjson.encode(record)
    M.do_redis("zadd", "log_user_inout:userid:" .. userid, date(record.enter_date):totimestamp(), json)

    local sql = mysql_utils.make_update_sql("log_user_inout", update_t, { id = inout_index })
    mysql_utils.async_write(sql)
end

-- 插入一条游戏记录
function M.insert_log_game_record(drawid, kindid, roomid, tableid, user_count, robot_count, score, revenue, str_start_time, str_end_time, wanfa)
    local insert_t = {
        drawid = drawid,
        kindid = kindid,
        roomid = roomid,
        tableid = tableid,
        user_count = user_count,
        robot_count = robot_count,
        change_score = score,
        revenue = revenue,
        game_start_date = str_start_time,
        game_end_date = str_end_time,
        wanfa = wanfa or "",
    }
    local json = cjson.encode(insert_t)
    local ret = M.do_redis("zadd", "log_game_record", drawid_to_score(drawid), json)

    local sql = mysql_utils.make_insert_sql("log_game_record", insert_t)
    mysql_utils.async_write(sql)

    return ret
end

-- 插入一条游戏记录详情
function M.insert_log_game_record_detail(userid, drawid, kindid, roomid, tableid, chairid, score, revenue, start_score, start_bank_score, play_time, gamelog, wanfa, clubid, performance)
    if performance and performance > 0 then
        -- 团队信息
        M.incrby_user_team_info(userid, clubid, { today_total_performance = performance })
    end

    local id = M.do_redis("incr", "log_game_record_detail:__id")
    local insert_t = {
        id = id,
        userid = userid,
        drawid = drawid,
        kindid = kindid,
        roomid = roomid,
        tableid = tableid,
        chairid = chairid,
        change_score = score,
        revenue = revenue,
        start_score = start_score,
        start_bank_score = start_bank_score,
        play_time = play_time,
        gamelog = gamelog,
        wanfa = wanfa or "",
    }
    local json = cjson.encode(insert_t)
    local ret = M.do_redis("zadd", "log_game_record_detail", drawid_to_score(drawid), json)

    local sql = mysql_utils.make_insert_sql("log_game_record_detail", insert_t)
    mysql_utils.async_write(sql)

    return ret
end

-- 插入一条转账记录
function M.insert_log_team_transfer(userid, clubid, dest_userid, dest_gameid, dest_nickname, transfer_score)
    local id = M.do_redis("incr", "log_team_transfer" .. clubid .. ":__id")
    local now = os.time()
    local nowdate = os.date("%Y-%m-%d %H:%M:%S", now)
    local insert_t = {
        id = id,
        userid = userid,
        dest_userid = dest_userid,
        dest_gameid = dest_gameid,
        dest_nickname = dest_nickname,
        transfer_score = transfer_score,
        state = 0,
        insert_date = nowdate
    }

    local json = cjson.encode(insert_t)
    M.do_redis("zadd", "log_team_transfer" .. clubid .. ":userid:" .. userid, now, json)
    M.do_redis("set", "log_team_transfer" .. clubid .. ":userid:" .. userid .. ":id:" .. id, json)
    M.do_redis("setex", "expired_log_team_transfer" .. clubid .. ":userid:" .. userid .. ":id:" .. id, 40, json)

    local sql = mysql_utils.make_insert_sql("log_team_transfer" .. clubid, insert_t)
    mysql_utils.async_write(sql)
end

-- 设置手机验证码 expired_second过期时间秒
function M.set_phone_code(phone_number, expired_second)
    return M.do_redis("setex", "phonecode:" .. phone_number, expired_second or 300)
end

-- 获取手机验证码
function M.get_phone_code(phone_number)
    return M.do_redis("get", "phonecode:" .. phone_number)
end

return M
