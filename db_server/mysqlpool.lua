local skynet = require "skynet"
require "skynet.manager"
local mysql = require "skynet.db.mysql"

local backupToMysqlTime = tonumber(skynet.getenv("backupToMysqlTime"))

local CMD = {}
local pool = {}
local queue = {}

local maxconn
local index = 2
local function getconn(sync)
    local db
    if sync then
        db = pool[1]
    else
        db = pool[index]
        assert(db)
        index = index + 1
        if index > maxconn then
            index = 2
        end
    end
    return db
end

-- 写入mysql
local function backupToMysql()
    while true do
        skynet.sleep(100 * backupToMysqlTime)

        local t = table.clone(queue, true)
        queue = {}

        -- TODO 把字符串全部合并 只写一次数据库
        -- TODO 给queue增加标记 比如部分update语句在这里先合并 然后再合并写入数据库
        for _, v in ipairs(t) do
            local ret = CMD.execute(v, true)
            if ret["err"] then
                skynet.error("backupToMysql error:" .. ret["err"])
                skynet.error(v)
                LOG_ERROR("backupToMysql error:" .. ret["err"])
                LOG_ERROR(v)
            end
        end
    end
end

function CMD.start()
    maxconn = tonumber(skynet.getenv("mysql_maxconn")) or 10
    assert(maxconn >= 2)
    for i = 1, maxconn do
        local db = mysql.connect{
            host = skynet.getenv("mysql_host"),
            port = tonumber(skynet.getenv("mysql_port")),
            database = skynet.getenv("mysql_db"),
            user = skynet.getenv("mysql_user"),
            password = skynet.getenv("mysql_pwd"),
            max_packet_size = 1024 * 1024
        }
        if db then
            table.insert(pool, db)
            db:query("set charset utf8")
        else
            skynet.error("mysql connect error")
        end
    end

    skynet.fork(backupToMysql)
end

-- sync为false或者nil，sql为读操作，如果sync为true用于数据变动时同步数据到mysql，sql为写操作
-- 写操作取连接池中的第一个连接进行操作
function CMD.execute(sql, sync)
    local db = getconn(sync)
    return db:query(sql)
end

function CMD.stop()
    for _, db in pairs(pool) do
        db:disconnect()
    end
    pool = {}
end

function CMD.async(sql)
    --table.insert(queue, sql)

    -- 前期直接写数据库了 sync=false 多个连接一起写也没事 对核心数据没有影响
    CMD.execute(sql, true)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd .. "not found")
        skynet.retpack(f(...))
    end)

    skynet.register(SERVICE_NAME)
end)
