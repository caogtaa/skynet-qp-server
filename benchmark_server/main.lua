
local skynet = require "skynet"

skynet.start(function()
    local a = skynet.uniqueservice("serviceA")
    skynet.call(a, 'lua', 'start')
end)
