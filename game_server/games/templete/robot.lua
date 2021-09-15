
local robot = class("robot")

function robot:ctor(user, on_robot_game_msg_cb, user_ready_cb)
    self.user = user
    self.on_robot_game_msg_cb = on_robot_game_msg_cb
    self.user_ready_cb = user_ready_cb
    self.timers = {}
end

function robot:on_game_msg(method, msg)
    local f = assert(robot[method])
    if f then
        return f(self,msg)
    end
end

function robot:send_msg_to_game(method, msg)
    self.on_robot_game_msg_cb(method, msg, self.user)
end

-- 计时器 每隔1秒被调用一次
function robot:on_timer()
    local remove_timers = {}
    for k, v in pairs(self.timers) do
        v.elapsed = v.elapsed + 1
        if v.elapsed >= v.delay then
            v.func()
            if v.repeated then
                v.elapsed = 0
            else
                table.insert(remove_timers, k)
            end
        end
    end

    for i, v in ipairs(remove_timers) do
        self.timers[v] = nil
    end
end

function robot:set_timer(id, delay, func, repeated)
    repeated = repeated or false
    self.timers[id] = { delay = delay, elapsed = 0, repeated = repeated, func = func }
end

function robot:kill_timer(id)
    self.timers[id] = nil
end

return robot
