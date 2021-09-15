local skynet = require "skynet"
local cluster = require "skynet.cluster"
local protobuf = require "protobuf"
local random = require "random"
local queue = require "skynet.queue"
local conf = require "config"
local roomid = tonumber(skynet.getenv("clusterid"))
local config = conf[roomid]

local game = require "game"
game.super = {}

--TODO 加上CS 保证顺序执行
--local cs = queue()
local CMD = {}

local gametable = {}
--gametable.__index = gametable
--setmetatable(game, gametable)
game.super = gametable

gametable._table_users = {}    -- chairid : { userinfo, init_game }
gametable._table_ob_users = {}        -- chairid : { userinfo, init_game }
gametable._tableid = 0
gametable._subroomid = 0
gametable._subroom_wanfaid = 0
gametable._game_started = false
gametable._game_start_time = skynet.time()
gametable._game_status = GAME_STATUS_FREE
gametable._drawid = 0
gametable._wanfa = ""

local max_chair_count = config.max_chair_count
local min_enter_score = 0

local all_is_robot = false
local game_records = {}

local timer_interval = 100
local timerid_game_offset = 1000000
local timers = {}       -- id : { delay, elapsed, repeated, func, game }
local function table_timer()
    local remove_timers = {}
    local timers_temp = table.clone(timers) -- 防止在func回调里移除计时器导致的迭代器失效
    for k, v in pairs(timers_temp) do
        v.elapsed = v.elapsed + timer_interval
        if v.elapsed >= v.delay then
            local id = k
            if v.game then
                id = id - timerid_game_offset
            end
            v.func(id)
            if v.repeated then
                v.elapsed = 0
            else
                table.insert(remove_timers, k)
            end
        end
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

--生成牌局编号
--TODO 这里其实还是可能会重复的 因为这个只作为游戏记录用 很小的重复影响也并不大 如有需要自行修改
local function make_drawid()
    local t = tostring(math.floor(skynet.time() * 100))
    local h = tostring(skynet.hpc())
    local e = string.sub(h, string.len(h) - 6)
    return tonumber(t .. e)
end

-- 获取最大椅子数目
local function get_max_chair_count(subroomid, subroom_wanfaid)
    if config.kindid == 3 then
        return config.subrooms[subroomid].wanfa[subroom_wanfaid].item[1]
    else
        return config.subrooms[subroomid].max_chair_count
    end
end

function CMD.start(tableid, subroomid, subroom_wanfaid)
    gametable._tableid = tableid
    gametable._subroomid = subroomid
    gametable._subroom_wanfaid = subroom_wanfaid

    gametable._table_users = {}
    gametable._table_ob_users = {}
    gametable._game_started = false
    gametable._game_start_time = skynet.time()
    gametable._game_status = GAME_STATUS_FREE
    gametable._wanfa = config.wanfa(config, subroomid, subroom_wanfaid)

    max_chair_count = get_max_chair_count(subroomid, subroom_wanfaid)
    min_enter_score = config.subrooms[gametable._subroomid].min_enter_score

    if game.on_init then
        game.on_init()
    end
end

-- 清理状态
function CMD.cleanup()
    gametable._tableid = 0
    gametable._subroomid = 0
    gametable._subroom_wanfaid = 0

    gametable._table_users = {}
    gametable._table_ob_users = {}
    gametable._game_started = false
    gametable._game_start_time = 0
    gametable._game_status = GAME_STATUS_FREE
    gametable._wanfa = ""

    timers = {}
end

local function forward_to_gate_server(source_gate, fd, pack)
    if source_gate ~= "robot" then
        cluster.send(source_gate, "@gateway", "pbrpc", pack, fd)
    end
end

local function reponse_action_failed(source_gate, fd, reason)
    local pack = netmsg_pack("game.reponse_action_failed", { reason = reason })
    forward_to_gate_server(source_gate, fd, pack)
end

local function check_table_rule(chairid, user)
    if config.subrooms[gametable._subroomid].min_enter_score ~= 0 and user.score < config.subrooms[gametable._subroomid].min_enter_score then
        reponse_action_failed(user.gate, user.fd, "余额不足，不能继续游戏")
        return false
    end
    return true
end

local function update_user_status(user, user_status, tableid, chairid, banker)
    local oldtableid = user.tableid
    local oldchairid = user.chairid

    user.tableid = tableid
    user.chairid = chairid
    user.user_status = user_status
    user.banker = banker

    if user.gate == "robot" then
        if not user.init_game and tableid ~= 0 then
            if game.on_robot_enter then
                game.on_robot_enter(chairid, user)
            end
            CMD.init_game(nil, chairid, user.userid)
        elseif user.init_game and tableid == 0 then
            user.init_game = false
            if game.on_robot_leave then
                game.on_robot_leave(oldchairid, user)
            end
        end
    end

    -- 通知gamemgr状态改变
    skynet.call("gamemgr", "lua", "tableevent", "update_user_status", user.userid, tableid, chairid, user_status, user.banker)

    if user_status == US_NULL or user_status == US_FREE then
        gametable._table_users[oldchairid] = nil
    end
end

local function update_table_status()
    local user_count = table.size(gametable._table_users)
    skynet.call("gamemgr", "lua", "tableevent", "update_table_status", gametable._tableid, gametable._game_started, user_count)
end

local function check_start_game(ready_chairid)
    if gametable.game_started or config.game_start_mode == START_MODE_TIME_CONTROL then return false end

    local ready_user_count = 0
    for k, v in pairs(gametable._table_users) do
        if not v.init_game then
            return false
        end
        if ready_chairid ~= k and v.user_status ~= US_READY then
            return false
        end
        ready_user_count = ready_user_count + 1
    end

    if config.game_start_mode == START_MODE_ALL_READY and ready_user_count >= 2 then
        return true
    elseif config.game_start_mode == START_MODE_FULL_READY and ready_user_count == max_chair_count then
        return true
    end

    return false
end

function CMD.user_sitdown(chairid, user)
    assert(chairid > 0)
    assert(user.tableid == 0 and user.chairid == 0)

    -- 游戏已经开始且不能游戏中加入
    local join_playing = config.allow_join_playing
    if gametable._game_started and not join_playing then
        reponse_action_failed(user.gate, user.fd, "游戏已经开始，不能进入游戏！")
        return false
    end

    local chair_user = gametable._table_users[chairid]
    -- 别人先坐下这个位置
    if chair_user then
        reponse_action_failed(user.gate, user.fd, "位置被占用，坐下失败")
        return false
    end

    -- 检查坐下规则
    local success = check_table_rule(chairid, user)
    if not success then
        return false
    end

    gametable._table_users[chairid] = user

    -- 更新用户状态
    if not gametable._game_started or config.game_start_mode ~= START_MODE_TIME_CONTROL then
        user.init_game = false
        update_user_status(user, US_SIT, gametable._tableid, chairid, user.banker)
    else
        user.init_game = false
        update_user_status(user, US_PLAYING, gametable._tableid, chairid, user.banker)
    end

    -- 通知游戏
    if game.on_user_sitdown then
        game.on_user_sitdown(chairid, user, false)
    end
end

function CMD.debug_table()
    return gametable._table_users
end

-- 用户起立
function CMD.user_standup(chairid, userid)
    local user = gametable._table_users[chairid]

    if user and user.userid == userid then
        if gametable._game_started and (user.user_status == US_PLAYING or user.user_status == US_OFFLINE) then
            local isplaying = true
            if game.is_user_playing then
                isplaying = game.is_user_playing(chairid)
            end
            if isplaying then return false end
        end

        -- 通知游戏
        if game.on_user_standup then
            game.on_user_standup(chairid, user, false)
        end

        --update_user_status(user, user.user_status == US_OFFLINE and US_NULL or US_FREE, 0, 0)
        update_user_status(user, US_FREE, 0, 0, false)

        -- 踢走旁观
        if table.size(gametable._table_users) == 0 then
            gametable.notify_system_message(NMT_CLOSE_GAME | NMT_POPUP, "游戏已经结束")
            gametable._table_ob_users = {}
        end

        -- 判断是否开始游戏
        local startgame = check_start_game(0)
        if startgame then
            gametable.start_game()
        end

        update_table_status()

        return true
    else
        for k, v in ipairs(gametable._table_ob_users) do
            if v.chairid == chairid and v.userid == userid then
                -- 通知游戏
                if game.on_user_standup then
                    game.on_user_standup(chairid, user, true)
                end

                update_user_status(v, US_FREE, 0, 0, false)
                table.remove(gametable._table_ob_users, k)
                return true
            end
        end

        LOG_ERROR("user_standup 无效的用户:" .. chairid .. "," .. userid)
        LOG_ERROR(debug.traceback())
    end

    return false
end

-- 机器人起立
function CMD.robot_standup(chairid, userid)
    if gametable._game_started then
        return
    end

    local player_count, robot_count, min_user_count, empty_chairid = CMD.get_table_info()

    if robot_count == 0 then
        return
    end

    local r = random.Get(1, 100)

    if player_count > 0 and r > 50 then
        return
    end
    if robot_count >= min_user_count and r > 50 then
        return
    end
    for k, v in pairs(gametable._table_users) do
        if v.is_robot then
            CMD.user_standup(k, v.userid)
            break
        end
    end
end

-- 用户旁观
function CMD.user_sitdown_ob(chairid, user)
    if not config.allow_ob and user.master_level == 0 then
        reponse_action_failed(user.gate, user.fd, "抱歉，游戏禁止用户旁观！")
        return false
    end

    table.insert(gametable._table_ob_users, user)
    update_user_status(user, US_OB, gametable._tableid, chairid, false)

    -- 通知游戏
    if game.on_user_sitdown then
        game.on_user_sitdown(chairid, user, true)
    end

    return true
end

-- 用户断线
function CMD.user_offline(chairid)
    local user = gametable._table_users[chairid]
    if not user then
        LOG_ERROR("user_offline 无效的用户")
        skynet.error("user_offline 无效的用户")
        return false
    end

    if user.user_status ~= US_OB then
        if (user.user_status == US_PLAYING or user.user_status == US_OFFLINE) and game.is_user_playing(chairid) then
            user.init_game = false
            update_user_status(user, US_OFFLINE, gametable._tableid, chairid, user.banker)

            if game.on_user_offline then
                game.on_user_offline(chairid, user)
            end

            return
        end
    end

    CMD.user_standup(chairid, user.userid)
end

function CMD.center_notify_update_score(chairid, score)
    local user = gametable._table_users[chairid]
    if not user then
        LOG_ERROR("user_offline 无效的用户")
        skynet.error("user_offline 无效的用户")
        return false
    end

    user.score = score
end

-- 删除桌子
function CMD.delete_table(force)
    if not force and gametable._game_started then
        return false
    end

    -- 先解散游戏
    if gametable._game_started then
        if game.on_game_dissolve then
            game.on_game_dissolve()
        end
    end

    gametable._game_started = false

    -- 所有用户起立
    local reason = "游戏已经被管理员解散"
    local spectators = table.clone(gametable._table_ob_users, true)
    for k, v in pairs(spectators) do
        gametable.notify_system_message(bit.bor(NMT_CLOSE_GAME, NMT_POPUP), reason, v.chairid)
        -- 通知游戏
        if game.on_user_standup then
            game.on_user_standup(v.chairid, v, true)
        end
        CMD.user_standup(v.chairid, v.userid)
    end

    local users = table.clone(gametable._table_users, true)
    for k, v in pairs(users) do
        gametable.notify_system_message(bit.bor(NMT_CLOSE_GAME, NMT_POPUP), reason, v.chairid)
        -- 通知游戏
        if game.on_user_standup then
            game.on_user_standup(v.chairid, v, false)
        end
        CMD.user_standup(v.chairid, v.userid)
    end

    update_table_status()

    return true
end

-- 获取可以坐下的椅子号
function CMD.get_can_sit_chairid()
    for i = 1, max_chair_count do
        if gametable._table_users[i] == nil then
            return i
        end
    end

    return 0
end

-- 游戏消息
function CMD.game_msg(msg, chairid)
    local user = gametable._table_users[chairid]
    if not user then
        LOG_ERROR("game_msg 用户不存在")
        return false
    end

    if game.on_game_msg then
        return game.on_game_msg(msg, user)
    end

    return false
end

-- 初始化游戏
function CMD.init_game(msg, chairid, userid)
    local user = gametable._table_users[chairid]
    if not user then
        for k, v in ipairs(gametable._table_ob_users) do
            if v.chairid == chairid and v.userid == userid then
                user = v
                break
            end
        end
        if not user then
            LOG_ERROR("init_game 用户不存在")
            return
        end
    end

    user.init_game = true

    if game.on_notify_game_scene then
        game.on_notify_game_scene(chairid, user, gametable._game_status)
    end

    -- 是否开始游戏
    if user.user_status == US_READY and check_start_game(chairid) then
        gametable.start_game()
    end
end

-- 用户准备
function CMD.user_ready(msg, chairid)
    local user = gametable._table_users[chairid]
    if not user then
        LOG_ERROR("user_ready 用户不存在")
        return
    end

    if user.user_status ~= US_SIT then
        return
    end

    if game.on_user_ready then
        game.on_user_ready(chairid, user)
    end

    -- 是否开始游戏
    if check_start_game(chairid) then
        gametable.start_game()
    else
        update_user_status(user, US_READY, gametable._tableid, chairid, false)
    end
end

-- 更新连接信息
function CMD.update_user_conn(chairid, source_gate, fd, ip, uuid)
    local user = gametable._table_users[chairid]
    if not user then
        LOG_ERROR("update_user_conn 用户不存在")
        return
    end

    user.gate = source_gate
    user.fd = fd
    user.ip = ip
    user.uuid = uuid

    update_user_status(user, US_PLAYING, gametable._tableid, user.chairid, user.banker)

    if game.on_user_reconnect then
        game.on_user_reconnect(user.chairid, user)
    end
end

-- 获取桌子信息
function CMD.get_table_info()
    local player_count = 0
    local robot_count = 0
    for k, v in pairs(gametable._table_users) do
        if v.is_robot then
            robot_count = robot_count + 1
        else
            player_count = player_count + 1
        end
    end

    local min_user_count = 0
    if config.game_start_mode == START_MODE_ALL_READY then
        min_user_count = 2
    elseif config.game_start_mode == START_MODE_TIME_CONTROL then
        min_user_count = 1
    else
        min_user_count = max_chair_count
    end

    local empty_chairid = 0
    if player_count + robot_count < max_chair_count then
        for i = 1, max_chair_count do
            if not gametable._table_users[i] then
                empty_chairid = i
                break
            end
        end
    end

    return player_count, robot_count, min_user_count, empty_chairid
end

skynet.start(function ()
    skynet.dispatch("lua", function (_,_, id, ...)
        local f = CMD[id]
        skynet.ret(skynet.pack(f(...)))
    end)

    protobuf.register_file("./protocol/netmsg.pb")
    protobuf.register_file("./protocol/center.pb")
    protobuf.register_file("./protocol/game.pb")

    skynet.timeout(timer_interval, table_timer)
end)

-- 开始游戏
function gametable.start_game()
    if gametable._game_started then
        return
    end
    
    gametable._game_started = true
    gametable._game_start_time = skynet.time()
    gametable._drawid = make_drawid()

    all_is_robot = true
    for k, v in pairs(gametable._table_users) do
        if not v.is_robot then
            all_is_robot = false
        end
        if v.user_status ~= US_OFFLINE and v.user_status ~= US_PLAYING then
            update_user_status(v, US_PLAYING, gametable._tableid, k, v.banker)
        end
    end

    update_table_status()

    if game.on_game_start then
        game.on_game_start()
    end
end

-- 结束游戏
function gametable.end_game()
    assert(gametable._game_started)
    if not gametable._game_started then return end

    gametable._game_started = false

    -- 游戏记录
    -- TODO 如果是系统做庄 balance需要修改
    --if not all_is_robot then
        local str_start_time = os.date("%Y-%m-%d %H:%M:%S", math.floor(gametable._game_start_time))
        local now = math.floor(skynet.time())
        local str_end_time = os.date("%Y-%m-%d %H:%M:%S", now)
        local user_count = 0
        local robot_count = 0
        local balance = 0
        local revenue = 0
        for k, v in pairs(game_records) do
            if gametable._table_users[k].is_robot then
                robot_count = robot_count + 1
                balance = balance + v.score + v.revenue
            else
                user_count = user_count + 1
                balance = balance - v.score - v.revenue
            end
            revenue = revenue + v.revenue
            local performance
            if gametable._table_users[k].is_club_user then
                performance = v.performance
            end

            skynet.call("gamemgr", "lua", "tableevent", "write_game_record_detail", v.userid, gametable._drawid,
            gametable._tableid, k, v.score, v.revenue, v.start_score, v.start_bank_score, v.play_time, v.gamelog, gametable._wanfa, performance)
        end
        skynet.call("gamemgr", "lua", "tableevent", "write_game_record", gametable._drawid,
            gametable._tableid, user_count, robot_count, balance, revenue, str_start_time, str_end_time, gametable._wanfa)
        game_records = {}
    --end

    local standup_users = {}
    for k, v in pairs(gametable._table_users) do
        if v.user_status == US_OFFLINE then
            table.insert(standup_users, { k, v.userid, "" })
        elseif min_enter_score ~= 0 and v.score < min_enter_score then
            table.insert(standup_users, { k, v.userid, "余额不足，不能继续游戏" })
        else
            update_user_status(v, US_SIT, gametable._tableid, k, v.banker)
        end
    end

    if game.on_game_reset then
        game.on_game_reset()
    end

    -- 条件不合适的的踢出
    for k, v in ipairs(standup_users) do
        if v[3] ~= "" then
            -- 发送消息
            gametable.notify_system_message(NMT_CLOSE_GAME | NMT_POPUP, v[3], v[1])
        end
        CMD.user_standup(v[1], v[2])
    end

    update_table_status()
end

-- 解散游戏
function gametable.dissolve_game()
    if not gametable._game_started then return end

    if game.on_game_dissolve then
        game.on_game_dissolve()
    end

    update_table_status()
end

-- 设置计时器
function gametable.set_timer(id, delay, repeated)
    id = id + timerid_game_offset
    delay = delay * timer_interval
    repeated = repeated or false
    timers[id] = { delay = delay, elapsed = 0, repeated = repeated, func = game.on_timer, game = true }
end

-- 删除计时器
function gametable.kill_timer(id)
    id = id + timerid_game_offset
    timers[id] = nil
end

-- 写入分数
function gametable.write_user_score(chairid, score, revenue, performance, gamelog, play_time)
    local user = gametable._table_users[chairid]
    if not user then
        LOG_ERROR("write_user_score 用户不存在")
        return
    end

    gamelog = gamelog or ""
    if not play_time then
        play_time = 0
        local now = skynet.time()
        if gametable._game_started then
            play_time = math.floor(now - gametable._game_start_time)
        end
    end

    local start_score = user.score
    local start_bank_score = user.bank_score
    user.score = user.score + score
    user.balance_score = user.balance_score + score
    user.today_balance_score = user.today_balance_score + score
    if score > 0 then
        user.win_count = user.win_count + 1
    elseif score < 0 then
        user.lost_count = user.lost_count + 1
    else
        user.draw_count = user.draw_count + 1
    end

    -- 写入记录
    game_records[chairid] = { userid = user.userid, score = score, revenue = revenue, start_score = start_score,
    start_bank_score = start_bank_score ,play_time = play_time, gamelog = gamelog, performance = performance }

    -- 写入分数
    --if not user.is_robot then
        skynet.call("gamemgr", "lua", "tableevent", "update_user_score", user.userid, score, revenue, play_time, gametable._drawid)
    --end
end

function gametable.notify_system_message(type, text, chairid)
    chairid = chairid or 0
    local pack = netmsg_pack("game.notify_system_message", { type = type, text = text })
    if chairid == 0 then
        for k, v in pairs(gametable._table_users) do
            if v.init_game then
                forward_to_gate_server(v.gate, v.fd, pack)
            end
        end

        for k, v in ipairs(gametable._table_ob_users) do
            if v.init_game then
                forward_to_gate_server(v.gate, v.fd, pack)
            end
        end
    else
        local user = gametable._table_users[chairid]
        if not user or not user.init_game then
            return
        end
        forward_to_gate_server(user.gate, user.fd, pack)

        for k, v in ipairs(gametable._table_ob_users) do
            if v.init_game and v.chairid == chairid then
                forward_to_gate_server(v.gate, v.fd, pack)
            end
        end
    end
end

function gametable.user_standup(user)
    CMD.user_standup(user.chairid, user.userid)
end

function gametable.user_ready(user)
    CMD.user_ready(nil, user.chairid) 
end

function gametable.set_banker(user, banker)
    update_user_status(user, user.user_status, user.tableid, user.chairid, banker or false)
end
