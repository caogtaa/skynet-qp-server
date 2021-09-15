
-- 游戏实现模版 不要修改 使用请复制一份

local game = {}
local skynet = require "skynet"
local cluster = require "skynet.cluster"
local protobuf = require "protobuf"
local robot = require "robot"

protobuf.register_file("./protocol/netmsg.pb")
local gamename = skynet.getenv("gamename")
protobuf.register_file(string.format("./protocol/%s.pb", gamename))

local robots = {}

-- 设置计时器
local function set_timer(id, delay, repeated)
    game.super.set_timer(id, delay, repeated)
end

-- 删除计时器
local function kill_timer(id)
    game.super.kill_timer(id)
end

-- 开始游戏
local function start_game()
    game.super.start_game()
end

-- 结束游戏
local function end_game()
    game.super.end_game()
end

-- chairid == nil 发送给所有桌上用户
local function send_msg_to_table_chair(method, msg, chairid)
    local packmsg = gamemsg_pack(gamename .. "." .. method, msg)
    if not chairid then
        for k, v in pairs(game.super._table_users) do
            if v.init_game then
                if v.gate ~= "robot" then
                    cluster.send(v.gate, "@gateway", "pbrpc", packmsg, v.fd)
                else
                    robots[v.chairid]:on_game_msg(method, msg)
                end
            end
        end
    else
        local user = game.super._table_users[chairid]
        if not user then
            LOG_ERROR(chairid .. "用户不存在")
            return
        end
        if user.init_game then
            if user.gate ~= "robot" then
                cluster.send(user.gate, "@gateway", "pbrpc", packmsg, user.fd)
            else
                robots[user.chairid]:on_game_msg(method, msg)
            end
        end
    end
end

-- user == nil 发送给所有桌上用户
local function send_msg_to_table_user(method, msg, user)
    local packmsg = gamemsg_pack(gamename .. "." .. method, msg)
    if not user then
        for k, v in pairs(game.super._table_users) do
            if v.init_game then
                if v.gate ~= "robot" then
                    cluster.send(v.gate, "@gateway", "pbrpc", packmsg, v.fd)
                else
                    robots[v.chairid]:on_game_msg(method, msg)
                end
            end
        end
    else
        if user.init_game then
            if user.gate ~= "robot" then
                cluster.send(user.gate, "@gateway", "pbrpc", packmsg, user.fd)
            else
                robots[user.chairid]:on_game_msg(method, msg)
            end
        end
    end
end

-- chairid == nil 发送给所有桌上旁观用户
local function send_msg_to_spectator_chair(method, msg, chairid)
    local packmsg = gamemsg_pack(gamename .. "." .. method, msg)
    for k, v in ipairs(game.super._table_spectator) do
        if v.init_game and (chairid == nil or chairid == v.chairid) then
            cluster.send(v.gate, "@gateway", "pbrpc", packmsg, v.fd)
        end
    end
end

-- user == nil 发送给所有桌上旁观用户
local function send_msg_to_spectator_user(method, msg, user)
    local packmsg = gamemsg_pack(gamename .. "." .. method, msg)
    for k, v in ipairs(game.super._table_spectator) do
        if v.init_game and (user == nil or user == v) then
            cluster.send(v.gate, "@gateway", "pbrpc", packmsg, v.fd)
        end
    end
end

-- 设置游戏状态
local function set_game_status(game_status)
    game.super._game_status = game_status
end

-- 获取游戏状态
local function get_game_status()
    return game.super._game_status
end

-- 根据椅子号获取用户
local function get_table_user(chairid)
    return game.super._table_users[chairid]
end

-- 获取所有桌子用户
local function get_all_table_users()
    return game.super._table_users
end

-- 游戏写分
local function write_user_score(chairid, score, revenue, gamelog, play_time)
    return game.super.write_user_score(chairid, score, revenue, gamelog, play_time)
end

-- 游戏初始化
function game.on_init()
end

-- 游戏重置 一般用于游戏结束后清理相关的逻辑变量
function game.on_game_reset()
end

-- 游戏开始通知
function game.on_game_start()
end

-- 游戏解散通知
function game.on_game_dissolve()
end

-- 通知客户端当前游戏的场景
function game.on_notify_game_scene(chairid, user, game_status)
end

-- 游戏计时器
function game.on_timer(id)
end

-- 客户端发送过来的消息
function game.on_game_msg(msg, user)
    local gamemsg = protobuf.decode(msg.name, msg.payload)
    if not gamemsg then
        LOG_ERROR(msg.name .. " decode error")
        return
    end

    local module, method = msg.name:match "([^.]*).([^.]*)"
    local f = assert(game[method])
    return f(gamemsg, user)
end

-- 机器人发送过来的消息
function game.on_robot_game_msg(method, msg, user)
    local f = assert(game[method])
    return f(msg, user)
end

-- 用户是否正在游戏
function game.is_user_playing(chairid)
    return true
end

-- 用户坐下通知
function game.on_user_sitdown(chairid, user, is_spectator)
    if not is_spectator then
    end
end

-- 用户起立通知
function game.on_user_standup(chairid, user, is_spectator)
    if not is_spectator then
    end
end

-- 用户准备通知
function game.on_user_ready(chairid, user)
end

-- 用户断线通知
function game.on_user_offline(chairid, user)
end

-- 用户重连通知
function game.on_user_reconnect(chairid, user)
end

-- 机器人进入
function game.on_robot_enter(chairid, user)
    robots[chairid] = robot.new(user, game.on_robot_game_msg, game.super.user_ready)
end

-- 机器人离开
function game.on_robot_leave(chairid, user)
    robots[chairid] = nil
end

return game