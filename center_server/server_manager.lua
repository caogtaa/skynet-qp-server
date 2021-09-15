
local skynet = require "skynet"
local socket = require "skynet.socket"
local cluster = require "skynet.cluster"
local protobuf = require "protobuf"

local CMD = {}
local rpc = {}

local gate_servers = {}
local hall_servers = {}
local game_servers = {}

function CMD.start(conf)
    cluster.register("center")
end

function CMD.notify_update_score(userid, score)
    for k, v in pairs(gate_servers) do
        cluster.send(v.clustername, "@gateway", "center_notify_update_score", userid, score)
    end

    for k, v in pairs(game_servers) do
        cluster.send(v.clustername, "@gamemgr", "center_notify_update_score", userid, score)
    end
end

function CMD.pbrpc(pb)
    local netmsg = protobuf.decode("netmsg.netmsg", pb)
    if not netmsg then
		LOG_ERROR("msg_unpack error")
        error("msg_unpack error")
        return
	end
    local msg = protobuf.decode(netmsg.name, netmsg.payload)
    if not msg then
        LOG_ERROR(netmsg.name .. " decode error")
        return
    end

    local module, method = netmsg.name:match "([^.]*).(.*)"
    local f = assert(rpc[method])
	return f(msg)
end

function rpc.register_gate_server(msg)
    if gate_servers[msg.gate.clusterid] then
        LOG_INFO(msg.gate.clustername .. " gate server already esxit!")
        --return netmsg_pack("center.response", { ret = false, desc = msg.gate.clustername .. " gate server already esxit!" })
    end
    gate_servers[msg.gate.clusterid] = msg.gate
    skynet.error(msg.gate.clusterid .. "= cluster:" .. msg.gate.clustername .. " |endpoint:" .. msg.gate.endpoint)
    return netmsg_pack("center.response", { ret = true, desc = "register gate success" })
end

function rpc.register_hall_server(msg)
    if hall_servers[msg.hall.clusterid] then
        LOG_INFO(msg.hall.clustername .. " hall server already esxit!")
        --return netmsg_pack("center.response", { ret = false, desc = msg.hall.clustername .. " hall server already esxit!" })
    end
    hall_servers[msg.hall.clusterid] = msg.hall
    skynet.error(msg.hall.clusterid .. "= cluster:" .. msg.hall.clustername)
    return netmsg_pack("center.response", { ret = true, desc = "register hall success" })
end

function rpc.register_game_server(msg)
    if game_servers[msg.game.clusterid] then
        LOG_INFO(msg.game.clustername .. " game server already esxit!")
        --return netmsg_pack("center.response", { ret = false, desc = msg.game.clustername .. " game server already esxit!" })
    end
    game_servers[msg.game.clusterid] = msg.game
    skynet.error(msg.game.clusterid .. "= cluster:" .. msg.game.clustername)
    return netmsg_pack("center.response", { ret = true, desc = "register game success" })
end

function rpc.request_gate_server_list(msg)
    local gates = {}
    for name, server in pairs(gate_servers) do
        table.insert(gates, server)
    end
    return netmsg_pack("center.response_gate_server_list", { gates = gates })
end

function rpc.request_hall_server_list(msg)
    local halls = {}
    for name, server in pairs(hall_servers) do
        table.insert(halls, server)
    end
    return netmsg_pack("center.response_hall_server_list", { halls = halls })
end

function rpc.request_game_server_list(msg)
    local games = {}
    for name, server in pairs(game_servers) do
        table.insert(games, server)
    end
    return netmsg_pack("center.response_game_server_list", { games = games })
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)
    
    protobuf.register_file("./protocol/netmsg.pb")
    protobuf.register_file("./protocol/center.pb")
end)
