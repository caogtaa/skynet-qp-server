--[[
    {
        -- 多张表模式 此模式的sql语句需要这样写select * from tbname%d;
        multi_tb_mode = true,
        -- 表名
        tbname = "user_account_info",
        -- 查询语句
        sql = "select * from tbname;",
        -- 存储格式数组
        stoarge = {
            {
                -- redis存储类型 对应的有string hash set zset list
                type = "hash",
                -- 主键 当type=set or zset的时候可以为nil 为nil的时候直接以表名作为key
                -- 也可以是多个主键
                pk = "userid" or { "kindid", "roomid" },
                -- value 在只有type!=hash的时候使用
                value = "name",
                -- value_json sql的记录集转为json
                value_json = true or false,
                -- score 在type=zset的时候使用
                score = "datetime",
                -- score_datetime=true的时候表示需要转为时间戳
                score_datetime = true or false

                -- 具体的存储形式 ?pk代表具体的pk值 比如pk="userid" userid=1 tbname:userid:1
                string set(tbname:pk:?pk, value or value_json)
                hash: hmset(tbname:pk:?pk, sql查询到的fields values)
                set: sadd(tbname:pk:?pk, value or value_json)
                zset: zadd(tbname:pk:?pk, score, value or value_json)
            }
        },
        -- 唯一标识 用于自增记录 redis string
        autoincrement = { key = "tbname:__id", value = "select max(id) as value from tbname;" }
        -- 是否用set保存主键 主要用于遍历主键
        savepk = { "userid" }
    }
]]
return {
    {
        -- 俱乐部信息
        tbname = "club_info",
        sql = "select * from club_info;",
        stoarge = {
            -- club_info:clubid:?clubid fields values见数据库字段
            {
                type = "hash",
                pk = "clubid",
            },
        },
        savepk = { "name", "clubid" },
        autoincrement = { key = "club_info:__id", value = "select max(clubid) as value from club_info;" }
    },
    --[[这个单独配置
        分为2个
        1: config_club_invite_code:invite_code:?invite_code fields
        2: config_club_invite_code list "id,invite_code"
    {
        -- 俱乐部邀请码配置
        tbname = "config_club_invite_code",
        sql = "select * from config_club_invite_code order by id asc;",
        stoarge = {
            -- config_club_invite_code list value
            {
                type = "list",
                value = {"id", "invite_code"},
            }
        }
    },
    ]]
    {
        -- 账户变更类型配置
        tbname = "config_change_score",
        sql = "select * from config_change_score;",
        stoarge = {
            -- config_change_score:cname:?c_name fields values见数据库字段
            {
                type = "hash",
                pk = "c_name",
            }
        }
    },
    {
        -- 游戏列表
        tbname = "config_game_kind_list",
        sql = "select kindid,typeid,sortid,kind_name from config_game_kind_list where disabled=0;",
        stoarge = {
            -- config_game_kind_list fields_values_json集合
            {
                type = "set",
                value_json = true
            }
        }
    },
    {
        -- 游戏类型列表
        tbname = "config_game_type_list",
        sql = "select typeid,sortid,type_name from config_game_type_list where disabled=0;",
        stoarge = {
            -- config_game_type_list fields_values_json集合
            {
                type = "set",
                value_json = true
            }
        }
    },
    {
        -- 机器人规则配置
        tbname = "config_game_robot_rule",
        sql = "select * from config_game_robot_rule;",
        stoarge = {
            -- config_game_robot_rule:kindid?kindid:roomid:?roomid fields_values_json key-value
            {
                type = "string",
                pk = {"kindid", "roomid"},
                value_json = true
            }
        },
        autoincrement = { key = "config_game_robot_rule:__id", value = "select max(id) as value from config_game_robot_rule;" }
    },
    {
        -- 全局配置
        tbname = "config_global",
        sql = "select c_name, c_value, c_string from config_global;",
        stoarge = {
            -- config_global:c_name:?c_name fields values见数据库字段
            {
                type = "hash",
                pk = "c_name",
            }
        }
    },
    {
        -- 游戏ID配置
        tbname = "config_gameids",
        sql = "select * from config_gameids order by userid asc;",
        stoarge = {
            -- config_gameids list[index - 1] = value
            {
                type = "list",
                index = "userid",
                value = "gameid",
            }
        }
    },
    {
        -- 商店和提现的配置
        tbname = "config_shop_exchange",
        sql = "select * from config_shop_exchange;",
        stoarge = {
            -- config_shop_exchange config_shop_exchange:type:?type content key-value
            {
                type = "string",
                pk = "type",
                value = "content"
            }
        }
    },

    {
        -- 用户账号信息
        tbname = "user_account_info",
        sql = "select * from user_account_info",
        stoarge = {
            -- user_account_info:userid:?userid fields values见数据库字段
            {
                type = "hash",
                pk = "userid",
            },
            -- user_account_info:username:?username userid
            {
                type = "string",
                pk = "username",
                value = "userid"
            },
            -- user_account_info:mobilephone:?mobilephone userid
            {
                type = "string",
                pk = "mobilephone",
                value = "userid"
            },
            -- user_account_info:gameid:?gameid userid
            {
                type = "string",
                pk = "gameid",
                value = "userid"
            },
            -- user_account_info:alipay_account:?alipay_account userid
            {
                type = "string",
                pk = "alipay_account",
                value = "userid"
            },
            -- user_account_info:bankcard_id:?bankcard_id userid
            {
                type = "string",
                pk = "bankcard_id",
                value = "userid"
            }
        },
        autoincrement = { key = "__userid", value = "select max(userid) as value from user_account_info;" },
        -- user_account_info:userid 所有userid的集合
        savepk = { "userid" }
    },
    {
        -- 用户游戏信息
        tbname = "user_game_info",
        sql = "select * from user_game_info",
        stoarge = {
            -- user_game_info:userid:?userid fields values见数据库字段
            {
                type = "hash",
                pk = "userid",
            }
        }
    },
    {
        -- 用户团队信息
        tbname = "user_team_info%d",
        multi_tb_mode = true,
        sql = "select * from user_team_info%d",
        stoarge = {
            -- user_team_info:userid:?userid fields values见数据库字段
            {
                type = "hash",
                pk = "userid",
            }
        }
    },
    {
        -- 用户绑定的上下级信息
        tbname = "user_team_bind_info%d",
        multi_tb_mode = true,
        sql = "select * from user_team_bind_info%d",
        stoarge = {
            -- user_team_bind_info:userid:?userid fields values见数据库字段
            {
                type = "hash",
                pk = "userid",
            }
        },
        -- user_team_bind_info%d:userid 所有userid的集合
        savepk = { "userid" }
    },
    {
        -- 用户邮件
        tbname = "user_message",
        sql = "select * from user_message where readed < 2",
        stoarge = {
            -- user_message:userid:?userid score(id) fields_values_json集合
            {
                type = "zset",
                pk = "userid",
                score = "id",
                value_json = true
            }
        },
        autoincrement = { key = "user_message:__id", value = "select max(id) as value from user_message;" }
    },

    {
        -- 分数变更记录
        tbname = "log_change_score",
        sql = "select * from log_change_score where change_date >= date_sub(curdate(), interval 3 day) order by id asc",
        stoarge = {
            -- log_change_score:userid:?userid score(change_date) fields_values_json集合
            {
                type = "zset",
                pk = "userid",
                score = "change_date",
                score_datetime = true,
                value_json = true,
            }
        },
        autoincrement = { key = "log_change_score:__id", value = "select max(id) as value from log_change_score" },
    },
    {
        -- 提现记录
        tbname = "log_exchange",
        sql = "select * from log_exchange where insert_date >= date_sub(curdate(), interval 30 day) order by id asc",
        stoarge = {
            -- log_exchange:userid:?userid score(insert_date) fields_values_json集合
            {
                type = "zset",
                pk = "userid",
                score = "insert_date",
                score_datetime = true,
                value_json = true,
            },
            -- log_exchange:userid:?userid:id:?id fields_values_json
            -- 这个主要用于更新兑换的状态 当兑换状态更新的时候 先获取到记录的json字符串 然后del(log_exchange:userid:?userid:id:?id)和
            -- zrem(log_exchange:userid:?userid, fields_values_json) 最后更新完状态后zadd(log_exchange:userid:?userid, fields_values_json)
            {
                type = "string",
                pk = {"userid", "id"},
                value_json = true,
            }
        },
        autoincrement = { key = "log_exchange:__id", value = "select max(id) as value from log_exchange" },
    },
    {
        -- 游戏记录日志
        tbname = "log_game_record",
        sql = "select * from log_game_record where game_end_date >= date_sub(curdate(), interval 3 day);",
        stoarge = {
            -- log_game_record score(drawid) fields_values_json集合
            -- drawid是带时间属性的 所以可以通过drawid来删除和查找记录
            {
                type = "zset",
                score = "drawid",
                score_drawid = true,
                value_json = true,
            }
        },
    },
    {
        -- 游戏记录详细日志
        tbname = "log_game_record_detail",
        sql = "select * from log_game_record_detail where insert_date >= date_sub(curdate(), interval 3 day) order by id asc;",
        stoarge = {
            -- log_game_record_detail:userid:?userid score(drawid) fields_values_json集合
            -- drawid是带时间属性的 所以可以通过drawid来删除和查找记录
            -- 同时在同一桌游戏的玩家具有相同的drawid 所以通过ZRANGEBYSCORE(key,drawid,drawid)得到同桌玩家的对局记录
            {
                type = "zset",
                pk = "userid",
                score = "drawid",
                score_drawid = true,
                value_json = true,
            },
        },
        autoincrement = { key = "log_game_record_detail:__id", value = "select max(id) as value from log_game_record_detail" },
        savepk = { "userid" }
    },
    {
        -- 充值记录
        tbname = "log_recharge",
        sql = "select * from log_recharge where insert_date >= date_sub(curdate(), interval 30 day) order by id asc",
        stoarge = {
            -- log_recharge:userid:?userid score(insert_date) fields_values_json集合
            {
                type = "zset",
                pk = "userid",
                score = "insert_date",
                score_datetime = true,
                value_json = true,
            },
            -- log_recharge:userid:?userid:id:?id fields_values_json
            -- 这个主要用于更新充值的状态 当充值状态更新的时候(比如第3方回调) 先获取到记录的json字符串 然后del(log_recharge:userid:?userid:id:?id)和
            -- zrem(log_recharge:userid:?userid, fields_values_json) 最后更新完状态后zadd(log_recharge:userid:?userid, fields_values_json)
            {
                type = "string",
                pk = {"userid", "id"},
                value_json = true,
            }
        },
        autoincrement = { key = "log_recharge:__id", value = "select max(id) as value from log_recharge" },
    },
    {
        -- 团队每天的报表记录
        tbname = "log_team_day_report%d",
        multi_tb_mode = true,
        -- TODO:这里的查询改为查2个月的
        sql = "select * from log_team_day_report%d where create_date >= date_sub(curdate(), interval 62 day) order by id asc",
        stoarge = {
            -- log_team_day_report(clubid):userid:?userid score(create_date) fields_values_json集合
            {
                type = "zset",
                pk = "userid",
                score = "create_date",
                score_datetime = true,
                value_json = true,
            },
            -- log_team_day_report(clubid):id:?id fields values见数据库字段
            {
                type = "hash",
                pk = "id",
            }
        },
        autoincrement = { key = "log_team_day_report%d:__id", value = "select max(id) as value from log_team_day_report%d" },
    },
    {
        -- 团队转账记录
        tbname = "log_team_transfer%d",
        multi_tb_mode = true,
        -- TODO:这里的查询改为查3个月的
        sql = "select * from log_team_transfer%d where insert_date >= date_sub(curdate(), interval 93 day) order by id asc",
        stoarge = {
            -- log_team_transfer(clubid):userid:?userid score(insert_date) fields_values_json集合
            {
                type = "zset",
                pk = "userid",
                score = "insert_date",
                score_datetime = true,
                value_json = true,
            },
            -- log_team_transfer(clubid):userid:?userid:id:?id fields_values_json
            -- 这个主要用于更新兑换的状态 当兑换状态更新的时候 先获取到记录的json字符串 然后del(log_team_transfer(clubid):userid:?userid:id:?id)和
            -- zrem(log_team_transfer(clubid):userid:?userid, fields_values_json) 最后更新完状态后zadd(log_team_transfer(clubid):userid:?userid, fields_values_json)
            {
                type = "string",
                pk = {"userid", "id"},
                value_json = true,
            }
        },
        autoincrement = { key = "log_team_transfer%d:__id", value = "select max(id) as value from log_team_transfer%d" },
    },
    {
        -- 用户进出房间的记录
        tbname = "log_user_inout",
        sql = "select * from log_user_inout where enter_date >= date_sub(curdate(), interval 3 day) order by id asc",
        stoarge = {
            -- log_user_inout:userid:?userid score(enter_date) fields_values_json集合
            {
                type = "zset",
                pk = "userid",
                score = "enter_date",
                score_datetime = true,
                value_json = true,
            },
            -- log_user_inout:userid:?userid:id:?id fields_values_json
            -- 这个主要用于更新进出的状态 当进出状态更新的时候(比如退出房间) 先获取到记录的json字符串 然后del(log_user_inout:userid:?userid:id:?id)和
            -- zrem(log_user_inout:userid:?userid, fields_values_json) 最后更新完状态后zadd(log_user_inout:userid:?userid, fields_values_json)
            {
                type = "string",
                pk = {"userid", "id"},
                value_json = true,
            }
        },
        autoincrement = { key = "log_user_inout:__id", value = "select max(id) as value from log_user_inout" },
    },
}
