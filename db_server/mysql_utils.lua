local skynet = require "skynet"

local M = {}

-- 同步写入数据库
function M.sync_write(sql)
    --LOG_ERROR(sql)
    local result = skynet.call("mysqlpool", "lua", "execute", sql, true)
    if result["err"] then
        skynet.error("写入数据错误:" .. result["err"])
        LOG_ERROR("写入数据错误:" .. result["err"])
        LOG_ERROR("写入数据错误:" .. sql)
        LOG_ERROR("写入数据错误:" .. debug.traceback())
    end
end

function M.sync_write_table(sql_table)
    if table.empty(sql_table) then
        LOG_WARNING("sync_write_table is empty")
        return
    end
    local sql = ""
    for _, v in ipairs(sql_table) do
        sql = sql .. v
    end
    M.sync_write(sql)
end

-- 异步写入数据库
function M.async_write(sql)
    M.sync_write(sql)
    --skynet.call("mysqlpool", "lua", "async", sql)
end

function M.async_write_table(sql_table)
    if table.empty(sql_table) then
        LOG_WARNING("async_write_table is empty")
        return
    end
    local sql = ""
    for _, v in ipairs(sql_table) do
        sql = sql .. v
    end
    M.sync_write(sql)
    --skynet.call("mysqlpool", "lua", "async", sql)
end

-- 生成一条插入sql
-- tbname:表名
-- insert_t: table
function M.make_insert_sql(tbname, insert_t)
    local keys = ""
    local values = ""
	for k, v in pairs(insert_t) do
        keys = keys .. k .. ","
        if type(v) == "string" then
            values = values .. "'" .. v .. "',"
        else
            values = values .. v .. ","
        end
	end

    keys = string.sub(keys, 0, string.len(keys) - 1)
    values = string.sub(values, 0, string.len(values) - 1)

    local sql = string.format("INSERT %s(%s) VALUES(%s);", tbname, keys, values)
    return sql
end

-- 生成一条更新sql
-- tbname:表名
-- update_t: 更新table
-- condition_t: 条件table
function M.make_update_sql(tbname, update_t, condition_t)
    -- 默认不允许空置条件 防止误操作
    if not condition_t or type(condition_t) ~= "table" or table.empty(condition_t) then
        LOG_WARNING("make_update_sql 条件不正确:" .. tbname)
        LOG_WARNING(debug.traceback())
        return ""
    end
    local u = ""
    for k, v in pairs(update_t) do
        if u ~= "" then
            u = u .. ","
        end
        if type(v) == "string" then
            u = u .. k .. "='" .. v .. "'"
        else
            u = u .. k .. "=" .. v
        end
    end

    local c = ""
    for k, v in pairs(condition_t) do
        if c ~= "" then
            c = c .. " AND"
        end
        if type(v) == "string" then
            c = c .. k .. "='" .. v .. "'"
        else
            c = c .. k .. "=" .. v
        end
    end

    local sql = string.format("UPDATE %s SET %s WHERE %s;", tbname, u, c)
    return sql
end

-- 生成一条更新sql
-- tbname:表名
-- update_t: 更新table
-- condition_t: 条件table
-- 和make_update_sql不同的是，这个函数在原基础上做加减 update_t里面对应的表字段只能是数字类型
--[[
    example:
    local update_t = {
        score = 100,
        bank_score = -100
    }
    local tbname = "user_game_info"
    local condition_t = { userid = 1 }
    print(make_update_incrby_sql(tbname, update_t, condition_t))
    输出: UPDATE score = score + 100, bank_score = bank_score + -100 SET %s WHERE userid=1;
]]
function M.make_update_incrby_sql(tbname, update_t, condition_t)
    -- 默认不允许空置条件 防止误操作
    if not condition_t or type(condition_t) ~= "table" or table.empty(condition_t) then
        LOG_WARNING("make_update_incrby_sql 条件不正确:" .. tbname)
        LOG_WARNING(debug.traceback())
        return ""
    end

    local u = ""
    for k, v in pairs(update_t) do
        local str = k .. "=" .. k .. "+" .. v
        if u ~= "" then
            u = u .. ","
        end
        u = u .. str
    end

    local c = ""
    for k, v in pairs(condition_t) do
        if c ~= "" then
            c = c .. " AND"
        end
        if type(v) == "string" then
            c = c .. k .. "='" .. v .. "'"
        else
            c = c .. k .. "=" .. v
        end
    end

    local sql = string.format("UPDATE %s SET %s WHERE %s;", tbname, u, c)
    return sql
end

return M
