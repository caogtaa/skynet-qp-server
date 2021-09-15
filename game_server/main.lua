
local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
    skynet.newservice("debug_console", tonumber(skynet.getenv("debug_port")))

    local log = skynet.uniqueservice("log")
    skynet.call(log, "lua", "start")

    local gamemgr = skynet.uniqueservice("gamemgr")
    skynet.call(gamemgr, 'lua', 'start')

    cluster.open(tostring(skynet.getenv("clustername")))
end)
