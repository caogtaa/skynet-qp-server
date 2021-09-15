
local crypt = require "client.crypt"
local util = require 'client_util'
local protobuf = require 'protobuf'
local c_game_niuniu = require "c_game_niuniu"

protobuf.register_file("protocol/netmsg.pb")
protobuf.register_file("protocol/game.pb")
protobuf.register_file("protocol/niuniu.pb")

local fd

local c_game = {}


function c_game.enter_room(userid, sessionid)
    local pack = util.netmsg_pack("game.request_enter_room", {userid = userid, password = "e10adc3949ba59abbe56e057f20f883e", uuid = "windows"}, sessionid)
    return pack
end

function c_game.leave_room(sessionid)
    local pack = util.netmsg_pack("game.request_leave_room", {}, sessionid)
    return pack
end

function c_game.sitdown(tableid, chairid, sessionid)
    local pack = util.netmsg_pack("game.request_sitdown", {tableid = tableid, chairid = chairid}, sessionid)
    return pack
end

function c_game.initgame(sessionid)
    local pack = util.netmsg_pack("game.request_init_game", {}, sessionid)
    return pack
end

function c_game.response_enter_room_failed(msg)
    print(msg)
end

function c_game.notify_room_info(msg)
    print(msg)
end

function c_game.notify_myself_info(msg)
    print(msg) 
end

function c_game.notify_user_enter(msg)
    print(msg) 
end

function c_game.notify_other_users_info(msg)
    print(msg) 
end

function c_game.notify_tables_info(msg)
    print(msg) 
end

function c_game.response_enter_room_success(msg)
    print("login success") 
end

function c_game.reponse_action_failed(msg)
    print(msg) 
end

function c_game.notify_userscore(msg)
    print(msg) 
end

function c_game.notify_userstatus(msg)
    print(msg) 
end

function c_game.gamemsg(msg)
    local gamemsg = protobuf.decode(msg.name, msg.payload)
    if not gamemsg then
        print(msg.name .. " decode error")
        return
    end

    local module, method = msg.name:match "([^.]*).([^.]*)"
    if module == "niuniu" then
        c_game_niuniu.game_msg(method, gamemsg)
    end
end

function c_game.shutdown()
end

return c_game

