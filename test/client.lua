package.cpath = "skynet/luaclib/?.so;luaclib/?.so"
local service_path = "./lualib/?.lua;" .. "./common/?.lua;" .. "./global/?.lua;" .. "./?.lua;" .. './test/?.lua'
package.path = "skynet/lualib/?.lua;skynet/service/?.lua;" .. service_path

require 'luaext'
local socket = require "client.socket"
local crypt = require "client.crypt"
local websocket = require "websocket"
local util = require 'client_util'
local protobuf = require 'protobuf'

protobuf.register_file("protocol/netmsg.pb")
protobuf.register_file("protocol/niuniu.pb")

local c_login = require "c_login"
local c_hall = require "c_hall"
local c_game = require "c_game"
local c_game_niuniu = require "c_game_niuniu"

local login_addr = {ip = '127.0.0.1', port = 8081}
c_login.set_addr(login_addr.ip, login_addr.port)

local ls

local handshake_index = 0
local handshake = false

local ws_id

local CMD = {}

local function help()
    print('> command list:')
    for k, v in pairs(CMD) do
        print(k)
    end
end

function CMD.login()
    handshake_index = 0
    code, ls = c_login.login("not used", "username", "e10adc3949ba59abbe56e057f20f883e")
    assert(code == 200)
    print('login ok, subid: ', ls.subid)
    print('get gate server:', ls.server)
end

function CMD.login2()
    handshake_index = 0
    code, ls = c_login.login("not used", "username2", "e10adc3949ba59abbe56e057f20f883e")
    assert(code == 200)
    print('login ok, subid: ', ls.subid)
    print('get gate server:', ls.server)
end

function CMD.wslogin()
    code, ls = c_login.wslogin("not used", "username21", "e10adc3949ba59abbe56e057f20f883e")
    assert(code == 200)
    print('login ok, subid: ', ls.subid)
    print('get gate server:', ls.server)
end

function CMD.connect_gate()
    ws_id = websocket.connect("ws://" .. ls.server .. "/")
    if not ws_id then
        print("connect gate failed")
    else
        local handshakeid = ls.subid
        local hmac = crypt.hmac64(crypt.hashkey(handshakeid), ls.secret)
        websocket.write(ws_id, handshakeid .. ":" .. handshake_index .. ":" .. crypt.base64encode(hmac)) 
    end
end

function CMD.close_gate()
    print("ready close gate")
    if ws_id then
        websocket.close(ws_id)
        ws_id = nil
        handshake = false
    end
end

function CMD.req_game_list()
    local pack = c_hall.request_game_list()
    local msg = crypt.desencode(ls.secret, pack)
    websocket.write(ws_id, msg) 
end

function CMD.req_enter_room()
    local pack = c_game.enter_room(1, 6000)
    local msg = crypt.desencode(ls.secret, pack)
    websocket.write(ws_id, msg) 
end

function CMD.req_leave_room()
    local pack = c_game.leave_room(6000)
    local msg = crypt.desencode(ls.secret, pack)
    websocket.write(ws_id, msg) 
end

function CMD.req_enter_room2()
    local pack = c_game.enter_room(3, 6000)
    local msg = crypt.desencode(ls.secret, pack)
    websocket.write(ws_id, msg) 
end

function CMD.req_sitdown()
    local pack = c_game.sitdown(1, 1, 6000)
    local msg = crypt.desencode(ls.secret, pack)
    websocket.write(ws_id, msg)
end

function CMD.req_initgame()
    local pack = c_game.initgame(6000)
    local msg = crypt.desencode(ls.secret, pack)
    websocket.write(ws_id, msg)
end

function CMD.nn_bet()
    local pack = c_game_niuniu.request_bet(1,6000)
    local msg = crypt.desencode(ls.secret, pack)
    websocket.write(ws_id, msg)
end

function CMD.test()
    print(186, string.char(186))
    print(crypt.base64decode("YWJjMTIz5Lit5paH5rWL6K+V"))
    print(crypt.base64encode(crypt.desencode("12345678", "123123")))
    local challenge = crypt.randomkey()
    local clientkey = crypt.randomkey()
    local serverkey = crypt.randomkey()
    local secret = crypt.dhsecret(crypt.dhexchange(serverkey), clientkey)
    print(crypt.base64encode(secret))
    local etoken = crypt.desencode(secret, "测试des")
    print(crypt.base64encode(etoken))
    print(crypt.desdecode(secret, etoken))
    print(crypt.dhexchange('12345678'))
    --print(crypt.desdecode("12345678", crypt.base64encode("VOyTogLhg4MAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==")))
end

function CMD.test1()
    local ret = 0x01 | 0x02 | 0x04 | 0x08 | 0x10 | 0x20 | 0x40 | 0x80 | 0x100
    print(ret)
end

function CMD.test2()
    local game = {}
    game.super = {}

    local gametable = {}
    gametable.__index = gametable
    game.super = gametable

    setmetatable(game, gametable)

    gametable._game_status = 0

    game.super._game_status = 1

    print(gametable._game_status)
    print(game.super._game_status)

    game.super._game_status = 2

    print(gametable._game_status)

    gametable._game_status = 3
    print(game.super._game_status)

    print(game._game_status)
end

function CMD.test3()
    local t = { 1, 2, nil , 4, 5 }
    for k, v in pairs(t) do
        if v == 2 then
            t[k] = nil
        end
        print(v)
    end

    for k, v in pairs(t) do
        print("new", v)
    end
end

local function run_command(cmd, ...)
    if CMD[cmd] then
        CMD[cmd](...)
    else
        help()
    end
end

--这里的输入命令在连接网关后会阻塞，需要等到接收到心跳包之后才重新识别，所以需要等待1-5秒才会执行
--TODO 以前是服务器发送心跳 后改为客户端发送 下面需要改
while true do
    local cmd = socket.readstdin()
    if cmd then
        if cmd == "quit" then
            return
        else
            local secs = string.split(cmd, ' ')
            run_command(secs[1], table.unpack(secs, 2))
        end
    else
        if ws_id then
            local resp, close_reason = websocket.read(ws_id)
            if not resp then
                print("server close " .. close_reason)
                ws_id = nil
                handshake = false
            elseif not handshake then
                if #resp >= 6 and string.sub(resp, 1, 6) == "200 OK" then
                    handshake = true
                    handshake_index = handshake_index + 1
                    local sessionid = tonumber(string.sub(resp, 7))
                    c_hall.set_sessionid(sessionid)
                else
                    ws_id = nil
                end
                print(resp)
            else
                local msg = crypt.desdecode(ls.secret, resp)
                local module, method, msg = util.netmsg_unpack(msg)
                if module == "hall" then
                    if c_hall[method] then
                        c_hall[method](msg)
                    else
                        print("hall " .. method .. " not exsit")
                    end
                elseif module == "game" then
                    if c_game[method] then
                        c_game[method](msg)
                    else
                        print("game " .. method .. " not exsit")
                    end
                else
                    if method ~= "heartbeat" then
                        print(module, method)
                    end
                end
            end
        end
        socket.usleep(100)
    end
end