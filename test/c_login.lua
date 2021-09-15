
local socket = require "client.socket"
local crypt = require "client.crypt"
local util = require 'client_util'
local websocket = require "websocket"

local ip, port
local c_login = {}

local function encode_token(server, username, pwd)
    return string.format("%s:%s:%s:%d:%s:%s", server, username, pwd, 1, 'uuid', 'iphone')
end

function c_login.set_addr(ip_, port_)
    ip = ip_
    port = port_
end

function c_login.login(server, username, pwd)
    local fd = assert(socket.connect(ip, port))
    util.writeline(fd, 'LS login')
    local challenge = crypt.base64decode(util.readline(fd))
    local clientkey = crypt.randomkey()
    util.writeline(fd, crypt.base64encode(crypt.dhexchange(clientkey)))
    local secret = crypt.dhsecret(crypt.base64decode(util.readline(fd)), clientkey)
    local hmac = crypt.hmac64(challenge, secret)
    util.writeline(fd, crypt.base64encode(hmac))
    local etoken = crypt.desencode(secret, encode_token(server, username, pwd))
    local b = crypt.base64encode(etoken)
    util.writeline(fd, crypt.base64encode(etoken))

    local result = util.readline(fd)
    local code = tonumber(string.sub(result, 1, 3))
    socket.close(fd)
    if code ~= 200 then
        return code
    end
    local pack = crypt.base64decode(string.sub(result, 5))
    local vec = string.split(pack, '#')
    local subid, server = vec[1], vec[2]
    return code, {subid = subid, server = server, hmac = hmac, secret = secret}
end

function c_login.wslogin(server, username, pwd)
    ws_id = websocket.connect("ws://127.0.0.1:8081/")
    if not ws_id then
        print("connect login failed")
    else
        local challenge
        local clientkey
        local secret
        websocket.write(ws_id, "LS login")
        while true do
            local resp, close_reason = websocket.read(ws_id)
            if not resp then
                print("server close " .. close_reason)
                break
            else
                local step = tonumber(string.sub(resp, 1, 1))
                local msg = string.sub(resp, 3)
                print(step, msg)
                
                if step == 1 then
                    challenge = crypt.base64decode(msg)
                    print(step, challenge)
                    clientkey = crypt.randomkey()
                    websocket.write(ws_id, step .. "#" .. crypt.base64encode(crypt.dhexchange(clientkey)))
                elseif step == 2 then
                    secret = crypt.dhsecret(crypt.base64decode(msg), clientkey)
                    local hmac = crypt.hmac64(challenge, secret)
                    websocket.write(ws_id, step .. "#" .. crypt.base64encode(hmac))

                    local etoken = crypt.desencode(secret, encode_token(server, username, pwd))
                    local b = crypt.base64encode(etoken)
                    websocket.write(ws_id, "3#" .. b)
                else
                    local code = tonumber(string.sub(msg, 1, 3))
                    if code ~= 200 then
                        return code
                    end
                    local pack = crypt.base64decode(string.sub(msg, 5))
                    local vec = string.split(pack, '#')
                    local subid, server = vec[1], vec[2]
                    return code, {subid = subid, server = server, secret = secret}
                end
            end
            socket.usleep(100)
        end
    end
end

return c_login
