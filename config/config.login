skynetroot = "./skynet/"
thread = 8
logger = nil
logpath = "."
harbor = 0
start = "main"	-- main script
bootstrap = "snlua bootstrap"	-- The service for bootstrap

cluster = "./config/clustername.lua"

log_dirname = "log"
log_basename = "login"

loginservice = "./login_server/?.lua;" ..
			   "./common/?.lua"

luaservice = skynetroot .. "service/?.lua;" .. loginservice
-- snax standard services
snax = loginservice

lualoader = skynetroot .. "lualib/loader.lua"
preload = "./global/preload.lua"	-- run preload.lua before every lua service run

cpath = skynetroot .. "cservice/?.so"

lua_path = skynetroot .. "lualib/?.lua;" ..
		   "./lualib/?.lua;" ..
		   "./global/?.lua"

lua_cpath = skynetroot .. "luaclib/?.so;" .. "./luaclib/?.so"

--daemon = "./login.pid"

port = 8081
endpoint = "127.0.0.1:8081"

clustername = "cluster_login"

mysql_maxconn = 10
mysql_host = "127.0.0.1"
mysql_port = 3306
mysql_db = "gamedb"
mysql_user = "root"
mysql_pwd = "123456"
