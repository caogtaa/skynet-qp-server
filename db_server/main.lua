
local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
    --skynet.newservice("debug_console", tonumber(skynet.getenv("debug_port")))

    local log = skynet.uniqueservice("log")
    skynet.call(log, "lua", "start")

    local mysqlpool = skynet.uniqueservice("mysqlpool")
    skynet.call(mysqlpool, 'lua', 'start')

    local dbmgr = skynet.uniqueservice("dbmgr")
    skynet.call(dbmgr, 'lua', 'start')

    cluster.open("cluster_db")
end)

