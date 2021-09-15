local skynet = require "skynet"
local crypt = require "skynet.crypt"
local netpack = require "skynet.netpack"
local cluster = require "skynet.cluster"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local protobuf = require "protobuf"

local __TEST__ = true

local CMD = {}

local connection = {}	-- fd -> connection : { fd, ip， uid, activetime,secret }
local user_online = {}  -- uid -> { fd, ip, subid }
local handshake = {}	-- 握手验证

local backend_servers = {}
local hall_servers = {}

local wsgateway = tonumber(...)

local source_cluster = tostring(skynet.getenv("clustername"))

-- 选择一个大厅服务器来服务 可以根据需要设计其他规则来分配大厅服务
local function select_hall(fd)
    local result = {}
    local size = 0
    for _, v in pairs(hall_servers) do
        size = size + 1
        table.insert(result, v)
    end
    if size == 0 then
        return ""
    end
    return result[1 + fd % size].clusterid
end

-- 通知hall_server和game_server客户端连接中断
-- TODO 保存用户所在的大厅和游戏服务器 直接向指定地址发送
local function disconnect(fd)
    for k, v in pairs(backend_servers) do
        cluster.send(v.clustername, "@" .. v.module, "disconnect", source_cluster, fd)
    end
end

-- 关闭网络连接
local function close_fd(fd, reconnect)
	local c = connection[fd]
	if c then
        local uid = connection[fd]
        if uid then
            disconnect(fd)
            user_online[uid] = nil
        end
		connection[fd] = nil
    end
    handshake[fd] = nil
    websocket.close(fd, not reconnect and 10054 or nil)
end

-- 踢出用户 同时关闭网络连接
local function kick_fd(fd, reason)
    local c = connection[fd]
	if c then
        local uid = c.uid
        if uid then
            disconnect(fd)

            local subid = user_online[uid].subid
            pcall(skynet.send, wsgateway, "lua", "unauth", subid, uid, ip, reason)
            local pack = netmsg_pack("login.kick", { uid = uid, subid = subid })
            pcall(cluster.send, c.source_login, "@login", "pbrpc", pack)

            user_online[uid] = nil
        end
		connection[fd] = nil
    end
    handshake[fd] = nil

    websocket.close(fd, 10054)
end

local function doauth(fd, message, addr)
    local subid, index, hmac = string.match(message, "([^:]*):([^:]*):([^:]*)")
    hmac = crypt.base64decode(hmac)

    local ok, ret = pcall(skynet.call, wsgateway, "lua", "auth", subid)
    if not ok or not ret then
        return "404 User Not Found"
    end

    local idx = assert(tonumber(index))

    if idx ~= ret.handshake_index then
        return "403 Index Expired"
    end

    if not __TEST__ then
        local calculated = crypt.hmac_hash(ret.secret, subid)
        if calculated ~= hmac then
            return "401 Unauthorized"
        end
    end
    
    local ok, r = pcall(skynet.call, wsgateway, "lua", "handshake", subid, idx + 1, skynet.self())
    if not ok or not r then
        return "405 handshake failed"
    end
    
    user_online[ret.uid] = { subid = subid, fd = fd, ip = addr }
    connection[fd].uid = ret.uid
    connection[fd].secret = ret.secret
end

local function auth(fd, addr, message)
    local ok, result = pcall(doauth, fd, message, addr)

    if not ok then
        LOG_WARNING("wsagent bad request " .. message)
        result = "400 Bad Request"
    end

    local close = result ~= nil

    if result == nil then
        local sessionid = select_hall(fd)
        result = "200 OK" .. sessionid
    end

    --notify client auth result
    websocket.write(fd, result)

    if close then
        close_fd(fd)
    end
end

local function forward_to_backend(fd, addr, pb)
    local netmsg = protobuf.decode("netmsg.netmsg", pb)
    if not netmsg then
		LOG_ERROR("msg_unpack error")
        error("msg_unpack error")
        kick_fd(fd, NERR_INVALID_PACK)
        return
    end
    local msg = protobuf.decode(netmsg.name, netmsg.payload)
    if not msg then
        LOG_ERROR(netmsg.name .. " decode error")
        kick_fd(fd, NERR_INVALID_PACK)
        return
    end

    local a = connection[fd]
    a.activetime = skynet.time()

    if netmsg.name == "netmsg.heartbeat" then
        --skynet.error("heartbeat", os.time())
        CMD.forward(fd, pb)
        return
    end

    local module, method = netmsg.name:match "([^.]*).([^.]*)"

    local clustername = backend_servers[netmsg.sessionid]
    if clustername then
        local ok = pcall(cluster.send, clustername.clustername, "@" .. module, "pbrpc", source_cluster, fd, addr, pb)
        if not ok then
            LOG_INFO(netmsg.name .. " forward " .. clustername.clustername .. " failed")
            kick_fd(fd, NERR_INVALID_PACK)
        end
    else
        kick_fd(fd, NERR_INVALID_PACK)
        LOG_INFO(netmsg.name .. " forward failed, cluster not exsit " .. netmsg.sessionid)
    end
end

local handler = {}

function handler.connect(id)
    print("ws connect from: " .. tostring(id))
end

function handler.handshake(id, header, url)
    local addr = websocket.addrinfo(id)

    local c = {
		fd = id,
        ip = addr,
        activetime = skynet.time()
    }
	connection[id] = c
    handshake[id] = addr
end

function handler.message(id, msg)
    local addr = handshake[id]
    if addr then
        handshake[id] = nil

        auth(id, addr, msg)
    else
        local a = connection[id]
        if a.uid then
            local pb
            if not __TEST__ then
                pb = crypt.desdecode(a.secret, msg)
            else
                pb = msg
            end
            forward_to_backend(id, a.ip, pb)
        else
            skynet.error("unknown socket data")
            close_fd(id)
        end
    end
end

--[[
function handler.message(id, msg)
    websocket.write(id, msg)
end
]]

function handler.ping(id)
    print("ws ping from: " .. tostring(id) .. "\n")
end

function handler.pong(id)
    print("ws pong from: " .. tostring(id))
end

function handler.close(id, code, reason)
    print("ws close from: " .. tostring(id), code, reason)


    local c = connection[id]
	if c then
        disconnect(id)
        local uid = connection[id]
        if uid then
            user_online[uid] = nil
        end
		connection[id] = nil
    end
    handshake[id] = nil
end

function handler.error(id)
    print("ws error from: " .. tostring(id))

    local c = connection[id]
	if c then
        disconnect(id)
        local uid = connection[id]
        if uid then
            user_online[uid] = nil
        end
		connection[id] = nil
    end
    handshake[id] = nil
end

function CMD.kick(uid)
    local u = user_online[uid]
    if u then
        -- 通知客户端
        local pack = netmsg_pack("netmsg.notify_system_message", { type = NMT_CLOSE_HALL, text = "您的帐号已经在其他地方登陆" })
        CMD.forward(u.fd, pack)
        close_fd(u.fd)
    end
end

function CMD.close_conn(fd, reason)
    kick_fd(fd, reason)
end

function CMD.forward(fd, pack)
    local a = connection[fd]
    if a then
        local pb
        if not __TEST__ then
            pb = crypt.desencode(a.secret, pack)
        else
            pb = pack
        end
        websocket.write(fd, pb, "binary")
    else
        LOG_ERROR("connection already invalid")
    end
end

function CMD.serverlist(halllist, list)
    hall_servers = halllist
    backend_servers = list
end

function CMD.center_notify_update_score(userid, score)
    if user_online[userid] then
        local pack = netmsg_pack("netmsg.notify_update_score", { score = score })
        CMD.forward(user_online[userid].fd, pack)
    end
end

skynet.start(function ()
    skynet.dispatch("lua", function (_,_, id, ...)
        local t = type(id)
        if t == "number" then
            local ok, err = websocket.accept(id, handler, ...)
            if not ok then
                print(err)
            end
        else
            local f = CMD[id]
            skynet.ret(skynet.pack(f(...)))
        end
    end)

    protobuf.register_file("./protocol/netmsg.pb")
    protobuf.register_file("./protocol/center.pb")
    protobuf.register_file("./protocol/login.pb")
    protobuf.register_file("./protocol/hall.pb")
    protobuf.register_file("./protocol/game.pb")

    skynet.fork(function()
        while true do
            local now = skynet.time()
            local logout = {}
            local closecon = {}
            for k, v in pairs(connection) do
                if now - v.activetime >= 600 then
                    table.insert(logout, k)
                elseif now - v.activetime >= 3 then
                    table.insert(closecon, k)
                end
            end
            for k, v in ipairs(logout) do
                kick_fd(v)
            end
            for k, v in ipairs(closecon) do
                close_fd(v, true)
            end

			skynet.sleep(100)
		end
	end)
end)
