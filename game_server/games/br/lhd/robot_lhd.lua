
local robot = class("robot")

local random = require "random"

local TIMER_BET = 1

local user_can_bet_score = { 100, 500, 1000, 5000, 10000, 50000, 100000 }
local user_can_bet_score_rate = { 0.3, 0.2, 0.2, 0.1, 0.1, 0.05, 0.05 }

function robot:ctor(user, on_robot_game_msg_cb, user_ready_cb, robotconf)
    self.user = user
    self.on_robot_game_msg_cb = on_robot_game_msg_cb
    self.user_ready_cb = user_ready_cb
    self.timers = {}

    self.robotconf = robotconf

    self.bet_area = 0
    self.current_banker = 0
    self.banker_reserve_score = 0

    self.all_bet_score = { 0, 0, 0 }
    self.me_bet_score = { 0, 0, 0 }

    self.user_bet_limit = 0
    self.area_bet_limit = 0
end

-- 游戏消息
function robot:on_game_msg(method, msg)
    local f = robot[method]
    if f then
        return f(self,msg)
    end
end

function robot:send_msg_to_game(method, msg)
    self.on_robot_game_msg_cb(method, msg, self.user)
end

function robot:notify_gs_free(msg)
    self.user_bet_limit = msg.user_bet_limit
    self.area_bet_limit = msg.area_bet_limit
end

function robot:notify_gs_bet(msg)
    self.user_bet_limit = msg.user_bet_limit
    self.area_bet_limit = msg.area_bet_limit
end

function robot:notify_gs_opencard(msg)
    self.user_bet_limit = msg.user_bet_limit
    self.area_bet_limit = msg.area_bet_limit
end

function robot:notify_game_free(msg)
    self.all_bet_score = { 0, 0, 0 }
    self.me_bet_score = { 0, 0, 0 }
end

function robot:calc_bet_range(max_bet_score)
    if max_bet_score < user_can_bet_score[1] then
        return false
    end

    local bet_chips = {}
    for k, v in ipairs(user_can_bet_score) do
        if not bet_chips[1] and v >= self.robotconf.bet_score[1] then
            bet_chips[1] = k
        end
        if v <= self.robotconf.bet_score[2] then
            bet_chips[2] = k
        end
    end

    if self.bet_times * user_can_bet_score[bet_chips[1]] > max_bet_score then
        if self.bet_times * user_can_bet_score[1] > max_bet_score then
            self.bet_times = math.floor(max_bet_score / user_can_bet_score[1])
            bet_chips = { 1, 1 }
        else
            while self.bet_times * user_can_bet_score[bet_chips[1]] > max_bet_score do
                if bet_chips[1] == 1 then
                    break
                end
                bet_chips[1] = bet_chips[1] - 1
            end
        end
    end

    return true, bet_chips
end

function robot:get_max_bet_score(bet_area)
    local max_bet_score = 0
    local total_bet_score = self.me_bet_score[1] + self.me_bet_score[2] + self.me_bet_score[3]

    if bet_area ~= 2 then
        max_bet_score = self.banker_reserve_score + math.min(self.all_bet_score[1], self.all_bet_score[2] + self.all_bet_score[3] - math.max(self.all_bet_score[1], self.all_bet_score[2]))
    else
        max_bet_score = self.banker_reserve_score / 16 - self.all_bet_score[3]
    end

    max_bet_score = math.min(max_bet_score, self.user.score - total_bet_score, self.user_bet_limit - total_bet_score, self.area_bet_limit - self.all_bet_score[bet_area + 1])
    max_bet_score = math.max(0, max_bet_score)

    return max_bet_score
end

function robot:notify_game_start(msg)
    self.current_banker = msg.current_banker
    self.banker_reserve_score = msg.banker_reserve_score

    if self.user.score < 5000 then
        return
    end

    self.bet_area = random.GetId({{ id = 0, rate = 0.45 }, { id = 1, rate = 0.45 }, { id = 2, rate = 0.1 }})

    if self.bet_area == 2 then
        self.bet_times = random.Get(1, 2)
    else
        self.bet_times = random.Get(self.robotconf.bet_times[1], self.robotconf.bet_times[2])
    end

    local ret, bet_chips = self:calc_bet_range(self.banker_reserve_score)
    if not ret then
        return 
    end

    -- 设置时间
    local time_grid = math.floor(msg.time_leave - 2) * 800 / self.bet_times
    for i = 0, self.bet_times - 1 do
        local rr = math.floor(time_grid * i / (1500 * math.sqrt(self.bet_times))) + 1
        local elapsed = 2 + (time_grid * i) / 1000 + ((random.Get(0, rr) + self.user.chairid) % (rr * 2) - (rr - 1))
        assert(elapsed >= 2 and elapsed <= msg.time_leave)
        if elapsed >= 2 and elapsed <= msg.time_leave then
            self:set_timer(TIMER_BET + i + 1, elapsed, function()
                local chips = table.clone(bet_chips, true)
                local bet_chip = chips[1]
                local max_bet_score = self:get_max_bet_score(self.bet_area)
                if chips[2] > chips[1] then
                    for i = chips[2], chips[1] + 1, -1 do
                        if max_bet_score >= user_can_bet_score[i] then
                            chips[2] = i
                            break
                        end
                    end
                    local t = {}
                    local rate = 0
                    for i = chips[1], chips[2] do
                        table.insert(t, { id = i, rate = user_can_bet_score_rate[i] })
                        rate = rate + user_can_bet_score_rate[i]
                    end
                    for _, v in ipairs(t) do
                        v.rate = v.rate / rate
                    end
                    bet_chip = random.GetId(t)
                end

                if max_bet_score >= user_can_bet_score[bet_chip] then
                    local request_bet = { bet_score = user_can_bet_score[bet_chip], bet_area = self.bet_area }
                    self:send_msg_to_game("request_bet", request_bet)
                end
            end)
        end
    end
end

function robot:notify_bet(msg)
    self.all_bet_score[msg.bet_area + 1] = self.all_bet_score[msg.bet_area + 1] + msg.bet_score
    if msg.bet_chairid == self.user.chairid then
        self.me_bet_score[msg.bet_area + 1] = self.me_bet_score[msg.bet_area + 1] + msg.bet_score
    end
end

function robot:notify_open_cards()
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
