local skynet = require "skynet"
require "skynet.manager"
local cluster = require "skynet.cluster"

local CMD = {}

local dbmgr

function CMD.start(db)
    dbmgr = db

    cluster.register("webdbmgr")
end

function CMD.stop()
end

--
function CMD.dbquery(luascript)
    luascript = [[
        local skynet = require("skynet")
        return skynet.call("dbmgr", "lua", "redis_cmd", "hgetall", "user_account_info:userid:1")
    ]]
    local func = load(luascript)
    return func()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd .. "not found")
        skynet.retpack(f(...))
    end)

    skynet.register(SERVICE_NAME)
end)
