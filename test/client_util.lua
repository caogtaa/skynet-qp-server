
local socket = require "client.socket"
local crypt = require "client.crypt"
local protobuf = require 'protobuf'

local util = {}

local function unpack_line(text)
    local from = text:find("\n", 1, true)
    if from then
        return text:sub(1, from-1), text:sub(from+1)
    end
    return nil, text
end

local last = ""

local function unpack_f(f)
    local function try_recv(fd, last)
        local result
        result, last = f(last)
        if result then
            return result, last
        end
        local r = socket.recv(fd)
        if not r then
            return nil, last
        end
        if r == "" then
            error "Server closed"
        end
        return f(last .. r)
    end

    return function(fd)
        while true do
            local result
            result, last = try_recv(fd, last)
            if result then
                return result
            end
            socket.usleep(100)
        end
    end
end

util.readline = unpack_f(unpack_line)

function util.writeline(fd, text)
    socket.send(fd, text .. "\n")
end

function util.netmsg_pack(name, msg, sessionid)
    local payload = protobuf.encode(name, msg)
    local netmsg = { name = name, payload = payload, sessionid = sessionid }
    local pack = protobuf.encode("netmsg.netmsg", netmsg)
    return pack
end

function util.netmsg_unpack(data)
    local netmsg = protobuf.decode("netmsg.netmsg", data)
    if not netmsg then
        error("netmsg_unpack error")
        return
	end
    local msg = protobuf.decode(netmsg.name, netmsg.payload)
    if not msg then
        error(netmsg.name .. " decode error")
        return
    end

    local module, method = netmsg.name:match "([^.]*).([^.]*)"
    return module, method, msg
end

function util.gamemsg_pack(name, msg, sessionid)
    local payload = protobuf.encode(name, msg)
    local gamemsg = { name = name, payload = payload }
    local gamepack = protobuf.encode("game.gamemsg", gamemsg)
    local netmsg = { name = "game.gamemsg", payload = gamepack, sessionid = sessionid }
    local pack = protobuf.encode("netmsg.netmsg", netmsg)
    return pack
end

function util.gamemsg_unpack(data)
    local netmsg = protobuf.decode("netmsg.netmsg", data)
    if not netmsg then
		LOG_ERROR("gamemsg_unpack error")
        error("gamemsg_unpack error")
        return
	end
    local gamemsg = protobuf.decode(netmsg.name, netmsg.payload)
    if not gamemsg then
        LOG_ERROR(gamemsg.name .. " decode error")
        return
    end

    local msg = protobuf.decode(gamemsg.name, gamemsg.payload)
    if not msg then
        LOG_ERROR(msg.name .. " decode error")
        return
    end

    local module, method = gamemsg.name:match "([^.]*).([^.]*)"
    return module, method, msg
end

local function unpack_package(text)
    local size = #text
    if size < 2 then
        return nil, text
    end
    local s = text:byte(1) * 256 + text:byte(2)
    if size < s+2 then
        return nil, text
    end

    return text:sub(3,2+s), text:sub(3+s)
end

function util.send_package(fd, pack)
    local package = string.pack(">s2", pack)
    socket.send(fd, package)
end

util.readpackage = unpack_f(unpack_package)

local function split(s, delim)
    local split = {}
    local pattern = "[^" .. delim .. "]+"
    string.gsub(s, pattern, function(v) table.insert(split, v) end)
    return split
end

return util

