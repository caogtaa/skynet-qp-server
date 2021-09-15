
--require("global.luaext") -- for test
local logic = {}

math.randomseed(tonumber(tostring(os.time()):reverse():sub(1,6)))

local ALL_CARDS_DATA = {
    0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,	-- 方块 A - K
	0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,	-- 梅花 A - K
	0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,	-- 红桃 A - K
	0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D	-- 黑桃 A - K
}

local CARD_TYPE = {
    CT_POINT = 0,
    CT_NIU1 = 1,
	CT_NIU2 = 2,
	CT_NIU3 = 3,
	CT_NIU4 = 4,
	CT_NIU5 = 5,
	CT_NIU6 = 6,
	CT_NIU7 = 7,
	CT_NIU8 = 8,
	CT_NIU9 = 9,
	CT_NIUNIU = 10,
	CT_SHUNZI = 11,		-- 顺子
	CT_YINNIU = 12,		-- 银牛
	CT_TONGHUA = 13,	-- 同花
	CT_JINNIU = 14,		-- 金牛
	CT_HULU = 15,		-- 葫芦
	CT_WUXIAONIU = 16,	-- 五小牛
	CT_ZHADAN = 17,		-- 炸弹
	CT_YITIAOLONG = 18,	-- 一条龙
	CT_TONGHUASHUN = 19,	-- 同花顺
}

-- 牌型规则
--local card_type_rule = 0
local card_type_rule = 0x1 | 0x2 | 0x4 | 0x8 | 0x10 | 0x20 | 0x40 | 0x80 | 0x100
-- 王癞
local laizi = false

-- 倍数规则
local card_times_rule = 0

-- 剩余扑克
local leave_cards_data

-- 牌型规则
function logic.set_card_type_rule(rule, lz)
    card_type_rule = rule
    laizi = lz or false
end

local function has_card_type(card_type)
    if card_type == CARD_TYPE.CT_TONGHUASHUN then
        return (card_type_rule & 0x1) ~= 0 and true or false
    elseif card_type == CARD_TYPE.CT_YITIAOLONG then
        return (card_type_rule & 0x2) ~= 0 and true or false
    elseif card_type == CARD_TYPE.CT_ZHADAN then
        return (card_type_rule & 0x4) ~= 0 and true or false
    elseif card_type == CARD_TYPE.CT_WUXIAONIU then
        return (card_type_rule & 0x8) ~= 0 and true or false
    elseif card_type == CARD_TYPE.CT_HULU then
        return (card_type_rule & 0x10) ~= 0 and true or false
    elseif card_type == CARD_TYPE.CT_JINNIU then
        return (card_type_rule & 0x20) ~= 0 and true or false
    elseif card_type == CARD_TYPE.CT_TONGHUA then
        return (card_type_rule & 0x40) ~= 0 and true or false
    elseif card_type == CARD_TYPE.CT_YINNIU then
        return (card_type_rule & 0x80) ~= 0 and true or false
    elseif card_type == CARD_TYPE.CT_SHUNZI then
        return (card_type_rule & 0x100) ~= 0 and true or false
    end
    return false
end

-- 倍数规则
function logic.set_card_times_rule(rule)
    card_times_rule = rule
end

-- 牌值
function logic.get_card_value(carddata)
    return carddata & 0x0F
end

-- 牌的花色
function logic.get_card_color(carddata)
    return (carddata & 0xF0) >> 4
end

-- 牌逻辑值
function logic.get_card_logic_value(carddata)
    local v = carddata & 0x0F
    return v > 10 and 10 or v
end

function logic.sort_cards_data(cardsdata)
    table.sort(cardsdata, function(a, b)
        return logic.get_card_value(a) > logic.get_card_value(b)
    end)
end

-- 获取牌型
function logic.get_card_type(cardsdata)
    local nolaizi_carddata = {}
    for i = 1, #cardsdata do
        if cardsdata[i] ~= 0x41 and cardsdata[i] ~= 0x42 then
            table.insert(nolaizi_carddata, cardsdata[i])
        end
    end
    local laizi_count = 5 - #nolaizi_carddata

    -- 4种花色的数量
    local color_count = { 0, 0, 0, 0 }
    do
        for i = 1, #nolaizi_carddata do
            local v = logic.get_card_color(nolaizi_carddata[i]) + 1
            color_count[v] = color_count[v] + 1
        end
    end
    -- 先匹配同花
    local tonghua = false
    for _, v in ipairs(color_count) do
        if v + laizi_count == 5 then
            tonghua = true
            break
        end
    end

    local shunzi = true
    do
        local tempcards = table.clone(nolaizi_carddata, true)
        logic.sort_cards_data(tempcards)
        local leave_laizi_count = laizi_count
        for i = 1, #tempcards - 1 do
            local v1 = logic.get_card_value(tempcards[i])
            local v2 = logic.get_card_value(tempcards[i + 1])
            local interval = v1 - v2
            if interval == 0 then
                shunzi = false
                break
            elseif interval > leave_laizi_count + 1 then
                shunzi = false
                break
            else
                leave_laizi_count = leave_laizi_count - interval + 1
            end
        end
    end

    -- 同花顺
    if tonghua and shunzi and has_card_type(CARD_TYPE.CT_TONGHUASHUN) then
        return CARD_TYPE.CT_TONGHUASHUN
    end

    local cards_value = {}
    for i = 1, #nolaizi_carddata do
        cards_value[i] = logic.get_card_value(nolaizi_carddata[i])
    end

    table.sort(cards_value, function(a, b)
        return a < b
    end)

    -- 一条龙
    if shunzi and has_card_type(CARD_TYPE.CT_YITIAOLONG) then
        local yitiaolong = true
        for i = 1, #cards_value do
            if cards_value[i] > 5 then
                yitiaolong = false
                break
            end
        end
        if yitiaolong then
            return CARD_TYPE.CT_YITIAOLONG
        end
    end

    local same_cards_count = {}
    for i = 1, 13 do
        same_cards_count[i] = 0
    end
    for i = 1, #cards_value do
        local v = cards_value[i]
        same_cards_count[v] = same_cards_count[v] + 1
    end

    -- 炸弹
    local has_bomb = false
    for i = 1, 13 do
        if same_cards_count[i] + laizi_count >= 4 then
            has_bomb = true
            break
        end
    end
    if has_bomb and has_card_type(CARD_TYPE.CT_ZHADAN) then
        return CARD_TYPE.CT_ZHADAN
    end

    -- 五小牛
    if has_card_type(CARD_TYPE.CT_WUXIAONIU) then
        local wuxiaoniu = true
        for i = 1, #cards_value do
            if cards_value[i] >= 5 then
                wuxiaoniu = false
                break
            end
        end
        if wuxiaoniu then
            local sumvalue = 0
            for _, v in ipairs(cards_value) do
                sumvalue = sumvalue + v
            end
            if sumvalue + laizi_count * 1 <= 10 then
                return CARD_TYPE.CT_WUXIAONIU
            end
        end
    end

    -- 葫芦
    local hulu1 = false
    local hulu2 = false
    table.sort(same_cards_count, function(a, b)
        return a > b
    end)
    local leave_laizi_count = laizi_count
    for i = 1, 13 do
        if same_cards_count[i] + leave_laizi_count >= 3 then
            leave_laizi_count = math.max(0, leave_laizi_count - (3 - same_cards_count[i]))
            hulu1 = true
        elseif same_cards_count[i] + leave_laizi_count >= 2 then
            leave_laizi_count = math.max(0, leave_laizi_count - (2 - same_cards_count[i]))
            hulu2 = true
        end
        if hulu1 and hulu2 then
            break
        end
    end
    if hulu1 and hulu2 and has_card_type(CARD_TYPE.CT_HULU) then
        return CARD_TYPE.CT_HULU
    end

    -- 金牛
    if has_card_type(CARD_TYPE.CT_JINNIU) then
        local jinniu = true
        for _, v in ipairs(cards_value) do
            if v <= 10 then
                jinniu = false
            end
        end
        if jinniu then
            return CARD_TYPE.CT_JINNIU
        end
    end

    -- 同花
    if tonghua and has_card_type(CARD_TYPE.CT_TONGHUA) then
        return CARD_TYPE.CT_TONGHUA
    end

    -- 银牛
    if has_card_type(CARD_TYPE.CT_YINNIU) then
        local ten_count = 0
        local all_ten = true
        for i = 1, #cards_value do
            if cards_value[i] < 10 then
                all_ten = false
                break
            elseif cards_value[i] == 10 then
                ten_count = ten_count + 1
            end
        end

        if all_ten and ten_count > 0 then
            return CARD_TYPE.CT_YINNIU
        end
    end

    -- 顺子
    if shunzi and has_card_type(CARD_TYPE.CT_SHUNZI) then
        return CARD_TYPE.CT_SHUNZI
    end

    local cards_logic_value = {}
    for i = 1, #nolaizi_carddata do
        cards_logic_value[i] = logic.get_card_logic_value(nolaizi_carddata[i])
    end

    -- 2个癞子肯定是牛牛
    if laizi_count == 2 then
        return CARD_TYPE.CT_NIUNIU
    elseif laizi_count == 1 then    -- 1个癞子肯定有牛 只要找到最大的点就可以了 包括牛牛
        local cards_logic_value_sum = 0
        for i = 1, #nolaizi_carddata do
            cards_logic_value_sum = cards_logic_value_sum + cards_logic_value[i]
        end
        local has_origin_niu = false
        for i = 1, #nolaizi_carddata do
            if (cards_logic_value_sum - cards_logic_value[i]) % 10 == 0 then
                has_origin_niu = true
                break
            end
        end
        if has_origin_niu then
            return CARD_TYPE.CT_NIUNIU
        else
            local ct = CARD_TYPE.CT_POINT
            for i = 1, #nolaizi_carddata - 1 do
                for j = i + 1, #nolaizi_carddata do
                    local n = (cards_logic_value[i] + cards_logic_value[j]) % 10
                    local t
                    if n == 0 then
                        return CARD_TYPE.CT_NIUNIU
                    else
                        t = n
                    end

                    if ct == CARD_TYPE.CT_POINT or t > ct then
                        ct = t
                    end
                end
            end
            return ct
        end
    else
        if (cards_logic_value[1] + cards_logic_value[2] + cards_logic_value[3]) % 10 ~= 0 then
            return CARD_TYPE.CT_POINT
        else
            local v = (cards_logic_value[4] + cards_logic_value[5]) % 10
            if v == 0 then
                return CARD_TYPE.CT_NIUNIU
            else
                return v
            end
        end
    end
end

-- 获取牌型倍数
function logic.get_card_type_times(cardsdata, card_type)
    if not card_type then
        card_type = logic.get_card_type(cardsdata)
    end

    if card_type == CARD_TYPE.CT_TONGHUASHUN then
        return 10
    elseif card_type == CARD_TYPE.CT_YITIAOLONG then
        return 9
    elseif card_type == CARD_TYPE.CT_ZHADAN then
        return 8
    elseif card_type == CARD_TYPE.CT_WUXIAONIU then
        return 7
    elseif card_type == CARD_TYPE.CT_HULU then
        return 7
    elseif card_type == CARD_TYPE.CT_JINNIU then
        return 6
    elseif card_type == CARD_TYPE.CT_TONGHUA then
        return 6
    elseif card_type == CARD_TYPE.CT_YINNIU then
        return 5
    elseif card_type == CARD_TYPE.CT_SHUNZI then
        return 5
    elseif card_type == CARD_TYPE.CT_NIUNIU then
        if card_times_rule == 2 then
            return 5
        elseif card_times_rule == 1 then
            return 4
        else
            return 3
        end
    elseif card_type == CARD_TYPE.CT_NIU9 then
        if card_times_rule == 2 then
            return 4
        elseif card_times_rule == 1 then
            return 3
        else
            return 2
        end
    elseif card_type == CARD_TYPE.CT_NIU8 then
        if card_times_rule == 2 then
            return 3
        elseif card_times_rule == 1 then
            return 2
        else
            return 2
        end
    elseif card_type == CARD_TYPE.CT_NIU7 then
        if card_times_rule == 2 then
            return 2
        elseif card_times_rule == 1 then
            return 2
        else
            return 1
        end
    else
        return 1
    end
end

-- 获取最大牛牛牌型
function logic.get_max_card_type(cards_data)
    local result_data = table.clone(cards_data, true)

    local card_type = logic.get_card_type(cards_data)
    if card_type > CARD_TYPE.CT_NIUNIU then
        return card_type, result_data
    end

    local nolaizi_carddata = {}
    for i = 1, #cards_data do
        if cards_data[i] ~= 0x41 and cards_data[i] ~= 0x42 then
            table.insert(nolaizi_carddata, cards_data[i])
        end
    end
    local laizi_count = 5 - #nolaizi_carddata
    if laizi_count == 2 then
        result_data[1] = 0x42
        result_data[2] = nolaizi_carddata[1]
        result_data[3] = nolaizi_carddata[2]
        result_data[4] = 0x41
        result_data[5] = nolaizi_carddata[3]
        return CARD_TYPE.CT_NIUNIU, result_data
    elseif laizi_count == 1 then
        local cards_logic_value_sum = 0
        local cards_logic_value = {}
        for i = 1, #nolaizi_carddata do
            cards_logic_value[i] = logic.get_card_logic_value(nolaizi_carddata[i])
            cards_logic_value_sum = cards_logic_value_sum + cards_logic_value[i]
        end
        local has_origin_niu = false
        for i = 1, #nolaizi_carddata do
            if (cards_logic_value_sum - cards_logic_value[i]) % 10 == 0 then
                result_data[4] = nolaizi_carddata[i]
                has_origin_niu = true
                break
            end
        end
        if has_origin_niu then
            local cnt = 1
            for _, v in ipairs(cards_data) do
                if v == 0x41 or v == 0x42 then
                    result_data[5] = v
                elseif v ~= result_data[4] then
                    result_data[cnt] = v
                    cnt = cnt + 1
                end
            end
            return CARD_TYPE.CT_NIUNIU, result_data
        else
            local ct = CARD_TYPE.CT_POINT
            for i = 1, #nolaizi_carddata - 1 do
                for j = i + 1, #nolaizi_carddata do
                    local n = (cards_logic_value[i] + cards_logic_value[j]) % 10
                    local t
                    if n == 0 then
                        t = CARD_TYPE.CT_NIUNIU
                    else
                        t = n
                    end
    
                    if ct == CARD_TYPE.CT_POINT or t > ct then
                        local cnt = 1
                        for k = 1, #nolaizi_carddata do
                            if k ~= i and k ~= j then
                                result_data[cnt] = nolaizi_carddata[k]
                                cnt = cnt + 1
                            end
                        end
                        for _, v in ipairs(cards_data) do
                            if v == 0x41 or v == 0x42 then
                                result_data[3] = v
                                break
                            end
                        end
    
                        cnt = cnt + 1
                        result_data[cnt] = nolaizi_carddata[i]
                        cnt = cnt + 1
                        result_data[cnt] = nolaizi_carddata[j]
                        cnt = cnt + 1
                        ct = t
                    end
                end
            end
            return ct, result_data
        end
    else
        local ct = CARD_TYPE.CT_POINT
        local cards_logic_value_sum = 0
        local cards_logic_value = {}
        for i = 1, 5 do
            cards_logic_value[i] = logic.get_card_logic_value(cards_data[i])
            cards_logic_value_sum = cards_logic_value_sum + cards_logic_value[i]
        end

        for i = 1, 4 do
            for j = i + 1, 5 do
                if (cards_logic_value_sum - cards_logic_value[i] - cards_logic_value[j]) % 10 == 0 then
                    local n = (cards_logic_value[i] + cards_logic_value[j]) % 10
                    local t
                    if n == 0 then
                        t = CARD_TYPE.CT_NIUNIU
                    else
                        t = n
                    end

                    if ct == CARD_TYPE.CT_POINT or t > ct then
                        local cnt = 1
                        for k = 1, 5 do
                            if k ~= i and k ~= j then
                                result_data[cnt] = cards_data[k]
                                cnt = cnt + 1
                            end
                        end

                        result_data[cnt] = cards_data[i]
                        cnt = cnt + 1
                        result_data[cnt] = cards_data[j]
                        cnt = cnt + 1
                        ct = t
                    end
                end
            end
        end

        return ct, result_data
    end
end

-- 比牌
function logic.compare_cards(first_cards_data, second_cards_data)
    local first_card_type = logic.get_card_type(first_cards_data)
    local second_card_type = logic.get_card_type(second_cards_data)

    if first_card_type ~= second_card_type then
        return first_card_type > second_card_type and true or false
    end

    local first_max_card_value = 0
    local second_max_card_value = 0

    local first_nolaizi_carddata = {}
    for i = 1, #first_cards_data do
        if first_cards_data[i] ~= 0x41 and first_cards_data[i] ~= 0x42 then
            table.insert(first_nolaizi_carddata, first_cards_data[i])
        end
    end
    local first_laizi_count = 5 - #first_nolaizi_carddata

    local second_nolaizi_carddata = {}
    for i = 1, #second_cards_data do
        if second_cards_data[i] ~= 0x41 and second_cards_data[i] ~= 0x42 then
            table.insert(second_nolaizi_carddata, second_cards_data[i])
        end
    end
    local second_laizi_count = 5 - #second_nolaizi_carddata

    -- 炸弹比四炸的点数
    if first_card_type == CARD_TYPE.CT_ZHADAN then
        local tempcards = table.clone(first_nolaizi_carddata, true)
        logic.sort_cards_data(tempcards)
        for i = 1, #tempcards - 1 do
            local v1 = logic.get_card_value(tempcards[i])
            local v2 = logic.get_card_value(tempcards[i + 1])
            if v1 == v2 then
                first_max_card_value = v1
                break
            end
        end

        tempcards = table.clone(second_nolaizi_carddata, true)
        logic.sort_cards_data(tempcards)
        for i = 1, #tempcards - 1 do
            local v1 = logic.get_card_value(tempcards[i])
            local v2 = logic.get_card_value(tempcards[i + 1])
            if v1 == v2 then
                second_max_card_value = v1
                break
            end
        end

        return first_max_card_value > second_max_card_value and true or false
    end

    -- 葫芦比3条的点数
    if first_card_type == CARD_TYPE.CT_HULU then
        local first_same_cards_count = {}
        for i = 1, 13 do
            first_same_cards_count[i] = 0
        end
        for i = 1, #first_nolaizi_carddata do
            local v = logic.get_card_value(first_nolaizi_carddata[i])
            first_same_cards_count[v] = first_same_cards_count[v] + 1
        end
        for i = 13, 1, -1 do
            if first_same_cards_count[i] + first_laizi_count >= 3 then
                first_max_card_value = i
                break
            end
        end

        local second_same_cards_count = {}
        for i = 1, 13 do
            second_same_cards_count[i] = 0
        end
        for i = 1, #second_nolaizi_carddata do
            local v = logic.get_card_value(second_nolaizi_carddata[i])
            second_same_cards_count[v] = second_same_cards_count[v] + 1
        end
        for i = 13, 1, -1 do
            if second_same_cards_count[i] + second_laizi_count >= 3 then
                second_max_card_value = i
                break
            end
        end

        return first_max_card_value > second_max_card_value and true or false
    end

    -- 同花牛 先按顺序依次比点 点数相同 比最大单张花色
    if first_card_type == CARD_TYPE.CT_TONGHUASHUN or first_card_type == CARD_TYPE.CT_TONGHUA then
        if first_laizi_count ~= second_laizi_count then
            return first_laizi_count > second_laizi_count and true or false
        else
            local first_temp_cards_data = table.clone(first_nolaizi_carddata)
            table.sort(first_temp_cards_data, function(a, b)
                return logic.get_card_value(a) > logic.get_card_value(b)
            end)
            local second_temp_cards_data = table.clone(second_nolaizi_carddata)
            table.sort(second_temp_cards_data, function(a, b)
                return logic.get_card_value(a) > logic.get_card_value(b)
            end)

            for i = 1, #first_nolaizi_carddata do
                local v1 = logic.get_card_value(first_temp_cards_data[i])
                local v2 = logic.get_card_value(second_temp_cards_data[i])
                if v1 ~= v2 then
                    return v1 > v2 and true or false
                end
            end

            return logic.get_card_color(first_temp_cards_data[1]) > logic.get_card_color(second_temp_cards_data[1]) and true or false
        end
    end

    -- 取其中最大的一张牌比较大小, 大小相同比花色
    local first_temp_cards_data = table.clone(first_nolaizi_carddata)
    table.sort(first_temp_cards_data, function(a, b)
        return logic.get_card_value(a) > logic.get_card_value(b)
    end)
    local second_temp_cards_data = table.clone(second_nolaizi_carddata)
    table.sort(second_temp_cards_data, function(a, b)
        return logic.get_card_value(a) > logic.get_card_value(b)
    end)

    local mv1 = logic.get_card_value(first_temp_cards_data[1])
    local mv2 = logic.get_card_value(second_temp_cards_data[1])
    if mv1 == mv2 then
        local mc1 = logic.get_card_color(first_temp_cards_data[1])
        local mc2 = logic.get_card_color(second_temp_cards_data[1])
        return mc1 > mc2 and true or false
    else
        return mv1 > mv2 and true or false
    end
end

-- 获取洗牌后的扑克
-- cards_count:返回几张牌
function logic.shuffle(cards_count)
    local cards = table.clone(leave_cards_data)
    local result = {}
    while cards_count > 0 do
        local pos = math.random(#cards)
        table.insert(result, cards[pos])
        table.remove(cards, pos)
        cards_count = cards_count - 1
    end

    for _, v in pairs(cards) do
        if v == 0x41 or v == 0x42 then
            result[5] = v
            break
        end
    end
    return result
end

function logic.reset()
    leave_cards_data = table.clone(ALL_CARDS_DATA, true)
    if laizi then
        table.insert(leave_cards_data, 0x41)
        table.insert(leave_cards_data, 0x42)
    end
end

function logic.remove_cards(cards_data)
    for _, v in ipairs(cards_data) do
        for k, d in ipairs(leave_cards_data) do
            if d == v then
                table.remove(leave_cards_data, k)
                break
            end
        end
    end
end

--[[
local function __test_is_card_type(cardsdata, card_type)
    local type = logic.get_card_type(cardsdata)
    if type == card_type then
        return true
    else
        return false, type
    end
end

print("------测试同花顺牌型开始------")
print(__test_is_card_type({1,2,3,4,5}, CARD_TYPE.CT_TONGHUASHUN))
print(__test_is_card_type({0x12,0x41,0x14,0x15,0x16}, CARD_TYPE.CT_TONGHUASHUN))
print(__test_is_card_type({0x12,0x41,0x14,0x15,0x42}, CARD_TYPE.CT_TONGHUASHUN))
print(__test_is_card_type({0x12,0x41,0x14,0x17,0x42}, CARD_TYPE.CT_TONGHUASHUN))
print("------测试同花顺牌型结束------")

print("------测试一条龙牌型开始------")
print(__test_is_card_type({0x31,0x22,0x33,4,5}, CARD_TYPE.CT_YITIAOLONG))
print(__test_is_card_type({0x31,0x41,0x42,4,5}, CARD_TYPE.CT_YITIAOLONG))
print(__test_is_card_type({0x22,0x41,0x14,0x15,0x13}, CARD_TYPE.CT_YITIAOLONG))
print("------测试一条龙牌型结束------")

print("------测试炸弹牌型开始------")
print(__test_is_card_type({0x04,0x14,0x24,0x34,5}, CARD_TYPE.CT_ZHADAN))
print(__test_is_card_type({0x1a,0x2a,0x42,0x3a,5}, CARD_TYPE.CT_ZHADAN))
print(__test_is_card_type({0x15,0x41,0x25,0x42,0x13}, CARD_TYPE.CT_ZHADAN))
print("------测试炸弹牌型结束------")

print("------测试五小牛牌型开始------")
print(__test_is_card_type({1, 2, 3, 2, 2}, CARD_TYPE.CT_WUXIAONIU))
print(__test_is_card_type({0x11,0x23,0x42,0x41,0x32}, CARD_TYPE.CT_WUXIAONIU))
print(__test_is_card_type({1, 0x12, 0x41, 0x33, 0x21}, CARD_TYPE.CT_WUXIAONIU))
print("------测试五小牛牌型结束------")

print("------测试葫芦牌型开始------")
print(__test_is_card_type({0x04,0x14,0x24,0x15,5}, CARD_TYPE.CT_HULU))
print(__test_is_card_type({0x1a,0x2a,0x42,0x41,5}, CARD_TYPE.CT_HULU))
print(__test_is_card_type({0x15,0x41,0x25,0x13,0x13}, CARD_TYPE.CT_HULU))
print("------测试葫芦牌型结束------")

print("------测试金牛牌型开始------")
print(__test_is_card_type({0x1b, 0x1b, 0x2b, 0x3c, 0x0d}, CARD_TYPE.CT_JINNIU))
print(__test_is_card_type({0x1c, 0x41, 0x2b, 0x3c, 0x0d}, CARD_TYPE.CT_JINNIU))
print(__test_is_card_type({0x1b, 0x41, 0x42, 0x3c, 0x0d}, CARD_TYPE.CT_JINNIU))
print("------测试金牛牌型结束------")

print("------测试同花牌型开始------")
print(__test_is_card_type({0x11, 0x13, 0x17, 0x19, 0x1d}, CARD_TYPE.CT_TONGHUA))
print(__test_is_card_type({0x11, 0x41, 0x17, 0x19, 0x1d}, CARD_TYPE.CT_TONGHUA))
print(__test_is_card_type({0x11, 0x41, 0x42, 0x19, 0x1d}, CARD_TYPE.CT_TONGHUA))
print("------测试同花牌型结束------")

print("------测试银牛牌型开始------")
print(__test_is_card_type({0x1a, 0x1b, 0x2b, 0x3c, 0x0d}, CARD_TYPE.CT_YINNIU))
print(__test_is_card_type({0x1a, 0x41, 0x2b, 0x3c, 0x0d}, CARD_TYPE.CT_YINNIU))
print(__test_is_card_type({0x1a, 0x41, 0x42, 0x3c, 0x0d}, CARD_TYPE.CT_YINNIU))
print("------测试银牛牌型结束------")

print("------测试顺子牌型开始------")
print(__test_is_card_type({0x1a, 0x1b, 0x3c, 0x2d, 0x09}, CARD_TYPE.CT_SHUNZI))
print(__test_is_card_type({0x1a, 0x41, 0x3c, 0x2d, 0x09}, CARD_TYPE.CT_SHUNZI))
print(__test_is_card_type({0x1a, 0x41, 0x3c, 0x42, 0x09}, CARD_TYPE.CT_SHUNZI))
print("------测试顺子牌型结束------")

print("------测试牛牛牌型开始------")
print(__test_is_card_type({0x13, 0x18, 0x39, 0x24, 0x06}, CARD_TYPE.CT_NIUNIU))
print(__test_is_card_type({0x13, 0x41, 0x39, 0x24, 0x06}, CARD_TYPE.CT_NIUNIU))
print(__test_is_card_type({0x13, 0x41, 0x42, 0x29, 0x06}, CARD_TYPE.CT_NIUNIU))
print("------测试牛牛牌型结束------")

print("------测试有问题牌型开始------")
print(__test_is_card_type({0x2b, 0x2a, 0x2c, 0x0c, 0x41}, CARD_TYPE.CT_TONGHUA))
print("------测试有问题牌型结束------")

local function print_max_card_type(type, result_cards)
    local result_str = {}
    for _, v in ipairs(result_cards) do
        table.insert(result_str, string.format("0x%02x", v))
    end
    print(type, table.unpack(result_str))
end 

print("------测试最大牌型开始------")
print_max_card_type(logic.get_max_card_type({0x13, 0x18, 0x39, 0x24, 0x06}))
print_max_card_type(logic.get_max_card_type({0x13, 0x41, 0x39, 0x24, 0x06}))
print_max_card_type(logic.get_max_card_type({0x13, 0x41, 0x42, 0x29, 0x06}))
print_max_card_type(logic.get_max_card_type({0x15, 0x25, 0x12, 0x28, 0x41}))
print("------测试最大牌型结束------")

print("------测试比牌开始------")
print(logic.compare_cards({0x01, 0x11, 0x21, 0x31, 0x25}, {0x0a, 0x1a, 0x2a, 0x3a, 0x35}) and "win" or "lose")
print(logic.compare_cards({0x01, 0x11, 0x21, 0x35, 0x25}, {0x0a, 0x1a, 0x2a, 0x02, 0x32}) and "win" or "lose")
print(logic.compare_cards({1, 4, 5, 6, 7}, {0x11, 0x14, 0x15, 0x16, 0x17}) and "win" or "lose")
print("------测试比牌结束------")

logic.reset()
local c1 = logic.shuffle(5)
logic.remove_cards(c1)
print(c1)
local c2 = logic.shuffle(5)
logic.remove_cards(c2)
print(c2)

print(#leave_cards_data, leave_cards_data)

--./skynet/3rd/lua/lua ./game_server/games/niuniu/logic.lua
]]

return logic
