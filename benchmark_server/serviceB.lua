local skynet = require "skynet"
require "skynet.manager"

local CMD = {}

local timer_interval = 100
local timers = {}       -- id : { delay, elapsed, repeated, func }
local function table_timer()
    local remove_timers = {}
    for k, v in pairs(timers) do
        print("t1:", k, table.size(timers))
        v.elapsed = v.elapsed + timer_interval
        if v.elapsed >= v.delay then
            local id = k
            print("t2:", k, table.size(timers))
            v.func(id)
            print("t3:", k, table.size(timers))
            if v.repeated then
                v.elapsed = 0
            else
                table.insert(remove_timers, k)
            end
        end
        print("t4:", k, table.size(timers))
    end

    for i, v in ipairs(remove_timers) do
        timers[v] = nil
    end

    skynet.timeout(timer_interval, table_timer)
end

local function set_table_timer(id, delay, func, repeated)
    id = id
    delay = delay * timer_interval
    repeated = repeated or false
    timers[id] = { delay = delay, elapsed = 0, repeated = repeated, func = func }
end

local function kill_table_timer(id)
    timers[id] = nil
end

function CMD.start(source, conf)
    print("start")
    skynet.timeout(timer_interval, table_timer)
end

local function test_timer()
    set_table_timer(1, 2, function()
        skynet.call("serviceA", "lua", "justcall")
    end, false)

    set_table_timer(2, 2, function()
        skynet.call("serviceA", "lua", "justcall2")
    end, false)
end

function CMD.test(source, conf)
    print("test")
    test_timer()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(source, ...)))
    end)

    skynet.register(SERVICE_NAME)
end)