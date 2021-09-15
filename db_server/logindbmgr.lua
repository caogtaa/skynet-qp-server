local skynet = require "skynet"
require "skynet.manager"
local cluster = require "skynet.cluster"
local random = require "random"
local cjson = require "cjson"
local date = require "date"
local mysql_utils = require "mysql_utils"
local db_helper = require "db_helper"

local CMD = {}

function CMD.start(db)
    cluster.register("logindbmgr")
end

function CMD.stop()
end

-- 验证用户登陆
function CMD.authenticate(username, pwd, mode, uuid, device)
    local ret = db_helper.get_user_account_info_by_username(username, "userid", "username", "password")
    if not ret[1] then
        return false
    end

    local recordset = {}
    recordset.userid = tonumber(ret[1])
    recordset.username = ret[2]
    recordset.password = ret[3]

    return recordset
end

-- 手机注册
function CMD.mobilephone_register(mobilephone, pwd, nickname, gender, invite_code, code, uuid, device, ip)
    -- TODO 进行条件过滤 比如 禁止IP 禁止机器等

    -- 查找重复
    local ret = db_helper.do_redis("get", "user_account_info:mobilephone:" .. mobilephone)
    if ret then
        return false, "手机号已经被注册"
    end

    -- 效验验证码
    local ret_code = db_helper.get_phone_code(mobilephone)
    if not ret then
        return false, "验证码已经失效"
    end
    if ret_code ~= code then
        return false, "验证码错误"
    end

    -- 上级userid
    invite_code = tostring(invite_code)
    local parent_userid = 0
    local clubid = 0    -- 俱乐部
    -- 邀请码是8位
    if invite_code and invite_code ~= "" and string.len(invite_code) == 8 then
        local result = db_helper.do_redis("hmget", "config_club_invite_code:invite_code:" .. invite_code, "userid", "clubid")
        if result[1] and result[2] then
            parent_userid = tonumber(result[1])
            clubid = tonumber(result[2])
        end
    end

    if parent_userid == 0 or clubid == 0 then
        return false, "邀请码无效"
    end

    -- 注册送分
    local register_score = db_helper.do_redis("hget", "config_global:c_name:register_score", "c_value")
    register_score = tonumber(register_score or 0)
    -- TODO 送分限制 检测IP和uuid

    local userid, gameid = db_helper.create_user(nickname, pwd, clubid, gender, mobilephone, ip, device, uuid, register_score, parent_userid)

    -- 返回用户信息
    local recordset = {
        userid = userid,
        username = gameid,
        password = pwd,
    }
    return true, recordset
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd .. "not found")
        skynet.retpack(f(...))
    end)

    skynet.register(SERVICE_NAME)
end)
