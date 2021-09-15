local skynet = require "skynet"
require "skynet.manager"
local cluster = require "skynet.cluster"
local cjson = require "cjson"
local date = require "date"
local db_helper = require "db_helper"
local mysql_utils = require "mysql_utils"

local CMD = {}

function CMD.start(db)
    cluster.register("gamedbmgr")
end

function CMD.stop()
end

function CMD.get_user_score(userid)
    local ret = db_helper.get_user_game_info(userid, "score")
    return tonumber(ret[1])
end

-- 用户进入房间
function CMD.game_user_enter_room(userid, pwd, ip, uuid, kindid, roomid)
    local account_keys = {
        "password", "gameid", "username", "nickname", "faceid", "head_img_url", "gender", "signature",
        "vip_level", "master_level", "is_robot", "disabled", "clubids", "selected_clubid"
    }
    local ret_account = db_helper.get_user_account_info_by_userid(userid, table.unpack(account_keys))
    if #ret_account == 0 then
        return false, "用户不存在"
    end
    local user = {}
    for k, v in ipairs(account_keys) do
        user[v] = ret_account[k]
    end
    if not (user.is_robot == "1" and ip == "0.0.0.0" and uuid == "internal") then
        if user.password ~= pwd then
            return false, "密码错误"
        elseif user.disabled ~= "0" then
            return false, "用户被禁用"
        end
    end

    local game_keys = {
        "score", "bank_score", "win_count", "draw_count", "lost_count", "play_time", "experience", "recharge_score",
        "recharge_times", "exchage_score", "exchange_times", "balance_score", "today_balance_score"
    }
    local ret_game = db_helper.get_user_game_info(userid, table.unpack(game_keys))
    if #ret_game == 0 then
        return false, "用户不存在"
    end

    for k, v in ipairs(game_keys) do
        user[v] = ret_game[k]
    end

    if tonumber(user.score) < 0 then
        return false, "用户分数异常"
    end

    -- 查看是否在游戏房间中
    local lockinfo = db_helper.do_redis("hmget", "temp_game_user_lock_info:userid:" .. userid, "kindid", "roomid", "inout_index")
    if table.empty(lockinfo) then
        local id, enter_date = db_helper.insert_log_user_inout(userid, kindid, roomid, tonumber(user.score), ip, uuid)

        -- 锁定房间
        local lock_t = {
            userid = userid, 
            kindid = kindid,
            roomid = roomid, 
            inout_index = id,
            enter_ip = ip,
            enter_uuid = uuid,
            enter_date = enter_date
        }
        lockinfo.inout_index = id
        db_helper.do_redis("hmset", "temp_game_user_lock_info:userid:" .. userid, table.tunpack(lock_t))
    else
        lockinfo.inout_index = lockinfo[3]
    end

    local recordset = {
        userid = userid,
        gameid = tonumber(user.gameid),
        username = user.username,
        nickname = user.nickname,
        faceid = tonumber(user.faceid),
        head_img_url = user.head_img_url,
        gender = tonumber(user.gender),
        signature = user.signature,
        vip_level = tonumber(user.vip_level),
        master_level = tonumber(user.master_level),
        is_robot = tonumber(user.is_robot) ~= 0 and true or false,
        clubids = string.split(user.clubids, ","),
        selected_clubid = tonumber(user.selected_clubid),
        score = tonumber(user.score),
        bank_score = tonumber(user.bank_score),
        win_count = tonumber(user.win_count),
        lost_count = tonumber(user.lost_count),
        draw_count = tonumber(user.draw_count),
        play_time = tonumber(user.play_time),
        experience = tonumber(user.experience),
        recharge_score = tonumber(user.recharge_score),
        recharge_times = tonumber(user.recharge_times),
        exchage_score = tonumber(user.exchage_score),
        exchange_times = tonumber(user.exchange_times),
        balance_score = tonumber(user.balance_score),
        today_balance_score = tonumber(user.today_balance_score),
        inout_index = tonumber(lockinfo.inout_index),
    }

    return true, recordset
end

-- 用户离开房间
function CMD.game_user_leave_room(userid, inout_index, score, revenue, play_time, kindid, roomid, ip, uuid)
    -- 删除记录
    db_helper.do_redis("del", "temp_game_user_locker:" .. userid)

    -- 更新进出记录
    db_helper.update_log_user_inout(userid, inout_index, score, revenue, play_time, ip, uuid)
end

-- 用户写分
function CMD.game_write_user_score(userid, score, revenue, play_time, kindid, roomid, drawid)
    local keys = {
        "score", "bank_score"
    }
    local values = db_helper.get_user_game_info(userid, table.unpack(keys))
    local win_count = 0
    local lost_count = 0
    local draw_count = 0
    if score > 0 then
        win_count = 1
    elseif score < 0 then
        lost_count = 1
    else
        draw_count = 1
    end

    local update_t = {
        score = score,
        revenue = revenue,
        win_count = win_count,
        lost_count = lost_count,
        draw_count = draw_count,
        play_time = play_time,
        balance_score = score,
        today_balance_score = score,
    }
    db_helper.incrby_user_game_info(userid, update_t)

    db_helper.insert_log_change_score("game", tostring(drawid), userid, tonumber(values[1]), score, tonumber(values[2]), 0, kindid, roomid)
end

-- 游戏记录
function CMD.game_write_game_record(drawid, kindid, roomid, tableid, user_count, robot_count, score, revenue, str_start_time, str_end_time, wanfa)
    db_helper.insert_log_game_record(drawid, kindid, roomid, tableid, user_count, robot_count, score, revenue, str_start_time, str_end_time, wanfa)
end

-- 游戏记录细节
function CMD.game_write_game_record_detail(userid, drawid, kindid, roomid, tableid, chairid, score, revenue, start_score, start_bank_score, play_time, gamelog, wanfa, clubid, performance)
    db_helper.insert_log_game_record_detail(userid, drawid, kindid, roomid, tableid, chairid, score, revenue, start_score, start_bank_score, play_time, gamelog, wanfa, clubid, performance)
end

-- 加载机器人
function CMD.game_robot_lock(kindid, roomid)
    local ret = db_helper.do_redis("get", string.format("config_game_robot_rule:kindid:%d:roomid:%d", kindid, roomid))
    local recordset = {}
    if ret then
        local robotrule = cjson.decode(ret)
        local robotcnt = db_helper.do_redis("scard", "temp_game_robot_userinfo:roomid:" .. roomid)
        local lock_rotob_cnt = math.random(tonumber(robotrule.min_robot_count), tonumber(robotrule.max_robot_count))
        local members
        if robotcnt < lock_rotob_cnt then
            robotcnt = lock_rotob_cnt - robotcnt
            members = db_helper.do_redis("srandmember", "temp_game_robot_userinfo:free", robotcnt)
            if #members > 0 then
                db_helper.do_redis("srem", "temp_game_robot_userinfo:free", table.unpack(members))
                db_helper.do_redis("sadd", "temp_game_robot_userinfo:roomid:" .. roomid, table.unpack(members))
            end
        end

        for _, m in ipairs(members or {}) do
            local t = table.clone(robotrule, true)
            t.userid = tonumber(m)
            t.password = ""
            table.insert(recordset, t)
        end
        
    end

    return true, recordset
end

-- 删除机器人
function CMD.game_robot_unlock(userid, roomid)
    if userid == 0 then
        local members = db_helper.do_redis("smembers", "temp_game_robot_userinfo:roomid:" .. roomid)
        if #members > 0 then
            db_helper.do_redis("sadd", "temp_game_robot_userinfo:free", table.unpack(members))
        end
        db_helper.do_redis("del", "temp_game_robot_userinfo:roomid:" .. roomid)
    else
        db_helper.do_redis("sadd", "temp_game_robot_userinfo:free", userid)
        db_helper.do_redis("srem", "temp_game_robot_userinfo:roomid:" .. roomid, userid)
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd .. "not found")
        skynet.retpack(f(...))
    end)

    skynet.register(SERVICE_NAME)
end)
