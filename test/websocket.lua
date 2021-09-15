local internal = require "internal"
local socket = require "client.socket"
local crypt = require "client.crypt"

local GLOBAL_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
local MAX_FRAME_SIZE = 256 * 1024 -- max frame is 256K

local M = {}

local ws_pool = {}
local function _close_websocket(ws_obj)
    local id = ws_obj.id
    assert(ws_pool[id] == ws_obj)
    ws_pool[id] = nil
    ws_obj.close()
end

local last = ""
local function readbytes(fd, sz)
    local function f(str, sz)
        if #str >= sz then
            return str:sub(1, sz), str:sub(sz + 1)
        end
        return nil, str
    end
    local function try_recv(fd, last, sz)
        local result
        result, last = f(last, sz)
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
        return f(last .. r, sz)
    end

    if sz then
        while true do
            local result
            result, last = try_recv(fd, last, sz)
            if result then
                return result
            end
            socket.usleep(100)
        end
    else
        while true do
            local r = socket.recv(fd)
            if r == "" then
                error "Server closed"
            end
            if r then
                return last .. r
            end
            socket.usleep(100)
        end
    end
end

local function _new_client_ws(socket_id, protocol)
    local obj
    if protocol == "ws" then
        obj = {
            websocket = true,
            close = function ()
                socket.close(socket_id)
            end,
            read = function (sz)
                local ret = readbytes(socket_id, sz)
                if ret then
                    return ret
                else
                    error(socket_error)
                end
            end,
            write = function (content)
                socket.send(socket_id, content)
            end,
        }
    else
        print(string.format("invalid websocket protocol:%s", tostring(protocol)))
    end

    obj.mode = "client"
    obj.id = assert(socket_id)
    obj.guid = GLOBAL_GUID
    ws_pool[socket_id] = obj
    return obj
end

local function write_handshake(self, host, url, header)
    local key = crypt.base64encode(crypt.randomkey()..crypt.randomkey())
    local request_header = {
        ["Upgrade"] = "websocket",
        ["Connection"] = "Upgrade",
        ["Sec-WebSocket-Version"] = "13",
        ["Sec-WebSocket-Key"] = key
    }
    if header then
        for k,v in pairs(header) do
            assert(request_header[k] == nil, k)
            request_header[k] = v
        end
    end

    local recvheader = {}
    local code, body = internal.request(self, "GET", host, url, recvheader, request_header)
    if code ~= 101 then
        error(string.format("websocket handshake error: code[%s] info:%s", code, body))    
    end

    if not recvheader["upgrade"] or recvheader["upgrade"]:lower() ~= "websocket" then
        error("websocket handshake upgrade must websocket")
    end

    if not recvheader["connection"] or recvheader["connection"]:lower() ~= "upgrade" then
        error("websocket handshake connection must upgrade")
    end

    local sw_key = recvheader["sec-websocket-accept"]
    if not sw_key then
        error("websocket handshake need Sec-WebSocket-Accept")
    end

    local guid = self.guid
    sw_key = crypt.base64decode(sw_key)
    if sw_key ~= crypt.sha1(key .. guid) then
        error("websocket handshake invalid Sec-WebSocket-Accept")
    end
end

local op_code = {
    ["frame"]  = 0x00,
    ["text"]   = 0x01,
    ["binary"] = 0x02,
    ["close"]  = 0x08,
    ["ping"]   = 0x09,
    ["pong"]   = 0x0A,
    [0x00]     = "frame",
    [0x01]     = "text",
    [0x02]     = "binary",
    [0x08]     = "close",
    [0x09]     = "ping",
    [0x0A]     = "pong",
}

local function write_frame(self, op, payload_data, masking_key)
    payload_data = payload_data or ""
    local payload_len = #payload_data
    local op_v = assert(op_code[op])
    local v1 = 0x80 | op_v -- fin is 1 with opcode
    local s
    local mask = masking_key and 0x80 or 0x00
    -- mask set to 0
    if payload_len < 126 then
        s = string.pack("I1I1", v1, mask | payload_len)
    elseif payload_len < 0xffff then
        s = string.pack("I1I1>I2", v1, mask | 126, payload_len)
    else
        s = string.pack("I1I1>I8", v1, mask | 127, payload_len)
    end
    self.write(s)

    -- write masking_key
    if masking_key then
        s = string.pack(">I4", masking_key)
        self.write(s)
        payload_data = crypt.xor_str(payload_data, s)
    end

    if payload_len > 0 then
        self.write(payload_data)
    end
end


local function read_close(payload_data)
    local code, reason
    local payload_len = #payload_data
    if payload_len > 2 then
        local fmt = string.format(">I2c%d", payload_len - 2)
        code, reason = string.unpack(fmt, payload_data)
    end
    return code, reason
end


local function read_frame(self)
    local s = self.read(2)
    local v1, v2 = string.unpack("I1I1", s)
    local fin  = (v1 & 0x80) ~= 0
    -- unused flag
    -- local rsv1 = (v1 & 0x40) ~= 0
    -- local rsv2 = (v1 & 0x20) ~= 0
    -- local rsv3 = (v1 & 0x10) ~= 0
    local op   =  v1 & 0x0f
    local mask = (v2 & 0x80) ~= 0
    local payload_len = (v2 & 0x7f)
    if payload_len == 126 then
        s = self.read(2)
        payload_len = string.unpack(">I2", s)
    elseif payload_len == 127 then
        s = self.read(8)
        payload_len = string.unpack(">I8", s)
    end

    if self.mode == "server" and payload_len > MAX_FRAME_SIZE then
        error("payload_len is too large")
    end

    -- print(string.format("fin:%s, op:%s, mask:%s, payload_len:%s", fin, op_code[op], mask, payload_len))
    local masking_key = mask and self.read(4) or false
    local payload_data = payload_len>0 and self.read(payload_len) or ""
    payload_data = masking_key and crypt.xor_str(payload_data, masking_key) or payload_data
    return fin, assert(op_code[op]), payload_data
end

function M.connect(url, header)
    local protocol, host, uri = string.match(url, "^(wss?)://([^/]+)(.*)$")
    if protocol ~= "wss" and protocol ~= "ws" then
        error(string.format("invalid protocol: %s", protocol))
    end
    
    assert(host)
    local host_name, host_port = string.match(host, "^([^:]+):?(%d*)$")
    assert(host_name and host_port)
    if host_port == "" then
        host_port = protocol == "ws" and 80 or 443
    end

    uri = uri == "" and "/" or uri
    local socket_id = socket.connect(host_name, host_port)
    local ws_obj = _new_client_ws(socket_id, protocol)
    ws_obj.addr = host
    write_handshake(ws_obj, host_name, uri, header)
    return socket_id
end

function M.read(id)
    local ws_obj = assert(ws_pool[id])
    local recv_buf
    while true do
        local fin, op, payload_data = read_frame(ws_obj)
        if op == "close" then
            _close_websocket(ws_obj)
            return false, payload_data
        elseif op == "ping" then
            write_frame(ws_obj, "pong")
        elseif op ~= "pong" then  -- op is frame, text binary
            if fin and not recv_buf then
                return payload_data
            else
                recv_buf = recv_buf or {}
                recv_buf[#recv_buf+1] = payload_data
                if fin then
                    local s = table.concat(recv_buf)
                    return s
                end
            end
        end
    end
    assert(false)
end

function M.write(id, data, fmt, masking_key)
    local ws_obj = assert(ws_pool[id])
    fmt = fmt or "text"
    assert(fmt == "text" or fmt == "binary")
    write_frame(ws_obj, fmt, data, masking_key)
end

function M.ping(id)
    local ws_obj = assert(ws_pool[id])
    write_frame(ws_obj, "ping")
end

function M.addrinfo(id)
    local ws_obj = assert(ws_pool[id])
    return ws_obj.addr
end

function M.close(id, code ,reason)
    local ws_obj = ws_pool[id]
    if not ws_obj then
        return
    end

    local ok, err = xpcall(function ()
        reason = reason or ""
        local payload_data
        if code then
            local fmt =string.format(">I2c%d", #reason)
            payload_data = string.pack(fmt, code, reason)
        end
        write_frame(ws_obj, "close", payload_data)
    end, debug.traceback)
    _close_websocket(ws_obj)
    if not ok then
        error(err)
    end
end

return M
