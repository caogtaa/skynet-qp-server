local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local cjson = require "cjson"
local cluster = require "skynet.cluster"

local function response(id, code, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id), code, ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end

local request = {}

function request.test(id, body, query)
    local t = {
        code = 200,
        reason = "success"
    }
    response(id, 200, cjson.encode(t))
end

function request.test2(id, body, query)
    local t = {
        code = 200,
        reason = "success"
    }
	local script = "print( 100 + 1)"
	local ret = load(script)
	ret()
    response(id, 200, cjson.encode(t))
end

function request.do_redis(cmd, ...)
    _G.print(cmd)
end

function request.dbquery(id, body, query)
	print(body)
	local ret = cluster.call("cluster_db", "@webdbmgr", "dbquery", body)
	print(ret)
end

skynet.start(function()
	skynet.dispatch("lua", function (_,_,id)
		socket.start(id)

		-- limit request body size to 8192 (you can pass nil to unlimit)
		local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
		if code then
			if code ~= 200 then
				response(id, code)
			else
				local path, query = urllib.parse(url)
				local command = string.gsub(string.sub(path, 2), "/", "_")
                local f = request[command]
                if f then
                    f(id, body, query)
                else
                    skynet.error("unkown path:" .. path)
                end
			end
		else
			if url == sockethelper.socket_error then
				skynet.error("socket closed")
			else
				skynet.error(url)
			end
		end
		socket.close(id)
	end)
end)