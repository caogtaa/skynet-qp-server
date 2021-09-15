local game = {}


game.test = function() print("test") end

local lhd = {}
lhd.test1 = function() print("test1") end

local ttt = setmetatable(game, { __index = lhd })

--检查中文，存在则返回true
local function CheckChinese(s) 
	local k = 1
	while true do
		if k > #s then break end
		local c = string.byte(s,k)
        if c < 228 or c > 233 then
            return false
        end
    end
    return true
end

local function filter_spec_chars(s)
	local ss = {}
	local k = 1
	while true do
		if k > #s then break end
		local c = string.byte(s,k)
		if not c then break end
		if c<192 then
			if (c>=48 and c<=57) or (c>= 65 and c<=90) or (c>=97 and c<=122) then
				table.insert(ss, string.char(c))
			end
			k = k + 1
		elseif c<224 then
			k = k + 2
		elseif c<240 then
			if c>=228 and c<=233 then
				local c1 = string.byte(s,k+1)
				local c2 = string.byte(s,k+2)
				if c1 and c2 then
					local a1,a2,a3,a4 = 128,191,128,191
					if c == 228 then a1 = 184
					elseif c == 233 then a2,a4 = 190,c1 ~= 190 and 191 or 165
					end
					if c1>=a1 and c1<=a2 and c2>=a3 and c2<=a4 then
						table.insert(ss, string.char(c,c1,c2))
					end
				end
			end
			k = k + 3
		elseif c<248 then
			k = k + 4
		elseif c<252 then
			k = k + 5
		elseif c<254 then
			k = k + 6
		end
	end
	return table.concat(ss)
end

--简单的判断字符串是不是全为中文
local function is_all_chinese(s)
	local k = 1
	while true do
		if k > #s then break end
		local c = string.byte(s, k)
		if not c then break end
        if c >= 228 and c <= 233 then
            local c1 = string.byte(s, k + 1)
            local c2 = string.byte(s, k + 2)
            if c1 and c2 then
                if c1 >= 128 and c1 <= 191 and c2 >= 128 and c2 <= 191 then
                    k = k + 3
                else
                    return false
                end
            else
                return false
            end
        else
            return false
        end
	end
	return true
end

print("123123")
print(game.test1())
--print(game.test)
print(is_all_chinese("中文1测试"))

local tm = "db:userid:1:id:1"
local tm1 = "db:userid"
print(string.match(tm, "([^:]*):([^:]*):([^:]*)"))
print(string.match(tm1, "([^:]*):([^:]*):([^:]*)"))
print(string.match("log_recharge:userid:1:id:1", "([^:]*):([^:]*):([^:]*):([^:]*):([^:]*)"))

local function utf8len(input)
    local left = string.len(input)
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left > 0 do
        local tmp = string.byte(input, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end

print(string.len("abc123中文"))
print(string.len("你好World"))
print(utf8len("abc123中文"))
print(utf8len("你好World"))

local function envIsAlphaNum(sIn) 
return (string.match(sIn,"[^%w]") == nil) end
print(envIsAlphaNum("你好World"))
print(envIsAlphaNum("World"))
print(envIsAlphaNum("World123"))
print(envIsAlphaNum("w_"))
print(envIsAlphaNum("w.#$"))

local key = "log_recharge:userid:1:id:1"
print(string.match(key, "([^:]*):([^:]*):([^:]*):([^:]*):([^:]*)"))
local key2 = "log_team_transfer1:userid:1:id:1"
print(string.match(key2, "([^:]*):([^:]*):([^:]*):([^:]*):([^:]*)"))