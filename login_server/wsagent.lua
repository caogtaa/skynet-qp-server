local skynet = require "skynet"
local crypt = require "skynet.crypt"
local netpack = require "skynet.netpack"
local cluster = require "skynet.cluster"
local socket = require "skynet.socket"
local websocket = require "http.websocket"

local user_auth = {}    -- fd ->

--[[

General Protocol:
    Client->Server: LS $method (method can be: login|...)

Login Protocol:
    1. Server->Client : base64(8bytes random challenge)
    2. Client->Server : base64(8bytes handshake client key)
    3. Server: Gen a 8bytes handshake server key
    4. Server->Client : base64(DH-Exchange(server key))
    5. Server/Client secret := DH-Secret(client key/server key)
    6. Client->Server : base64(HMAC(challenge, secret))
    7. Client->Server : DES(secret, base64(token))
    8. Server : call auth_handler(token) -> server, uid (A user defined method)
    9. Server : call login_handler(server, uid, secret) ->subid (A user defined method)
    10. Server->Client : 200 base64(subid#gate)

Error Code:
    400 Bad Request . challenge failed
    401 Unauthorized . unauthorized by auth_handler
    403 Forbidden . login_handler failed
    404 User Not Found

Success:
    200 base64(subid#gate)
]]

local mark = 'LS '
local M_login = 'login'
local METHODS = {}

local wsgate = tonumber(...)

local function close_fd(fd)
    user_auth[fd] = nil
    websocket.close(fd)
end

function METHODS.login(fd, token, secret)
    local ret = string.split(token, ":")
    assert(#ret == 5)
    local username = ret[1]
    local password = ret[2]
    local mode = ret[3]
    local uuid = ret[4]
    local device = ret[5]

    local ret = cluster.call("cluster_db", "@logindbmgr", "authenticate", username, password, mode, uuid, device)
    if not ret then
        websocket.write(fd, "0#401 Unauthorized")
        close_fd(fd)
        return
    end

    if ret.username ~= username or ret.password ~= password then
        websocket.write(fd, "0#404 User Not Found")
        close_fd(fd)
        return
    end

    local r, result = skynet.call(wsgate, "lua", "login", ret.userid, secret)
    if not r then
        websocket.write(fd, result)
    else
        websocket.write(fd, "0#200 " .. crypt.base64encode(result .. "#" .. ret.userid .. "#" .. ret.password))
    end
    close_fd(fd)
end

local function auth(fd, message, stage)
    if stage.step == 0 then
        stage.step = 1
        stage.challenge = crypt.randomkey()
        websocket.write(fd, stage.step .. "#" .. crypt.base64encode(stage.challenge))
    else
        if string.len(message) <= 2 or stage.step ~= tonumber(string.sub(message, 1, 1)) then
            error('invalid request')
            websocket.write(fd, "0#400 Bad Request")
            close_fd(fd)
            return
        end

        local msg = string.sub(message, 3)
        if stage.step == 1 then
            local clientkey = crypt.base64decode(msg)
            if #clientkey ~= 8 then
                error "Invalid client key"
                websocket.write(fd, "0#400 Bad Request")
                close_fd(fd)
                return
            end
            stage.step = 2
            stage.clientkey = clientkey
            stage.serverkey = crypt.randomkey()
            websocket.write(fd, stage.step .. "#" .. crypt.base64encode(crypt.dhexchange(stage.serverkey)))
    
            stage.secret = crypt.dhsecret(stage.clientkey, stage.serverkey)
        elseif stage.step == 2 then
            local hmac = crypt.hmac64(stage.challenge, stage.secret)
            if hmac ~= crypt.base64decode(msg) then
                error "challenge failed"
                websocket.write(fd, "0#400 Bad Request")
                close_fd(fd)
                return
            end
            stage.step = 3
            stage.auth = true
        elseif stage.step == 3 and stage.auth then
            local token = crypt.desdecode(stage.secret, crypt.base64decode(msg))
            METHODS[stage.method](fd, token, stage.secret)
        else
            error "invalid request"
            websocket.write(fd, "0#400 Bad Request")
            close_fd(fd)
            return
        end
    end
end

local handler = {}

function handler.connect(id)
    print("ws connect from: " .. tostring(id))
end

function handler.handshake(id, header, url)
    local addr = websocket.addrinfo(id)

    user_auth[id] = { activetime = skynet.time(), ip = addr }
end

function handler.message(id, msg)
    local stage = user_auth[id]
    if stage.step then
        auth(id, msg, stage)
    else
        if string.len(msg) <= #mark or string.sub(msg, 1, #mark) ~= mark then
            error('invalid method')
            websocket.write(id, "0#400 Bad Request")
            close_fd(id)
            return
        end
        stage.step = 0
        stage.method = string.sub(msg, #mark + 1)
        if METHODS[stage.method] == nil then
            error('method not found')
            websocket.write(id, "0#400 Bad Request")
            close_fd(id)
            return
        end
        auth(id, msg, stage)
    end
end

function handler.ping(id)
    print("ws ping from: " .. tostring(id) .. "\n")
end

function handler.pong(id)
    print("ws pong from: " .. tostring(id))
end

function handler.close(id, code, reason)
    print("ws close from: " .. tostring(id), code, reason)

    user_auth[id] = nil
end

function handler.error(id)
    print("ws error from: " .. tostring(id))

    user_auth[id] = nil
end

local CMD = {}

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

    -- 移除验证超时的连接
    skynet.fork(function()
        while true do
            local now = skynet.time()
            local remove = {}
            for k, v in pairs(user_auth) do
                if now - v.activetime >= 10 then
                    table.insert(remove, k)
                end
            end
            for k, v in ipairs(remove) do
                close_fd(v)
            end
			skynet.sleep(500)
		end
	end)
end)
