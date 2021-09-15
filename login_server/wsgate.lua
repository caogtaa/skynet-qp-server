--websocket协议的网关
local skynet = require "skynet"
local crypt = require "skynet.crypt"
local netpack = require "skynet.netpack"
local cluster = require "skynet.cluster"
local socket = require "skynet.socket"
local protobuf = require "protobuf"

--暂时用5个 有需要可以增加
local balance = 5
local wsagent = {}

local user_online = {}

local gate_servers = {}

-- 选择一个网关服务器服务
local function select_gate(uid)
    --TODO 可以根据需要(负载, 哈希值, 等)来选择网关
    local name, value = next(gate_servers)
    return value
end

local CMD = {}
local rpc = {}

-- 由wsagent调用
function CMD.login(uid, secret)
    local gate = select_gate(uid)
    local gatecluster = gate and gate.clustername or "unknown cluster"
    local gateserver = gate and gate.endpoint or "0.0.0.0:0"

	-- 不允许重复登陆
	local last = user_online[uid]
    if last then
        local pack = netmsg_pack("login.kick", { uid = uid, subid = last.subid })
        local ok = pcall(cluster.call, last.cluster, "@gateway", "pbrpc", pack)
        user_online[uid] = nil
    end
    
    -- 用户可能在上面的pcall时重新登陆
	if user_online[uid] then
        return false, "405 user is already online"
    end

    local pack = netmsg_pack("login.login", { uid = tonumber(uid), secret = secret })
    local ok, subid = pcall(cluster.call, gatecluster, "@gateway", "pbrpc", pack)
    if not ok then
        --error(string.format("login gate server [%s] error", gatecluster))
        LOG_ERROR(string.format("login gate server [%s] error", gatecluster))
        return false, "406 gate server error"
    end

    user_online[uid] = { subid = subid, cluster = gatecluster, secret = secret }

    return true, subid .. "#" .. gateserver
end

-- 由gate_server或hall_server调用 切换帐号之类的
function rpc.kick(msg)
    local u = user_online[msg.uid]
    if u then
        LOG_INFO(string.format("%d#%d is logout", msg.uid, u.subid))
        user_online[msg.uid] = nil
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

local function update_gate_state()
    local pack = netmsg_pack("center.request_gate_server_list", {})
    local ok, ret = pcall(cluster.call, "cluster_center", "@center", "pbrpc", pack)
    if not ok then
        LOG_ERROR("update_gate_state failed")
        return
    end

    local module, method, msg = netmsg_unpack(ret)
    gate_servers = msg.gates
    
    skynet.error("gate server begin")
    for k, v in pairs(msg.gates) do
        skynet.error(v.clusterid .. "=" .. v.endpoint)
        skynet.error(v.clustername)
    end
    skynet.error("gate server end")
end

function CMD.start(conf)
    cluster.register("login")

    protobuf.register_file("./protocol/netmsg.pb")
    protobuf.register_file("./protocol/center.pb")
    protobuf.register_file("./protocol/login.pb")

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
		print(string.format("accept client socket_id: %s addr:%s", id, addr))

        skynet.send(wsagent[id % balance + 1], "lua", id, protocol, addr)
    end)

    update_gate_state()
    skynet.fork(function ()
        while true do
            skynet.sleep(60000) -- 600s
            update_gate_state()
        end
    end)
end

skynet.start(function ()
    skynet.dispatch("lua", function(_,_, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)
end)
