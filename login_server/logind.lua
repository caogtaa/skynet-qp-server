
local login = require "loginserverex"
local crypt = require "skynet.crypt"
local skynet = require "skynet"
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local protobuf = require 'protobuf'

local server = {
    host = "0.0.0.0",
    port = tonumber(skynet.getenv("port")),
    multilogin = false, -- disallow multilogin
    name = "login_master",
    instance = 16,
}

local user_online = {}

local gate_servers = {}

local function select_gate(uid)
    --TODO 可以根据需要(负载, 哈希值, 等)来选择网关
    local name, value = next(gate_servers)
    return value
end

local function register(sdkid, pid, password)
    local account_dc = snax.uniqueservice("accountdc")
    local acc = account_dc.req.get(sdkid, pid)
    if not table.empty(acc) then
        return false
    end
    local uid = account_dc.req.get_nextid()
    if uid < 1 then
        error(LOG_ERROR("register account get nextid failed"))
    end
    local row = { id = uid, pid = pid, sdkid = sdkid, password = password }
    local ret = account_dc.req.add(row)
    if not ret then
        error(LOG_ERROR("register account failed"))
    end
    LOG_INFO("register account succ uid=%d", uid)
    return true
end

local function bind(sdkid1, pid1, sdkid2, pid2, password)
    local account_dc = snax.uniqueservice("accountdc")
    local acc1 = account_dc.req.get(sdkid1, pid1)
    local acc2 = account_dc.req.get(sdkid2, pid2)
    if not table.empty(acc2) then
        error(LOG_WARNING('bind an existing account (%d,%s)', sdkid1, pid1))
    end
    if table.empty(acc1) then
        LOG_WARNING('bind account not exist (%d,%s)', sdkid1, pid1)
        return false
    end
    local id = acc1.id
    -- WTF! because sdkid,pid is uniq index
    account_dc.req.delete(acc1)
    acc1.pid = pid2
    acc1.sdkid = sdkid2
    acc1.password = password
    local ok = account_dc.req.add(acc1)
    LOG_INFO('bind account (%d,%s) by (%d,%s)', sdkid1, pid1, sdkid2, pid2)
    return ok
end

local function auth(username, password, mode, uuid, device)
    local ret = skynet.call("logindbmgr", "lua", "authenticate", username, password, mode, uuid, device)
    if not ret then
        return false, 0
    end

    if ret.username ~= username or ret.password ~= password then
        return false, 0
    end
    return true, ret.userid
end

-- return false if user not registered yet
function server.auth_handler(args)
    local ret = string.split(args, ":")
    assert(#ret == 6)
    local server = ret[1]
    local username = ret[2]
    local password = ret[3]
    local mode = ret[4]
    local uuid = ret[5]
    local device = ret[6]
    skynet.error(args)

    local ok, uid = auth(username, password, mode, uuid, device)
    return ok, server, uid
end

-- called in login master
function server.login_handler(_, uid, secret)
    local gate = select_gate(uid)
    local gatecluster = gate and gate.clustername or "unknown cluster"
    local gateserver = gate and gate.endpoint or "0.0.0.0:0"

	-- only one can login, because disallow multilogin
	local last = user_online[uid]
    if last then
        local pack = netmsg_pack("login.kick", { uid = uid, subid = last.subid })
        local ok = pcall(cluster.call, last.cluster, "@gateway", "pbrpc", pack)
        user_online[uid] = nil
    end
    
    -- the user may re-login after `pcall' above
	if user_online[uid] then
		error(string.format("user %s is already online", uid))
    end

    local pack = netmsg_pack("login.login", { uid = tonumber(uid), secret = secret })
    local ok, subid = pcall(cluster.call, gatecluster, "@gateway", "pbrpc", pack)
    if not ok then
        error(string.format("login gate server [%s] error", gatecluster))
    end

    user_online[uid] = { subid = subid, cluster = gatecluster, secret = secret }

    return subid .. "#" .. gateserver
end

local METHODS = {}

function METHODS.register(sdkid, pid, password)
    local ok = register(tonumber(sdkid), pid, password or '')
    return ok and '200 OK\n' or '406 Exists\n'
end

function METHODS.bind(sdkid1, pid1, sdkid2, pid2, password)
    if tonumber(sdkid1) ~= SDKID_GUEST then
        return '403 Forbidden\n'
    end
    local ok = bind(tonumber(sdkid1), pid1, tonumber(sdkid2), pid2, password or '')
    return ok and '200 OK\n' or '404 Acc Not Found\n'
end

-- called in login slave
function server.method_handler(method, line)
    if METHODS[method] == nil then
        error('method not found')
    end
    return METHODS[method](table.unpack(string.split(line, ':')))
end

local CMD = {}

-- 由gate_server或hall_server调用 切换帐号之类的
function CMD.kick(uid)
    local u = user_online[uid]
    if u then
        LOG_INFO(string.format("%d#%d is logout", uid, u.subid))
        user_online[uid] = nil
    end
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

function CMD.start()
    protobuf.register_file("protocol/netmsg.pb")
    protobuf.register_file("protocol/center.pb")
    protobuf.register_file("protocol/login.pb")

    update_gate_state()
    skynet.fork(function ()
        while true do
            skynet.sleep(60000) -- 600s
            update_gate_state()
        end
    end)
end

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

    local module, method = netmsg.name:match "([^.]*).([^.]*)"
    local f = assert(rpc[method])
	return f(msg)
end

function server.command_handler(command, source, ...)
    local f = assert(CMD[command])
    return f(source, ...)
end

login(server)
