--websocket协议的网关
--负责连接验证以及网络协议解析和网络数据的转发
local skynet = require "skynet"
local crypt = require "skynet.crypt"
local netpack = require "skynet.netpack"
local cluster = require "skynet.cluster"
local socket = require "skynet.socket"
local protobuf = require "protobuf"

local subid_online = {} -- subid -> { uid, secret, handshake_index, agent, source_login }

local internal_id = 0

--暂时用5个 有需要可以增加
local balance = 5
local wsagent = {}

local hall_servers = {}     -- 大厅服务器集群
local game_servers = {}     -- 游戏服务器集群
local backend_servers = {}  -- 所有后端服务器 大厅+游戏

-- 从中心服务器获取所有大厅服务器
local function update_hall_state()
    local pack = netmsg_pack("center.request_hall_server_list", {})
    local ok, ret = pcall(cluster.call, "cluster_center", "@center", "pbrpc", pack)
    if not ok then
        LOG_ERROR("update_hall_state failed")
        return
    end

    local module, method, msg = netmsg_unpack(ret)
    hall_servers = msg.halls
    
    skynet.error("hall server begin")
    for k, v in pairs(msg.halls) do
        skynet.error(v.clusterid .. "=" .. v.clustername)
    end
    skynet.error("hall server end")
end

-- 从中心服务器获取所有游戏服务器
local function update_game_state()
    local pack = netmsg_pack("center.request_game_server_list", {})
    local ok, ret = pcall(cluster.call, "cluster_center", "@center", "pbrpc", pack)
    if not ok then
        LOG_ERROR("update_game_state failed")
        return
    end

    local module, method, msg = netmsg_unpack(ret)
    game_servers = msg.games
    
    skynet.error("game server begin")
    for k, v in pairs(msg.games) do
        skynet.error(v.clusterid .. "=" .. v.clustername)
    end
    skynet.error("game server end")
end

-- 从中心服务器获取所有后端服务器
local function update_server_state()
    update_hall_state()
    update_game_state()

    backend_servers = {}
    for k, v in pairs(hall_servers) do
        backend_servers[v.clusterid] = { module = "hall", clustername = v.clustername }
    end

    for k, v in pairs(game_servers) do
        backend_servers[v.clusterid] = { module = "game", clustername = v.clustername }
    end

    for k, v in pairs(wsagent) do
        skynet.send(v, "lua", "serverlist", hall_servers, backend_servers)
    end
end

-- 统计网络错误
local function collect_error(uid, ip, reason)
    if not reason or reason == NERR_NORMAL then
        return
    end

    -- TODO 根据规则 可以加入黑名单等
    LOG_ERROR(string.format("%d(%s)网络错误:%d", uid, ip, reason))
end

local CMD = {}
local rpc = {}

function CMD.close_conn(source, fd, reason)
    skynet.send(wsagent[fd % balance + 1], "lua", "close_conn", fd, reason)
end

function CMD.pbrpc(source, pb, fd)
    if fd then
        skynet.send(wsagent[fd % balance + 1], "lua", "forward", fd, pb)
    else
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
        return f(source, msg)
    end
end

-- 由登陆服务器调用
function rpc.kick(source, msg)
    if msg.subid then
        local s = subid_online[msg.subid]
        if s and s.agent then
            skynet.call(s.agent, "lua", "kick", msg.uid)
        end
        subid_online[msg.subid] = nil
    end
end

-- 由登陆服务器调用
function rpc.login(source, msg)
    internal_id = internal_id + 1
    local subid = internal_id

    subid_online[subid] = { uid = msg.uid, secret = msg.secret, handshake_index = 0, source_login = source }

    return subid
end

function CMD.start(source, conf)
    cluster.register("gateway")

    protobuf.register_file("./protocol/netmsg.pb")
    protobuf.register_file("./protocol/center.pb")
    protobuf.register_file("./protocol/hall.pb")
    protobuf.register_file("./protocol/login.pb")
    protobuf.register_file("./protocol/game.pb")

    local pack = netmsg_pack("center.register_gate_server", { gate = { clusterid = tonumber(skynet.getenv("clusterid")), clustername = skynet.getenv("clustername"), endpoint = skynet.getenv("endpoint") }})
    local ok, ret = pcall(cluster.call, "cluster_center", "@center", "pbrpc", pack)
    if not ok then
        LOG_ERROR("center.register_gate_server failed")
    end

    local module, method, msg = netmsg_unpack(ret)
    skynet.error(msg.desc)

    for i= 1, balance do
        wsagent[i] = skynet.newservice("wsagent", skynet.self())
    end

    local endpoint = skynet.getenv("endpoint")
	local ip, port = string.match(endpoint, "([^:]*):([^:]*)")
    ip = "0.0.0.0"
    local protocol = "ws"
	local s = socket.listen(ip, tonumber(port))
	skynet.error(string.format("Listen websocket %s protocol:%s", endpoint, protocol))
    socket.start(s, function(id, addr)
        skynet.send(wsagent[id % balance + 1], "lua", id, protocol, addr)
    end)

    update_server_state()
    skynet.fork(function ()
        while true do
            skynet.sleep(60000) -- 600s
            update_server_state()
        end
    end)
end

function CMD.auth(source, subid)
    -- TODO 判断黑名单用户和IP
    return subid_online[tonumber(subid)]
end

function CMD.unauth(source, subid, uid, ip, reason)
    collect_error(uid, ip, reason)
    subid_online[tonumber(subid)] = nil
end

function CMD.handshake(source, subid, index, agent)
    local user = subid_online[tonumber(subid)]
    if user then
        user.handshake_index = index
        user.agent = tonumber(agent)
        return true
    end
    return false
end

function CMD.center_notify_update_score(source, userid, score)
    for k, v in pairs(subid_online) do
        if v.uid == userid then
            skynet.send(v.agent, "lua", "center_notify_update_score", userid, score)
            break
        end
    end
end

skynet.start(function ()
    skynet.dispatch("lua", function(_, source, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(source,...)))
    end)
end)
