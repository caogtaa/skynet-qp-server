
local crypt = require "client.crypt"
local util = require 'client_util'
local protobuf = require 'protobuf'

protobuf.register_file("protocol/netmsg.pb")
protobuf.register_file("protocol/niuniu.pb")

local fd

local c_game_niuniu = {}


function c_game_niuniu.request_bet(score, sessionid)
    local pack = util.gamemsg_pack("niuniu.request_bet", {bet_score = score}, sessionid)
    return pack
end

function c_game_niuniu.game_msg(method, msg)
    if c_game_niuniu[method] then
        c_game_niuniu[method](msg)
    else
        print(method .. "未处理")
    end
end

return c_game_niuniu
