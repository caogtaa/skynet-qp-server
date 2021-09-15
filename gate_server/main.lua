
local skynet = require "skynet"
local cluster = require "skynet.cluster"
local socket = require "skynet.socket"

skynet.start(function()
	skynet.newservice("debug_console", 9000)

    local log = skynet.uniqueservice("log")
	skynet.call(log, "lua", "start")

	--[[
	local endpoint = skynet.getenv("endpoint")
	local ip, port = string.match(endpoint, "([^:]*):([^:]*)")

	local gate = skynet.uniqueservice("gateway")
	skynet.call(gate, "lua", "open", {
		address = ip,
		port = port or 8080,
		nodelay = true,
		maxclient = 1024
	})
	]]

	local wsgate = skynet.uniqueservice("wsgateway")
	skynet.call(wsgate, "lua", "start")
	
    cluster.open(tostring(skynet.getenv("clustername")))
end)
