
local game = {}
local skynet = require "skynet"
local cluster = require "skynet.cluster"
local protobuf = require "protobuf"
local logic = require "logic"
local robot = require "robot"
local conf = require "config"
local clusterid = tonumber(skynet.getenv("clusterid"))
local config = conf[clusterid]

protobuf.register_file("./protocol/netmsg.pb")
local gamename = skynet.getenv("gamename")
protobuf.register_file(string.format("./protocol/%s.pb", gamename))

local robots = {}

-- 计时器(id, second)
local TIMER_READY = { 1, 9 }
local TIMER_CALL_BANKER = { 2, 10 }
local TIMER_BET = { 3, 7 }
local TIMER_OPEN_CARD = { 4, 10 }

-- 游戏状态
local GS = {
    FREE = GAME_STATUS_FREE,
    PLAY = GAME_STATUS_PLAY,
}

-- 底分
local base_score = 1
-- 牌桌人数
local max_chair_count = config.max_chair_count
-- 牌桌局数
local max_draw_count = 1
-- 扎码数量
local ma_count = 1

-- 庄家
local banker_chairid = 0
-- 当前用户
local current_chairid = 0
-- 还原用户
local resume_chairid = 0
-- 出牌用户
local outcard_chairid = 0
-- 出牌数据
local outcard_data = 0
-- 最后一个摸牌的用户(用于流局当庄)
local last_getcard_chairid = 0

-- 是否托管
local tuoguan = {}

-- 用户叫庄状态
local user_call_banker_status = {}
-- 用户叫庄倍数
local user_call_banker_times = {}
-- 用户扑克
local user_cards_data = {}
-- 开牌扑克
local user_open_cards_data = {}
-- 开牌牌型
local user_open_card_type = {}
-- 开牌倍数
local user_open_card_times = {}
-- 用户可以下注的分数
local user_can_bet_score = { base_score * 5, base_score * 10, base_score * 15, base_score * 20 }
-- 用户实际下注分数
local user_bet_score = {}
-- 用户可以下注翻倍
local user_can_double_bet = { }

-- 设置计时器
local function set_timer(id, delay, repeated)
    game.super.set_timer(id, delay, repeated)
end

-- 删除计时器
local function kill_timer(id)
    game.super.kill_timer(id)
end

-- 开始游戏
local function start_game()
    game.super.start_game()
end

-- 结束游戏
local function end_game()
    game.super.end_game()
end

-- chairid == nil 发送给所有桌上用户
local function send_msg_to_table_chair(method, msg, chairid)
    local packmsg = gamemsg_pack(gamename .. "." .. method, msg)
    if not chairid then
        for k, v in pairs(game.super._table_users) do
            if v.init_game then
                if v.gate ~= "robot" then
                    cluster.send(v.gate, "@gateway", "pbrpc", packmsg, v.fd)
                else
                    robots[v.chairid]:on_game_msg(method, msg)
                end
            end
        end
    else
        local user = game.super._table_users[chairid]
        if not user then
            LOG_ERROR(chairid .. "用户不存在")
            return
        end
        if user.init_game then
            if user.gate ~= "robot" then
                cluster.send(user.gate, "@gateway", "pbrpc", packmsg, user.fd)
            else
                robots[user.chairid]:on_game_msg(method, msg)
            end
        end
    end
end

-- user == nil 发送给所有桌上用户
local function send_msg_to_table_user(method, msg, user)
    local packmsg = gamemsg_pack(gamename .. "." .. method, msg)
    if not user then
        for k, v in pairs(game.super._table_users) do
            if v.init_game then
                if v.gate ~= "robot" then
                    cluster.send(v.gate, "@gateway", "pbrpc", packmsg, v.fd)
                else
                    robots[v.chairid]:on_game_msg(method, msg)
                end
            end
        end
    else
        if user.init_game then
            if user.gate ~= "robot" then
                cluster.send(user.gate, "@gateway", "pbrpc", packmsg, user.fd)
            else
                robots[user.chairid]:on_game_msg(method, msg)
            end
        end
    end
end

-- chairid == nil 发送给所有桌上旁观用户
local function send_msg_to_ob_chair(method, msg, chairid)
    local packmsg = gamemsg_pack(gamename .. "." .. method, msg)
    for k, v in ipairs(game.super._table_ob_users) do
        if v.init_game and (chairid == nil or chairid == v.chairid) then
            cluster.send(v.gate, "@gateway", "pbrpc", packmsg, v.fd)
        end
    end
end

-- user == nil 发送给所有桌上旁观用户
local function send_msg_to_ob_user(method, msg, user)
    local packmsg = gamemsg_pack(gamename .. "." .. method, msg)
    for k, v in ipairs(game.super._table_ob_users) do
        if v.init_game and (user == nil or user == v) then
            cluster.send(v.gate, "@gateway", "pbrpc", packmsg, v.fd)
        end
    end
end

-- 设置游戏状态
local function set_game_status(game_status)
    game.super._game_status = game_status
end

-- 获取游戏状态
local function get_game_status()
    return game.super._game_status
end

-- 根据椅子号获取用户
local function get_table_user(chairid)
    return game.super._table_users[chairid]
end

-- 获取所有桌子用户
local function get_all_table_users()
    return game.super._table_users
end

-- 游戏写分
local function write_user_score(chairid, score, revenue, performance, gamelog, play_time)
    return game.super.write_user_score(chairid, score, revenue, performance, gamelog, play_time)
end

-- 牌局ID
local function drawid()
    return game.super._drawid
end

-- 游戏初始化
function game.on_init()
    max_chair_count = config.subrooms[game.super._subroomid].max_chair_count
    base_score = config.subrooms[game.super._subroomid].base_score
    logic.set_card_type_rule(config.subrooms[game.super._subroomid].wanfa[game.super._subroom_wanfaid].item[2], (config.subrooms[game.super._subroomid].wanfa[game.super._subroom_wanfaid].item[3] & 0x04) ~= 0 and true or false)
    logic.set_card_times_rule(config.subrooms[game.super._subroomid].wanfa[game.super._subroom_wanfaid].item[1])
    -- 下注翻倍
    if (config.subrooms[game.super._subroomid].wanfa[game.super._subroom_wanfaid].item[3] & 0x02) ~= 0 then
        double_bet = true
    end

    user_can_bet_score = { base_score * 5, base_score * 10, base_score * 15, base_score * 20 }
    banker_chairid = 0
    for i = 1, max_chair_count do
        user_playing[i] = false
        user_call_banker_status[i] = false
        user_call_banker_times[i] = 0
        user_cards_data[i] = { 0, 0, 0, 0, 0 }
        user_open_cards_data[i] = { 0, 0, 0, 0, 0 }
        user_open_card_type[i] = 0
        user_open_card_times[i] = 0
        user_bet_score[i] = 0
        user_can_double_bet[i] = false
    end

    -- 机器人使用
    set_timer(0, 1, true)
end

-- 游戏重置 一般用于游戏结束后清理相关的逻辑变量
function game.on_game_reset()
    banker_chairid = 0
    for i = 1, max_chair_count do
        user_playing[i] = false
        user_call_banker_status[i] = false
        user_call_banker_times[i] = 0
        user_cards_data[i] = { 0, 0, 0, 0, 0 }
        user_open_cards_data[i] = { 0, 0, 0, 0, 0 }
        user_open_card_type[i] = 0
        user_open_card_times[i] = 0
        user_bet_score[i] = 0
        user_can_double_bet[i] = false
    end

    kill_timer(TIMER_CALL_BANKER[1])
    kill_timer(TIMER_BET[1])
    kill_timer(TIMER_OPEN_CARD[1])
    set_timer(TIMER_READY[1], TIMER_READY[2])
end

local function send_cards()
    logic.reset()
    for i = 1, max_chair_count do
        user_cards_data[i] = logic.shuffle(5)
        logic.remove_cards(user_cards_data[i])
    end
end

-- 游戏开始通知
function game.on_game_start()
    kill_timer(TIMER_READY[1])

    set_game_status(GS.CALL_BANKER)

    send_cards()

    local users = get_all_table_users()
    for k, v in pairs(users) do
        user_playing[k] = true

        local cardsdata = table.clone(user_cards_data[k], true)
        if not v.is_robot then
            cardsdata[5] = nil
        end
        send_msg_to_table_chair("notify_game_start", {cards_data = cardsdata, dealid = drawid()}, k)
    end
    send_msg_to_ob_chair("notify_game_start", {cards_data = {0,0,0,0}})

    set_timer(TIMER_CALL_BANKER[1], TIMER_CALL_BANKER[2])
end

-- 游戏解散通知
function game.on_game_dissolve()
end

-- 通知客户端当前游戏的场景
function game.on_notify_game_scene(chairid, user, game_status)
    if game_status == GS.FREE then
        send_msg_to_table_chair("notify_gs_free", { base_score = base_score }, chairid)
    elseif game_status == GS.CALL_BANKER then
        local msg = {}
        msg.dealid = drawid()
        msg.base_score = base_score
        msg.playing_status = user_playing
        msg.call_banker_status = user_call_banker_status
        msg.call_banker_times = user_call_banker_times
        msg.cards_data = table.clone(user_cards_data[chairid])
        msg.cards_data[5] = 0
        send_msg_to_table_chair("notify_gs_callbanker", msg, chairid)
    elseif game_status == GS.BET then
        local msg = {}
        msg.dealid = drawid()
        msg.base_score = base_score
        msg.playing_status = user_playing
        msg.banker_chairid = banker_chairid
        msg.banker_times = user_call_banker_times[banker_chairid]
        msg.allow_double_bet = user_can_double_bet[chairid]
        msg.user_can_bet_score = user_can_bet_score
        msg.user_bet_score = user_bet_score
        msg.cards_data = table.clone(user_cards_data[chairid])
        msg.cards_data[5] = 0
        send_msg_to_table_chair("notify_gs_bet", msg, chairid)
    elseif game_status == GS.OPEN_CARD then
        local msg = {}
        msg.dealid = drawid()
        msg.base_score = base_score
        msg.playing_status = user_playing
        msg.banker_chairid = banker_chairid
        msg.banker_times = user_call_banker_times[banker_chairid]
        msg.user_bet_score = user_bet_score
        msg.cards_data = user_cards_data[chairid]
        local opendata = {}
        for i = 1, max_chair_count do
            table.insert(opendata, {cards_data = user_open_cards_data[i]})
        end
        msg.open_cards_data = opendata
        msg.open_card_type = user_open_card_type
        msg.open_card_times = user_open_card_times
        send_msg_to_table_chair("notify_gs_opencard", msg, chairid)
    end
end

-- 游戏计时器
function game.on_timer(id)
    if id == 0 then
        for k, v in pairs(robots) do
            v:on_timer()
        end
    elseif id == TIMER_READY[1] then
        if get_game_status() == GS.FREE then
            for k, v in pairs(get_all_table_users()) do
                if v.user_status < US_READY then
                    game.super.user_standup(v)
                end
            end
        end
    elseif id == TIMER_CALL_BANKER[1] then
        if get_game_status() == GS.CALL_BANKER then
            for k, v in pairs(get_all_table_users()) do
                if user_playing[k] and not user_call_banker_status[k] then
                    game.request_call_banker({index=0}, v)
                end
            end
        end
    elseif id == TIMER_BET[1] then
        if get_game_status() == GS.BET then
            for k, v in pairs(get_all_table_users()) do
                if user_playing[k] and user_bet_score[k] == 0 and k ~= banker_chairid then
                    game.request_bet({bet_score=user_can_bet_score[1]}, v)
                end
            end
        end
    elseif id == TIMER_OPEN_CARD[1] then
        if get_game_status() == GS.OPEN_CARD then
            for k, v in pairs(get_all_table_users()) do
                if user_playing[k] and user_open_cards_data[k][1] == 0 then
                    game.request_open_card({cards_data={}}, v)
                end
            end
        end
    end
end

-- 客户端发送过来的消息
function game.on_game_msg(msg, user)
    local gamemsg = protobuf.decode(msg.name, msg.payload)
    if not gamemsg then
        LOG_ERROR(msg.name .. " decode error")
        return
    end

    local module, method = msg.name:match "([^.]*).([^.]*)"
    local f = assert(game[method])
    return f(gamemsg, user)
end

-- 机器人发送过来的消息
function game.on_robot_game_msg(method, msg, user)
    local f = assert(game[method])
    return f(msg, user)
end

-- 用户叫庄
function game.request_call_banker(msg, user)
    if get_game_status() ~= GS.CALL_BANKER then
        LOG_ERROR("用户叫庄状态错误，当前状态:" .. get_game_status())
        return
    end

    if user_call_banker_status[user.chairid] then
        LOG_ERROR(string.format("用户%s(%d,%d)已经叫庄", user.nickname, user.gameid, user.chairid))
        return
    end

    if msg.index > 4 then
        LOG_ERROR(string.format("用户%s(%d,%d)叫庄倍数(%d)错误", user.nickname, user.gameid, user.chairid, msg.index))
        return
    end

    local notifymsg = {}
    notifymsg.call_banker_chairid = user.chairid
    notifymsg.call_banker_times = msg.index
    send_msg_to_table_chair("notify_call_banker", notifymsg)
    send_msg_to_ob_chair("notify_call_banker", notifymsg)

    user_call_banker_status[user.chairid] = true
    user_call_banker_times[user.chairid] = msg.index
    if double_bet and msg.index == 4 then
        user_can_double_bet[user.chairid] = true
    end

    local player_count = 0
    local call_banker_user_count = 0
    local users = get_all_table_users()
    for k, v in pairs(users) do
        player_count = player_count + 1
        if user_playing[k] and user_call_banker_status[k] then
            call_banker_user_count = call_banker_user_count + 1
        elseif not user_playing[k] then
            call_banker_user_count = call_banker_user_count + 1
        end
    end

    -- 叫庄结束
    if player_count == call_banker_user_count then
        set_game_status(GS.BET)

        notifymsg = {}

        -- 确定庄家
        local call_banker_times_user_list = { {}, {}, {}, {}, {} }
        for k, v in pairs(users) do
            if user_playing[k] then
                table.insert(call_banker_times_user_list[user_call_banker_times[k] + 1], k)
            end
        end

        for i = #call_banker_times_user_list, 1, -1 do
            local l = call_banker_times_user_list[i]
            if #l > 0 then
                banker_chairid = l[math.random(#l)]
                notifymsg.banker_chairid = banker_chairid
                notifymsg.call_user_list = l

                break
            end
        end

        if user_call_banker_times[banker_chairid] == 0 then
            user_call_banker_times[banker_chairid] = 1
        end

        notifymsg.banker_times = user_call_banker_times[banker_chairid]
        notifymsg.user_can_bet_score = user_can_bet_score
        for k, v in pairs(users) do
            notifymsg.allow_double_bet = user_can_double_bet[k]
            send_msg_to_table_chair("notify_start_bet", notifymsg, k)
        end
        notifymsg.allow_double_bet = false
        send_msg_to_ob_chair("notify_start_bet", notifymsg)

        kill_timer(TIMER_CALL_BANKER[1])
        set_timer(TIMER_BET[1], TIMER_BET[2])
    end
end

function game.request_bet(msg, user)
    if get_game_status() ~= GS.BET then
        LOG_ERROR("用户下注状态错误，当前状态:" .. get_game_status())
        return false
    end

    if user_bet_score[user.chairid] ~= 0 then
        LOG_ERROR(string.format("用户%s(%d,%d)已经下注%d", user.nickname, user.gameid, user.chairid, user_bet_score[user.chairid]))
        return
    end

    local bet_success = false
    for i = 1, #user_can_bet_score do
        if user_can_bet_score[i] == msg.bet_score or (user_can_double_bet[user.chairid] and msg.bet_score == user_can_bet_score[i] * 2) then
            bet_success = true
            break
        end
    end
    if not bet_success then
        LOG_ERROR(string.format("用户%s(%d,%d)下注失败%d", user.nickname, user.gameid, user.chairid, msg.bet_score))
        return false
    end

    if user.chairid == banker_chairid then
        LOG_ERROR(string.format("用户%s(%d,%d)是庄家，下注失败", user.nickname, user.gameid, user.chairid))
        return false
    end

    if msg.bet_score > user.score then
        LOG_ERROR(string.format("用户%s(%d,%d)的分数(%d)不够，下注%d失败", user.nickname, user.gameid, user.chairid, user.score, msg.bet_score))
        return false
    end

    user_bet_score[user.chairid] = msg.bet_score

    local notifymsg = {}
    notifymsg.bet_chairid = user.chairid
    notifymsg.bet_score = msg.bet_score
    send_msg_to_table_chair("notify_bet", notifymsg)
    send_msg_to_ob_chair("notify_bet", notifymsg)

    -- 下注结束
    local player_count = 0
    local bet_user_count = 0
    local users = get_all_table_users()
    for k, v in pairs(users) do
        player_count = player_count + 1
        if user_playing[k] and user_bet_score[k] > 0 then
            bet_user_count = bet_user_count + 1
        elseif not user_playing[k] or k == banker_chairid then
            bet_user_count = bet_user_count + 1
        end
    end

    if player_count == bet_user_count then
        set_game_status(GS.OPEN_CARD)

        notifymsg = {}
        local black_cards = { 0, 0, 0, 0, 0 }
        for k, v in pairs(users) do
            if user_playing[k] then
                notifymsg.cards_data = user_cards_data[k]
                send_msg_to_table_chair("notify_start_open_card", notifymsg, k)
            else
                notifymsg.cards_data = black_cards
                send_msg_to_table_chair("notify_start_open_card", notifymsg, k)
            end
        end
        notifymsg.cards_data = black_cards
        send_msg_to_ob_chair("notify_start_open_card", notifymsg)

        kill_timer(TIMER_BET[1])
        set_timer(TIMER_OPEN_CARD[1], TIMER_OPEN_CARD[2])
    end

    return true
end

function game.request_open_card(msg, user)
    if get_game_status() ~= GS.OPEN_CARD then
        LOG_ERROR("用户开牌状态错误，当前状态:" .. get_game_status())
        return
    end

    if user_open_cards_data[user.chairid][1] ~= 0 then
        LOG_ERROR(string.format("用户%s(%d,%d)重复开牌", user.nickname, user.gameid, user.chairid))
        return
    end

    user_open_card_type[user.chairid], user_open_cards_data[user.chairid] = logic.get_max_card_type(user_cards_data[user.chairid])
    user_open_card_times[user.chairid] = logic.get_card_type_times(user_open_cards_data[user.chairid], user_open_card_type[user.chairid])

    local notifymsg = {}
    notifymsg.open_chairid = user.chairid
    notifymsg.open_card_type = user_open_card_type[user.chairid]
    notifymsg.open_cards_data = user_open_cards_data[user.chairid]
    notifymsg.open_card_times = user_open_card_times[user.chairid]
    send_msg_to_table_chair("notify_open_cards", notifymsg)
    send_msg_to_ob_chair("notify_open_cards", notifymsg)

    -- 开牌结束
    local player_count = 0
    local open_user_count = 0
    local users = get_all_table_users()
    for k, v in pairs(users) do
        player_count = player_count + 1
        if user_playing[k] and user_open_cards_data[k][1] ~= 0 then
            open_user_count = open_user_count + 1
        elseif not user_playing[k] then
            open_user_count = open_user_count + 1
        end
    end

    if player_count == open_user_count then
        kill_timer(TIMER_OPEN_CARD[1])
        game.game_end()
    end
end

-- 游戏结束
function game.game_end()
    set_game_status(GS.FREE)

    local notifymsg = {}
    notifymsg.game_score = {}
    for i = 1, max_chair_count do
        notifymsg.game_score[i] = 0
    end
    local users = get_all_table_users()
    
    local banker_win_score = 0          -- 庄家赢分
    local loser_total_lose_score = 0    -- 输家的实际总输分
    local loser_total_bet_score = 0     -- 输家总下注
    local banker_card_times = user_open_card_times[banker_chairid]    -- 庄家牌的倍数
    local losers = {}    -- 所有输家chairid
    local winners = {}  -- 所有赢家chairid
    for k, v in pairs(users) do
        if user_playing[k] and k ~= banker_chairid then
            if logic.compare_cards(user_open_cards_data[banker_chairid], user_open_cards_data[k]) then
                local win_score = user_bet_score[k] * banker_card_times * user_call_banker_times[banker_chairid]
                win_score = math.min(win_score, v.score)
                notifymsg.game_score[k] = -win_score
                banker_win_score = banker_win_score + win_score
                table.insert(losers, k)
                loser_total_lose_score = loser_total_lose_score + win_score
                loser_total_bet_score = loser_total_bet_score + user_bet_score[k]
            else
                table.insert(winners, k)
            end
        end
    end

    local banker_total_score = banker_win_score + users[banker_chairid].score   -- 庄家的总分数
    local winners_total_win_score = 0   -- 赢家总赢分

    if #winners > 0 then
        local winner_max_win_score = {}
        local winner_max_total_win_score = 0
        for k, v in ipairs(winners) do
            local times = user_open_card_times[v]
            local win_score = user_bet_score[v] * times * user_call_banker_times[banker_chairid]
            win_score = math.min(win_score, users[v].score)
            table.insert(winner_max_win_score, win_score)
            winner_max_total_win_score = winner_max_total_win_score + win_score
        end

        local temp_banker_total_score = banker_total_score
        for k, v in ipairs(winners) do
            local win_score = winner_max_win_score[k]
            if temp_banker_total_score < winner_max_total_win_score then
                local each_score = temp_banker_total_score * win_score / winner_max_total_win_score
                win_score = math.min(win_score, each_score)
            end
            banker_total_score = banker_total_score - win_score
            notifymsg.game_score[v] = win_score
            winners_total_win_score = winners_total_win_score + win_score
        end
    end

    -- 庄家赢分超过自己携带分数 需要返还
    if banker_total_score > users[banker_chairid].score * 2 then
        notifymsg.game_score[banker_chairid] = users[banker_chairid].score

        local unreturn_users = {}
        local unreturn_total_score = 0
        local is_score_enough = true  -- 是否所有用户分都够,如有不够的就只返还足额用户
        for k, v in ipairs(losers) do
            local rate_lose_score = (winners_total_win_score + users[banker_chairid].score) * user_bet_score[v] / loser_total_bet_score
            if rate_lose_score <= users[v].score then
                table.insert(unreturn_users, v)
                unreturn_total_score = unreturn_total_score + user_bet_score[v]
            else
                is_score_enough = false
            end
        end

        if is_score_enough then
            for k, v in ipairs(losers) do
                local rate_lose_score = (winners_total_win_score + users[banker_chairid].score) * user_bet_score[v] / loser_total_bet_score
                notifymsg.game_score[v] = -rate_lose_score
            end
        else
            for k, v in ipairs(unreturn_users) do
                local each_score = (banker_total_score - users[banker_chairid].score * 2) * user_bet_score[v] / unreturn_total_score
                notifymsg.game_score[v] = notifymsg.game_score[v] + each_score
            end
        end
    else
        notifymsg.game_score[banker_chairid] = banker_total_score - users[banker_chairid].score
    end

    -- 计算税收
    local revenue_rate = config.revenue
    local user_revenue = {}
    local user_performance = {}
    for i = 1, max_chair_count do
        user_revenue[i] = 0
        user_performance[i] = 0
    end
    for k, v in pairs(users) do
        if user_playing[k] then
            user_performance[k] = math.floor(math.abs(notifymsg.game_score[k]) * revenue_rate)
        end

        if user_playing[k] and notifymsg.game_score[k] > 0 then
            user_revenue[k] = math.floor(notifymsg.game_score[k] * revenue_rate)
            notifymsg.game_score[k] = notifymsg.game_score[k] - user_revenue[k]
        end

        if user_playing[k] then
            write_user_score(k, notifymsg.game_score[k], user_revenue[k], user_performance[k], "log")
        end
    end
    send_msg_to_table_chair("notify_game_end", notifymsg)
    send_msg_to_ob_chair("notify_game_end", notifymsg)

    end_game()
end

-- 用户是否正在游戏
function game.is_user_playing(chairid)
    return user_playing[chairid]
end

-- 用户坐下通知
function game.on_user_sitdown(chairid, user, is_obuser)
    if not is_obuser then
        if user.gate == "robot" then
           -- robots[chairid] = robot.new(user, game.on_robot_game_msg, game.super.user_ready)
        end
    end
end

-- 用户起立通知
function game.on_user_standup(chairid, user, is_obuser)
    if not is_obuser then
        if user.gate == "robot" then
            --robots[chairid] = nil
        end
    end
end

-- 用户准备通知
function game.on_user_ready(chairid, user)
end

-- 用户断线通知
function game.on_user_offline(chairid, user)
end

-- 用户重连通知
function game.on_user_reconnect(chairid, user)
end

-- 机器人进入
function game.on_robot_enter(chairid, user)
    robots[chairid] = robot.new(user, game.on_robot_game_msg, game.super.user_ready)
end

-- 机器人离开
function game.on_robot_leave(chairid, user)
    robots[chairid] = nil
end

return game
