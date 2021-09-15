
local game = {}
local skynet = require "skynet"
local cluster = require "skynet.cluster"
local protobuf = require "protobuf"
local logic = require "logic_lhd"
local robot = require "robot_lhd"
local conf = require "config"
local clusterid = tonumber(skynet.getenv("clusterid"))
local config = conf[clusterid]
local random = require "random"
local cjson = require "cjson"

protobuf.register_file("./protocol/netmsg.pb")
local gamename = "lhd"
protobuf.register_file(string.format("./protocol/%s.pb", gamename))

local robots = {}

-- 准备计时
local TIMER_FREE = { 1, 1 }
local TIMER_BET = { 2, 15 }
local TIMER_OPEN_CARD = { 3, 8 }

-- 游戏状态
local GS = {
    FREE = GAME_STATUS_FREE,
    BET = GAME_STATUS_PLAY,
    OPEN_CARD = GAME_STATUS_PLAY + 1
}

-- 下注分数
local user_can_bet_score = { 100, 500, 1000, 5000, 10000, 50000, 100000 }

-- 这里应当使用game.super._subroomid 但是由于require这个文件的时候还没有赋值super 需要延后到on_init函数 懒得写了 直接写固定值就可以了 反正也是固定值
local max_chair_count = config.subrooms[1].max_chair_count
-- 系统庄家的分数
local sys_banker_score = config.subrooms[1].sys_banker_score
-- 用户下注限制
local user_bet_limit = config.subrooms[1].user_bet_limit
-- 区域下注限制
local area_bet_limit = config.subrooms[1].area_bet_limit
-- 上庄条件
local banker_condition = config.subrooms[1].banker_condition
-- 下庄条件
local downbanker_condition = config.subrooms[1].downbanker_condition
-- 下注条件
local bet_condition = config.subrooms[1].bet_condition
-- 允许系统坐庄
local enable_sys_banker = config.subrooms[1].enable_sys_banker
-- 允许机器人坐庄
local enable_robot_banker = config.subrooms[1].enable_robot_banker
-- 抽水比例
local revenue_rate = config.revenue
-- 底分
local base_score = 1
-- 开始时间
local stage_start_time = 0
-- 庄家
local current_banker = 0
-- 庄家分数
local banker_reserve_score = 0
-- 初始上庄分数
local banker_init_reserve_score = 0
-- 连庄次数
local banker_count = 0
-- 庄家请求下庄
local banker_request_down = false

-- 区域总下注 { long, hu, he }
local all_bet_score = { 0, 0, 0 }
-- 用户区域下注 chairid->{ long, hu, he }
local user_bet_score = {}
-- 筹码信息 { bet_chairid=chairid, bet_score=score, bet_area=area }
local bet_chips_info = {}

-- 开牌数据
local cards_data = { 0, 0 }

-- 用户赢分 chairid->win_score
local user_win_score = {}
-- 用户抽水 chairid->revenue
local user_revenue = {}
-- 用户业绩 chairid->performance
local user_performance= {}

-- 上庄列表 { apply_chairid = chairid, reserve_score = reserve_score }
local apply_banker_list = {}
-- 游戏记录
local game_records = {}

-- 2边的用户 8个chairid
local top_user_list = {}

-- 用户对局记录 chairid->{ { 下注分数, 赢分 }, ...保存最近20局 }
local draw_records = {}

-- 排序对局记录函数
local function draw_records_sortfunc(a, b)
    local a_bet_score = 0
    local b_bet_score = 0
    local a_win_count = 0
    local b_win_count = 0
    for _, v in ipairs(a.records) do
        a_bet_score = a_bet_score + v[1]
        a_win_count = a_win_count + (v[2] > 0 and 1 or 0)
    end
    for _, v in ipairs(b.records) do
        b_bet_score = b_bet_score + v[1]
        b_win_count = b_win_count + (v[2] > 0 and 1 or 0)
    end
    if a_win_count > b_win_count then
        return true
    elseif a_win_count == b_win_count then
        return a_bet_score > b_bet_score
    else
        return false
    end
end

-- 排序对局记录
local function sort_draw_records()
    local t = {}
    for k, v in pairs(draw_records) do
        table.insert(t, { chairid = k, records = v })
    end
    table.sort(t, draw_records_sortfunc)
    return t
end

-- 增加对局记录
local function add_draw_record(chairid, bet_score, win_score)
    local dr = draw_records[chairid]
    if not dr then
        dr = {}
        draw_records[chairid] = dr
    end

    table.insert(dr, { bet_score, win_score })
end

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

-- 计算哪个区域赢
local function calc_win_area()
    local long = cards_data[1] & 0x0F
    local hu = cards_data[2] & 0x0F
    if long == hu then
        return 2
    elseif long > hu then
        return 0
    else
        return 1
    end
end

-- 计算每个玩家的赢分 返回系统输赢
local function calc_win_score()
    for i = 0, max_chair_count do
        user_win_score[i] = 0
        user_revenue[i] = 0
        user_performance[i] = 0
    end

    local win_area = calc_win_area()
    local banker_is_robot = current_banker == 0 or get_table_user(current_banker).is_robot

    local all_users = get_all_table_users()
    local banker_win_score = 0
    local system_win_score = 0
    for k, v in pairs(all_users) do
        if k ~= current_banker then
            user_performance[k] = math.floor((user_bet_score[k][1] + user_bet_score[k][2] + user_bet_score[k][3]) * revenue_rate)
            if win_area == 2 then
                local win_score = user_bet_score[k][win_area + 1] * 16
                user_win_score[k] = user_win_score[k] + win_score
                banker_win_score = banker_win_score - win_score

                if win_score > 0 then
                    local revenue = math.floor(win_score * revenue_rate)
                    user_revenue[k] = user_revenue[k] + revenue
                    user_win_score[k] = user_win_score[k] - revenue
                end

                if banker_is_robot then
                    if not v.is_robot then
                        system_win_score = system_win_score - win_score
                    end
                else
                    if v.is_robot then
                        system_win_score = system_win_score + win_score
                    end
                end
            else
                if win_area == 0 then
                    user_win_score[k] = user_win_score[k] + user_bet_score[k][1]
                    banker_win_score = banker_win_score - user_bet_score[k][1]
                    if user_bet_score[k][1] > 0 then
                        local revenue = math.floor(user_bet_score[k][1] * revenue_rate)
                        user_revenue[k] = user_revenue[k] + revenue
                        user_win_score[k] = user_win_score[k] - revenue
                    end

                    user_win_score[k] = user_win_score[k] - user_bet_score[k][2] - user_bet_score[k][3]
                    banker_win_score = banker_win_score + user_bet_score[k][2] + user_bet_score[k][3]

                    if banker_is_robot then
                        if not v.is_robot then
                            system_win_score = system_win_score - user_bet_score[k][1]
                            system_win_score = system_win_score + user_bet_score[k][2] + user_bet_score[k][3]
                        end
                    else
                        if v.is_robot then
                            system_win_score = system_win_score + user_bet_score[k][1]
                            system_win_score = system_win_score - user_bet_score[k][2] - user_bet_score[k][3]
                        end
                    end
                else
                    user_win_score[k] = user_win_score[k] + user_bet_score[k][2]
                    banker_win_score = banker_win_score - user_bet_score[k][2]
                    if user_bet_score[k][2] > 0 then
                        local revenue = math.floor(user_bet_score[k][2] * revenue_rate)
                        user_revenue[k] = user_revenue[k] + revenue
                        user_win_score[k] = user_win_score[k] - revenue
                    end

                    user_win_score[k] = user_win_score[k] - user_bet_score[k][1] - user_bet_score[k][3]
                    banker_win_score = banker_win_score + user_bet_score[k][1] + user_bet_score[k][3]

                    if banker_is_robot then
                        if not v.is_robot then
                            system_win_score = system_win_score - user_bet_score[k][2]
                            system_win_score = system_win_score + user_bet_score[k][1] + user_bet_score[k][3]
                        end
                    else
                        if v.is_robot then
                            system_win_score = system_win_score + user_bet_score[k][2]
                            system_win_score = system_win_score - user_bet_score[k][1] - user_bet_score[k][3]
                        end
                    end
                end
            end
        end
    end

    user_win_score[current_banker] = banker_win_score
    user_performance[current_banker] = math.floor(math.abs(banker_win_score) * revenue_rate)
    if banker_win_score > 0 then
        local revenue = math.floor(banker_win_score * revenue_rate)
        user_revenue[current_banker] = user_revenue[current_banker] + revenue
        user_win_score[current_banker] = user_win_score[current_banker] - revenue
    end

    return system_win_score
end

-- 开奖
local function open_cards()
    cards_data = logic.shuffle(2)

    local system_win_score = calc_win_score()

    banker_reserve_score = banker_reserve_score + user_win_score[current_banker]

    -- 游戏记录
    local win_area = calc_win_area()
    if #game_records >= 20 then
        table.remove(game_records, 1)
    end
    table.insert(game_records, win_area)

    local notify_open_cards = {}
    notify_open_cards.time_leave = TIMER_OPEN_CARD[2]
    notify_open_cards.cards_data = cards_data
    notify_open_cards.win_area = win_area
    notify_open_cards.win_score = {}

    for k, v in ipairs(top_user_list) do
        if v ~= 0 then
            notify_open_cards.win_score[k] = user_win_score[v]
        else
            notify_open_cards.win_score[k] = 0
        end
    end

    local others_win_score = 0
    local all_users = get_all_table_users()
    for k, v in pairs(all_users) do
        local intop = false
        if k ~= current_banker then
            for _, chairid in ipairs(top_user_list) do
                if chairid == k then
                    intop = true
                    break
                end
            end
            if not intop then
                others_win_score = others_win_score + user_win_score[k]
            end
        end
    end
    notify_open_cards.win_score[10] = user_win_score[current_banker]

    for k, v in pairs(all_users) do
        notify_open_cards.win_score[9] = user_win_score[k]
        notify_open_cards.win_score[11] = others_win_score - user_win_score[k]
        send_msg_to_table_user("notify_open_cards", notify_open_cards, v)
    end
end

-- 发送上庄列表的用户
local function send_apply_banker_list(user)
    local notify_apply_list = {}
    notify_apply_list.apply_list = apply_banker_list
    send_msg_to_table_user("notify_apply_list", notify_apply_list, user)
end

-- 发送游戏记录
local function send_game_records(user)
    local notify_game_records = { records = game_records }
    send_msg_to_table_user("notify_game_records", notify_game_records, user)
end

-- 发送下注信息
local function send_bet_chips(user)
    local notify_bet_chips = { bet_chips = bet_chips_info }
    send_msg_to_table_user("notify_bet_chips", notify_bet_chips, user)
end

-- 发送2边的用户
local function send_top_users(user)
    local notify_top_players = { chairids = top_user_list }
    send_msg_to_table_user("notify_top_players", notify_top_players, user)
end

-- 轮换庄家
local function take_turns_banker()
    if get_game_status() ~= GS.FREE then
        return
    end

    local remove_users = {}
    for k, v in ipairs(apply_banker_list) do
        local user = get_table_user(v.apply_chairid)
        if user then
            if user.score >= v.reserve_score then
                current_banker = v.apply_chairid
                banker_init_reserve_score = v.reserve_score
                banker_reserve_score = v.reserve_score
                table.remove(apply_banker_list, k)
                break
            else
                local notify_cancel_banker = {}
                notify_cancel_banker.cancel_chairid = v.apply_chairid
                send_msg_to_table_chair("notify_cancel_banker", notify_cancel_banker)
                -- ipairs可以直接remove
                table.remove(apply_banker_list, k)
            end
        else
            local notify_cancel_banker = {}
            notify_cancel_banker.cancel_chairid = v.apply_chairid
            send_msg_to_table_chair("notify_cancel_banker", notify_cancel_banker)
            -- ipairs可以直接remove
            table.remove(apply_banker_list, k)
        end
    end
end

-- 机器人上庄
local function robot_upbanker()
    if enable_robot_banker and #apply_banker_list < 3 then
        local users = get_all_table_users()
        for k, v in pairs(users) do
            if v.is_robot and k ~= current_banker and v.score >= banker_condition then
                local already_apply = false
                for _, apply_user in ipairs(apply_banker_list) do
                    if k == apply_user.apply_chairid then
                        already_apply = true
                        break
                    end
                end
                if not already_apply then
                    local rate_list = {
                        { id = banker_condition, rate = 0.40 },
                        { id = banker_condition + 100000, rate = 0.30 },
                        { id = banker_condition + 200000, rate = 0.1 },
                        { id = banker_condition + 300000, rate = 0.1 },
                        { id = banker_condition + 400000, rate = 0.05 },
                        { id = banker_condition + 500000, rate = 0.05 }
                        }
                    local upbanker_score = random.GetId(rate_list)
                    if v.score >= upbanker_score then
                        game.request_apply_banker({reserve_score = upbanker_score}, v)
                        break
                    end
                end
            end
        end
    end
end

-- 更换庄家
local function change_banker(cancel_current_banker)
    robot_upbanker()

    local change = false
    local change_reason

    if cancel_current_banker then
        if current_banker ~= 0 then
            local banker_user = get_table_user(current_banker)
            game.super.set_banker(banker_user, false)
        end
        current_banker = 0
        take_turns_banker()
        change = true
        banker_count = 1
        change_reason = "庄家提前下庄，庄家更换"
    elseif current_banker ~= 0 then     -- 轮庄
        local banker_user = get_table_user(current_banker)
        local robot_down = false
        if banker_user.is_robot and (banker_reserve_score - banker_init_reserve_score > banker_init_reserve_score / 2) then
            robot_down = true
        end
        if banker_reserve_score < downbanker_condition or banker_count > 10 or robot_down then
            game.super.set_banker(banker_user, false)
            current_banker = 0
            take_turns_banker()
            change = true
            banker_count = 1
            if robot_down then
                change_reason = "庄家提前下庄，庄家更换"
            elseif banker_reserve_score < downbanker_condition then
                change_reason = "庄家金币不足，自动下庄"
            else
                change_reason = "庄家连庄次数达到10次，自动下庄"
            end
            
        end
    elseif current_banker == 0 and #apply_banker_list > 0 then
        take_turns_banker()
        change = true
        banker_count = 1
    end

    if change then
        local notify_change_banker = {}
        notify_change_banker.current_banker = current_banker
        if current_banker == 0 then
            banker_reserve_score = sys_banker_score
        end
        notify_change_banker.banker_reserve_score = banker_reserve_score
        notify_change_banker.banker_count = banker_count
        notify_change_banker.reason = change_reason
        send_msg_to_table_chair("notify_change_banker", notify_change_banker)

        if current_banker ~= 0 then
            local banker_user = get_table_user(current_banker)
            game.super.set_banker(banker_user, true)
        end
    end
end

-- 更新用户对局信息
local function update_draw_users(user)
    local t = sort_draw_records()
    local notify_user_list = {}
    notify_user_list.users = {}
    for k, v in ipairs(t) do
        local bet_score = 0
        local win_count = 0
        for _, r in ipairs(v.records or {}) do
            bet_score = bet_score + r[1]
            if r[2] > 0 then
                win_count = win_count + 1
            end
        end
        table.insert(notify_user_list.users, { chairid = v.chairid, bet_score = bet_score, win_count = win_count })
        if k == 20 then
            break
        end
    end

    send_msg_to_table_user("notify_user_list", notify_user_list, user)

    return t
end

local function update_top_users()
    for i = 1, 8 do
        top_user_list[i] = 0
    end

    local t = update_draw_users()
    for k, v in ipairs(t) do
        if v.chairid ~= current_banker then
            top_user_list[1] = v.chairid
            break
        end
    end

    -- 富豪
    local users = get_all_table_users()
    local topusers = {}
    for k, v in pairs(users) do
        if k ~= current_banker then
            table.insert(topusers, { chairid = k, score = v.score })
        end
    end
    table.sort(topusers, function(a, b)
        return a.score > b.score
    end)
    local top_index = 2
    for k, v in ipairs(topusers) do
        top_user_list[top_index] = v.chairid
        top_index = top_index + 1
        if top_index > 8 then
            break
        end
    end

    local notify_top_players = { chairids = top_user_list }
    send_msg_to_table_chair("notify_top_players", notify_top_players)
end

-- 获取用户可下注分数
local function get_user_max_bet_score(chairid, bet_area)
    local user = get_table_user(chairid)
    local max_bet_score = 0

    local total_bet_score = user_bet_score[chairid][1] + user_bet_score[chairid][2] + user_bet_score[chairid][3]
    if bet_area ~= 2 then
        if bet_area == 0 then
            max_bet_score = all_bet_score[2] - all_bet_score[1] + banker_reserve_score + all_bet_score[3]
        else
            max_bet_score = all_bet_score[1] - all_bet_score[2] + banker_reserve_score + all_bet_score[3]
        end
    else
        max_bet_score = math.floor(banker_reserve_score / 16) - all_bet_score[3]
    end

    max_bet_score = math.min(max_bet_score, user_bet_limit - total_bet_score, user.score - total_bet_score, area_bet_limit - all_bet_score[bet_area + 1])
    max_bet_score = math.max(0, max_bet_score)
    return max_bet_score
end

-- 游戏初始化
function game.on_init()
    -- 机器人使用
    set_timer(0, 1, true)

    for i = 1, max_chair_count do
        user_bet_score[i] = { 0, 0, 0 }
    end
end

-- 游戏重置 一般用于游戏结束后清理相关的逻辑变量
function game.on_game_reset()
    all_bet_score = { 0, 0, 0 }
    for i = 1, max_chair_count do
        user_bet_score[i] = { 0, 0, 0 }
        user_win_score[i] = 0
        user_revenue[i] = 0
        user_performance[i] = 0
    end
    bet_chips_info = {}

    cards_data = { 0, 0 }
end

-- 游戏开始通知
function game.on_game_start()
    local notify_game_start = {}
    notify_game_start.dealid = drawid()
    notify_game_start.time_leave = TIMER_BET[2]
    notify_game_start.current_banker = current_banker
    notify_game_start.banker_count = banker_count
    if current_banker == 0 then
        banker_reserve_score = sys_banker_score
    end
    notify_game_start.banker_reserve_score = banker_reserve_score

    send_msg_to_table_chair("notify_game_start", notify_game_start)


end

-- 游戏解散通知
function game.on_game_dissolve()
end

-- 通知客户端当前游戏的场景
function game.on_notify_game_scene(chairid, user, game_status)
    local msg = {}
    msg.dealid = drawid()
    msg.enable_sys_banker = enable_sys_banker
    msg.banker_condition = banker_condition
    msg.downbanker_condition = downbanker_condition
    msg.user_bet_limit = user_bet_limit
    msg.area_bet_limit = area_bet_limit
    msg.bet_condition = bet_condition
    msg.current_banker = current_banker
    msg.banker_reserve_score = banker_reserve_score
    msg.banker_count = banker_count

    if game_status == GS.FREE then
        msg.time_leave = TIMER_FREE[2]
        send_msg_to_table_chair("notify_gs_free", msg, chairid)
    elseif game_status == GS.BET then
        msg.time_leave = TIMER_BET[2] - math.min(TIMER_BET[2], math.floor(skynet.time() - stage_start_time))
        msg.all_bet_score = all_bet_score
        msg.me_bet_score = user_bet_score[chairid]
        send_msg_to_table_chair("notify_gs_bet", msg, chairid)
    elseif game_status == GS.OPEN_CARD then
        msg.time_leave = TIMER_OPEN_CARD[2] - math.min(TIMER_OPEN_CARD[2], math.floor(skynet.time() - stage_start_time))
        msg.all_bet_score = all_bet_score
        msg.me_bet_score = user_bet_score[chairid]

        msg.cards_data = cards_data
        msg.win_area = calc_win_area()
        msg.win_score = {}
        for k, v in ipairs(top_user_list) do
            if v ~= 0 then
                msg.win_score[k] = user_win_score[v]
            else
                msg.win_score[k] = 0
            end
        end
    
        local others_win_score = 0
        local all_users = get_all_table_users()
        for k, v in pairs(all_users) do
            local intop = false
            if k ~= current_banker then
                for _, chairid in ipairs(top_user_list) do
                    if chairid == k then
                        intop = true
                        break
                    end
                end
                if not intop then
                    others_win_score = others_win_score + user_win_score[k]
                end
            end
        end
        msg.win_score[10] = user_win_score[current_banker]
        msg.win_score[9] = user_win_score[chairid]
        msg.win_score[11] = others_win_score - user_win_score[chairid]
        send_msg_to_table_chair("notify_gs_opencard", msg, chairid)
    end

    send_apply_banker_list(user)
    send_top_users(user)
    send_bet_chips(user)
    send_game_records(user)
    update_draw_users(user)
end

-- 游戏计时器
function game.on_timer(id)
    if id == 0 then
        for k, v in pairs(robots) do
            v:on_timer()
        end
    elseif id == TIMER_FREE[1] then
        start_game()
        set_game_status(GS.BET)
        stage_start_time = skynet.time()
        set_timer(TIMER_BET[1], TIMER_BET[2])
    elseif id == TIMER_BET[1] then
        set_game_status(GS.OPEN_CARD)
        stage_start_time = skynet.time()
        open_cards()
        set_timer(TIMER_OPEN_CARD[1], TIMER_OPEN_CARD[2])
    elseif id == TIMER_OPEN_CARD[1] then
        set_game_status(GS.FREE)
        stage_start_time = skynet.time()

        local all_users = get_all_table_users()
        for k, v in pairs(all_users) do
            if user_win_score[k] ~= 0 or user_revenue[k] ~= 0 or user_performance[k] ~= 0 then
                local tlog = {}
                tlog.banker = current_banker
                tlog.win_area = calc_win_area()
                tlog.bet_score = { user_bet_score[k][1], user_bet_score[k][2], user_bet_score[k][3] }
                write_user_score(k, user_win_score[k], user_revenue[k], user_performance[k], cjson.encode(tlog))

                if k ~= current_banker then
                    add_draw_record(k, user_bet_score[k][1] + user_bet_score[k][2] + user_bet_score[k][3], user_win_score[k])
                end
            end
        end
        end_game()

        local notify_game_free = { time_leave = TIMER_FREE[2], current_banker = current_banker, banker_reserve_score = banker_reserve_score, banker_count = banker_count }
        send_msg_to_table_chair("notify_game_free", notify_game_free)

        -- 切换庄家
        banker_count = banker_count + 1
        change_banker(banker_request_down)
        banker_request_down = false

        if current_banker ~= 0 or enable_sys_banker then
            set_timer(TIMER_FREE[1], TIMER_FREE[2])
        else
            stage_start_time = 0
        end

        -- 更新TOP用户
        update_top_users()
    end
end

-- 客户端发送过来的消息
function game.on_game_msg(msg, user)
    local gamemsg = protobuf.decode(msg.name, msg.payload)
    if not gamemsg then
        LOG_ERROR(msg.name .. " decode error")
        return false
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

function game.request_bet(msg, user)
    if get_game_status() ~= GS.BET then
        LOG_ERROR("用户下注状态错误，当前状态:" .. get_game_status())
        return true
    end

    if msg.bet_area >= 3 then
        LOG_ERROR("用户下注区域错误:" .. msg.bet_area .. " userid:" .. user.userid)
        return false
    end

    local success = false
    for k, v in ipairs(user_can_bet_score) do
        if msg.bet_score == v then
            success = true
            break
        end
    end
    if not success then
        LOG_ERROR("用户下注分数错误:" .. msg.bet_score .. " userid:" .. user.userid)
        return false
    end

    if user.chairid == current_banker then
        return true
    end
    if not enable_sys_banker and current_banker == 0 then
        return true
    end

    local total_bet_score = user_bet_score[user.chairid][1] + user_bet_score[user.chairid][2] + user_bet_score[user.chairid][3]
    if total_bet_score + msg.bet_score > user.score then
        LOG_ERROR(string.format("用户(%d)下注分数不够, 已下注:%d,期望下注:%d,携带分数:%d", user.userid, total_bet_score, msg.bet_score, user.score))
        return true
    end
    if total_bet_score + msg.bet_score > user_bet_limit then
        LOG_ERROR(string.format("用户(%d)下注分数超过用户限制, 已下注:%d,期望下注:%d,用户下注限制:%d", user.userid, total_bet_score, msg.bet_score, user_bet_limit))
        return true
    end

    if get_user_max_bet_score(user.chairid, msg.bet_area) >= msg.bet_score then
        all_bet_score[msg.bet_area + 1] = all_bet_score[msg.bet_area + 1] + msg.bet_score
        user_bet_score[user.chairid][msg.bet_area + 1] = user_bet_score[user.chairid][msg.bet_area + 1] + msg.bet_score

        table.insert(bet_chips_info, { bet_chairid=user.chairid, bet_score=msg.bet_score, bet_area=msg.bet_area })

        local notify_bet = { bet_chairid=user.chairid, bet_score=msg.bet_score, bet_area=msg.bet_area }
        send_msg_to_table_chair("notify_bet", notify_bet)
    end
    
    return true
end

function game.request_apply_banker(msg, user)
    if msg.reserve_score < banker_condition then
        LOG_ERROR(string.format("用户%d申请上庄不符合条件%d,%d", user.userid, banker_condition, msg.reserve_score))
        return false
    end

    if user.chairid == current_banker then
        LOG_ERROR("庄家不能再次申请庄家")
        return true
    end

    for k, v in ipairs(apply_banker_list) do
        if user.chairid == v.apply_chairid then
            LOG_ERROR("用户已经在申请列表:%d", user.userid)
            return true
        end
    end

    table.insert(apply_banker_list, { apply_chairid = user.chairid, reserve_score = msg.reserve_score})
    table.sort(apply_banker_list, function(a, b)
        return a.reserve_score > b.reserve_score
    end)

    local notify_apply_banker = { apply_chairid = user.chairid, reserve_score = msg.reserve_score }
    send_msg_to_table_chair("notify_apply_banker", notify_apply_banker)

    if GS.FREE == get_game_status() and stage_start_time == 0 then
        change_banker()
        stage_start_time = skynet.time()
        set_timer(TIMER_FREE[1], TIMER_FREE[2])
        set_game_status(GS.FREE)
    end

    return true
end

function game.request_cancel_banker(msg, user)
    if user.chairid == current_banker then
        if GS.FREE == get_game_status() then
            change_banker(true)
        else
            banker_request_down = true
            local notify_cancel_banker = { cancel_chairid = user.chairid }
            send_msg_to_table_chair("notify_cancel_banker", notify_cancel_banker)
        end
    else
        for k, v in ipairs(apply_banker_list) do
            if user.chairid == v.apply_chairid then
                table.remove(apply_banker_list, k)
                local notify_cancel_banker = { cancel_chairid = user.chairid }
                send_msg_to_table_chair("notify_cancel_banker", notify_cancel_banker)
                break
            end
        end
    end

    return true
end

-- 用户是否正在游戏
function game.is_user_playing(chairid)
    if get_game_status() ~= GS.FREE then
        if chairid == current_banker then
            return true
        end

        local total_bet_score = 0
        for i = 1, 3 do
            total_bet_score = total_bet_score + user_bet_score[chairid][i]
        end

        if total_bet_score > 0 then
            return true
        end
    end
    return false
end

-- 用户坐下通知
function game.on_user_sitdown(chairid, user, is_obuser)
    if not is_obuser then
        draw_records[chairid] = {}

        if stage_start_time == 0 then
            robot_upbanker()
        end
    end
end

-- 用户起立通知
function game.on_user_standup(chairid, user, is_obuser)
    if not is_obuser then
        if chairid == current_banker then
            change_banker(true)
        else
            for k, v in ipairs(apply_banker_list) do
                if v.apply_chairid == chairid then
                    local notify_cancel_banker = {}
                    notify_cancel_banker.cancel_chairid = v.apply_chairid
                    send_msg_to_table_chair("notify_cancel_banker", notify_cancel_banker)
                    table.remove(apply_banker_list, k)
                    break
                end
            end
        end

        draw_records[chairid] = nil
        for i = 1, 8 do
            if top_user_list[i] == chairid then
                update_top_users()
            end
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
    robots[chairid] = robot.new(user, game.on_robot_game_msg, game.super.user_ready, config.subrooms[1].robotconf)
end

-- 机器人离开
function game.on_robot_leave(chairid, user)
    robots[chairid] = nil
end

return game
