
local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
    local log = skynet.uniqueservice("log")
    skynet.call(log, "lua", "start")

    local httpserver = skynet.uniqueservice("httpserver")

    local server_mgr = skynet.uniqueservice("server_manager")
    skynet.call(server_mgr, 'lua', 'start')

    cluster.open("cluster_center")
end)

