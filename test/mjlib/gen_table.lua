
-- 生成非字牌表

local table_mgr = require "table_mgr"

local gui_tested = {}
local gui_eye_tested = {}
for i = 0, 8 do
    gui_tested[i] = {}
    gui_eye_tested[i] = {}
end

local function check_add(encode_cards, gui_num, eye)
    local key = 0

    for i = 1, 9 do
        key = key * 10 + encode_cards[i]
    end

    if key == 0 then
        return false
    end

    local m
    if not eye then
        m = gui_tested[gui_num]
    else
        m = gui_eye_tested[gui_num]
    end

    if m[key] then
        return false
    end

    m[key] = true

    for i = 1, 9 do
        if encode_cards[i] > 4 then
            return true
        end
    end
    table_mgr:add(key, gui_num, eye, true)
    return true
end

local function parse_table_sub(encode_cards, gui_num, eye)
    for i = 1, 9 do
        repeat
            if encode_cards[i] == 0 then
                break
            end

            encode_cards[i] = encode_cards[i] - 1

            if not check_add(encode_cards, gui_num, eye) then
                encode_cards[i] = encode_cards[i] + 1
                break
            end
            if gui_num < 8 then
                parse_table_sub(encode_cards, gui_num + 1, eye)
            end
            encode_cards[i] = encode_cards[i] + 1
        until(true)
    end
end

local function parse_table(encode_cards, eye)
    if not check_add(encode_cards, 0, eye) then
        return
    end
    parse_table_sub(encode_cards, 1, eye)
end

local function gen_table_sub(t, level, eye)
    -- 9种刻子+7种连子
    for j = 1, 16 do
        repeat
            if j <= 9 then
                if t[j] > 3 then
                    break
                end
                t[j] = t[j] + 3
            elseif j <= 16 then
                local idx = j - 9
                if t[idx] >= 4 or t[idx + 1] >= 4 or t[idx + 2] >= 4 then
                    break
                end
                t[idx] = t[idx] + 1
                t[idx + 1] = t[idx + 1] + 1
                t[idx + 2] = t[idx + 2] + 1
            end

            parse_table(t, eye)
            if level < 4 then
                gen_table_sub(t, level + 1, eye)
            end

            if j <= 9 then
                t[j] = t[j] - 3
            else
                local idx = j - 9
                t[idx] = t[idx] - 1
                t[idx + 1] = t[idx + 1] - 1
                t[idx + 2] = t[idx + 2] - 1
            end
        until(true)
    end
end

local function gen_table()
    local t = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }
    gen_table_sub(t, 1, false)
end

local function gen_eye_table()
    local t = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }

    for i = 1, 9 do
        t[i] = 2
        parse_table(t, true)
        gen_table_sub(t, 1, true)
        t[i] = 0
    end
end

local function main()
    table_mgr:init()
    gen_table()
    gen_eye_table()
    table_mgr:dump_table()
end

main()
