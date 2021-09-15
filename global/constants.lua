-- 团队模式 0:无限代理模式 1:俱乐部模式
TEAM_MODE = 1

-- 游戏状态
GAME_STATUS_FREE = 0          -- 空闲状态
GAME_STATUS_PLAY = 100        -- 游戏状态

-- 用户状态
US_NULL = 0     -- 没有状态
US_FREE = 1     -- 站立状态
US_SIT = 2      -- 坐下状态
US_READY = 3    -- 同意状态
US_OB = 4       -- 旁观状态
US_PLAYING = 5  -- 游戏状态
US_OFFLINE = 6  -- 断线状态

-- 开始模式
START_MODE_ALL_READY = 0         -- 所有人准备
START_MODE_FULL_READY = 1        -- 满人开始
START_MODE_TIME_CONTROL = 2      -- 时间控制

-- 消息类型
NMT_CHAT = 0x01         -- 聊天信息
NMT_TOAST = 0x02        -- TOAST
NMT_POPUP = 0x04        -- 弹出消息
NMT_CLOSE_GAME = 0x08   -- 关闭游戏
NMT_CLOSE_ROOM = 0x10   -- 关闭房间
NMT_CLOSE_HALL = 0x20   -- 关闭大厅

-- 网络错误
NERR_NORMAL = 0        -- 正常退出
NERR_INVALID_PACK = 1  -- 无效包
NERR_INVALID_PARAM = 2 -- 无效的参数
NERR_GAME_MSG = 3      -- 游戏处理失败

-- 各种字符串的最大长度
LEN_USERNAME = 32       -- 用户名
LEN_NICKNAME = 32       -- 昵称
LEN_PASSWORD = 24       -- 密码
LEN_MD5 = 32            -- MD5
LEN_SIGNATURE = 64      -- 个性签名
LEN_REALNAME = 16       -- 真实姓名
LEN_EMAIL = 64          --
LEN_ALIPAY_ACCOUNT = 64 -- 支付宝帐号
LEN_BANKCARD_ID = 32    -- 银行卡号
LEN_BANKCARD_ADDR = 128 -- 银行开户行
LEN_PHONE = 11          -- 手机号
LEN_DEVICE = 32         -- 设备名
LEN_UUID = 32           -- 设备标识
LEN_CLUB_NAME = 64      -- 俱乐部名字
LEN_WX = 64             -- 微信
LEN_QQ = 24             -- QQ
LEN_NOTICE = 254        -- 公告
LEN_INVITE_CODE = 8     -- 邀请码