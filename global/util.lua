local skynet = require "skynet"
local protobuf = require "protobuf"

function LOG_DEBUG(fmt, ...)
    local msg = string.format(fmt, ...)
    local info = debug.getinfo(2)
    if info then
        msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
    end
    skynet.send("log", "lua", "debug", SERVICE_NAME, msg)
    return msg
end

function LOG_INFO(fmt, ...)
    local msg = string.format(fmt, ...)
    local info = debug.getinfo(2)
    if info then
        msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
    end
    skynet.send("log", "lua", "info", SERVICE_NAME, msg)
    return msg
end

function LOG_WARNING(fmt, ...)
    local msg = string.format(fmt, ...)
    local info = debug.getinfo(2)
    if info then
        msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
    end
    skynet.send("log", "lua", "warning", SERVICE_NAME, msg)
    return msg
end

function LOG_ERROR(fmt, ...)
    local msg = string.format(fmt, ...)
    local info = debug.getinfo(2)
    if info then
        msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
    end
    skynet.send("log", "lua", "error", SERVICE_NAME, msg)
    return msg
end

function LOG_FATAL(fmt, ...)
    local msg = string.format(fmt, ...)
    local info = debug.getinfo(2)
    if info then
        msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
    end
    skynet.send("log", "lua", "fatal", SERVICE_NAME, msg)
    return msg
end

function netmsg_pack(name, msg)
    local payload = protobuf.encode(name, msg)
    local netmsg = { name = name, payload = payload }
    local pack = protobuf.encode("netmsg.netmsg", netmsg)
    return pack
end

function netmsg_unpack(data)
    local netmsg = protobuf.decode("netmsg.netmsg", data)
    if not netmsg then
		LOG_ERROR("netmsg_unpack error")
        error("netmsg_unpack error")
        return
	end
    local msg = protobuf.decode(netmsg.name, netmsg.payload)
    if not msg then
        LOG_ERROR(netmsg.name .. " decode error")
        return
    end

    local module, method = netmsg.name:match "([^.]*).([^.]*)"
    return module, method, msg
end

function gamemsg_pack(name, msg)
    local payload = protobuf.encode(name, msg)
    local gamemsg = { name = name, payload = payload }
    local gamepack = protobuf.encode("game.gamemsg", gamemsg)
    local netmsg = { name = "game.gamemsg", payload = gamepack }
    local pack = protobuf.encode("netmsg.netmsg", netmsg)
    return pack
end

function gamemsg_unpack(data)
    local netmsg = protobuf.decode("netmsg.netmsg", data)
    if not netmsg then
		LOG_ERROR("gamemsg_unpack error")
        error("gamemsg_unpack error")
        return
	end
    local gamemsg = protobuf.decode(netmsg.name, netmsg.payload)
    if not gamemsg then
        LOG_ERROR(gamemsg.name .. " decode error")
        return
    end

    local msg = protobuf.decode(gamemsg.name, gamemsg.payload)
    if not msg then
        LOG_ERROR(msg.name .. " decode error")
        return
    end

    local module, method = gamemsg.name:match "([^.]*).([^.]*)"
    return module, method, msg
end

function check_phone_number(phone_number)
    return string.match(phone_number,"[1][3,4,5,6,7,8,9]%d%d%d%d%d%d%d%d%d") == phone_number
end

function check_email(str)
    if string.len(str or "") < 6 then return false end
    local b,e = string.find(str or "", '@')
    local bstr = ""
    local estr = ""
    if b then
        bstr = string.sub(str, 1, b-1)
        estr = string.sub(str, e+1, -1)
    else
        return false
    end

    -- check the string before '@'
    local p1,p2 = string.find(bstr, "[%w_]+")
    if (p1 ~= 1) or (p2 ~= string.len(bstr)) then return false end

    -- check the string after '@'
    if string.find(estr, "^[%.]+") then return false end
    if string.find(estr, "%.[%.]+") then return false end
    if string.find(estr, "@") then return false end
    if string.find(estr, "%s") then return false end --空白符
    if string.find(estr, "[%.]+$") then return false end

    _,count = string.gsub(estr, "%.", "")
    if (count < 1 ) or (count > 3) then
        return false
    end

    return true
end

--判断此字符串是否为纯数字
function check_number(words)
    if string.len(words) < 1 then
        return false
    end
    for i = 1, string.len(words) do
        if string.byte(string.sub(words,i,i)) < 48 or string.byte(string.sub(words,i,i)) > 57 then
            return false
        end
    end
    return true
end

--判断此字符串是否为数字或者字母的组合
function check_alpha_num(s) 
    return (string.match(s, "[^%w]") == nil)
end

-- 简单的判断字符串是不是全为中文
function check_all_chinese(s)
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

-- 由于redis zset score的精度问题 需要把drawid做裁剪
function drawid_to_score(drawid)
    return tonumber(string.sub(tostring(drawid), 1, -10))
end