
local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
    local log = skynet.uniqueservice("log")
    skynet.call(log, "lua", "start")

    --local logind = skynet.uniqueservice("logind")
    --skynet.call(logind, 'lua', 'start')

    local wsgate = skynet.uniqueservice("wsgate")
	skynet.call(wsgate, "lua", "start")

    cluster.open(tostring(skynet.getenv("clustername")))
end)
