
local robot = class("robot")

local TIMER_READY = { 1, 2 }
local TIMER_CALL_BANKER = { 2, 3 }
local TIMER_BET = { 3, 3 }
local TIMER_OPEN_CARD = { 4, 3 }
local TIMER_READY2 = { 5, 3 }

function robot:ctor(user, on_robot_game_msg_cb, user_ready_cb)
    self.user = user
    self.on_robot_game_msg_cb = on_robot_game_msg_cb
    self.user_ready_cb = user_ready_cb
    self.timers = {}

    self.user_playing = false
    self.banker_chairid = 0
    self.user_can_bet_score = {}
    self.me_cards_data = {}
    self.max_call_banker_times = 0
end

-- 游戏消息
function robot:on_game_msg(method, msg)
    local f = assert(robot[method])
    if f then
        return f(self,msg)
    end
end

function robot:send_msg_to_game(method, msg)
    self.on_robot_game_msg_cb(method, msg, self.user)
end

function robot:notify_gs_free()
    self:set_timer(TIMER_READY[1], TIMER_READY[2], function()
        self.user_ready_cb(self.user)
    end)
end

function robot:notify_gs_callbanker()
end

function robot:notify_gs_bet()
end

function robot:notify_gs_opencard()
end

function robot:open_cards_data()
end

function robot:notify_game_start()
    self.user_playing = true

    self:set_timer(TIMER_CALL_BANKER[1], TIMER_CALL_BANKER[2], function()
        self:send_msg_to_game("request_call_banker", {index=0})
    end)
end

function robot:notify_call_banker()
end

function robot:notify_start_bet(msg)
    self.banker_chairid = msg.banker_chairid
    self.user_can_bet_score = msg.user_can_bet_score
    if self.user_playing and self.user.chairid ~= self.banker_chairid then
        self:set_timer(TIMER_BET[1], TIMER_BET[2], function()
            self:send_msg_to_game("request_bet", {bet_score=self.user_can_bet_score[1]})
        end)
    end
end

function robot:notify_bet()
end

function robot:notify_start_open_card()
    if self.user_playing then
        self:set_timer(TIMER_OPEN_CARD[1], TIMER_OPEN_CARD[2], function()
            self:send_msg_to_game("request_open_card", {cards_data={}})
        end)
    end
end

function robot:notify_open_cards()
end

function robot:notify_game_end()
    self:set_timer(TIMER_READY2[1], TIMER_READY2[2], function()
        self.user_ready_cb(self.user)
    end)

    self.user_playing = false
    self.banker_chairid = 0
    self.user_can_bet_score = {}
    self.me_cards_data = {}
    self.max_call_banker_times = 0
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
