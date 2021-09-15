
local skynet = require "skynet"
require "skynet.manager"
local redis = require "skynet.db.redis"
local dbconfig = require "mysqldbconfig"
local date = require "date"
local cluster = require "skynet.cluster"
local cjson = require "cjson"
local random = require "random"
local mysql_utils = require "mysql_utils"
local db_helper = require "db_helper"

--[[
    redis存储信息:

    从mysql读取
        见mysqldbconfig.lua

    临时表 不保存到mysql 进程结束失效
        用户房间锁定
            hash temp_game_user_lock_info:userid:?userid "userid", "kindid", "roomid", "inout_index", "enter_ip", "enter_uuid"
        机器人用户信息:
            set temp_game_robot_userinfo:free userid集合  空闲机器人
            set temp_game_robot_userinfo:roomid:?roomid userid集合 指定房间的机器人
        手机验证码：
            key-value phonecode:?phonenumber code
        用户当天兑换信息 用于保存 前几次提现免税 每天最多兑换几次
            hash temp_user_exchange_info:userid:?userid count score
    
]]

local redisconf = {
    host = skynet.getenv("redis_host"),
    port = tonumber(skynet.getenv("redis_port")),
    db = tonumber(skynet.getenv("redis_db"))
}
local redisdb

local function hmset(key, t)
	local data = {}
	for k, v in pairs(t) do
		table.insert(data, k)
		table.insert(data, v)
	end

	redisdb:hmset(key, table.unpack(data))
end

-- 加载数据到redis
local function load_mysql_to_redis()
    local now = date()

    local clubids = skynet.call("mysqlpool", "lua", "execute", "select clubid from club_info;")
    for k, v in ipairs(dbconfig) do
        local tbsql_t = {}
        if v.multi_tb_mode then
            for _, record in ipairs(clubids) do
                table.insert(tbsql_t, {string.format(v.tbname, record.clubid),string.format(v.sql, record.clubid), record.clubid})
            end
        else
            table.insert(tbsql_t, {v.tbname, v.sql})
        end
        for _, tbsql in ipairs(tbsql_t) do
            local result = skynet.call("mysqlpool", "lua", "execute", tbsql[2])
            if result["err"] then
                skynet.error("load_data_to_redis error:" .. result["err"])
                return false
            end
            local tbname = tbsql[1]
            for _, record in ipairs(result) do
                for _, stoarge in ipairs(v.stoarge) do
                    if stoarge.type == "hash" then
                        if type(stoarge.pk) ~= "string" then
                            skynet.error("load_data_to_redis hash stoarge pk 只能是string类型")
                            return false
                        end
                        hmset(tbname .. ":" .. stoarge.pk .. ":" .. record[stoarge.pk], record)
                    elseif stoarge.type == "string" then
                        if stoarge.pk then
                            local rkey
                            if type(stoarge.pk) == "table" then
                                rkey = tbname
                                for _, pkitem in ipairs(stoarge.pk) do
                                    -- pk不能是空字符串 主要是用于还未绑定手机 支付宝等的情况判定
                                    if tostring(record[pkitem]) == "" then
                                        rkey = nil
                                        break
                                    end
                                    rkey = rkey .. ":" .. pkitem .. ":" .. record[pkitem]
                                end
                            elseif tostring(record[stoarge.pk]) ~= "" then
                                rkey = tbname .. ":" .. stoarge.pk .. ":" .. record[stoarge.pk]
                            end
                            if rkey then
                                if stoarge.value_json then
                                    redisdb:set(rkey, cjson.encode(record))
                                elseif stoarge.value then
                                    redisdb:set(rkey, record[stoarge.value])
                                else
                                    skynet.error("load_data_to_redis string stoarge value 不能是nil")
                                    return false
                                end
                            end
                        else
                            skynet.error("load_data_to_redis string stoarge pk 不能是nil")
                            return false
                        end
                    elseif stoarge.type == "set" then
                        if stoarge.pk then
                            local rkey
                            if type(stoarge.pk) == "table" then
                                rkey = tbname
                                for _, pkitem in ipairs(stoarge.pk) do
                                    -- pk不能是空字符串 主要是用于还未绑定手机 支付宝等的情况判定
                                    if tostring(record[pkitem]) == "" then
                                        rkey = nil
                                        break
                                    end
                                    rkey = rkey .. ":" .. pkitem .. ":" .. record[pkitem]
                                end
                            elseif tostring(record[stoarge.pk]) ~= "" then
                                rkey = tbname .. ":" .. stoarge.pk .. ":" .. record[stoarge.pk]
                            end
                            if rkey then
                                if stoarge.value_json then
                                    redisdb:sadd(rkey, cjson.encode(record))
                                elseif stoarge.value then
                                    redisdb:sadd(rkey, record[stoarge.value])
                                else
                                    skynet.error("load_data_to_redis set stoarge value 不能是nil")
                                    return false
                                end
                            end
                        else
                            if stoarge.value_json then
                                redisdb:sadd(tbname, cjson.encode(record))
                            elseif stoarge.value then
                                redisdb:sadd(tbname, record[stoarge.value])
                            else
                                skynet.error("load_data_to_redis set stoarge value 不能是nil")
                                return false
                            end
                        end
                    elseif stoarge.type == "zset" then
                        if not stoarge.score then
                            skynet.error("load_data_to_redis zset stoarge score 不能是nil")
                            return false
                        end
                        local score = record[stoarge.score]
                        if stoarge.score_datetime then
                            score = date(score):totimestamp()
                        elseif stoarge.score_drawid then
                            score = drawid_to_score(score)
                        end
                        if stoarge.pk then
                            local rkey
                            if type(stoarge.pk) == "table" then
                                rkey = tbname
                                for _, pkitem in ipairs(stoarge.pk) do
                                    -- pk不能是空字符串 主要是用于还未绑定手机 支付宝等的情况判定
                                    if tostring(record[pkitem]) == "" then
                                        rkey = nil
                                        break
                                    end
                                    rkey = rkey .. ":" .. pkitem .. ":" .. record[pkitem]
                                end
                            elseif tostring(record[stoarge.pk]) ~= "" then
                                rkey = tbname .. ":" .. stoarge.pk .. ":" .. record[stoarge.pk]
                            end
                            if rkey then
                                if stoarge.value_json then
                                    redisdb:zadd(rkey, score, cjson.encode(record))
                                elseif stoarge.value then
                                    redisdb:zadd(rkey, score, record[stoarge.value])
                                else
                                    skynet.error("load_data_to_redis zset stoarge value 不能是nil")
                                    return false
                                end
                            end
                        else
                            if stoarge.value_json then
                                redisdb:zadd(tbname, score, cjson.encode(record))
                            elseif stoarge.value then
                                redisdb:zadd(tbname, score, record[stoarge.value])
                            else
                                skynet.error("load_data_to_redis zset stoarge value 不能是nil")
                                return false
                            end
                        end
                    elseif stoarge.type == "list" then
                        if stoarge.pk then
                            local rkey
                            if type(stoarge.pk) == "table" then
                                rkey = tbname
                                for _, pkitem in ipairs(stoarge.pk) do
                                    -- pk不能是空字符串 主要是用于还未绑定手机 支付宝等的情况判定
                                    if tostring(record[pkitem]) == "" then
                                        rkey = nil
                                        break
                                    end
                                    rkey = rkey .. ":" .. pkitem .. ":" .. record[pkitem]
                                end
                            elseif tostring(record[stoarge.pk]) ~= "" then
                                rkey = tbname .. ":" .. stoarge.pk .. ":" .. record[stoarge.pk]
                            end
                            if rkey then
                                if stoarge.value_json then
                                    redisdb:rpush(rkey, cjson.encode(record))
                                elseif stoarge.value then
                                    redisdb:rpush(rkey, record[stoarge.value])
                                else
                                    skynet.error("load_data_to_redis list stoarge value 不能是nil")
                                    return false
                                end
                            end
                        else
                            if stoarge.value_json then
                                redisdb:rpush(tbname, cjson.encode(record))
                            elseif stoarge.value then
                                redisdb:rpush(tbname, record[stoarge.value])
                            else
                                skynet.error("load_data_to_redis list stoarge value 不能是nil")
                                return false
                            end
                        end
                    else
                        skynet.error("load_data_to_redis 不支持存储:" .. stoarge.type)
                        return false
                    end
                end

                if v.savepk then
                    for _, pkitem in ipairs(v.savepk) do
                        redisdb:sadd(tbname .. ":" .. pkitem, record[pkitem])
                    end
                end
            end

            if v.autoincrement then
                local sqlvalue = v.autoincrement.value
                local akey = v.autoincrement.key
                if v.multi_tb_mode then
                    sqlvalue = string.format(v.autoincrement.value, tbsql[3])
                    akey = string.format(v.autoincrement.key, tbsql[3])
                end
                local result = skynet.call("mysqlpool", "lua", "execute", sqlvalue)
                if result["err"] then
                    skynet.error("load_data_to_redis autoincrement error:" .. result["err"])
                    return false
                end
                redisdb:set(akey, result[1].value or 0)
            end
        end
    end

    -- 俱乐部邀请码
    local result = skynet.call("mysqlpool", "lua", "execute", "select * from config_club_invite_code order by id asc;")
    if result["err"] then
        skynet.error("load_data_to_redis config_club_invite_code error:" .. result["err"])
        return false
    end
    for _, record in ipairs(result) do
        if record.userid > 0 and record.clubid > 0 then
            hmset("config_club_invite_code:invite_code:" .. record.invite_code, record)
        else
            redisdb:rpush("config_club_invite_code", record.id .. "," .. record.invite_code)
        end
    end

    return true
end

-- 临时数据表
local function make_tempdata_to_redis()
    -- 机器人用户信息
    local result = skynet.call("mysqlpool", "lua", "execute", "select userid from user_account_info where is_robot = 1;")
    if result["err"] then
        skynet.error("make_tempdata_to_redis error:" .. result["err"])
        return false
    end

    for _, record in ipairs(result) do
        redisdb:sadd("temp_game_robot_userinfo:free", record.userid)
    end
end

-- 每天0点的时候汇总团队报表
local function collect_team_report()
    local now = date()
    skynet.error("collect_team_report:", now:fmt("%F %T"))
    local hpc1 = skynet.hpc()

    local change_type_reason = redisdb:hmget("config_change_score:c_name:commission", "c_value", "c_string")

    -- 所有的俱乐部
    local clubids = redisdb:smembers("club_info:clubid")
    for _, clubid in ipairs(clubids or {}) do
        -- 当前俱乐部的所有用户
        local club_userids = redisdb:smembers("user_team_bind_info" .. clubid .. ":userid")

        -- 保存每个用户的分成比例，今日税收和所有上级
        local user_team_info = {}
        for _, userid in ipairs(club_userids) do
            local item = {}
            local ret = redisdb:hmget("user_team_info" .. clubid .. ":userid:" .. userid, "share_ratio", "today_total_performance", "today_new_members_count", "today_new_direct_members_count", "month_total_performance", "month_total_commission")
            item.share_ratio = tonumber(ret[1])
            item.today_total_performance = tonumber(ret[2])
            item.today_new_members_count = tonumber(ret[3])
            item.today_new_direct_members_count = tonumber(ret[4])
            item.month_total_performance = tonumber(ret[6])
            item.month_total_commission = tonumber(ret[6])
            local bind_info = redisdb:hmget("user_team_bind_info" .. clubid .. ":userid:" .. userid, "parent_userids", "direct_userids", "direct_partner_userids", "partner_userids")
            item.parent_userids = string.split(bind_info[1], ",")
            item.direct_userids = string.split(bind_info[2], ",")
            item.direct_partner_userids = string.split(bind_info[3], ",")
            item.partner_userids = string.split(bind_info[4], ",")
            user_team_info[tonumber(userid)] = item
        end

        -- 先从下往上把佣金全部计算一遍
        local user_commission = {}  -- userid -> commission
        for userid, team_info in pairs(user_team_info) do
            if not user_commission[userid] then
                user_commission[userid] = 0
            end
            -- 有业绩才统计
            local performance = team_info.today_total_performance
            if performance > 0 then
                local share_ratio = team_info.share_ratio
                -- 先计算自己的
                if share_ratio > 0 then
                    local commission = math.floor(performance * share_ratio / 100)
                    user_commission[userid] = user_commission[userid] + commission
                end

                -- 计算所有上级的
                local parent_userids = team_info.parent_userids
                if #parent_userids > 0 then
                    -- 从后往前计算
                    local last_share_ratio = share_ratio
                    for i = #parent_userids, 1, -1 do
                        local uid = tonumber(parent_userids[i])
                        if not user_commission[uid] then
                            user_commission[uid] = 0
                        end
                        local parent_share_ratio = user_team_info[uid].share_ratio
                        if parent_share_ratio > 0 then
                            local commission = math.floor(performance * (parent_share_ratio - last_share_ratio) / 100)
                            user_commission[uid] = user_commission[uid] + commission
                            last_share_ratio = parent_share_ratio
                        end
                    end
                end
            end
        end

        -- 直接合伙人的佣金
        local function calc_direct_partner_commission(t_direct_partner_userids)
            local commission = 0
            for _, userid in ipairs(t_direct_partner_userids) do
                commission = commission + user_commission[tonumber(userid)]
            end
            return commission
        end

        -- 间接合伙人的佣金
        local function calc_partner_commission(t_partner_userids)
            local commission = 0
            for _, userid in ipairs(t_partner_userids) do
                commission = commission + user_commission[tonumber(userid)]
            end
            return commission
        end

        -- 直属会员业绩
        local function calc_direct_members_performance(t_direct_userids)
            local performance = 0
            for _, userid in ipairs(t_direct_userids) do
                performance = performance + user_team_info[tonumber(userid)].today_total_performance
            end
            return performance
        end

        -- 记录时间减一天
        local collect_date = date():adddays(-1):sethours(0, 0, 0, 0)
        local report_date = collect_date:fmt("%F %T")
        local report_timestamp = collect_date:totimestamp()
        for userid, team_info in pairs(user_team_info) do
            local sql = ""

            local id = redisdb:incr(string.format("log_team_day_report%s:__id", clubid))

            local direct_partner_commission = calc_direct_partner_commission(team_info.direct_partner_userids)
            local partner_commission = calc_partner_commission(team_info.partner_userids)
            local direct_members_performance = calc_direct_members_performance(team_info.direct_userids)

            -- 存入报表
            local insert_t = {
                id = id,
                userid = userid,
                performance = team_info.today_total_performance,
                share_ratio = team_info.share_ratio,
                commission = user_commission[userid] or 0,
                partner_commission = direct_partner_commission + partner_commission,
                direct_userids = table.concat(team_info.direct_userids, ","),
                direct_members_performance = direct_members_performance,
                direct_partner_userids = table.concat(team_info.direct_partner_userids, ","),
                direct_partner_commission = direct_partner_commission,
                new_members_count = team_info.today_new_members_count,
                new_direct_members_count = team_info.today_new_direct_members_count,
                create_date = report_date
            }
            redisdb:hmset(string.format("log_team_day_report%s:id:%d", clubid, id), table.tunpack(insert_t))
            redisdb:zadd(string.format("log_team_day_report%s:userid:%d", clubid, userid), report_timestamp, cjson.encode(insert_t))
            sql = sql .. mysql_utils.make_insert_sql(string.format("log_team_day_report%s", clubid), insert_t, { userid = userid })

            -- 更新团队信息
            local update_team_info_t = {
                month_total_performance = team_info.today_total_performance,
                month_total_commission = insert_t.commission,
                today_total_performance = -team_info.today_total_performance,
                today_new_members_count = -team_info.today_new_members_count,
                today_new_direct_members_count = -team_info.today_new_direct_members_count,
            }
            redisdb:hincrby(string.format("user_team_info%s:userid:%d", clubid, userid), "month_total_performance", update_team_info_t.month_total_performance)
            redisdb:hincrby(string.format("user_team_info%s:userid:%d", clubid, userid), "month_total_commission", update_team_info_t.month_total_commission)
            redisdb:hincrby(string.format("user_team_info%s:userid:%d", clubid, userid), "today_total_performance", update_team_info_t.today_total_performance)
            redisdb:hincrby(string.format("user_team_info%s:userid:%d", clubid, userid), "today_new_members_count", update_team_info_t.today_new_members_count)
            redisdb:hincrby(string.format("user_team_info%s:userid:%d", clubid, userid), "today_new_direct_members_count", update_team_info_t.today_new_direct_members_count)
            sql = sql .. mysql_utils.make_update_incrby_sql(string.format("user_team_info%s", clubid), update_team_info_t, { userid = userid })

            -- 发放佣金
            if insert_t.commission > 0 then
                local game_info = redisdb:hmget("user_game_info:userid:" .. userid, "score", "bank_score")
                redisdb:hincrby("user_game_info:userid:" .. userid, "score", insert_t.commission)
                sql = sql .. "update user_game_info set score = score + " .. insert_t.commission .. " where userid = " .. userid .. ";"

                local id = redisdb:incr("log_change_score:__id")
                local change_nowtime = os.time()
                local insert_log_t = {
                    id = id,
                    userid = userid,
                    kindid = 0,
                    roomid = 0,
                    source_score = tonumber(game_info[1]),
                    change_score = insert_t.commission,
                    source_bank_score = tonumber(game_info[2]),
                    change_bank_score = 0,
                    change_type = tonumber(change_type_reason[1]),
                    change_reason = change_type_reason[2],
                    change_origin = "",
                    change_date = os.date("%Y-%m-%d %H:%M:%S", change_nowtime)
                }
                redisdb:zadd("log_change_score:userid:" .. userid, change_nowtime, cjson.encode(insert_log_t))
                sql = sql .. mysql_utils.make_insert_sql("log_change_score", insert_log_t)

                -- 通知游戏大厅和游戏服务器更新分数 如果在游戏或者大厅
                local updatescore = redisdb:hget("user_game_info:userid:" .. userid, "score")
                cluster.send("cluster_center", "@center", "notify_update_score", userid, tonumber(updatescore))
            end

            -- 如果是每个月的第1天 清空月相关的数据
            if now:getday() == 1 then
                -- 更新团队信息
                local update_team_info_t = {
                    month_total_performance = -(team_info.month_total_performance + team_info.today_total_performance),
                    month_total_commission = -(team_info.month_total_commission + insert_t.commission),
                }
                redisdb:hincrby(string.format("user_team_info%s:userid:%d", clubid, userid), "month_total_performance", update_team_info_t.month_total_performance)
                redisdb:hincrby(string.format("user_team_info%s:userid:%d", clubid, userid), "month_total_commission", update_team_info_t.month_total_commission)
                sql = sql .. mysql_utils.make_update_incrby_sql(string.format("user_team_info%s", clubid), update_team_info_t, { userid = userid })
            end

            mysql_utils.async_write(sql)
        end
    end

    skynet.error("collect_team_report hpc cost:" .. ((skynet.hpc() - hpc1) / 1000000000) .. "秒")
end

-- 清理帐变记录 只保留3天的数据
local function clean_log_change_score()
    local cleandate = date():adddays(-3)
    local cleants = cleandate:sethours(0, 0, 0, 0):totimestamp()

    local all_userids = redisdb:smembers("user_account_info:userid")
    for _, v in ipairs(all_userids) do
        redisdb:zremrangebyscore("log_change_score:userid:" .. v, 0, cleants)
    end
end

-- 清理充值提现记录 只保留30天的数据
local function clean_log_recharge_and_exchange()
    local cleandate = date():adddays(-30)
    local cleants = cleandate:sethours(0, 0, 0, 0):totimestamp()

    local all_userids = redisdb:smembers("user_account_info:userid")
    for _, v in ipairs(all_userids) do
        redisdb:zremrangebyscore("log_exchange:userid:" .. v, 0, cleants)
        redisdb:zremrangebyscore("log_recharge:userid:" .. v, 0, cleants)
    end
end

-- 清理游戏记录 只保留3天的数据
local function clean_log_game_record()
    local cleandate = date():adddays(-3)
    local cleants = cleandate:sethours(0, 0, 0, 0):totimestamp()

    -- TODO:有修改
    --redisdb:zremrangebyscore("log_game_record", 0, cleants)
    --redisdb:zremrangebyscore("log_game_record_detail", 0, cleants)
end

-- 清理团队每天的报表记录 只保留2个月的数据 每个月执行一下就可以了
local function clean_log_team_day_report()
    if date():getday() ~= 1 then
        return
    end
    local cleandate = date():addmonths(-1)
    local cleants = cleandate:setday(1):sethours(0, 0, 0, 0):totimestamp()

    local all_userids = redisdb:smembers("user_account_info:userid")
    for _, v in ipairs(all_userids) do
        redisdb:zremrangebyscore("log_team_day_report:userid:" .. v, 0, cleants)
    end
end

-- 清理进出房间记录 只保留3天的数据
local function clean_log_user_inout()
    local cleandate = date():adddays(-3)
    local cleants = cleandate:sethours(0, 0, 0, 0):totimestamp()

    local all_userids = redisdb:smembers("user_account_info:userid")
    for _, v in ipairs(all_userids) do
        redisdb:zremrangebyscore("log_user_inout:userid:" .. v, 0, cleants)
    end
end

-- 0点执行的定时器
local function exec_timer_0(first)
    if not first then
        collect_team_report()
    end

    local now = date()
    local nexttm = date(now):adddays(1)
    nexttm:sethours(0, 0, 0, 0)
    skynet.error(string.format("当前时间:%s 下一次0点统计时间是%s, %d秒后执行", now:fmt("%F %T"), nexttm:fmt("%F %T"), date.diff(nexttm, now):spanseconds()))
    skynet.timeout(date.diff(nexttm, now):spanseconds() * 100, exec_timer_0)
end

-- 5点执行的定时器 用于执行不需要0点准时更新的数据 延迟到5点执行
local function exec_timer_5(first)
    if not first then
        clean_log_change_score()
        clean_log_recharge_and_exchange()
        clean_log_game_record()
        clean_log_team_day_report()
        clean_log_user_inout()
    end

    local now = date()
    local nexttm = date(now):adddays(1)
    nexttm:sethours(5, 0, 0, 0)
    skynet.error(string.format("当前时间:%s 下一次5点统计时间是%s, %d秒后执行", now:fmt("%F %T"), nexttm:fmt("%F %T"), date.diff(nexttm, now):spanseconds()))
    skynet.timeout(date.diff(nexttm, now):spanseconds() * 100, exec_timer_5)
end

-- 过期事件
local function watching_expired_event()
    local w = redis.watch(redisconf)
    local keyevent_expired = string.format("__keyevent@%d__:expired", redisconf.db)
	w:subscribe(keyevent_expired)

	while true do
        local key, channel = w:message()
        assert(channel == keyevent_expired)
        if (channel == keyevent_expired) then
            local m1, m2, m3, m4, m5 = string.match(key, "([^:]*):([^:]*):([^:]*):([^:]*):([^:]*)")
            if m2 == "userid" and m4 == "id" then
                if m1 == "log_recharge" then
                    -- TODO: 处理充值订单过期失效
                    -- 充值订单格式 log_recharge:userid:1:id:1
                    local userid = tonumber(m3)
                    local id = tonumber(m5)
                    print("recharge failed", userid, id)
                    print(redisdb:get(key))
                else
                    local i, j = string.find(m1, "expired_log_team_transfer")
                    if i then
                        -- TODO: 处理转帐过期成功
                        -- 转账记录格式 log_team_transfer1:userid:1:id:1
                        local clubid = tonumber(string.sub(m1, j + 1))
                        local userid = tonumber(m3)
                        local id = tonumber(m5)
                        local log_key = string.format("log_team_transfer%d:userid:%d:id:%d", clubid, userid, id)
                        local json = redisdb:get(log_key)
                        print(redisdb:del(log_key))
                        print(redisdb:zrem("log_team_transfer" .. clubid .. ":userid:" .. userid, json))
                        local log_item = cjson.decode(json)

                        -- 增加金额
                        local incrby_score_t = {
                            score = log_item.transfer_score
                        }
                        local source_game_score = db_helper.get_user_game_info(log_item.dest_userid, "score", "bank_score")
                        local updatescore = db_helper.incrby_user_game_info(log_item.dest_userid, incrby_score_t)
                        db_helper.insert_log_change_score("team_transfer", "", log_item.dest_userid, tonumber(source_game_score[1]), log_item.transfer_score, tonumber(source_game_score[2]), 0)
                        cluster.send("cluster_center", "@center", "notify_update_score", log_item.dest_userid, tonumber(updatescore[1]))

                        log_item.state = 1
                        local timestamp = date(log_item.insert_date):totimestamp()
                        json = cjson.encode(log_item)
                        redisdb:zadd("log_team_transfer" .. clubid .. ":userid:" .. userid, timestamp, json)
                        mysql_utils.async_write(mysql_utils.make_update_sql("log_team_transfer" .. clubid, log_item, { id = id }))
                        print("transfer success", clubid, userid, id)
                    end
                end
            end
        end
		print("Watch", key, channel)
	end
end

-- 生成一批gameid存储到mysql
local function make_gameids_to_mysql()
    local total_count = 1000

    local exsit_gameids = {}
    local start_userid = 0
    local result = skynet.call("mysqlpool", "lua", "execute", "select * from config_gameids order by userid asc;", true)
    for _, record in ipairs(result) do
        table.insert(exsit_gameids, record.gameid)
        start_userid = record.userid
    end

    local function make_gameid()
        local gameid
        while true do
            -- 8位数字
            gameid = random.Get(10000000, 99999999)
            for k, v in ipairs(exsit_gameids) do
                if v == gameid then
                    gameid = nil
                    break
                end
            end
            if gameid then
                break
            end
        end
        table.insert(exsit_gameids, gameid)
        return gameid
    end
    
    for i = 1, total_count do
        local gameid = make_gameid()
        skynet.call("mysqlpool", "lua", "execute", string.format("INSERT INTO config_gameids(userid, gameid) VALUES(%d, %d)", start_userid + i, gameid), true)
    end
end

-- 生成一批邀请码存储到mysql
local function make_invite_code_to_mysql()
    local total_count = 1000

    local exsit_ids = {}
    local start_id = 0
    local result = skynet.call("mysqlpool", "lua", "execute", "select * from config_club_invite_code order by id asc;", true)
    for _, record in ipairs(result) do
        table.insert(exsit_ids, record.invite_code)
        start_id = record.id
    end

    local function make_id()
        local id
        while true do
            -- 8位数字
            id = random.Get(10000000, 99999999)
            for k, v in ipairs(exsit_ids) do
                if v == id then
                    id = nil
                    break
                end
            end
            if id then
                break
            end
        end
        table.insert(exsit_ids, id)
        return id
    end
    
    for i = 1, total_count do
        local id = make_id()
        skynet.call("mysqlpool", "lua", "execute", string.format("INSERT INTO config_club_invite_code(id, invite_code) VALUES(%d, %d)", start_id + i, id), true)
    end
end

local CMD = {}

function CMD.start()
    --make_gameids_to_mysql()
    --make_invite_code_to_mysql()

    redisdb = redis.connect(redisconf)
    skynet.fork(watching_expired_event)

    redisdb:flushall()
    load_mysql_to_redis()
    make_tempdata_to_redis()

    exec_timer_0(true)
    exec_timer_5(true)

    local halldbmgr = skynet.uniqueservice("halldbmgr")
    skynet.call(halldbmgr, "lua", "start", skynet.self())

    local logindbmgr = skynet.uniqueservice("logindbmgr")
    skynet.call(logindbmgr, "lua", "start", skynet.self())

    local gamedbmgr = skynet.uniqueservice("gamedbmgr")
    skynet.call(gamedbmgr, "lua", "start", skynet.self())

    local webdbmgr = skynet.uniqueservice("webdbmgr")
    skynet.call(webdbmgr, "lua", "start", skynet.self())

    --print(skynet.call(halldbmgr, "lua", "team_create_club", 1, "", "第1个创建的俱乐部"))
    --print(skynet.call(halldbmgr, "lua", "team_join_club", 3, "", "49651573"))
    --print(skynet.call(halldbmgr, "lua", "team_join_club", 4, "", "37730897"))
    --print(skynet.call(halldbmgr, "lua", "team_join_club", 8, "", "49651573"))
    --print(skynet.call(halldbmgr, "lua", "team_join_club", 9, "", "33799069"))

    --print(skynet.call(halldbmgr, "lua", "team_parent_info", 9, "", 1))
    --print(skynet.call(halldbmgr, "lua", "team_parent_info", 1, "", 1))

    --print(skynet.call(halldbmgr, "lua", "team_myinfo", 9, "", 1))
    --print(skynet.call(halldbmgr, "lua", "team_myinfo", 4, "", 1))
    --print(skynet.call(halldbmgr, "lua", "team_myinfo", 1, "", 1))

    --print(skynet.call(halldbmgr, "lua", "team_members_info", 1, "", 1))

    --print(skynet.call(halldbmgr, "lua", "team_report_info", 1, "", 1, 0))

    --print(skynet.call(halldbmgr, "lua", "team_transfer", 1, "", 1, 3, 10000))

    --print(skynet.call(halldbmgr, "lua", "team_edit_notice", 1, "", 1, "修改公告"))
    --print(skynet.call(halldbmgr, "lua", "team_edit_card", 1, "", 1, "wx", "qq"))
    --print(skynet.call(halldbmgr, "lua", "team_edit_card", 1, "", 1, "wx1", ""))

    --print(skynet.call(halldbmgr, "lua", "team_log_transfer", 1, "", 1))

    --print(skynet.call(halldbmgr, "lua", "team_transfer_cancel", 1, "", 1, 4))
    --print(skynet.call(halldbmgr, "lua", "team_log_transfer", 1, "", 1))

    --print(skynet.call(halldbmgr, "lua", "team_transfer_cancel", 1, "", 1, 7))

    --print(skynet.call(halldbmgr, "lua", "team_team_auto_be_partner", 1, "", 1, true, 50))
    --print(skynet.call(halldbmgr, "lua", "team_join_club", 23, "", "49651573"))

    --print(skynet.call(halldbmgr, "lua", "team_set_partner_share_ratio", 1, "", 1, 23, 40))
    --print(skynet.call(halldbmgr, "lua", "team_set_partner_share_ratio", 1, "", 1, 24, 40))

    --print(skynet.call(halldbmgr, "lua", "team_be_partner", 1, "", 1, 24, 60))
    --print(skynet.call(halldbmgr, "lua", "team_be_partner", 1, "", 1, 23, 70))
    --print(skynet.call(halldbmgr, "lua", "team_be_partner", 1, "", 1, 25, 95))

    --print(skynet.call(halldbmgr, "lua", "team_game_records", 1, "", 1, 1, 0))

    --print(skynet.call(halldbmgr, "lua", "team_report_member_info", 1, "", 1, 1))

    --collect_team_report()
    --print(require("db_helper").create_user("newnickname", "e10adc3949ba59abbe56e057f20f883e", 1, 0, "12345678901", "0.0.0.0", "newdevice", "newuuid", 500000, 9))
end

function CMD.redis_cmd(cmd, ...)
    return redisdb[cmd](redisdb, ...)
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)

    skynet.register(SERVICE_NAME)
end)
