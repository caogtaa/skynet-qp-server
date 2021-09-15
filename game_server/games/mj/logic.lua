
local logic = {}

local tbl = {}
local eye_tbl = {}
local feng_tbl = {}
local feng_eye_tbl = {}

local function _load(file, tbl)
    local num = 0
    local f = io.open(file, "r")
    while true do
        local line = f:read()
        if not line then
            break
        end
        num = num + 1
        tbl[tonumber(line)] = true
    end
    f:close()
end

local function _init_tbl()
    for i = 0, 4 do
        tbl[i] = {}
        eye_tbl[i] = {}
        feng_tbl[i] = {}
        feng_eye_tbl[i] = {}

        _load(string.format("./game_server/games/mj/tbl/table_%d.tbl",i), tbl[i])
        _load(string.format("./game_server/games/mj/tbl/eye_table_%d.tbl",i), eye_tbl[i])
        _load(string.format("./game_server/games/mj/tbl/feng_table_%d.tbl",i), feng_tbl[i])
        _load(string.format("./game_server/games/mj/tbl/feng_eye_table_%d.tbl",i), feng_eye_tbl[i])
    end
end
_init_tbl()

local function check(key, gui_num, eye, chi)
    if not chi then
        if eye then
            return feng_eye_tbl[gui_num][key]
        else
            return feng_tbl[gui_num][key]
        end
    else
        if eye then
            return eye_tbl[gui_num][key]
        else
            return tbl[gui_num][key]
        end
    end
end

math.randomseed(tonumber(tostring(os.time()):reverse():sub(1,6)))

local ALL_CARDS_DATA = {
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, -- 万
    0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, -- 筒
    0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, -- 条
    0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, -- 东、南、西、北、中、发、白
}

local ColorStr = { "万", "筒", "条" }
local ZiStr = { "东", "西", "南", "北", "中", "发", "白" }
function logic.get_card_str(carddata)
    local color = carddata & 0xF0 >> 4
    local value = carddata & 0x0F
    if color <= 2 then
        return value .. ColorStr[value]
    else
        return ZiStr[value]
    end
end

function logic.get_card_index(carddata)
    if not tonumber(carddata) then
        return 0
    end

    local value = carddata & 0x0F
    local color = (carddata & 0xF0) >> 4
    local idx = color * 9 + value
    return idx
end

-- 编码麻将
--[[
    原始 6万6万6万4筒4筒4筒4条4条5条5条6条6条发发
    编码后变为 {
        0,0,0,   0,0,3,   0,0,0,
        0,0,0,   3,0,0,   0,0,0,
        0,0,0,   2,2,2,   0,0,0,
        0,0,0,0, 0,2,0}
]]
function logic.encode_cardsdata(cardsdata)
    local t = {}
    for i, v in ipairs(ALL_CARDS_DATA) do
        t[i] = 0
    end

    for _, v in ipairs(cardsdata) do
        local idx = logic.get_card_index(v)
        t[idx] = t[idx] + 1
    end
    return t
end

-- 洗牌
function logic.shuffle()
    local t = table.clone(ALL_CARDS_DATA, true)
    for i = #t, 2, -1 do
        local tmp = t[i]
        local index = math.random(1, i - 1)
        t[i] = t[index]
        t[index] = tmp
    end
    return t
end

function logic.can_peng(hand_cardsdata, carddata)
    local cards = logic.encode_cardsdata(hand_cardsdata)
    return cards[logic.get_card_index(carddata)] >= 2
end

function logic.can_angang(hand_cardsdata, carddata)
    local cards = logic.encode_cardsdata(hand_cardsdata)
    return cards[logic.get_card_index(carddata)] == 4
end

function logic.can_diangang(hand_cardsdata, carddata)
    local cards = logic.encode_cardsdata(hand_cardsdata)
    return cards[logic.get_card_index(carddata)] == 3
end

local function can_chi(hand_cardsindex, card1index, card2index)
    if not hand_cardsindex[card1index] or not hand_cardsindex[card2index] then
        return false
    end

    if hand_cardsindex[card1index] == 0 or hand_cardsindex[card2index] == 0 then
        return false
    end

    if card1index >= 28 or card2index >= 28 then
        return false
    end

    local color1 = ALL_CARDS_DATA[card1index] & 0xF0
    local color2 = ALL_CARDS_DATA[card2index] & 0xF0

    if color1 ~= color2 then
        return false
    end

    return true
end

function logic.can_left_chi(hand_cardsdata, carddata)
    local hand_cardsindex = logic.encode_cardsdata(hand_cardsdata)
    local cardindex = logic.get_card_index(carddata)
    return can_chi(hand_cardsindex, cardindex + 1, cardindex + 2)
end

function logic.can_middle_chi(hand_cardsdata, carddata)
    local hand_cardsindex = logic.encode_cardsdata(hand_cardsdata)
    local cardindex = logic.get_card_index(carddata)
    return can_chi(hand_cardsindex, cardindex - 1, cardindex + 1)
end

function logic.can_right_chi(hand_cardsdata, carddata)
    local hand_cardsindex = logic.encode_cardsdata(hand_cardsdata)
    local cardindex = logic.get_card_index(carddata)
    return can_chi(hand_cardsindex, cardindex - 2, cardindex - 1)
end

local function _get_need_gui(cards, from, to, chi, gui_num)
	local num = 0
	local key = 0
	for i=from,to do
		key = key * 10 + cards[i]
		num = num + cards[i]
	end
	
	if num == 0 then
	    return 0, false
	end

    for i=0, gui_num do
        local yu = (num + i)%3
        if yu ~= 1 then
            local eye = (yu == 2)
            if check(key, i, eye, chi) then
                return i, eye
            end
        end
    end
end

local function _check(cards, gui_num)
	local total_need_gui = 0
	local eye_num = 0
	for i=0,3 do
		local from = i*9 + 1
		local to = from + 8
		if i == 3 then
			to = from + 6
		end
		
		local need_gui, eye = _get_need_gui(cards, from, to, i<3, gui_num)
		if not need_gui then
		    return false
		end
		total_need_gui = total_need_gui + need_gui
		if eye then
			eye_num = eye_num + 1
		end
	end

	if eye_num == 0 then
		return total_need_gui + 2 <= gui_num
	elseif eye_num == 1 then
		return total_need_gui <= gui_num
	else
		return total_need_gui + eye_num - 1 <= gui_num
	end
end

local function is_7_dui_with_gui(hand_cards, gui_index)
    local sum = 0
    local gui_num = 0
    if gui_index and gui_index > 0 then
        gui_num = hand_cards[gui_index]
        hand_cards[gui_index] = 0
    end
    local need_gui = 0
    for i,v in ipairs(hand_cards) do
        sum = sum + v
        if v == 1 or v == 3 then
            need_gui = need_gui + 1
        end 
    end
    if gui_index and gui_index > 0 then
        hand_cards[gui_index] = gui_num
    end
    return sum + gui_num == 14 and gui_num >= need_gui
end

function logic.can_hu(hand_cardsdata, gui_carddata)
    local hand_cards = logic.encode_cardsdata(hand_cardsdata)
    local gui_index = logic.get_card_index(gui_carddata)

    if is_7_dui_with_gui(hand_cards, gui_index) then
        return true
    end

    local gui_num = 0
    if gui_index > 0 then
        gui_num = hand_cards[gui_index]
        hand_cards[gui_index] = 0
    end

    return _check(hand_cards, gui_num)
end

function logic._can_hu(hand_cards, gui_index)
    local gui_num = 0
    if gui_index > 0 then
        gui_num = hand_cards[gui_index]
        hand_cards[gui_index] = 0
    end

    return _check(hand_cards, gui_num)
end


-- 测试-----------------

local function test_one()
    -- 6万6万6万4筒4筒4筒4条4条5条5条6条6条发发
    local t = {
        0,0,0,   0,0,3,   0,0,0,
        0,0,0,   3,0,0,   0,0,0,
        0,0,0,   2,2,2,   0,0,0,
        0,0,0,0, 2,0,0}
    if not logic._can_hu(t, 0) then
        print("不能胡牌")
    else
        print("可以胡牌")
    end
end

local function test_7dui()
    local t = {
        2,0,2,   0,0,2,   0,0,0,
        0,0,0,   0,0,0,   0,0,0,
        0,0,0,   2,2,2,   0,0,0,
        0,0,0,0, 1,0,1}
    if not logic.is_7_dui_with_gui(t, #t) then
        print("不是7对")
    else
        print("是7对")
    end
end
test_one()
test_7dui()

return logic
