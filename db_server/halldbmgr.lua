local skynet = require "skynet"
require "skynet.manager"
local cluster = require "skynet.cluster"
local cjson = require "cjson"
local date = require "date"
local db_helper = require "db_helper"
local mysql_utils = require "mysql_utils"

local CMD = {}

function CMD.start(db)
    cluster.register("halldbmgr")
end

function CMD.stop()
end

-- 获取用户信息
function CMD.get_userinfo(userid, pwd)
    local keys_and_tonumber = {
        { "userid", true },
        { "gameid", true },
        { "faceid", true },
        { "gender", true },
        { "nickname", false },
        { "password", false },
        { "mobilephone", false },
        { "alipay_name", false },
        { "alipay_account", false },
        { "bankcard_id", false },
        { "bankcard_name", false },
        { "vip_level", true },
        { "signature", false },
        { "head_img_url", false },
        { "clubids", false },
        { "selected_clubid", true },
    }
    local keys = {}
    for k, v in ipairs(keys_and_tonumber) do
        table.insert(keys, v[1])
    end

    local ret = db_helper.get_user_account_info_by_userid(userid, table.unpack(keys))
    local userinfo = {}
    for k, v in ipairs(keys_and_tonumber) do
        if v[2] then
            userinfo[v[1]] = tonumber(ret[k])
        else
            userinfo[v[1]] = ret[k]
        end
    end
    if not userinfo.userid then
        return false, "用户不存在"
    end
    if userinfo.password ~= pwd then
        return false, "密码错误"
    end

    local game_keys = {
        "score", "bank_score", "recharge_score"
    }
    local game_info_result = db_helper.get_user_game_info(userid, table.unpack(game_keys))
    for k, v in ipairs(game_keys) do
        userinfo[v] = tonumber(game_info_result[k])
    end

    local user_lock_info_result = db_helper.do_redis("hmget", "temp_game_user_lock_info:userid:" .. userid, "kindid", "roomid")

    -- 团队信息
    local club_info = {}
    if userinfo.clubids ~= "" then
        local clubids = string.split(userinfo.clubids, ",")
        for _, v in ipairs(clubids) do
            local item = {}
            item.clubid = tonumber(v)
            local ret_clubinfo = db_helper.get_club_info(v, "creator_userid", "name", "member_count")
            item.club_name = ret_clubinfo[2]
            item.member_count = tonumber(ret_clubinfo[3])
            if tonumber(ret_clubinfo[1]) == userid then
                item.identity = 0
            else
                local ret_team_info = db_helper.get_user_team_info(userid, v, "share_ratio")
                item.identity = ret_team_info[1] == "0" and 2 or 1
            end
            table.insert(club_info, item)
        end
    end
    userinfo.clubids = nil
    userinfo.club_info = club_info

    userinfo.lock_kindid = tonumber(user_lock_info_result[1] or 0)
    userinfo.lock_roomid = tonumber(user_lock_info_result[2] or 0)

    return true, userinfo
end

-- 获取游戏类型列表
function CMD.load_game_type_list()
    local ret = db_helper.do_redis("smembers", "config_game_type_list")
    local result = {}
    for _, v in ipairs(ret or {}) do
        table.insert(result, cjson.decode(v))
    end
    return result
end

-- 获取游戏列表
function CMD.load_game_kind_list()
    local ret = db_helper.do_redis("smembers", "config_game_kind_list")
    local result = {}
    for _, v in ipairs(ret or {}) do
        table.insert(result, cjson.decode(v))
    end
    return result
end

-- 银行存钱
function CMD.bank_save_score(userid, pwd, save_score)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password")
    if not ret[1] then
        return false, { result_code = 1, user_score = 0, bank_score = 0, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return false, { result_code = 2, user_score = 0, bank_score = 0, reason = "密码错误" }
    end

    -- TODO 查看配置表是否允许银行操作

    ret = db_helper.get_user_game_info(userid, "score", "bank_score")
    local user_game_info_result = {}
    user_game_info_result.score = tonumber(ret[1])
    user_game_info_result.bank_score = tonumber(ret[2])

    if user_game_info_result.score < save_score then
        return false, { result_code = 3, user_score = 0, bank_score = 0, reason = "分数不足" }
    end

    local update_t = {
        score = -save_score,
        bank_score = save_score,
    }
    
    local new_user_game_info_result = db_helper.incrby_user_game_info(userid, update_t)

    -- 插入记录表
    db_helper.insert_log_change_score("bank_save", "", userid, user_game_info_result.score, -save_score, user_game_info_result.bank_score, save_score)

    return true, { result_code = 0, user_score = tonumber(new_user_game_info_result[1]), bank_score = tonumber(new_user_game_info_result[2]), reason = "" }
end

-- 银行取钱
function CMD.bank_get_score(userid, pwd, get_score)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password")
    if not ret[1] then
        return false, { result_code = 1, user_score = 0, bank_score = 0, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return false, { result_code = 2, user_score = 0, bank_score = 0, reason = "密码错误" }
    end

    -- TODO 查看配置表是否允许银行操作

    ret = db_helper.get_user_game_info(userid, "score", "bank_score")
    local user_game_info_result = {}
    user_game_info_result.score = tonumber(ret[1])
    user_game_info_result.bank_score = tonumber(ret[2])
    if user_game_info_result.bank_score < get_score then
        return false, { result_code = 3, user_score = 0, bank_score = 0, reason = "分数不足" }
    end

    local update_t = {
        score = get_score,
        bank_score = -get_score,
    }
    local new_user_game_info_result = db_helper.incrby_user_game_info(userid, update_t)

    -- 插入记录表
    db_helper.insert_log_change_score("bank_get", "", userid, user_game_info_result.score, get_score, user_game_info_result.bank_score, -get_score)

    return true, { result_code = 0, user_score = tonumber(new_user_game_info_result[1]), bank_score = tonumber(new_user_game_info_result[2]), reason = "" }
end

-- 帐变记录
function CMD.log_change_score(userid, pwd, day)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password")
    if not ret[1] then
        return {}
    end
    if ret[1] ~= pwd then
        return {}
    end
    if day < 0 or day > 2 then
        return {}
    end

    local today = date()
    local start_date = today:adddays(-day)
    start_date:sethours(0, 0, 0, 0)
    local min = start_date:totimestamp()
    local end_date = today:adddays(-day + 1)
    end_date:sethours(0, 0, 0, 0)
    local max = end_date:totimestamp()

    local records = db_helper.do_redis("zrevrangebyscore", "log_change_score:userid:" .. userid, max, min)
    local result = {}
    for k, v in pairs(records or {}) do
        local item = cjson.decode(v)
        table.insert(result, {
            source_score = item.source_score,
            change_score = item.change_score,
            id = item.id,
            change_type = item.change_type,
            change_reason = item.change_reason,
            change_origin = item.change_origin,
            change_date = item.change_date
        })
    end
    return result
end

-- 商城兑换配置
function CMD.load_config_shop_exchange(type)
    local name = "shop"
    if type ~= 0 then
        name = "exchange"
    end
    local records = db_helper.do_redis("get", "config_shop_exchange:type:" .. name)
    return records
end

-- 账号升级
function CMD.accountup(userid, pwd, phone_number, code, new_password)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "mobilephone")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码错误" }
    end

    if not check_alpha_num(new_password) or string.len(new_password) > LEN_MD5 then
        return { result_code = 3, reason = "无效密码" }
    end

    if ret[2] ~= "" then
        return { result_code = 3, reason = "您已经绑定手机了" }
    end

    phone_number = string.trim(phone_number)
    if not check_phone_number(phone_number) then
        return { result_code = 3, reason = "请输入正确的手机号码" }
    end

    local esxit = db_helper.do_redis("get", "user_account_info:mobilephone:" .. phone_number)
    if esxit then
        return { result_code = 4, reason = "该手机号码已经绑定了其他账号，不能重复绑定" }
    end

    local ret_code = db_helper.get_phone_code(phone_number)
    if not ret_code or ret_code ~= code then
        --return { result_code = 5, reason = "验证码有误" }
    end

    local update_t = {
        mobilephone = phone_number,
        password = new_password
    }

    db_helper.update_user_account_info_by_userid(userid, update_t)
    db_helper.do_redis("set", "user_account_info:mobilephone:" .. phone_number, userid)

    local bind_score = db_helper.do_redis("hget", "config_global:c_name:bind_phone", "c_value")
    local ext
    if bind_score and tonumber(bind_score) > 0 then
        bind_score = tonumber(bind_score)
        local values = db_helper.get_user_game_info(userid, "score", "bank_score")
        local score_info = {}
        score_info.score = tonumber(values[1])
        score_info.bank_score = tonumber(values[2])
        db_helper.insert_log_change_score("bind_phone", "", userid, score_info.score, bind_score, score_info.bank_score, 0)

        local new_score = db_helper.incrby_user_game_info(userid, "score", bind_score)
        ext = { score = new_score[1], bank_score = score_info.bank_score }
    end

    return { result_code = 0, reason = "绑定成功" }, ext
end

-- 修改密码
function CMD.modify_password(userid, pwd, new_password, phone_number, code)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "mobilephone")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码错误" }
    end

    if not check_alpha_num(new_password) or string.len(new_password) > LEN_MD5 then
        return { result_code = 3, reason = "无效密码" }
    end

    if ret[2] ~= phone_number or phone_number == "" then
        return { result_code = 3, reason = "手机号码有误" }
    end

    local ret_code = db_helper.get_phone_code(phone_number)
    if not ret_code or ret_code ~= code then
        --return { result_code = 5, reason = "验证码有误" }
    end

    local update_t = {
        password = new_password,
    }

    db_helper.update_user_account_info_by_userid(userid, update_t)
    
    return { result_code = 0, reason = "修改成功" }
end

-- 绑定手机
function CMD.bind_phone(userid, pwd, phone_number, code)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "mobilephone")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码错误" }
    end

    if ret[2] ~= "" then
        return { result_code = 3, reason = "您已经绑定手机了" }
    end
    phone_number = string.trim(phone_number)
    if not check_phone_number(phone_number) then
        return { result_code = 3, reason = "请输入正确的手机号码" }
    end

    local esxit = db_helper.do_redis("get", "user_account_info:mobilephone:" .. phone_number)
    if esxit then
        return { result_code = 4, reason = "该手机号码已经绑定了其他账号，不能重复绑定" }
    end

    local ret_code = db_helper.get_phone_code(phone_number)
    if not ret_code or ret_code ~= code then
        --return { result_code = 5, reason = "验证码有误" }
    end

    local update_t = {
        mobilephone = phone_number,
    }

    db_helper.update_user_account_info_by_userid(userid, update_t)
    db_helper.do_redis("set", "user_account_info:mobilephone:" .. phone_number, userid)

    local bind_score = db_helper.do_redis("hget", "config_global:c_name:bind_phone", "c_value")
    local ext
    if bind_score and tonumber(bind_score) > 0 then
        bind_score = tonumber(bind_score)
        local ret = db_helper.get_user_game_info(userid, "score", "bank_score")
        local values = {}
        values.score = tonumber(ret[1])
        values.bank_score = tonumber(ret[2])
        db_helper.insert_log_change_score("bind_phone", "", userid, values.score, bind_score, values.bank_score, 0)

        local new_score = db_helper.incrby_user_game_info(userid, "score", bind_score)
        ext = { score = new_score[1], bank_score = values.bank_score }
    end

    return { result_code = 0, reason = "绑定成功" }, ext
end

-- 绑定支付宝
function CMD.bind_alipay(userid, pwd, alipay_account, alipay_name)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "alipay_account")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码错误" }
    end
    if ret[2] ~= "" then
        return { result_code = 3, reason = "您已经绑定过支付宝" }
    end

    alipay_account = string.trim(alipay_account)
    if not check_phone_number(alipay_account) and not check_email(alipay_account) then
        return { result_code = 3, reason = "请输入正确的支付宝账号" }
    end

    if string.len(alipay_account) > LEN_ALIPAY_ACCOUNT or string.len(alipay_name) > LEN_REALNAME then
        return { result_code = 3, reason = "请输入正确的支付宝账号和名字" }
    end

    alipay_name = string.trim(alipay_name)
    if not check_all_chinese(alipay_name) then
        return { result_code = 3, reason = "请输入中文支付宝名字" }
    end

    local esxit = db_helper.do_redis("get", "user_account_info:alipay_account:" .. alipay_account)
    if esxit then
        return { result_code = 4, reason = "该支付宝已经绑定了其他账号，不能重复绑定" }
    end

    local update_t = {
        alipay_account = alipay_account,
        alipay_name = alipay_name,
    }

    db_helper.update_user_account_info_by_userid(userid, update_t)
    db_helper.do_redis("set", "user_account_info:alipay_account:" .. alipay_account, userid)
    
    return { result_code = 0, reason = "绑定成功" }
end

-- 绑定银行卡
function CMD.bind_bankcard(userid, pwd, bankcard_id, bankcard_name, bankcard_addr)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "bankcard_id")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码错误" }
    end
    if ret[2] ~= "" then
        return { result_code = 3, reason = "您已经绑定过银行卡" }
    end

    bankcard_id = string.trim(bankcard_id)
    if not check_number(bankcard_id) then
        return { result_code = 3, reason = "银行卡号只能是数字" }
    end

    bankcard_name = string.trim(bankcard_name)
    if not check_all_chinese(bankcard_name) then
        return { result_code = 3, reason = "请输入中文银行卡名字" }
    end

    bankcard_addr = string.trim(bankcard_addr)
    if not check_all_chinese(bankcard_addr) then
        return { result_code = 3, reason = "请输入中文银行开户行地址" }
    end

    if string.len(bankcard_id) > LEN_BANKCARD_ID or string.len(bankcard_name) > LEN_REALNAME or string.len(bankcard_addr) > LEN_BANKCARD_ADDR then
        return { result_code = 3, reason = "请输入正确的长度" }
    end

    local esxit = db_helper.do_redis("get", "user_account_info:bankcard_id:" .. bankcard_id)
    if esxit then
        return { result_code = 4, reason = "该银行卡已经绑定了其他账号，不能重复绑定" }
    end

    local update_t = {
        bankcard_id = bankcard_id,
        bankcard_name = bankcard_name,
        bankcard_addr = bankcard_addr,
    }

    db_helper.update_user_account_info_by_userid(userid, update_t)
    db_helper.do_redis("set", "user_account_info:bankcard_id:" .. bankcard_id, userid)

    return { result_code = 0, reason = "绑定成功" }
end

-- 兑换
function CMD.exchange(userid, pwd, type, score)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "bankcard_id", "bankcard_name", "alipay_account", "alipay_name")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码错误" }
    end

    if type < 0 or type >= 2 then
        return { result_code = 2, bank_score = 0, reason = "无效的参数" }
    end
    if type == 0 and ret[2] == "" then
        return { result_code = 3, bank_score = 0, reason = "未绑定银行卡" }
    elseif type == 1 and ret[4] == "" then
        return { result_code = 3, bank_score = 0, reason = "未绑定支付宝" }
    end

    local ret_score = db_helper.get_user_game_info(userid, "bank_score", "score")
    local score_result = {}
    score_result.bank_score = tonumber(ret_score[1])
    score_result.score = tonumber(ret_score[2])
    if score_result.bank_score < score then
        return { result_code = 4, bank_score = 0, reason = "存款不足" }
    end

    -- 单笔最小金额 最大金额 每天最大额度 每天最多兑换几次 前几笔不抽水 抽水比例 流水倍数
    -- TODO 流水还没有处理
    local cash_config_content = db_helper.do_redis("get", "config_shop_exchange:type:exchange")
    local cash_config = cjson.decode(cash_config_content)
    local type_cash_config
    for _, v in pairs(cash_config) do
        if v.type == type then
            type_cash_config = v
            break
        end
    end
    if not type_cash_config then
        return { result_code = 4, bank_score = 0, reason = "取款方式未开放" }
    end
    if score < type_cash_config.min_amount * 100 then
        return { result_code = 5, bank_score = 0, reason = string.format("每次最少取款金额%d元", type_cash_config.min_amount) }
    end
    if score > type_cash_config.max_amount * 100 then
        return { result_code = 5, bank_score = 0, reason = string.format("每次最大可取款额度为%d元", type_cash_config.max_amount) }
    end

    local exchange_info = db_helper.do_redis("hmget", "temp_user_exchange_info:userid:" .. userid, "count", "score")
    if exchange_info[1] and tonumber(exchange_info[1]) >= type_cash_config.max_exchange_count then
        return { result_code = 5, bank_score = 0, reason = string.format("每天最多兑换%d次", type_cash_config.max_exchange_count) }
    end
    if exchange_info[2] and tonumber(exchange_info[2]) >= type_cash_config.max_exchange_amount * 100 then
        return { result_code = 5, bank_score = 0, reason = string.format("每天最大可取款额度为%d元", type_cash_config.max_exchange_amount) }
    end

    local cnt = db_helper.do_redis("hincrby", "temp_user_exchange_info:userid:" .. userid, "count", 1)
    local tax = type_cash_config.tax / 100
    if cnt == 1 then
        -- 设置过期时间
        local now = date()
        local nexttm = date(now):adddays(1)
        nexttm:sethours(0, 0, 0, 0)
        local secs = math.floor(date.diff(nexttm, now):spanseconds())
        db_helper.do_redis("expire", "temp_user_exchange_info:userid:" .. userid, secs)
    end
    if cnt <= type_cash_config.free_count then
        tax = 0
    end
    local revenue = math.floor(score * tax)
    local real_score = score - revenue
    db_helper.do_redis("hincrby", "temp_user_exchange_info:userid:" .. userid, "score", score)

    local new_bank_score = db_helper.incrby_user_game_info(userid, "bank_score", -score)

    local account = type == 0 and ret[2] or ret[4]
    local account_name = type == 0 and ret[3] or ret[5]
    db_helper.insert_log_exchange(userid, score - revenue, revenue, account, account_name, type)

    db_helper.insert_log_change_score("exchange", "", userid, score_result.score, 0, score_result.bank_score, -score)

    return { result_code = 0, bank_score = tonumber(new_bank_score[1]) }
end

-- 兑换
function CMD.exchange_record(userid, pwd, start_date, end_date)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password")
    if not ret[1] then
        return {  }
    end
    if ret[1] ~= pwd then
        return {  }
    end

    if date(start_date) > date(end_date) then
        start_date = end_date
    end
    
    if date.diff(date(end_date), date(start_date)):spandays() > 30 then
        return {}
    end

    local nexttm = date(end_date):adddays(1)
    nexttm:sethours(0, 0, 0, 0)
    local min = date(start_date):totimestamp()
    local max = date(nexttm):totimestamp()

    local records = db_helper.do_redis("zrevrangebyscore", "log_exchange:userid:" .. userid, max, min)
    local result = {}
    for k, v in pairs(records or {}) do
        local item = cjson.decode(v)
        table.insert(result, {
            id = item.id,
            score = item.score,
            revenue = item.revenue,
            account = item.account,
            state = item.state,
            reason = item.reason,
            insert_date = item.insert_date
        })
    end
    return result
end

-- 充值记录
function CMD.recharge_record(userid, pwd, start_date, end_date)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password")
    if not ret[1] then
        return {  }
    end
    if ret[1] ~= pwd then
        return {  }
    end

    if date(start_date) > date(end_date) then
        start_date = end_date
    end
    
    if date.diff(date(end_date), date(start_date)):spandays() > 30 then
        return {}
    end

    local nexttm = date(end_date):adddays(1)
    nexttm:sethours(0, 0, 0, 0)
    local min = date(start_date):totimestamp()
    local max = date(nexttm):totimestamp()

    local records = db_helper.do_redis("zrevrangebyscore", "log_recharge:userid:" .. userid, max, min)
    local result = {}
    for k, v in pairs(records or {}) do
        local item = cjson.decode(v)
        table.insert(result, {
            order_no = item.order_no,
            channel = item.channel,
            pay_amount = item.pay_amount,
            real_amount = item.real_amount,
            state = item.state,
            insert_date = item.insert_date
        })
    end
    return result
end

-- 用户的邮件
function CMD.user_message(userid, pwd)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password")
    if not ret[1] then
        return {  }
    end
    if ret[1] ~= pwd then
        return {  }
    end

    local records = db_helper.do_redis("zrevrange", "user_message:userid:" .. userid, 0, -1)
    local result = {}
    for k, v in pairs(records or {}) do
        local item = cjson.decode(v)
        item.userid = nil
        table.insert(result, item)
    end
    return result
end

-- 处理邮件
function CMD.user_message_deal(userid, pwd, id, deal)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password")
    if not ret[1] then
        return false
    end
    if ret[1] ~= pwd then
        return false
    end

    local result = db_helper.do_redis("zrangebyscore", "user_message:userid:" .. userid, id, id, "limit", 0, 1)
    if #result == 0 then
        return false
    end

    db_helper.do_redis("zremrangebyscore", "user_message:userid:" .. userid, id, id)
    if deal == 0 then
        local t = cjson.decode(result[1])
        t.readed = 1
        db_helper.do_redis("zadd", "user_message:userid:" .. userid, id, cjson.encode(t))
    end

    local update_t = {
        readed = deal == 0 and 1 or 2
    }
    local sql = mysql_utils.make_update_sql("user_message", update_t, { userid = userid })
    mysql_utils.async_write(sql)

    return true
end

-- 创建俱乐部
function CMD.team_create_club(userid, pwd, clubname)
    if TEAM_MODE == 0 then
        return { result_code = 1, reason = "不允许创建俱乐部" }
    end
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "clubids")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "用户不存在" }
    end

    if string.len(clubname) > LEN_CLUB_NAME then
        return { result_code = 3, reason = "名字太长" }
    end

    -- 名字重复
    local exsit = db_helper.do_redis("sismember", "club_info:name", clubname)
    if exsit then
        return { result_code = 3, reason = "名字重复" }
    end

    -- 创建俱乐部信息
    local clubid = tonumber(db_helper.do_redis("incr", "club_info:__id"))
    local insert_t = {
        clubid = clubid,
        creator_userid = userid,
        name = clubname,
        member_count = 1,
        create_date = os.date("%Y-%m-%d %H:%M:%S", os.time())
    }
    db_helper.do_redis("hmset", "club_info:clubid:" .. clubid, table.tunpack(insert_t))
    db_helper.do_redis("sadd", "club_info:name", clubname)
    mysql_utils.async_write(mysql_utils.make_insert_sql("club_info", insert_t))

    -- 创建表user_team_info user_team_bind_info log_team_day_report(clubid)
    mysql_utils.sync_write(string.format("CALL create_club(%d)", clubid))
    
    -- 绑定团队
    db_helper.bind_team(userid, clubid, 0)

    local club_info = {}
    club_info.club_name = clubname
    club_info.member_count = 1
    club_info.clubid = clubid
    club_info.identity = 0

    return { result_code = 0, club_info = club_info }
end

-- 搜索俱乐部
function CMD.team_search_club(userid, pwd, invite_code)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "clubids")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "用户不存在" }
    end

    if string.len(tostring(invite_code)) ~= 8  then
        return { result_code = 3, reason = "无效的邀请码" }
    end

    local parent_userid = 0 -- 上级ID
    local clubid = 0    -- 俱乐部
    local result = db_helper.do_redis("hmget", "config_club_invite_code:invite_code:" .. invite_code, "userid", "clubid")
    if result[1] and result[2] then
        parent_userid = tonumber(result[1])
        clubid = tonumber(result[2])
    end

    if parent_userid == 0 or clubid == 0 then
        return { result_code = 4, reason = "未搜索到俱乐部" }
    end

    local ret_club_info = db_helper.get_club_info(clubid, "name", "member_count")
    local club_info = {}
    club_info.club_name = ret_club_info[1]
    club_info.member_count = tonumber(ret_club_info[2])
    club_info.clubid = clubid
    club_info.identity = 0

    return { result_code = 0, club_info = club_info }
end

-- 加入俱乐部
function CMD.team_join_club(userid, pwd, invite_code)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "clubids")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "用户不存在" }
    end

    if string.len(tostring(invite_code)) ~= 8  then
        return { result_code = 3, reason = "无效的邀请码" }
    end

    local parent_userid = 0 -- 上级ID
    local clubid = 0    -- 俱乐部
    local result = db_helper.do_redis("hmget", "config_club_invite_code:invite_code:" .. invite_code, "userid", "clubid")
    if result[1] and result[2] then
        parent_userid = tonumber(result[1])
        clubid = tonumber(result[2])
    end

    if parent_userid == 0 or clubid == 0 then
        return { result_code = 4, reason = "未搜索到俱乐部" }
    end

    if string.find(ret[2], clubid) then
        return { result_code = 5, reason = "您已经加入该俱乐部" }
    end

    db_helper.bind_team(userid, clubid, parent_userid)

    local ret_club_info = db_helper.get_club_info(clubid, "name", "member_count")
    local ret_team_info = db_helper.get_user_team_info(userid, clubid, "share_ratio")
    local club_info = {}
    club_info.club_name = ret_club_info[1]
    club_info.member_count = tonumber(ret_club_info[2])
    club_info.clubid = clubid
    club_info.identity = ret_team_info[1] == "0" and 2 or 1

    return { result_code = 0, club_info = club_info }
end

-- 切换俱乐部
function CMD.team_change_club(userid, pwd, clubid)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "clubids")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "用户不存在" }
    end

    local clubids = string.split(ret[2], ",")
    local exsit = false
    for _, v in ipairs(clubids) do
        if clubid == tonumber(v) then
            exsit = true
            break
        end
    end
    if not exsit then
        return { result_code = 3, reason = "您还没有加入该俱乐部" }
    end

    db_helper.update_user_account_info_by_userid(userid, { selected_clubid = clubid })

    return { result_code = 0, reason = "切换成功", clubid = clubid }
end

-- 我的上级
function CMD.team_parent_info(userid, pwd, clubid)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "clubids", "selected_clubid")
    if not ret[1] then
        return false, { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return false, { result_code = 2, reason = "用户不存在" }
    end

    if tonumber(ret[3]) ~= clubid then
        return false, { result_code = 3, reason = "俱乐部信息有误" }
    end
    
    -- 找到上级
    local parent_info = db_helper.get_user_team_bind_info(userid, clubid, "parent_userid")
    if parent_info[1] then
        local parent_userid = tonumber(parent_info[1])
        if parent_userid ~= 0 then
            local result = db_helper.get_user_account_info_by_userid(parent_userid, "gameid", "nickname", "head_img_url")
            local result2 = db_helper.get_user_team_bind_info(parent_userid, clubid, "invited_code", "wx", "qq", "notice")
            local result3 = db_helper.get_club_info(clubid, "name")
            return true, { gameid = tonumber(result[1]), nickname = result[2], head_img_url = result[3],
            invited_code = result2[1], wx = result2[2], qq = result2[3], notice = result2[4], club_name = result3[1] }
        else
            -- 自己是最上级
            return true, {}
        end
    else
        LOG_WARNING("未找到上级用户, userid:" .. userid)
        return true, {}
    end
end

-- 我的信息
function CMD.team_myinfo(userid, pwd, clubid)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid", "nickname", "gameid", "head_img_url")
    if not ret[1] then
        return false, { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return false, { result_code = 2, reason = "用户不存在" }
    end

    if tonumber(ret[2]) ~= clubid then
        return false, { result_code = 3, reason = "俱乐部信息有误" }
    end
    
    local result = {}
    result.nickname = ret[3]
    result.gameid = tonumber(ret[4])
    result.head_img_url = ret[5]

    local bind_info = db_helper.get_user_team_bind_info(userid, clubid, "invite_code", "wx", "qq", "notice")
    result.invited_code = bind_info[1]
    result.wx = bind_info[2]
    result.qq = bind_info[3]
    result.notice = bind_info[4]
    local team_info = db_helper.get_user_team_info(userid, clubid, "share_ratio")
    result.share_ratio = tonumber(team_info[1])
    local club_info = db_helper.get_club_info(clubid, "name")
    result.club_name = club_info[1]

    return true, result
end

local function get_team_member_info(userids, clubid)
    local ret = {}
    if userids == "" then
        return ret
    end
    local t_userids = string.split(userids, ",")
    for _, v in ipairs(t_userids) do
        local command_t = {}
        local account_info_t = {
            cmd = "hmget",
            key = "user_account_info:userid:" .. v,
            fvs = { "gameid", "nickname", "head_img_url", "last_login_date" }
        }
        table.insert(command_t, account_info_t)
        local bind_info_t = {
            cmd = "hmget",
            key = "user_team_bind_info" .. clubid .. ":userid:" .. v,
            fvs = { "parent_gameid", "direct_userids", "insert_date" }
        }
        table.insert(command_t, bind_info_t)
        local team_info_t = {
            cmd = "hmget",
            key = "user_team_info" .. clubid .. ":userid:" .. v,
            fvs = { "share_ratio", "today_total_performance", "today_new_members_count" }
        }
        table.insert(command_t, team_info_t)
        local report_info_t = {
            cmd = "hmget",
            key = "log_team_day_report" .. clubid .. ":userid:" .. v,
            fvs = { "performance", "new_members_count" }
        }
        table.insert(command_t, report_info_t)
        local result = db_helper.do_redis_multi_exec(command_t)
        local item = {}
        item.userid = tonumber(v)
        item.gameid = tonumber(result[1][1])
        item.nickname = result[1][2]
        item.head_img_url = result[1][3]
        item.last_login_date = result[1][4]
        item.share_ratio = tonumber(result[3][1])
        item.today_total_performance = tonumber(result[3][2])
        item.today_new_members_count = tonumber(result[3][3])
        item.yestoday_total_performance = tonumber(result[4][1] or 0)
        item.yestoday_new_members_count = tonumber(result[4][2] or 0)
        item.direct_members_count = table.size(string.split(result[2][2], ","))
        item.join_date = result[2][3]
        item.parent_gameid = tonumber(result[2][1])
        table.insert(ret, item)
    end
    return ret
end

-- 我的会员信息
function CMD.team_members_info(userid, pwd, clubid)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return false, { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return false, { result_code = 2, reason = "用户不存在" }
    end

    if tonumber(ret[2]) ~= clubid then
        return false, { result_code = 3, reason = "俱乐部信息有误" }
    end

    local bind_info = db_helper.get_user_team_bind_info(userid, clubid, "auto_be_partner", "auto_partner_share_ratio")
    local auto_be_partner = bind_info[1] ~= "0" and true or false
    local auto_partner_share_ratio = tonumber(bind_info[2])

    local team_info = db_helper.get_user_team_info(userid, clubid, "share_ratio")
    local share_ratio = tonumber(team_info[1])
    
    local bind_result = db_helper.get_user_team_bind_info(userid, clubid, "direct_userids", "direct_partner_userids", "member_userids")
    local direct_partner_items = get_team_member_info(bind_result[2], clubid)
    local direct_member_items = get_team_member_info(bind_result[1], clubid)
    local member_items = get_team_member_info(bind_result[3], clubid)

    return true, { share_ratio = share_ratio, auto_be_partner = auto_be_partner, auto_partner_share_ratio = auto_partner_share_ratio, direct_partner_items = direct_partner_items, direct_member_items = direct_member_items, member_items = member_items }
end

-- 我的合伙人会员信息
function CMD.team_partner_member_info(userid, pwd, clubid, partner_userid)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return { items = {} }
    end
    if ret[1] ~= pwd then
        return { items = {} }
    end

    if tonumber(ret[2]) ~= clubid then
        return { items = {} }
    end
    
    local items = {}
    local bind_result = db_helper.get_user_team_bind_info(partner_userid, clubid, "direct_userids")
    local direct_userids = string.split(bind_result[1], ",")
    for _, v in ipairs(direct_userids) do
        local account_info = db_helper.get_user_account_info_by_userid(v, "gameid", "nickname", "head_img_url")
        table.insert(items, { gameid = tonumber(account_info[1]), nickname = account_info[2], head_img_url = bind_result[3] })
    end

    return { items = items }
end

-- 直属会员税收明细
function CMD.team_report_member_info(userid, pwd, clubid, id)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return { items = {} }
    end
    if ret[1] ~= pwd then
        return { items = {} }
    end

    if tonumber(ret[2]) ~= clubid then
        return { items = {} }
    end

    local ret_report = db_helper.do_redis("hmget", "log_team_day_report" .. clubid .. ":id:" .. id, "share_ratio", "direct_userids", "direct_partner_userids", "create_date")
    if not ret_report[1] then
        return { items = {} }
    end

    local my_share_ratio = tonumber(ret_report[1])
    local timestamp = date(ret_report[4]):totimestamp()
    local datequery = date(ret_report[4]):fmt("%F %T")
    
    local items = {}
    local direct_userids = string.split(ret_report[2], ",")
    for _, v in ipairs(direct_userids) do
        local record = db_helper.do_redis("zrangebyscore", string.format("log_team_day_report%d:userid:%s", clubid, v), timestamp, timestamp)
        local report_item = cjson.decode(record[1])

        local item = { partner = false, date = datequery }
        local account_info = db_helper.get_user_account_info_by_userid(v, "gameid", "nickname")
        item.gameid = tonumber(account_info[1])
        item.nickname = account_info[2]
        item.share_ratio = report_item.share_ratio
        item.performance = report_item.performance
        item.commission = report_item.commission
        table.insert(items, item)
    end

    local direct_partner_userids = string.split(ret_report[3], ",")
    for _, v in ipairs(direct_partner_userids) do
        local record = db_helper.do_redis("zrangebyscore", string.format("log_team_day_report%d:userid:%s", clubid, v), timestamp, timestamp)
        local report_item = cjson.decode(record[1])

        local item = { partner = true, date = datequery }
        local account_info = db_helper.get_user_account_info_by_userid(v, "gameid", "nickname")
        item.gameid = tonumber(account_info[1])
        item.nickname = account_info[2]
        item.share_ratio = report_item.share_ratio
        item.performance = report_item.performance
        item.commission = report_item.commission
        table.insert(items, item)
    end

    return { items = items }
end

-- 直属合伙人税收明细
function CMD.team_report_partner_info(userid, pwd, clubid, id)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return { items = {} }
    end
    if ret[1] ~= pwd then
        return { items = {} }
    end

    if tonumber(ret[2]) ~= clubid then
        return { items = {} }
    end

    local ret_report = db_helper.do_redis("hmget", "log_team_day_report" .. clubid .. ":id:" .. id, "share_ratio", "direct_partner_userids", "create_date")
    if not ret_report[1] then
        return { items = {} }
    end

    local my_share_ratio = tonumber(ret_report[1])
    local timestamp = date(ret_report[3]):totimestamp()
    local datequery = date(ret_report[3]):fmt("%F %T")
    
    local items = {}
    local direct_partner_userids = string.split(ret_report[2], ",")
    for _, v in ipairs(direct_partner_userids) do
        local record = db_helper.do_redis("zrangebyscore", string.format("log_team_day_report%d:userid:%s", clubid, v), timestamp, timestamp)
        local report_item = cjson.decode(record[1])

        local item = { date = datequery }
        local account_info = db_helper.get_user_account_info_by_userid(v, "gameid", "nickname")
        item.gameid = tonumber(account_info[1])
        item.nickname = account_info[2]
        item.share_ratio = report_item.share_ratio
        item.performance = report_item.performance
        item.commission = report_item.commission
        table.insert(items, item)
    end

    return { items = items }
end

-- 报表明细
function CMD.team_report_info(userid, pwd, clubid, month)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return false, { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return false, { result_code = 2, reason = "用户不存在" }
    end

    if tonumber(ret[2]) ~= clubid then
        return false, { result_code = 3, reason = "俱乐部信息有误" }
    end

    local ret_team = db_helper.get_user_team_info(userid, clubid, "today_total_performance", "month_total_performance", "month_total_commission")
    local result = {}
    result.today_total_performance = tonumber(ret_team[1])
    result.month_total_performance = tonumber(ret_team[2])
    result.month_total_commission = tonumber(ret_team[3])
    
    local startdate, enddate
    if month == 0 then
        startdate = date():setday(1):totimestamp()
        enddate = date():sethours(0, 0, 0):totimestamp()
    else
        enddate = date():setday(1):totimestamp()
        startdate = date():addmonths(-month):sethours(0, 0, 0):totimestamp()
    end
    result.items = {}
    local report_result = db_helper.do_redis("zrevrangebyscore", "log_team_day_report" .. clubid .. ":userid:" .. userid, enddate, startdate)
    for _, v in ipairs(report_result) do
        local r = cjson.decode(v)
        local item = {}
        item.id = r.id
        item.create_date = r.create_date
        item.performance = r.performance
        item.share_ratio = r.share_ratio
        item.commission = r.commission
        item.partner_commission = r.partner_commission
        item.direct_members_performance = r.direct_members_performance
        item.direct_partner_commission = r.direct_partner_commission
        table.insert(result.items, item)
    end

    return true, result
end

-- 推广信息
function CMD.team_spread_info(userid, pwd, clubid)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return false, { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return false, { result_code = 2, reason = "用户不存在" }
    end

    if tonumber(ret[2]) ~= clubid then
        return false, { result_code = 3, reason = "俱乐部信息有误" }
    end
    
    local result = {}
    local bind_info = db_helper.get_user_team_bind_info(userid, clubid, "invite_code")
    result.invited_code = bind_info[1]

    -- 推广数据
    local invite_items = {}
    local today_info = db_helper.get_user_team_info(userid, clubid, "today_new_members_count", "today_new_direct_members_count")
    table.insert(invite_items, { new_members_count = tonumber(today_info[1]), new_direct_members_count = tonumber(today_info[2]) })
    -- 过去5天的
    local startdate = date():adddays(-1):sethours(0, 0, 0, 0):totimestamp()
    local enddate = date():adddays(-5):sethours(0, 0, 0, 0):totimestamp()
    local ret_items = db_helper.do_redis("zrevrangebyscore", "log_team_day_report" .. clubid .. ":userid:" .. userid, startdate, enddate)
    for _, v in ipairs(ret_items) do
        local item = cjson.decode(v)
        table.insert(invite_items, { new_members_count = tonumber(item.new_members_count), new_direct_members_count = tonumber(item.new_direct_members_count) })
    end
    
    result.new_members_item = invite_items
    result.invite_urls = {}

    return true, result
end

-- 转账
function CMD.team_transfer(userid, pwd, clubid, dest_userid, transfer_score)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码有误" }
    end

    if tonumber(ret[2]) ~= clubid then
        return { result_code = 3, reason = "当前俱乐部不能转账" }
    end

    local ret_game = db_helper.get_user_game_info(userid, "bank_score", "score")
    local score_result = {}
    score_result.bank_score = tonumber(ret_game[1])
    score_result.score = tonumber(ret_game[2])
    if score_result.score < transfer_score or score_result.score < 10000 or (score_result.score - transfer_score) < 300 then
        return { result_code = 4, reason = "金额有误" }
    end

    local dest_user = db_helper.get_user_account_info_by_userid(dest_userid, "gameid", "nickname")
    if not dest_user[1] then
        return { result_code = 4, reason = "目标用户不存在" }
    end

    -- 只能给直属下级或者直属合伙人转账
    local bind_info = db_helper.get_user_team_bind_info(userid, clubid, "direct_userids", "direct_partner_userids")
    local direct_userids = string.split(bind_info[1], ",")
    local exsit_user = false
    for _, v in ipairs(direct_userids) do
        if tonumber(v) == dest_userid then
            exsit_user = true
            break
        end
    end
    local direct_partner_userids = string.split(bind_info[2], ",")
    for _, v in ipairs(direct_partner_userids) do
        if tonumber(v) == dest_userid then
            exsit_user = true
            break
        end
    end
    if not exsit_user then
        return { result_code = 5, reason = "只能给直属下级或者直属合伙人转账" }
    end

    -- 扣除金额
    local incrby_score_t = {
        score = -transfer_score
    }
    local source_game_score = db_helper.get_user_game_info(userid, "score", "bank_score")
    local updatescore = db_helper.incrby_user_game_info(userid, incrby_score_t)
    db_helper.insert_log_change_score("team_transfer", "", userid, tonumber(source_game_score[1]), -transfer_score, tonumber(source_game_score[2]), 0)

    db_helper.insert_log_team_transfer(userid, clubid, dest_userid, tonumber(dest_user[1]), dest_user[2], transfer_score)

    -- 通知更新
    cluster.send("cluster_center", "@center", "notify_update_score", userid, tonumber(updatescore[1]))
    
    return { result_code = 0, reason = "转账成功，等待确认" }
end

-- 编辑公告
function CMD.team_edit_notice(userid, pwd, clubid, notice)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码有误" }
    end

    if tonumber(ret[2]) ~= clubid then
        return { result_code = 3, reason = "俱乐部信息有误" }
    end

    if string.len(notice) > LEN_NOTICE then
        return { result_code = 4, reason = "公告字数太多" }
    end

    local update_t = {
        notice = notice
    }
    db_helper.update_user_team_bind_info(userid, clubid, update_t)
    
    return { result_code = 0, reason = "修改公告成功" }
end

-- 编辑名片
function CMD.team_edit_card(userid, pwd, clubid, wx, qq)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码有误" }
    end

    if tonumber(ret[2]) ~= clubid then
        return { result_code = 3, reason = "俱乐部信息有误" }
    end

    if string.len(wx) > LEN_WX or string.len(qq) > LEN_QQ then
        return { result_code = 4, reason = "微信或QQ太长" }
    end

    local update_t = {
        wx = wx,
        qq = qq
    }
    db_helper.update_user_team_bind_info(userid, clubid, update_t)
    
    return { result_code = 0, reason = "修改名片成功" }
end

-- 转账明细
function CMD.team_log_transfer(userid, pwd, clubid)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return {  }
    end
    if ret[1] ~= pwd then
        return {  }
    end

    if tonumber(ret[2]) ~= clubid then
        return {  }
    end

    local max = date():totimestamp()
    local end_date = date():addmonths(-2)
    end_date:sethours(0, 0, 0, 0)
    end_date:setday(1)
    local min = end_date:totimestamp()

    local records = db_helper.do_redis("zrevrangebyscore", "log_team_transfer" .. clubid .. ":userid:" .. userid, max, min)
    local result = {}
    for k, v in pairs(records or {}) do
        local item = cjson.decode(v)
        table.insert(result, {
            id = item.id,
            insert_date = item.insert_date,
            nickname = item.dest_nickname,
            gameid = item.dest_gameid,
            transfer_score = item.transfer_score,
            state = item.state,
            expired_seconds = item.state == 0 and (db_helper.do_redis("ttl", "expired_log_team_transfer" .. clubid .. ":userid:" .. userid .. ":id:" .. item.id)) or nil
        })
    end
    
    return result
end

-- 撤销转账
function CMD.team_transfer_cancel(userid, pwd, clubid, id)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码有误" }
    end

    if tonumber(ret[2]) ~= clubid then
        return { result_code = 3, reason = "俱乐部信息有误" }
    end

    local count = db_helper.do_redis("del", "expired_log_team_transfer" .. clubid .. ":userid:" .. userid .. ":id:" .. id)
    if count ~= 1 then
        return { result_code = 4, reason = "撤消转账失败" }
    end

    local log_key = string.format("log_team_transfer%d:userid:%d:id:%d", clubid, userid, id)
    local json = db_helper.do_redis("get", log_key)
    local log_item = cjson.decode(json)

    -- 增加金额
    local incrby_score_t = {
        score = log_item.transfer_score
    }
    local source_game_score = db_helper.get_user_game_info(userid, "score", "bank_score")
    local updatescore = db_helper.incrby_user_game_info(userid, incrby_score_t)
    db_helper.insert_log_change_score("team_transfer_cancel", "", userid, tonumber(source_game_score[1]), log_item.transfer_score, tonumber(source_game_score[2]), 0)
    cluster.send("cluster_center", "@center", "notify_update_score", userid, tonumber(updatescore[1]))

    db_helper.do_redis("zrem", "log_team_transfer" .. clubid .. ":userid:" .. userid, json)
    log_item.state = 2
    local timestamp = date(log_item.insert_date):totimestamp()
    json = cjson.encode(log_item)
    db_helper.do_redis("zadd", "log_team_transfer" .. clubid .. ":userid:" .. userid, timestamp, json)
    mysql_utils.async_write(mysql_utils.make_update_sql("log_team_transfer" .. clubid, log_item, { id = id }))

    return { result_code = 0, reason = "撤消转账成功", id = id }
end

-- 自动成为合伙人
function CMD.team_auto_be_partner(userid, pwd, clubid, auto_be_partner, auto_partner_share_ratio)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码有误" }
    end

    if tonumber(ret[2]) ~= clubid then
        return { result_code = 3, reason = "俱乐部信息有误" }
    end

    if auto_be_partner then
        local team_info = db_helper.get_user_team_info(userid, clubid, "share_ratio")
        if auto_partner_share_ratio > tonumber(team_info[1]) then
            return { result_code = 4, reason = "分成比例不能高于自己的分成比例" }
        end
    else
        auto_partner_share_ratio = 0
    end

    local update_t = {
        auto_be_partner = auto_be_partner and 1 or 0,
        auto_partner_share_ratio = auto_partner_share_ratio
    }
    db_helper.update_user_team_bind_info(userid, clubid, update_t)

    return { result_code = 0, reason = "设置成功" }
end

-- 升级为合伙人
function CMD.team_be_partner(userid, pwd, clubid, dest_userid, share_ratio)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码有误" }
    end

    if tonumber(ret[2]) ~= clubid then
        return { result_code = 3, reason = "俱乐部信息有误" }
    end

    if share_ratio <= 0 then
        return { result_code = 4, reason = "无效的分成比例" }
    end

    -- 只能给直属下级升级为合伙人
    local bind_info = db_helper.get_user_team_bind_info(userid, clubid, "direct_userids", "direct_partner_userids")
    print(bind_info[1])
    local direct_userids = string.split(bind_info[1], ",")
    local exsit_user = 0
    for i, v in ipairs(direct_userids) do
        if tonumber(v) == dest_userid then
            exsit_user = i
            break
        end
    end
    if exsit_user == 0 then
        return { result_code = 5, reason = "只能给直属下级升级为合伙人" }
    end

    local team_info = db_helper.get_user_team_info(userid, clubid, "share_ratio")
    if share_ratio > tonumber(team_info[1]) then
        return { result_code = 6, reason = "分成比例不能高于自己的分成比例" }
    end

    local direct_partner_userids = bind_info[2]
    if direct_partner_userids ~= "" then
        direct_partner_userids = direct_partner_userids .. "," .. tostring(dest_userid)
    else
        direct_partner_userids = tostring(dest_userid)
    end
    table.remove(direct_userids, exsit_user)
    local update_bind_t = {
        direct_partner_userids = direct_partner_userids,
        direct_userids = table.concat(direct_userids, ",")
    }
    db_helper.update_user_team_bind_info(userid, clubid, update_bind_t)

    local update_t = {
        share_ratio = share_ratio,
    }
    db_helper.update_user_team_info(dest_userid, clubid, update_t)

    return { result_code = 0, reason = "升级成功" }
end

-- 设置合伙人的分成比例
function CMD.team_set_partner_share_ratio(userid, pwd, clubid, partner_userid, share_ratio)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return { result_code = 1, reason = "用户不存在" }
    end
    if ret[1] ~= pwd then
        return { result_code = 2, reason = "密码有误" }
    end

    if tonumber(ret[2]) ~= clubid then
        return { result_code = 3, reason = "俱乐部信息有误" }
    end

    -- 只能给直属合伙人设置
    local bind_info = db_helper.get_user_team_bind_info(userid, clubid, "direct_partner_userids")
    local direct_partner_userids = string.split(bind_info[1], ",")
    local exsit_user = false
    for _, v in ipairs(direct_partner_userids) do
        if tonumber(v) == partner_userid then
            exsit_user = true
            break
        end
    end
    if not exsit_user then
        return { result_code = 5, reason = "只能给直属合伙人设置分成比例" }
    end

    local team_info = db_helper.get_user_team_info(userid, clubid, "share_ratio")
    if share_ratio > tonumber(team_info[1]) then
        return { result_code = 6, reason = "分成比例不能高于自己的分成比例" }
    end

    local update_t = {
        share_ratio = share_ratio,
    }
    db_helper.update_user_team_info(partner_userid, clubid, update_t)

    return { result_code = 0, reason = "设置成功" }
end

-- 战绩
function CMD.team_game_records(userid, pwd, clubid, type, day)
    local ret = db_helper.get_user_account_info_by_userid(userid, "password", "selected_clubid")
    if not ret[1] then
        return { items = {} }
    end
    if ret[1] ~= pwd then
        return { items = {} }
    end

    if tonumber(ret[2]) ~= clubid then
        return { items = {} }
    end

    if day < 0 or day > 2 then
        return { items = {} }
    end

    local today = date()
    local start_date = today:adddays(-day)
    start_date:sethours(0, 0, 0, 0)
    local min = start_date:totimestamp()
    local end_date = today:adddays(-day + 1)
    end_date:sethours(0, 0, 0, 0)
    local max = end_date:totimestamp()

    if type == 0 then
        local result = { items = {} }
        local ret_team = db_helper.get_user_team_info(userid, clubid, "share_ratio")
        local share_ratio = tonumber(ret_team[1])
        local records = db_helper.do_redis("zrevrangebyscore", "log_game_record_detail:userid:" .. userid, max, min)
        for k, v in ipairs(records) do
            local record = cjson.decode(v)
            local item = {}
            item.drawid = record.drawid
            item.insert_date = record.insert_date
            item.wanfa = record.wanfa
            item.change_score = record.change_score
            item.revenue = record.revenue
            item.commission = record.performance * share_ratio // 100
            table.insert(result.items, item)
        end
        return result
    else
        local result = { items = {} }
        local ret_bind = db_helper.get_user_team_bind_info(userid, clubid, "direct_userids", "direct_partner_userids")
        local direct_userids = string.split(ret_bind[1], ",")
        local direct_partner_userids = string.split(ret_bind[2], ",")
        for _, v in ipairs(direct_partner_userids) do
            table.insert(direct_userids, v)
        end
        for _, v in ipairs(direct_userids) do
            local ret_account = db_helper.get_user_account_info_by_userid(v, "gameid")
            local gameid = tonumber(ret_account[1])
            local ret_team = db_helper.get_user_team_info(v, clubid, "share_ratio")
            local share_ratio = tonumber(ret_team[1])
            local records = db_helper.do_redis("zrevrangebyscore", "log_game_record_detail:userid:" .. v, max, min)
            for _, r in ipairs(records) do
                local item = {}
                local record = cjson.decode(r)
                item.drawid = record.drawid
                item.gameid = gameid
                item.insert_date = record.insert_date
                item.wanfa = record.wanfa
                item.change_score = record.change_score
                item.revenue = record.revenue
                item.commission = record.performance * share_ratio // 100
                table.insert(result.items, item)
            end
        end
        return result
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd .. "not found")
        skynet.retpack(f(...))
    end)

    skynet.register(SERVICE_NAME)
end)
