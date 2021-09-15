local M = {}

M.CardType = {
    [0x10] = {min = 1, max = 9, chi = true},
    [0x20] = {min = 10, max = 18, chi = true},
    [0x30] = {min = 19, max = 27, chi = true},
    [0x40] = {min = 28, max = 34, chi = false},
}

M.CardDefine = {
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, -- 万
    0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, -- 筒
    0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, -- 条
    0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, -- 东、南、西、北、中、发、白
}

local ColorStr = { "万", "筒", "条" }
local ZiStr = { "东", "西", "南", "北", "中", "发", "白" }
function M.get_card_str(carddata)
    local color = carddata & 0xF0 >> 4
    local value = carddata & 0x0F
    if color <= 2 then
        return value .. ColorStr[value]
    else
        return ZiStr[value]
    end
end

function M.encode_cardsdata(cardsdata)
    local t = {}
    for i, v in ipairs(M.CardDefine) do
        t[i] = 0
    end

    for _, v in ipairs(cardsdata) do
        local value = v & 0x0F
        local color = (v & 0xF0) >> 4
        local idx = color * 9 + value
        t[idx] = t[idx] + 1
    end
end

-- 创建一幅牌,牌里存的不是牌本身，而是牌的序号
function M.create(zi)
    local t = {}

    local num = 3*9

    if zi then
        num = num + 7
    end

    for i=1,num do
        for _=1,4 do
            table.insert(t, i)
        end
    end

    return t
end

-- 洗牌
function M.shuffle(t)
    for i=#t,2,-1 do
        local tmp = t[i]
        local index = math.random(1, i - 1)
        t[i] = t[index]
        t[index] = tmp
    end
end

function M.can_peng(hand_cards, card)
    return hand_cards[card] >= 2
end

function M.can_angang(hand_cards, card)
    return hand_cards[card] == 4
end

function M.can_diangang(hand_cards, card)
    return hand_cards[card] == 3
end

function M.can_hu()
end

return M
