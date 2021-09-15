
local socket = require "client.socket"
local crypt = require "client.crypt"
local util = require 'client_util'
local protobuf = require 'protobuf'

protobuf.register_file("protocol/netmsg.pb")
protobuf.register_file("protocol/hall.pb")

local c_hall = {}
local sessionid = 0

function c_hall.set_sessionid(sid)
    sessionid = sid
end

function c_hall.request_game_list()
    local pack = util.netmsg_pack("hall.request_game_list", {}, sessionid)
    return pack
end

function c_hall.response_game_type_list(msg)
    print(msg)
end

function c_hall.response_game_kind_list(msg)
    print(msg) 
end

function c_hall.response_game_room_list(msg)
    print(msg) 
end

return c_hall
