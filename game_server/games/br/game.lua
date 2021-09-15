
local game = {}
local skynet = require "skynet"
local conf = require "config"

local clusterid = tonumber(skynet.getenv("clusterid"))
local config = conf[clusterid]

-- 百人的逻辑都差不多 其实可以写在一起的 如果人少 放在一起没什么关系 人多需要分开的时候方便拆开
-- 游戏初始化
function game.on_init()
    local gamename = config.subrooms[game.super._subroomid].gamename
    local game_hook = require("game_" .. gamename)
    game_hook.super = game.super
    setmetatable(game, { __index = game_hook })

    game_hook.on_init()
end

return game
