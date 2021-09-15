local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"

skynet.start(function()
	local agent = {}
	local protocol = "http"
	for i= 1, 5 do
		agent[i] = skynet.newservice("httpserveragent")
	end
	local balance = 1
	local id = socket.listen("0.0.0.0", tonumber(skynet.getenv("http_port")))
	skynet.error(string.format("Listen web port 8001 protocol:%s", protocol))
	socket.start(id , function(id, addr)
		skynet.error(string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
		skynet.send(agent[balance], "lua", id)
		balance = balance + 1
		if balance > #agent then
			balance = 1
		end
	end)
end)
