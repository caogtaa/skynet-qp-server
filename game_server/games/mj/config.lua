
-- 麻将的游戏配置 房间配置 机器人配置
return {
    [6002] = {
        -- 游戏种类
        kindid = 3,

        -- 俱乐部id
        clubid = 1,

        -- 房间名字
        room_name = "红中麻将",

        -- 游戏开始模式 0:所有人准备 1:满人开始 2:时间控制
        game_start_mode = 1,

        -- 房间类型 0 金币场 1 私人场
        type = 0,

        -- 房间排序
        sortid = 0,

        -- 房间预创建桌子数
        precreate_table_count = 10,

        -- 房间最大桌子数目
        max_table_count = 60,

        -- 房间最大椅子数
        max_chair_count = 4,

        -- 房间最大人数
        max_player = 300,

        -- 税收比例
        revenue = 0.06,

        -- 房间最小进入分数
        min_enter_score = 0,

        -- 允许游戏中加入
        allow_join_playing = false,

        -- 允许机器人
        allow_robot = false,

        -- 允许旁观
        allow_ob = true,

        -- 获取玩法
        wanfa = function(self, subroomid, subroom_wanfaid)
            return "红中麻将" end,

        -- 子房间配置
        -- 房间等级 对应 初级场 1 中级场 2 高级场 3 土豪场 4 至尊场 5 皇家场 6
        subrooms = {
            [1] = {
                subroomid = 1,
                open = true,    -- 是否开放
                name = "初级场",    -- 名字
                base_score = 100, -- 底分
                min_enter_score = 5000,  -- 准入分数
                max_chair_count = 4,   -- 最大椅子数
                -- 桌子玩法
                -- 牌卓人数 2 4
                -- 牌桌局数 1 2
                -- 扎码数量 1:一码全中 2-6:对应的码数
                -- 特殊规则 可胡七对0x01 做 或 运算
                wanfa = {
                    {
                        item = { 2, 2, 1, 1 },
                    },
                    {
                        item = { 4, 2, 1, 1 },
                    },
                },
            },
            [2] = {
                subroomid = 2,
                open = true,    -- 是否开放
                name = "中级场",    -- 名字
                base_score = 500, -- 底分
                min_enter_score = 20000,  -- 准入分数
                max_chair_count = 4,   -- 最大椅子数
                -- 桌子玩法
                -- 牌卓人数 2 4
                -- 牌桌局数 1 2
                -- 扎码数量 1:一码全中 2-6:对应的码数
                -- 特殊规则 可胡七对0x01 做 或 运算
                wanfa = {
                    {
                        item = { 2, 2, 1, 1 },
                    },
                    {
                        item = { 4, 2, 1, 1 },
                    },
                },
            },
            [3] = {
                subroomid = 3,
                open = true,    -- 是否开放
                name = "高级场",    -- 名字
                base_score = 1000, -- 底分
                min_enter_score = 50000,  -- 准入分数
                max_chair_count = 4,   -- 最大椅子数
                -- 桌子玩法
                -- 牌卓人数 2 4
                -- 牌桌局数 1 2
                -- 扎码数量 1:一码全中 2-6:对应的码数
                -- 特殊规则 可胡七对0x01 做 或 运算
                wanfa = {
                    {
                        item = { 2, 2, 1, 1 },
                    },
                    {
                        item = { 4, 2, 1, 1 },
                    },
                },
            },
            [4] = {
                subroomid = 4,
                open = true,    -- 是否开放
                name = "土豪场",    -- 名字
                base_score = 3000, -- 底分
                min_enter_score = 100000,  -- 准入分数
                max_chair_count = 4,   -- 最大椅子数
                -- 桌子玩法
                -- 牌卓人数 2 4
                -- 牌桌局数 1 2
                -- 扎码数量 1:一码全中 2-6:对应的码数
                -- 特殊规则 可胡七对0x01 做 或 运算
                wanfa = {
                    {
                        item = { 2, 2, 1, 1 },
                    },
                    {
                        item = { 4, 2, 1, 1 },
                    },
                },
            },
            [5] = {
                subroomid = 5,
                open = true,    -- 是否开放
                name = "至尊场",    -- 名字
                base_score = 5000, -- 底分
                min_enter_score = 200000,  -- 准入分数
                max_chair_count = 4,   -- 最大椅子数
                -- 桌子玩法
                -- 牌卓人数 2 4
                -- 牌桌局数 1 2
                -- 扎码数量 1:一码全中 2-6:对应的码数
                -- 特殊规则 可胡七对0x01 做 或 运算
                wanfa = {
                    {
                        item = { 2, 2, 1, 1 },
                    },
                    {
                        item = { 4, 2, 1, 1 },
                    },
                },
            },
            [6] = {
                subroomid = 6,
                open = false,    -- 是否开放
                name = "皇家场",    -- 名字
                base_score = 500, -- 底分
                min_enter_score = 200000,  -- 准入分数
                max_chair_count = 4,   -- 最大椅子数
                -- 桌子玩法
                -- 牌卓人数 2 4
                -- 牌桌局数 1 2
                -- 扎码数量 1:一码全中 2-6:对应的码数
                -- 特殊规则 可胡七对0x01 做 或 运算
                wanfa = {
                    {
                        item = { 2, 2, 1, 1 },
                    },
                    {
                        item = { 4, 2, 1, 1 },
                    },
                },
            },
        },
    }
}
