local skynet = require "skynet"
local cluster = require "skynet.cluster"
local protobuf = require "protobuf"

local game_type_list
local game_kind_list
local game_room_list = {}

local CMD = {}
local rpc = {}

function CMD.start(typelist, kindlist)
    game_type_list = typelist
    game_kind_list = kindlist
end

function CMD.forward(source_cluster, fd, ip, pb)
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

    local f = assert(rpc[method])
    return f(source_cluster, fd, ip, msg)
end

function rpc.request_userinfo(source_cluster, fd, ip, msg)
    local ret, result = cluster.call("cluster_db", "@halldbmgr", "get_userinfo", msg.userid, msg.password)
    if not ret then
        -- 获取用户信息失败
        local pack = netmsg_pack("hall.response_userinfo_failed", { reason = result })
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    else
        local pack = netmsg_pack("hall.response_userinfo", result)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    end
end

function rpc.request_game_list(source_cluster, fd, ip, msg)
    local pack = netmsg_pack("hall.response_game_type_list", { game_type_list = game_type_list })
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)

    pack = netmsg_pack("hall.response_game_kind_list", { game_kind_list = game_kind_list })
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)

    local roomlist = {}
    for i, v in pairs(game_room_list) do
        local item = {}
        item.sessionid = v.clusterid
        item.kindid = v.kindid
        item.sortid = v.sortid
        item.min_enter_score = v.min_enter_score
        item.room_name = v.room_name
        table.insert(roomlist, item)
    end
    pack = netmsg_pack("hall.response_game_room_list", { game_room_list = roomlist })
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_bank_save_score(source_cluster, fd, ip, msg)
    local ret, result = cluster.call("cluster_db", "@halldbmgr", "bank_save_score", msg.userid, msg.password, msg.save_score)
    local pack = netmsg_pack("hall.reponse_bank_result", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_bank_get_score(source_cluster, fd, ip, msg)
    local ret, result = cluster.call("cluster_db", "@halldbmgr", "bank_get_score", msg.userid, msg.password, msg.get_score)
    local pack = netmsg_pack("hall.reponse_bank_result", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_log_change_score(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "log_change_score", msg.userid, msg.password, msg.day)
    local pack = netmsg_pack("hall.reponse_log_change_score", { items = result })
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_config_shop_exchange(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "load_config_shop_exchange", msg.type)
    local pack = netmsg_pack("hall.response_config_shop_exchange", { content = result or "" })
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_accountup(source_cluster, fd, ip, msg)
    local result, ext = cluster.call("cluster_db", "@halldbmgr", "accountup", msg.userid, msg.password, msg.new_password, msg.phone_number, msg.code)
    local pack = netmsg_pack("hall.response_operate_result", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    if ext then
        local pack = netmsg_pack("hall.notify_update_userscore", ext)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    end
end

function rpc.request_modify_password(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "modify_password", msg.userid, msg.password, msg.new_password, msg.phone_number, msg.code)
    local pack = netmsg_pack("hall.response_operate_result", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_bind_phone(source_cluster, fd, ip, msg)
    local result, ext = cluster.call("cluster_db", "@halldbmgr", "bind_phone", msg.userid, msg.password, msg.phone_number, msg.code)
    local pack = netmsg_pack("hall.response_operate_result", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    if ext then
        local pack = netmsg_pack("hall.notify_update_userscore", ext)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    end
end

function rpc.request_bind_alipay(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "bind_alipay", msg.userid, msg.password, msg.alipay_account, msg.alipay_name)
    local pack = netmsg_pack("hall.response_operate_result", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_bind_bankcard(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "bind_bankcard", msg.userid, msg.password, msg.bankcard_id, msg.bankcard_name, msg.bankcard_addr)
    local pack = netmsg_pack("hall.response_operate_result", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_exchange(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "exchange", msg.userid, msg.password, msg.type, msg.score)
    local pack = netmsg_pack("hall.reponse_exchange_result", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_exchange_record(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "exchange_record", msg.userid, msg.password, msg.start_date, msg.end_date)
    local pack = netmsg_pack("hall.reponse_exchange_record_result", { items = result })
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_recharge_record(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "recharge_record", msg.userid, msg.password, msg.start_date, msg.end_date)
    local pack = netmsg_pack("hall.reponse_recharge_record_result", { items = result })
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_user_message(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "user_message", msg.userid, msg.password)
    local pack = netmsg_pack("hall.notify_user_message", { items = result })
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_user_message_deal(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "user_message_deal", msg.userid, msg.password, msg.id, msg.deal)
end

function rpc.request_team_create_club(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_create_club", msg.userid, msg.password, msg.clubname, msg.join_auth)
    local pack = netmsg_pack("hall.response_team_create_club", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_search_club(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_search_club", msg.userid, msg.password, msg.club_invite_code)
    local pack = netmsg_pack("hall.response_team_search_club", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_join_club(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_search_club", msg.userid, msg.password, msg.club_invite_code)
    local pack = netmsg_pack("hall.response_team_join_club", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_change_club(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_change_club", msg.userid, msg.password, msg.clubid)
    local pack = netmsg_pack("hall.response_team_change_club", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_parent_info(source_cluster, fd, ip, msg)
    local ret, result = cluster.call("cluster_db", "@halldbmgr", "team_parent_info", msg.userid, msg.password, msg.clubid)
    if ret then
        local pack = netmsg_pack("hall.response_team_parent_info", result)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    else
        local pack = netmsg_pack("hall.response_operate_result", result)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    end
end

function rpc.request_team_myinfo(source_cluster, fd, ip, msg)
    local ret, result = cluster.call("cluster_db", "@halldbmgr", "team_myinfo", msg.userid, msg.password, msg.clubid)
    if ret then
        local pack = netmsg_pack("hall.response_team_myinfo", result)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    else
        local pack = netmsg_pack("hall.response_operate_result", result)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    end
end

function rpc.request_team_members_info(source_cluster, fd, ip, msg)
    local ret, result = cluster.call("cluster_db", "@halldbmgr", "team_members_info", msg.userid, msg.password, msg.clubid)
    if ret then
        local pack = netmsg_pack("hall.response_team_members_info", result)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    else
        local pack = netmsg_pack("hall.response_operate_result", result)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    end
end

function rpc.request_team_report_info(source_cluster, fd, ip, msg)
    local ret, result = cluster.call("cluster_db", "@halldbmgr", "team_report_info", msg.userid, msg.password, msg.clubid, msg.month)
    if ret then
        local pack = netmsg_pack("hall.response_team_report_info", result)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    else
        local pack = netmsg_pack("hall.response_operate_result", result)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    end
end

function rpc.request_team_spread_info(source_cluster, fd, ip, msg)
    local ret, result = cluster.call("cluster_db", "@halldbmgr", "team_spread_info", msg.userid, msg.password, msg.clubid)
    if ret then
        local pack = netmsg_pack("hall.response_team_spread_info", result)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    else
        local pack = netmsg_pack("hall.response_operate_result", result)
        cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
    end
end

function rpc.request_team_transfer(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_transfer", msg.userid, msg.password, msg.clubid, msg.dest_userid, msg.transfer_score)
    local pack = netmsg_pack("hall.response_team_transfer", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_log_transfer(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_log_transfer", msg.userid, msg.password, msg.clubid)
    local pack = netmsg_pack("hall.response_team_log_transfer", { items = result })
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_transfer_cancel(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_transfer_cancel", msg.userid, msg.password, msg.clubid, msg.id)
    local pack = netmsg_pack("hall.response_team_transfer_cancel", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_auto_be_partner(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_auto_be_partner", msg.userid, msg.password, msg.clubid, msg.auto_be_partner, msg.auto_partner_share_ratio)
    local pack = netmsg_pack("hall.response_team_auto_be_partner", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_be_partner(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_be_partner", msg.userid, msg.password, msg.clubid, msg.dest_userid, msg.share_ratio)
    local pack = netmsg_pack("hall.response_team_be_partner", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_set_partner_share_ratio(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_set_partner_share_ratio", msg.userid, msg.password, msg.clubid, msg.partner_userid, msg.share_ratio)
    local pack = netmsg_pack("hall.response_team_set_partner_share_ratio", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_edit_notice(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_edit_notice", msg.userid, msg.password, msg.clubid, msg.notice)
    local pack = netmsg_pack("hall.response_team_edit_notice", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_edit_card(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_edit_card", msg.userid, msg.password, msg.clubid, msg.wx, msg.qq)
    local pack = netmsg_pack("hall.response_team_edit_card", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_partner_member_info(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_partner_member_info", msg.userid, msg.password, msg.clubid, msg.partner_userid)
    local pack = netmsg_pack("hall.response_team_partner_member_info", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_report_member_info(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_report_member_info", msg.userid, msg.password, msg.clubid, msg.id)
    local pack = netmsg_pack("hall.response_team_report_member_info", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_report_partner_info(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_report_partner_info", msg.userid, msg.password, msg.clubid, msg.id)
    local pack = netmsg_pack("hall.response_team_report_partner_info", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

function rpc.request_team_game_records(source_cluster, fd, ip, msg)
    local result = cluster.call("cluster_db", "@halldbmgr", "team_game_records", msg.userid, msg.password, msg.clubid, msg.type, msg.day)
    local pack = netmsg_pack("hall.response_team_game_records", result)
    cluster.send(source_cluster, "@gateway", "pbrpc", pack, fd)
end

local function get_game_room_list()
    local pack = netmsg_pack("center.request_game_server_list", {})
    local ok, ret = pcall(cluster.call, "cluster_center", "@center", "pbrpc", pack)
    if not ok then
        LOG_ERROR("get_game_room_list failed")
        return
    end

    local module, method, msg = netmsg_unpack(ret)
    game_room_list = msg.games
end

skynet.start(function ()
    skynet.dispatch("lua", function (_,_, id, ...)
        local f = CMD[id]
        skynet.ret(skynet.pack(f(...)))
    end)

    protobuf.register_file("./protocol/netmsg.pb")
    protobuf.register_file("./protocol/center.pb")
    protobuf.register_file("./protocol/hall.pb")

    get_game_room_list()
    skynet.fork(function ()
        while true do
            skynet.sleep(60000) -- 600s
            get_game_room_list()
        end
    end)
end)
