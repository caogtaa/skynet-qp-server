--负责连接验证以及网络协议解析和网络数据的转发
local skynet = require "skynet"
local gateserver = require "snax.gateserver"
local crypt = require "skynet.crypt"
local socketdriver = require "skynet.socketdriver"
local netpack = require "skynet.netpack"
local cluster = require "skynet.cluster"
local protobuf = require "protobuf"

local connection = {}	-- fd -> connection : { fd, ip， uid, activetime }
local user_online = {}  -- uid -> { fd, ip, subid }
local subid_online = {} -- subid -> { uid, secret, handshake_index }
local handshake = {}	-- 握手验证

local internal_id = 0

local hall_servers = {}
local game_servers = {}
local backend_servers = {}

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

local function update_game_state()
    local pack = netmsg_unpack("center.request_game_server_list", {})
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

local function update_server_state()
    update_hall_state()
    update_game_state()

    backend_servers = {}
    for k, v in pairs(hall_servers) do
        backend_servers[v.clusterid] = v.clustername
    end

    for k, v in pairs(game_servers) do
        backend_servers[v.clusterid] = v.clustername
    end

    skynet.error("backend server begin")
    skynet.error(tostring(backend_servers))
    skynet.error("backend server end")
end

local function close_fd(fd)
	local c = connection[fd]
	if c then
        local uid = connection[fd]
        if uid then
            user_online[uid] = nil
        end
		connection[fd] = nil
	end
end

local function kick_fd(fd, logout)
    local c = connection[fd]
	if c then
        local uid = connection[fd]
        if uid then
            if logout then
                local subid = user_online[uid].subid
                local pack = netmsg_pack("login.kick", { uid = uid, subid = subid })
                cluster.send("cluster_login", "@logind", "pbrpc", pack)
                subid_online[subid] = nil
            end
            user_online[uid] = nil
        end
		connection[fd] = nil
    end
    handshake[fd] = nil
    gateserver.closeclient(fd)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

local handler = {}

local function doauth(fd, message, addr)
    local subid, index, hmac = string.match(message, "([^:]*):([^:]*):([^:]*)")
    hmac = crypt.base64decode(hmac)

    local user = subid_online[tonumber(subid)]
    if user == nil then
        return "404 User Not Found"
    end

    local idx = assert(tonumber(index))

    if idx ~= user.handshake_index then
        return "403 Index Expired"
    end

    local text = string.format("%d", subid)
    local calculated = crypt.hmac_hash(user.secret, subid)
    
    if calculated ~= hmac then
        return "401 Unauthorized"
	end
	
    user.handshake_index = idx
    
    user_online[user.uid] = { subid = subid, fd = fd, ip = addr }
    connection[fd].uid = user.uid
end

local function auth(fd, addr, msg, sz)
    local message = netpack.tostring(msg, sz)
    local ok, result = pcall(doauth, fd, message, addr)

    if not ok then
        LOG_WARNING("gate bad request " .. message)
        result = "400 Bad Request"
    end

    local close = result ~= nil

    if result == nil then
        result = "200 OK"
    end

    --notify client auth result
    socketdriver.send(fd, netpack.pack(result))

    if close then
        connection[fd] = nil
        handshake[fd] = nil
        gateserver.closeclient(fd)
    end
end

local function forward_to_backend(fd, addr, msg, sz)
    local pb = skynet.tostring(msg, sz)

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

    if netmsg.name == "netmsg.heartbeat" then
        skynet.error("heartbeat")
        return
    end

    local module, method = netmsg.name:match "([^.]*).(.*)"
    skynet.error(method)

    local clustername = backend_servers[netmsg.sessionid]
    if clustername then
        local ok = pcall(cluster.send, clustername, "@" .. module, "pbrpc", fd, addr, pb)
        if not ok then
            LOG_INFO(netmsg.name .. " forward " .. clustername .. " failed")
            kick_fd(fd, true)
        end
    else
        kick_fd(fd, true)
        LOG_INFO(netmsg.name .. " forward failed, clustername not exsit " .. netmsg.sessionid)
    end
end

function handler.open(source, conf)
    cluster.register("gateway")

    protobuf.register_file("./protocol/netmsg.pb")
    protobuf.register_file("./protocol/center.pb")
    protobuf.register_file("./protocol/hall.pb")
    protobuf.register_file("./protocol/login.pb")

    local pack = netmsg_pack("center.register_gate_server", { gate = { clusterid = tonumber(skynet.getenv("clusterid")), clustername = skynet.getenv("clustername"), endpoint = skynet.getenv("endpoint") }})
    local ok, ret = pcall(cluster.call, "cluster_center", "@center", "pbrpc", pack)
    if not ok then
        LOG_ERROR("center.register_gate_server failed")
    end

    local module, method, msg = netmsg_unpack(ret)
    skynet.error(msg.desc)

    update_server_state()
    skynet.fork(function ()
        while true do
            skynet.sleep(60000) -- 600s
            update_server_state()
        end
    end)

    -- 心跳包
    skynet.fork(function()
        local pack = netmsg_pack("netmsg.heartbeat", {})
        while true do
            local now = os.time()
            local logout = {}
            for k, v in pairs(connection) do
                if now - v.activetime >= 600 then
                    table.insert(logout, k)
                elseif now - v.activetime >= 5 then
                    socketdriver.send(k, netpack.pack(pack))
                end
            end
            for k, v in ipairs(logout) do
                kick_fd(v)
            end
			skynet.sleep(1000)
		end
	end)
end

function handler.message(fd, msg, sz)
    local addr = handshake[fd]

    if addr then
        handshake[fd] = nil

        auth(fd, addr, msg, sz)
    else
        local a = connection[fd]
        a.activetime = os.time()
        if a.uid then
            forward_to_backend(fd, a.ip, msg, sz)
        else
			skynet.trash(msg,sz)
			skynet.error("unknown socket data")
			--TODO可以直接踢掉 因为正常流程是等到验证完成后才发送其他消息
        end
    end
end

function handler.connect(fd, addr)
    local c = {
		fd = fd,
        ip = addr,
        activetime = os.time()
    }
	connection[fd] = c
    gateserver.openclient(fd)
    handshake[fd] = addr
end

function handler.disconnect(fd)
    handshake[fd] = nil
    close_fd(fd)
    gateserver.closeclient(fd)
end

function handler.error(fd, msg)
    handshake[fd] = nil
    close_fd(fd)
    gateserver.closeclient(fd)
end

function handler.warning(fd, size)
    print("socket warning", fd, size)
end

local CMD = {}
local rpc = {}

function CMD.pbrpc(source, pb)
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
	return f(source, netmsg, msg)
end

function handler.command(cmd, source, ...)
    local f = assert(CMD[cmd])
	return f(source, ...)
end

-- call by login server
function rpc.kick(source, netmsg, msg)
    if msg.subid then
        subid_online[msg.subid] = nil
    end

    local u = user_online[msg.uid]
    handshake[u.fd] = nil
    close_fd(u.fd)
    gateserver.closeclient(u.fd)
end

-- call by login server
function rpc.login(source, netmsg, msg)
    internal_id = internal_id + 1
    local subid = internal_id

    local u = user_online[msg.uid]
    if u and subid_online[u.subid] then
        error(string.format("%d is already login", msg.uid))
    end

    subid_online[subid] = { uid = msg.uid, secret = msg.secret, handshake_index = 0 }

    return subid
end

function rpc.ResponseTest(source, netmsg, msg)
    skynet.error(msg.res)
    local pack = netmsg_pack("hall.ResponseTest", msg)
    socketdriver.send(netmsg.fd, netpack.pack(pack))
end

gateserver.start(handler)
