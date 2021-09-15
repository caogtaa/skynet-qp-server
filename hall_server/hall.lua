
local skynet = require "skynet"
local socket = require "skynet.socket"
local cluster = require "skynet.cluster"
local protobuf = require "protobuf"

local CMD = {}

--暂时用5个 有需要可以增加
local balance = 5
local agent = {}

function CMD.start(source, conf)
    cluster.register("hall")
end

function CMD.pbrpc(source, source_cluster, fd, ip, pb)
    skynet.send(agent[fd % balance + 1], "lua", "forward", source_cluster, fd, ip, pb)
end

function CMD.disconnect(source, source_gate, fd)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(source, ...)))
    end)
    
    protobuf.register_file("./protocol/netmsg.pb")
    protobuf.register_file("./protocol/center.pb")
    protobuf.register_file("./protocol/hall.pb")
    protobuf.register_file("./protocol/login.pb")

    local gametypelist = cluster.call("cluster_db", "halldbmgr", "load_game_type_list")
    local gamekindlist = cluster.call("cluster_db", "halldbmgr", "load_game_kind_list")

    for i= 1, balance do
        agent[i] = skynet.newservice("agent")
        skynet.call(agent[i], "lua", "start", gametypelist, gamekindlist)
    end

    local pack = netmsg_pack("center.register_hall_server", { hall = { clusterid = tonumber(skynet.getenv("clusterid")), clustername = skynet.getenv("clustername") }})
    local ok, ret = pcall(cluster.call, "cluster_center", "@center", "pbrpc", pack)
    if not ok then
        LOG_ERROR("center.register_hall_server failed")
    end

    local module, method, msg = netmsg_unpack(ret)
    skynet.error(msg.desc)
end)
