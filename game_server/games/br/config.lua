
-- 百人游戏的游戏配置 房间配置 机器人配置
return {
    [6001] = {
        -- 游戏种类
        kindid = 2000,

        -- 俱乐部id
        clubid = 1,

        -- 房间名字
        room_name = "百人游戏",

        -- 游戏开始模式 0:所有人准备 1:满人开始 2:时间控制
        game_start_mode = 2,

        -- 房间类型 0 金币场 1 私人场
        type = 0,

        -- 房间排序
        sortid = 0,

        -- 房间预创建桌子数
        precreate_table_count = 10,

        -- 房间最大桌子数目
        max_table_count = 100,

        -- 房间最大椅子数
        max_chair_count = 1000,

        -- 房间最大人数
        max_player = 1000,

        -- 税收比例
        revenue = 0.06,

        -- 房间最小进入分数
        min_enter_score = 0,

        -- 允许游戏中加入
        allow_join_playing = true,

        -- 允许机器人
        allow_robot = true,

        -- 允许旁观
        allow_ob = false,

        -- 获取玩法
        wanfa = function(self, subroomid, subroom_wanfaid)
            local name = self.subrooms[subroomid].name 
            return (self.subrooms[subroomid].wanfa[subroom_wanfaid].item[1] == 0) and name or name .. "拼庄"
        end,

        -- 子房间配置
        subrooms = {
            [1] = {
                subroomid = 1,
                open = true,    -- 是否开放
                name = "百人龙虎",    -- 名字
                gamename = "lhd",
                base_score = 1, -- 底分
                min_enter_score = 0,  -- 准入分数
                max_chair_count = 1000,   -- 最大椅子数
                user_bet_limit = 50000000,  -- 用户下注限制
                area_bet_limit = 50000000,  -- 区域下注限制
                banker_condition = 500000,  -- 上庄条件
                downbanker_condition = 250000,  -- 下庄条件
                enable_sys_banker = true,   -- 允许系统坐庄
                sys_banker_score = 100000000,   -- 系统做庄分数
                enable_robot_banker = true, -- 允许机器人坐庄
                bet_condition = 5000,  -- 下注条件
                -- 桌子玩法
                -- 是否拼庄 0或者1 下注需要 上庄需要
                wanfa = {
                    {
                        item = { 0, 5000, 500000 },
                    },
                    {
                        item = { 1, 5000, 500000 },
                    },
                },

                robotconf = {
                    bet_times = { 5, 10 },
                    bet_score = { 100, 100000 },
                },
            },
            [2] = {
                subroomid = 2,
                open = false,    -- 是否开放
                name = "百人牛牛",    -- 名字
                gamename = "brnn",
                base_score = 1, -- 底分
                min_enter_score = 0,  -- 准入分数
                max_chair_count = 1000,   -- 最大椅子数
                user_bet_limit = 50000000,  -- 用户下注限制
                area_bet_limit = 50000000,  -- 区域下注限制
                banker_condition = 500000,  -- 上庄条件
                downbanker_condition = 250000,  -- 下庄条件
                enable_sys_banker = true,   -- 允许系统坐庄
                sys_banker_score = 100000000,   -- 系统做庄分数
                enable_robot_banker = true, -- 允许机器人坐庄
                bet_condition = 5000,  -- 下注条件
                -- 桌子玩法
                -- 是否拼庄 0或者1 下注需要 上庄需要
                wanfa = {
                    {
                        item = { 0, 5000, 500000 },
                    },
                    {
                        item = { 1, 5000, 500000 },
                    },
                },
            },
            [3] = {
                subroomid = 3,
                open = false,    -- 是否开放
                name = "百人炸金花",    -- 名字
                gamename = "hhdz",
                base_score = 1, -- 底分
                min_enter_score = 0,  -- 准入分数
                max_chair_count = 1000,   -- 最大椅子数
                user_bet_limit = 50000000,  -- 用户下注限制
                area_bet_limit = 50000000,  -- 区域下注限制
                banker_condition = 500000,  -- 上庄条件
                downbanker_condition = 250000,  -- 下庄条件
                enable_sys_banker = true,   -- 允许系统坐庄
                sys_banker_score = 100000000,   -- 系统做庄分数
                enable_robot_banker = true, -- 允许机器人坐庄
                bet_condition = 5000,  -- 下注条件
                -- 桌子玩法
                -- 是否拼庄 0或者1 下注需要 上庄需要
                wanfa = {
                    {
                        item = { 0, 5000, 500000 },
                    },
                    {
                        item = { 1, 5000, 500000 },
                    },
                },
            },
            [4] = {
                subroomid = 4,
                open = false,    -- 是否开放
                name = "百家乐",    -- 名字
                gamename = "bjl",
                base_score = 1, -- 底分
                min_enter_score = 0,  -- 准入分数
                max_chair_count = 1000,   -- 最大椅子数
                user_bet_limit = 50000000,  -- 用户下注限制
                area_bet_limit = 50000000,  -- 区域下注限制
                banker_condition = 500000,  -- 上庄条件
                downbanker_condition = 250000,  -- 下庄条件
                enable_sys_banker = true,   -- 允许系统坐庄
                sys_banker_score = 100000000,   -- 系统做庄分数
                enable_robot_banker = true, -- 允许机器人坐庄
                bet_condition = 5000,  -- 下注条件
                -- 桌子玩法
                -- 是否拼庄 0或者1 下注需要 上庄需要
                wanfa = {
                    {
                        item = { 0, 5000, 500000 },
                    },
                    {
                        item = { 1, 5000, 500000 },
                    },
                },
            },
            [5] = {
                subroomid = 5,
                open = false,    -- 是否开放
                name = "百人斗神兽",    -- 名字
                gamename = "brdss",
                base_score = 1, -- 底分
                min_enter_score = 0,  -- 准入分数
                max_chair_count = 1000,   -- 最大椅子数
                user_bet_limit = 50000000,  -- 用户下注限制
                area_bet_limit = 50000000,  -- 区域下注限制
                banker_condition = 500000,  -- 上庄条件
                downbanker_condition = 250000,  -- 下庄条件
                enable_sys_banker = true,   -- 允许系统坐庄
                sys_banker_score = 100000000,   -- 系统做庄分数
                enable_robot_banker = true, -- 允许机器人坐庄
                bet_condition = 5000,  -- 下注条件
                -- 桌子玩法
                -- 是否拼庄 0或者1 下注需要 上庄需要
                wanfa = {
                    {
                        item = { 0, 5000, 500000 },
                    },
                    {
                        item = { 1, 5000, 500000 },
                    },
                },
            },
            [6] = {
                subroomid = 6,
                open = false,    -- 是否开放
                name = "奔驰宝马",    -- 名字
                gamename = "bcbm",
                base_score = 1, -- 底分
                min_enter_score = 0,  -- 准入分数
                max_chair_count = 1000,   -- 最大椅子数
                user_bet_limit = 50000000,  -- 用户下注限制
                area_bet_limit = 50000000,  -- 区域下注限制
                banker_condition = 500000,  -- 上庄条件
                downbanker_condition = 250000,  -- 下庄条件
                enable_sys_banker = true,   -- 允许系统坐庄
                sys_banker_score = 100000000,   -- 系统做庄分数
                enable_robot_banker = true, -- 允许机器人坐庄
                bet_condition = 5000,  -- 下注条件
                -- 桌子玩法
                -- 是否拼庄 0或者1 下注需要 上庄需要
                wanfa = {
                    {
                        item = { 0, 5000, 500000 },
                    },
                    {
                        item = { 1, 5000, 500000 },
                    },
                },
            },
        },
    }
}
