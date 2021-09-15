
local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local cluster = require "skynet.cluster"
local protobuf = require "protobuf"
local queue = require "skynet.queue"
local conf = require "config"

local cs = queue()

local CMD = {}
local roomevent = {}
local tableevent = {}

local roomid = tonumber(skynet.getenv("clusterid"))
local config = conf[roomid]
local kindid = config.kindid
local clubid = config.clubid

local game_tables_pool = {} -- serviceid
local game_free_tableids = {}   -- 空闲tableid
local game_tables = {}  -- tableid : { serviceid, isplaying, subroomid, subroom_wanfaid }

local user_online = {}  -- userid : { userinfo, gate, fd, ip }
local user_online_by_gatefd = {} -- source_gate + fd : { userinfo, gate, fd, ip }

local robots = {}
local online_robots = {}

-- 关闭网关连接
local function close_connection(source_gate, fd, reason)
    if source_gate ~= "robot" then
        cluster.send(source_gate, "@gateway", "close_conn", fd, reason)
    end
end

-- 转发到网关
local function forward_to_gate_server(source_gate, fd, pack)
    if source_gate ~= "robot" then
        cluster.send(source_gate, "@gateway", "pbrpc", pack, fd)
    end
end

-- 获取最大椅子数目
local function get_max_chair_count(subroomid, subroom_wanfaid)
    if kindid == 3 then
        return config.subrooms[subroomid].wanfa[subroom_wanfaid].item[1]
    else
        return config.subrooms[subroomid].max_chair_count
    end
end

-- 创建机器人
local function create_robot()
    if #robots == 0 then
        return false
    end

    local robot = table.remove(robots)
    robot.enter_time = skynet.time()
    robot.play_time = math.random(robot.min_play_time, robot.max_play_time)
    robot.play_draw = math.random(robot.min_play_draw, robot.max_play_draw)
    online_robots[robot.userid] = robot

    cs(roomevent.request_enter_room, "robot", robot.userid, "0.0.0.0", { userid = robot.userid, password = robot.password, uuid = "internal" })
    --roomevent.request_enter_room("robot", robot.userid, "0.0.0.0", { userid = robot.userid, password = robot.password, uuid = "" })

    return true
end

-- 删除机器人
local function delete_robot(userid)
    online_robots[userid] = nil

    cluster.send("cluster_db", "@gamedbmgr", "game_robot_unlock", userid, roomid)
end

-- 加载机器人
local function load_robots()
    local ret, result = cluster.call("cluster_db", "@gamedbmgr", "game_robot_lock", config.kindid, roomid)

    if ret then
        if result then
            for k, v in pairs(result) do
                table.insert(robots, v)
            end
        end
        skynet.timeout(6000, load_robots)
    end
end

-- 机器人进出
local function robot_inout()
    create_robot()

    local now = skynet.time()
    for k, user in pairs(user_online) do
        if user.is_robot then
            if user.user_status == US_FREE or user.user_status == US_SIT then
                local leave_room = false
                local v = online_robots[user.userid]
                if not v then
                    leave_room = true
                elseif user.enter_time + v.play_time < now then
                    leave_room = true
                end
                if leave_room then
                    cs(roomevent.request_leave_room, "robot", user.userid, "0.0.0.0", {  })
                    break
                end
            end
        end
    end

    skynet.timeout(450, robot_inout)
end

local function get_robots_info()
    local free_robots = {}
    local sit_robots = {}
    local playing_robots = {}
    local now = skynet.time()
    for k, v in pairs(user_online) do
        if v.is_robot then
            local robot = online_robots[v.userid]
            if robot then
                if v.enter_time + robot.play_time > now then
                    if v.user_status == US_FREE then
                        table.insert(free_robots, v)
                    elseif v.user_status == US_SIT or v.user_status == US_READY then
                        table.insert(sit_robots, v)
                    elseif v.user_status == US_PLAYING or v.user_status == US_OFFLINE then
                        table.insert(playing_robots, v)
                    end
                end
            end
        end
    end
    return free_robots, sit_robots, playing_robots
end

-- 机器人坐下
local function robot_sitdown()
    cs(function()
        local free_robots, sit_robots, playing_robots = get_robots_info()
        if #free_robots > 0 then
            for k, v in pairs(game_tables) do
                if not v.isplaying or (v.isplaying and config.allow_join_playing) then
                    local player_count, robot_count, min_user_count, empty_chairid = skynet.call(v.serviceid, "lua", "get_table_info")
                    local max_chair_count = get_max_chair_count(v.subroomid, v.subroom_wanfaid)
                    if empty_chairid > 0 and robot_count > 0 and robot_count < max_chair_count - 1 then
                        local user = table.remove(free_robots)
                        skynet.call(v.serviceid, "lua", "user_sitdown", empty_chairid, user)
                        break
                    end
                end
            end

            -- 主动坐下
            if #free_robots > 0 and table.size(game_tables) < 5 then
                local user = table.remove(free_robots)
                --随机选择subroom
                local valid_subrooms = {}
                for k, v in pairs(config.subrooms) do
                    if v.open then
                        table.insert(valid_subrooms, v.subroomid)
                    end
                end
                local pos = math.random(#valid_subrooms)
                local subroomid = valid_subrooms[pos]
                local subroom_wanfaid = math.random(#config.subrooms[subroomid].wanfa)
                roomevent.request_sitdown(user.gate, user.fd, user.ip, {tableid=0,chairid=0,subroomid=subroomid, subroom_wanfaid=subroom_wanfaid})
            end
        end
    end)

    skynet.timeout(400, robot_sitdown)
end

-- 机器人起立
local function robot_standup()
    local sids = {}
    for k, v in pairs(game_tables) do
        table.insert(sids, v.serviceid)
    end
    for k, v in ipairs(sids) do
        cs(function()
            skynet.call(v, "lua", "robot_standup")
        end)
    end

    skynet.timeout(600, robot_standup)
end

function CMD.debug_online()
    local online = {}
    local sss = { "US_FREE","US_SIT","US_READY","US_LOOKON","US_PLAYING","US_OFFLINE", }
    for k, v in pairs(user_online) do
        if true then
            table.insert(online, {userid=v.userid,userstatus=sss[v.user_status],tableid=v.tableid,chairid=v.chairid})
        end
    end
    return online
end

function CMD.debug_ronline()
    local online = {}
    local sss = { "US_FREE","US_SIT","US_READY","US_LOOKON","US_PLAYING","US_OFFLINE", }
    for k, v in pairs(robots) do
        if true then
            table.insert(online, {userid=v.userid})
        end
    end
    return online
end

function CMD.debug_robotinfo()
    local free_robots, sit_robots, playing_robots = get_robots_info()
    return {free_robots, sit_robots, playing_robots}
end

function CMD.debug_robotinfo2()
    return online_robots
end

function CMD.debug_gatefd()
    return table.indices(user_online_by_gatefd)
end

function CMD.debug_tableinfo()
    local online = {}
    for k, v in pairs(game_tables) do
        local player_count, robot_count, min_user_count, empty_chairid = skynet.call(v.serviceid, "lua", "get_table_info")
        online[k] = {}
        online[k].player_count = player_count
        online[k].robot_count = robot_count
        online[k].empty_chairid = empty_chairid
    end
    return online
end

function CMD.start(source, conf)
    cluster.register("game")

    if config.allow_robot then
        load_robots()
        robot_inout()
        robot_sitdown()
        robot_standup()
    end
end

function CMD.get_users_online()
    return user_online
end

function CMD.pbrpc(source, source_gate, fd, ip, pb)
    local netmsg = protobuf.decode("netmsg.netmsg", pb)
    if not netmsg then
		LOG_ERROR("msg_unpack error")
        error("msg_unpack error")
        return
	end
    local msg = protobuf.decode(netmsg.name, netmsg.payload)
    if not msg then
        LOG_ERROR(netmsg.name .. " decode error")
        return
    end

    local module, method = netmsg.name:match "([^.]*).([^.]*)"

    local f = assert(roomevent[method])
    cs(f, source_gate, fd, ip, msg)
end

function CMD.disconnect(source, source_gate, fd)
    cs(function()
        local user = user_online_by_gatefd[source_gate .. fd]
        if not user then
            return
        end

        if user.tableid ~= 0 then
            -- 断线处理
            skynet.call(game_tables[user.tableid].serviceid, "lua", "user_offline", user.chairid)
        else
            tableevent.update_user_status(user.userid, 0, 0, US_OFFLINE, false)
        end
    end)
end

function CMD.center_notify_update_score(source, userid, __score)
    cs(function()
        local user = user_online[userid]
        if not user then
            return
        end

        -- 重新获取分数
        local score = cluster.call("cluster_db", "@gamedbmgr", "get_user_score", userid)
        user.score = score
        if user.tableid ~= 0 then
            skynet.call(game_tables[user.tableid].serviceid, "lua", "center_notify_update_score", user.chairid, score)
        end
        
        local pack = netmsg_pack("game.notify_userscore", { userid = userid, user_score = score })
        for k, v in pairs(user_online) do
            forward_to_gate_server(v.gate, v.fd, pack)
        end
    end)
end

function CMD.tableevent(source, method, ...)
    local f = assert(tableevent[method])
    return f(...)
    --cs(f, ...)
end

function CMD._internal_delete_table(source, tableid)
    cs(function()
        -- 重新检查桌子状态
        local player_count, robot_count, min_user_count, empty_chairid = skynet.call(game_tables[tableid].serviceid, "lua", "get_table_info")
        if player_count + robot_count > 0 then
            return
        end

        local notifymsg = netmsg_pack("game.notify_delete_table", { tableid = tableid })
        for k, v in pairs(user_online) do
            forward_to_gate_server(v.gate, v.fd, notifymsg)
        end

        local tableinfo = game_tables[tableid]
        skynet.call(tableinfo.serviceid, "lua", "cleanup")
        game_tables[tableid] = nil
        table.insert(game_tables_pool, tableinfo.serviceid)
        table.insert(game_free_tableids, tableid)
        table.sort(game_free_tableids, function(a, b)
            return a > b
        end)
    end)
end

local function check_room_rule(user, source_gate, fd)
    if config.min_enter_score ~= 0 and user.score < config.min_enter_score and user.master_level == 0 then
        local pack = netmsg_pack("game.response_enter_room_failed", { reason = "余额不足，不能进入游戏" })
        forward_to_gate_server(source_gate, fd, pack)
        return false
    end

    if user.master_level == 0 and table.size(user_online) >= config.max_player then
        local pack = netmsg_pack("game.response_enter_room_failed", { reason = "房间已经满员，请稍候再进入" })
        forward_to_gate_server(source_gate, fd, pack)
        return false
    end

    return true
end

local function _user_enter_room(user, offline)
    local subrooms = {}
    for k, v in pairs(config.subrooms) do
        local sr = {}
        sr.subroomid = v.subroomid
        sr.open = v.open
        sr.name = v.name
        sr.base_score = v.base_score
        sr.min_enter_score = v.min_enter_score
        sr.max_chair_count = v.max_chair_count
        sr.wanfa = {}
        for _, w in pairs(v.wanfa) do
            table.insert(sr.wanfa, {item = w.item})
        end
        table.insert(subrooms, sr)
    end
    local pack = netmsg_pack("game.notify_room_info", { room_type = config.type, allow_join_playing = config.allow_join_playing, allow_ob = config.allow_ob, subrooms = subrooms })
    forward_to_gate_server(user.gate, user.fd, pack)

    local userinfo = {}
    userinfo.userid = user.userid
    userinfo.gameid = user.gameid
    userinfo.nickname = user.nickname
    userinfo.faceid = user.faceid
    userinfo.head_img_url = user.head_img_url
    userinfo.gender = user.gender
    userinfo.signature = user.signature
    userinfo.vip_level = user.vip_level
    userinfo.master_level = user.master_level
    userinfo.score = user.score
    userinfo.tableid = user.tableid
    userinfo.chairid = user.chairid
    userinfo.user_status = user.user_status
    userinfo.banker = user.banker
    pack = netmsg_pack("game.notify_myself_info", { userinfo = userinfo })
    forward_to_gate_server(user.gate, user.fd, pack)

    local myselfpack = netmsg_pack("game.notify_user_enter", { userinfo = userinfo })

    -- 发送其他用户信息
    local others_userinfo = {}
    for k, v in pairs(user_online) do
        if k ~= user.userid then
            local item = {}
            item.userid = v.userid
            item.gameid = v.gameid
            item.nickname = v.nickname
            item.faceid = v.faceid
            item.head_img_url = v.head_img_url
            item.gender = v.gender
            item.signature = v.signature
            item.vip_level = v.vip_level
            item.master_level = v.master_level
            item.score = v.score
            item.tableid = v.tableid
            item.chairid = v.chairid
            item.user_status = v.user_status
            item.banker = v.banker
            table.insert(others_userinfo, item)

            -- 通知其他已经在房间用户有新用户进入
            if not offline then
                forward_to_gate_server(v.gate, v.fd, myselfpack)
            end
        end
    end
    pack = netmsg_pack("game.notify_other_users_info", { users_info = others_userinfo })
    forward_to_gate_server(user.gate, user.fd, pack)

    -- 桌子信息
    local tables_info = {}
    for k, v in pairs(game_tables) do
        local item = {}
        item.tableid = k
        item.subroomid = v.subroomid
        item.param = {
            base_score = config.subrooms[v.subroomid].base_score,
            min_enter_score = config.subrooms[v.subroomid].min_enter_score,
            max_chair_count = get_max_chair_count(v.subroomid, v.subroom_wanfaid),
            wanfa = { item = config.subrooms[v.subroomid].wanfa[v.subroom_wanfaid].item },
        },
        table.insert(tables_info, item)
    end
    pack = netmsg_pack("game.notify_tables_info", { tables_info = tables_info })
    forward_to_gate_server(user.gate, user.fd, pack)

    pack = netmsg_pack("game.response_enter_room_success", { })
    forward_to_gate_server(user.gate, user.fd, pack)
end

local function check_club_user(clubids_t)
    for _, v in ipairs(clubids_t) do
        if clubid == tonumber(v) then
            return true
        end
    end
    return false
end

-- 用户请求进入房间
function roomevent.request_enter_room(source_gate, fd, ip, msg)
    local user = user_online[msg.userid]
    if user then
        if user.password == msg.password then
            local gatefd = user.gate .. user.fd
            user_online_by_gatefd[gatefd] = nil

            user.gate = source_gate
            user.fd = fd
            user.ip = ip
            user.uuid = msg.uuid
            user_online_by_gatefd[source_gate .. fd] = user

            _user_enter_room(user, true)

            if user.tableid ~= 0 then
                skynet.call(game_tables[user.tableid].serviceid, "lua", "update_user_conn", user.chairid, source_gate, fd, ip, msg.uuid)
            else
                tableevent.update_user_status(user.userid, user.tableid, user.chairid, US_FREE, false)
            end
        else
            -- 登陆失败
            local pack = netmsg_pack("game.response_enter_room_failed", { reason = "进入房间失败" })
            forward_to_gate_server(source_gate, fd, pack)
            if source_gate == "robot" then
                LOG_ERROR("request_enter_room: robot enter failed")
                delete_robot(msg.userid)
            end
        end
        return
    else
        local ret, result = cluster.call("cluster_db", "@gamedbmgr", "game_user_enter_room", msg.userid, msg.password, ip, msg.uuid, config.kindid, roomid)
        if not ret then
            -- 登陆失败
            local pack = netmsg_pack("game.response_enter_room_failed", { reason = result })
            forward_to_gate_server(source_gate, fd, pack)
            if source_gate == "robot" then
                LOG_ERROR(source_gate .. ":" .. fd .. " request_enter_room: robot enter failed." .. result)
                delete_robot(msg.userid)
            end
        else
            if result.is_robot then
                --result.score = math.random(online_robots[result.userid].min_take_score, online_robots[result.userid].max_take_score)
            end

            if not check_room_rule(result, source_gate, fd) then
                return
            end

            -- 登陆成功
            result.gate = source_gate
            result.fd = fd
            result.ip = ip
            result.uuid = msg.uuid
            result.tableid = 0
            result.chairid = 0
            result.change_score = 0
            result.change_revenue = 0
            result.change_playtime = 0
            result.user_status = US_FREE
            result.banker = false
            result.enter_time = skynet.time()
            result.password = msg.password
            result.is_club_user = check_club_user(result.clubids)
            user_online[msg.userid] = result
            
            local gatefd = source_gate .. fd
            user_online_by_gatefd[gatefd] = result

            _user_enter_room(result)
        end
        
    end
end

-- 用户请求离开房间
function roomevent.request_leave_room(source_gate, fd, ip, msg)
    local user = user_online_by_gatefd[source_gate .. fd]
    if not user then
        LOG_ERROR("request_leave_room 用户不存在:" .. source_gate .. "," .. fd .. "," .. ip)
        return
    end

    if user.tableid ~= 0 then
        if user.is_robot then
            local ret = skynet.call(game_tables[user.tableid].serviceid, "lua", "user_standup", user.chairid, user.userid)
            if ret then
                delete_robot(user.userid)
            end
        else
            -- 断线处理
            skynet.call(game_tables[user.tableid].serviceid, "lua", "user_offline", user.chairid)
        end
    else
        tableevent.update_user_status(user.userid, 0, 0, US_NULL, false)
    end
end

local function reponse_action_failed(source_gate, fd, reason)
    local pack = netmsg_pack("game.reponse_action_failed", { reason = reason })
    forward_to_gate_server(source_gate, fd, pack)
end

-- 用户请求坐下
function roomevent.request_sitdown(source_gate, fd, ip, msg)
    local user = user_online_by_gatefd[source_gate .. fd]
    if not user then
        LOG_ERROR("request_sitdown 用户不存在")
        return
    end

    -- 重复判断
    if msg.tableid > 0 and msg.chairid > 0 then
        if user.tableid == msg.tableid and user.chairid == msg.chairid then
            return
        end
    end

    if msg.subroomid and msg.subroomid ~= 0 then
        if msg.tableid ~= 0 or msg.chairid ~= 0 then
            close_connection(source_gate, fd, NERR_INVALID_PARAM)
            return
        end
        if msg.subroomid <= 0 or msg.subroomid > #config.subrooms then
            close_connection(source_gate, fd, NERR_INVALID_PARAM)
            return
        end
    end

    if user.user_status == US_PLAYING then
        reponse_action_failed(source_gate, fd, "您正在游戏中，暂时不能离开")
        return
    end

    if user.user_status == US_OFFLINE and user.tableid > 0 then
        skynet.call(game_tables[user.tableid].serviceid, "lua", "update_user_conn", user.chairid, source_gate, fd, ip, user.uuid)
        return
    end

    -- 离开上次坐下的桌子
    if msg.tableid > 0 and user.tableid > 0 then
        local ret = skynet.call(game_tables[user.tableid].serviceid, "lua", "user_standup", user.chairid, user.userid)
        if not ret then
            return
        end
    end

    local request_tableid = msg.tableid
    local request_chairid = msg.chairid

    if request_tableid == 0 then
        -- 随机挑选一个桌子和椅子
        local join_playing = config.allow_join_playing
        for k, v in pairs(game_tables) do
            if (v.subroomid == msg.subroomid and v.subroom_wanfaid == msg.subroom_wanfaid) and (not v.isplaying or join_playing) then
                local ret = skynet.call(v.serviceid, "lua", "get_can_sit_chairid")
                if ret ~= 0 then
                    request_tableid = k
                    request_chairid = ret
                    break
                end
            end
        end
    elseif request_chairid == 0 then
        local join_playing = config.allow_join_playing
        local gametb = game_tables[request_tableid]
        if gametb and (not gametb.isplaying or join_playing) then
            request_chairid = skynet.call(gametb.serviceid, "lua", "get_can_sit_chairid")
        end

        if request_chairid == 0 then
            reponse_action_failed(source_gate, fd, "加入游戏失败,请稍候再试")
            return
        end
    end

    if request_tableid == 0 or request_chairid == 0 then
        --reponse_action_failed(source_gate, fd, "加入游戏失败,请稍候再试")
        --return

        if #game_free_tableids == 0 then
            reponse_action_failed(source_gate, fd, "加入游戏失败,请稍候再试")
            return
        end

        -- 创建桌子
        local tid = table.remove(game_free_tableids)
        if #game_tables_pool > 0 then
            local serviceid = table.remove(game_tables_pool)
            skynet.call(serviceid, "lua", "start", tid, msg.subroomid, msg.subroom_wanfaid)
            game_tables[tid] = {}
            game_tables[tid].serviceid = serviceid
            game_tables[tid].isplaying = false
            game_tables[tid].subroomid = msg.subroomid
            game_tables[tid].subroom_wanfaid = msg.subroom_wanfaid
            request_tableid = tid
        else
            local serviceid = skynet.newservice("gametable")
            skynet.call(serviceid, "lua", "start", tid, msg.subroomid, msg.subroom_wanfaid)
            game_tables[tid] = {}
            game_tables[tid].serviceid = serviceid
            game_tables[tid].isplaying = false
            game_tables[tid].subroomid = msg.subroomid
            game_tables[tid].subroom_wanfaid = msg.subroom_wanfaid
            request_tableid = tid
        end

        local notifymsg = netmsg_pack("game.notify_create_table", {
            table_info = {
                tableid = tid,
                subroomid = msg.subroomid,
                param = {
                    base_score = config.subrooms[msg.subroomid].base_score,
                    min_enter_score = config.subrooms[msg.subroomid].min_enter_score,
                    max_chair_count = get_max_chair_count(msg.subroomid, msg.subroom_wanfaid),
                    wanfa = {item = config.subrooms[msg.subroomid].wanfa[msg.subroom_wanfaid].item},
                },
            }
        })
        for k, v in pairs(user_online) do
            forward_to_gate_server(v.gate, v.fd, notifymsg)
        end

        -- 随机挑选一个桌子和椅子
        local join_playing = config.allow_join_playing
        if not game_tables[tid].isplaying or join_playing then
            local ret = skynet.call(game_tables[tid].serviceid, "lua", "get_can_sit_chairid")
            if ret ~= 0 then
                request_chairid = ret
            end
        end

        if request_tableid == 0 or request_chairid == 0 then
            LOG_ERROR("加入游戏失败")
            reponse_action_failed(source_gate, fd, "加入游戏失败,请稍候再试")
            return
        end
    end

    skynet.call(game_tables[request_tableid].serviceid, "lua", "user_sitdown", request_chairid, user)
end

-- 用户起立
function roomevent.request_standup(source_gate, fd, ip, msg)
    local user = user_online_by_gatefd[source_gate .. fd]
    if not user then
        LOG_ERROR("request_standup 用户不存在")
        return
    end

    --效验数据
    if msg.tableid == 0 or msg.chairid == 0 then
        LOG_ERROR("request_standup tableid或chairid无效")
        return
    end

    if user.tableid ~= msg.tableid or user.chairid ~= msg.chairid then
        LOG_WARNING(string.format("客户端发送起立的数据不匹配 服务器(tableid:%d,chairid:%d) 客户端(tableid:%d,chairid:%d)",
        user.tableid, user.chairid, msg.tableid, msg.chairid))
        return
    end

    if user.user_status == US_PLAYING then
        --reponse_action_failed(source_gate, fd, "您正在游戏中，暂时不能离开")
        -- 断线处理
        skynet.call(game_tables[user.tableid].serviceid, "lua", "user_offline", user.chairid)
        return
    end

    if user.tableid ~= 0 then
        if msg.ob_mode and user.user_status == US_OB then
            return
        end

        -- 让其起立
        local ret = skynet.call(game_tables[user.tableid].serviceid, "lua", "user_standup", user.chairid, user.userid)

        if not ret then
            LOG_WARNING(string.format("%d起立异常", user.userid))
        elseif msg.ob_mode then
            skynet.call(game_tables[msg.tableid].serviceid, "lua", "user_sitdown_ob", msg.chairid, user)
        end
    end
end

-- 请求换桌
function roomevent.request_change_table(source_gate, fd, ip, msg)
    local user = user_online_by_gatefd[source_gate .. fd]
    if not user then
        LOG_ERROR("request_change_table 用户不存在")
        return
    end

    if user.user_status == US_PLAYING then
        reponse_action_failed(source_gate, fd, "您正在游戏中，暂时不能离开")
        return
    end

    local request_tableid = 0
    local request_chairid = 0

    -- 随机挑选一个桌子和椅子
    local join_playing = false
    for k, v in pairs(game_tables) do
        if k ~= user.tableid and (not v.isplaying or join_playing) then
            local ret = skynet.call(v.serviceid, "lua", "get_can_sit_chairid")
            if ret ~= 0 then
                request_tableid = k
                request_chairid = ret
                break
            end
        end
    end

    --TODO 可以分配一个空桌子给用户

    if request_tableid == 0 or request_chairid == 0 then
        reponse_action_failed(source_gate, fd, "换桌失败,请稍候再试")
        return
    end

    skynet.call(game_tables[request_tableid].serviceid, "lua", "user_sitdown", request_chairid, user)
end

-- 创建桌子
function roomevent.request_create_table(source_gate, fd, ip, msg)
    do
        return
    end
    local user = user_online_by_gatefd[source_gate .. fd]
    if not user then
        LOG_ERROR("用户不存在")
        return
    end

    -- TODO 判断权限 规则验证
end

-- 删除桌子
function roomevent.request_delete_table(source_gate, fd, ip, msg)
    do
        return
    end

    local user = user_online_by_gatefd[source_gate .. fd]
    if not user then
        LOG_ERROR("用户不存在")
        return
    end

    -- TODO 判断权限
end

-- 游戏消息
function roomevent.gamemsg(source_gate, fd, ip, msg)
    local user = user_online_by_gatefd[source_gate .. fd]
    if not user then
        LOG_ERROR("用户不存在")
        return
    end
    if user.tableid == 0 or user.chairid == 0 then
        LOG_ERROR("用户不在游戏中")
        return
    end

    local ret = skynet.call(game_tables[user.tableid].serviceid, "lua", "game_msg", msg, user.chairid)
    -- nil不做处理 显式false做处理
    if ret == false then
        close_connection(source_gate, fd, NERR_GAME_MSG)
    end
end

function roomevent.request_init_game(source_gate, fd, ip, msg)
    local user = user_online_by_gatefd[source_gate .. fd]
    if not user then
        LOG_ERROR("用户不存在")
        return
    end
    if user.tableid == 0 or user.chairid == 0 then
        LOG_ERROR("用户不在游戏中")
        return
    end
    skynet.call(game_tables[user.tableid].serviceid, "lua", "init_game", msg, user.chairid, user.userid)
end

function roomevent.request_userready(source_gate, fd, ip, msg)
    local user = user_online_by_gatefd[source_gate .. fd]
    if not user then
        LOG_ERROR("用户不存在")
        return
    end
    if user.tableid == 0 or user.chairid == 0 then
        LOG_ERROR("用户不在游戏中")
        return
    end

    skynet.call(game_tables[user.tableid].serviceid, "lua", "user_ready", msg, user.chairid)
end

-- 通知所有客户端用户状态改变
function tableevent.update_user_status(userid, tableid, chairid, user_status, banker)
    local user = user_online[userid]
    if not user then
        LOG_ERROR(debug.traceback())
        LOG_ERROR(string.format("gamemgr 更新用户(%d)的状态失效", userid))
        return
    end

    user.tableid = tableid
    user.chairid = chairid
    user.user_status = user_status
    user.banker = banker

    local pack = netmsg_pack("game.notify_userstatus", { userid = userid, tableid = tableid, chairid = chairid, user_status = user_status, banker = banker })
    for k, v in pairs(user_online) do
        --TODO:只通知不在游戏中的用户 让客户端主动请求更新信息
        forward_to_gate_server(v.gate, v.fd, pack)
    end

    -- 用户离开
    if user_status == US_NULL then
        cluster.send("cluster_db", "@gamedbmgr", "game_user_leave_room", userid, user.inout_index, user.change_score, user.change_revenue, user.change_playtime,
        config.kindid, roomid, user.ip, user.uuid)
        if user.is_robot then
            delete_robot(user.userid)
        end
        user_online_by_gatefd[user.gate .. user.fd] = nil
        user_online[userid] = nil
    end
end

-- 通知所有客户端用户分数改变
function tableevent.update_user_score(userid, score, revenue, play_time, drawid)
    local user = user_online[userid]
    if not user then
        LOG_ERROR(string.format("gamemgr 更新用户(%d)的分数失效", userid))
        return
    end

    user.change_score = user.change_score + score
    user.change_revenue = user.change_revenue + revenue
    user.change_playtime = user.change_playtime + play_time

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

    local pack = netmsg_pack("game.notify_userscore", { userid = userid, user_score = user.score })
    for k, v in pairs(user_online) do
        forward_to_gate_server(v.gate, v.fd, pack)
    end

    -- 更新分数到数据库
    cluster.send("cluster_db", "@gamedbmgr", "game_write_user_score", userid, score, revenue, play_time, config.kindid, roomid, drawid)
end

function tableevent.write_game_record(drawid, tableid, user_count, robot_count, score, revenue, str_start_time, str_end_time, wanfa)
    cluster.send("cluster_db", "@gamedbmgr", "game_write_game_record", drawid, config.kindid, roomid, tableid, user_count, robot_count, score, revenue, str_start_time, str_end_time, wanfa)
end

function tableevent.write_game_record_detail(userid, drawid, tableid, chairid, score, revenue, start_score, start_bank_score, play_time, gamelog, wanfa, performance)
    cluster.send("cluster_db", "@gamedbmgr", "game_write_game_record_detail", userid, drawid, config.kindid, roomid, tableid, chairid, score, revenue, start_score, start_bank_score, play_time, gamelog, wanfa, clubid, performance)
end

-- 通知所有客户端桌子状态改变
function tableevent.update_table_status(tableid, started, user_count)
    game_tables[tableid].isplaying = started

    -- 移除桌子
    if user_count == 0 and config.kindid < 2000 then
        -- 异步删除
        skynet.send("gamemgr", "lua", "_internal_delete_table", tableid)
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(source, ...)))
    end)
    
    protobuf.register_file("./protocol/netmsg.pb")
    protobuf.register_file("./protocol/center.pb")
    protobuf.register_file("./protocol/game.pb")

    for i = config.max_table_count, 1, -1 do
        table.insert(game_free_tableids, i)
    end

    local precreate_table_count = config.precreate_table_count
    for i= 1, precreate_table_count do
        table.insert(game_tables_pool, skynet.newservice("gametable"))
    end

    -- 百人游戏直接创建桌子 不销毁
    if config.kindid >= 2000 then
        for k, v in pairs(config.subrooms) do
            if v.open then
                for id, wanfa in pairs(v.wanfa) do
                    -- 创建桌子
                    local tid = table.remove(game_free_tableids)
                    if #game_tables_pool > 0 then
                        local serviceid = table.remove(game_tables_pool)
                        skynet.call(serviceid, "lua", "start", tid, v.subroomid, id)
                        game_tables[tid] = {}
                        game_tables[tid].serviceid = serviceid
                        game_tables[tid].isplaying = false
                        game_tables[tid].subroomid = v.subroomid
                        game_tables[tid].subroom_wanfaid = id
                    else
                        local serviceid = skynet.newservice("gametable")
                        skynet.call(serviceid, "lua", "start", tid, v.subroomid, id)
                        game_tables[tid] = {}
                        game_tables[tid].serviceid = serviceid
                        game_tables[tid].isplaying = false
                        game_tables[tid].subroomid = v.subroomid
                        game_tables[tid].subroom_wanfaid = id
                    end
                end
            end
        end
    end

    local game_server = { clusterid = roomid, clustername = skynet.getenv("clustername") }
    game_server.kindid = config.kindid
    game_server.sortid = config.sortid
    game_server.min_enter_score = config.min_enter_score
    game_server.room_name = config.room_name
    local pack = netmsg_pack("center.register_game_server", { game = game_server })
    local ok, ret = pcall(cluster.call, "cluster_center", "@center", "pbrpc", pack)
    if not ok then
        LOG_ERROR("center.register_game_server failed")
    end

    local module, method, msg = netmsg_unpack(ret)
    skynet.error(msg.desc)

    skynet.register(SERVICE_NAME)
end)
