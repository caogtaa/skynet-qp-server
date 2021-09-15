
local skynet = require "skynet"
require "skynet.manager"

local CMD = {}

function CMD.start(source, conf)
    local send = false
    skynet.timeout(100, function()
        if not send then
            skynet.call("serviceB", "lua", "test")
            send = true
        end
    end)
end

function CMD.justcall()
    print("justcall")
    skynet.sleep(200)
end

function CMD.justcall2()
    print("justcall2")
    skynet.sleep(200)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(source, ...)))
    end)

    skynet.register(SERVICE_NAME)

    local b = skynet.newservice("serviceB")
    skynet.call(b, "lua", "start")
end)
