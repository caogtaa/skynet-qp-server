
local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
    local log = skynet.uniqueservice("log")
    skynet.call(log, "lua", "start")

    local server_mgr = skynet.uniqueservice("hall")
    skynet.call(server_mgr, 'lua', 'start')

    cluster.open(tostring(skynet.getenv("clustername")))
end)
