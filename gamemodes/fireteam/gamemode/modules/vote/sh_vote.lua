-- modules/vote/sh_vote.lua
-- FIRETEAM Voting System - Shared
-- 投票队列/选项定义/阈值规则（服务端计票，客户端渲染）

if not Fireteam then Fireteam = {} end
Fireteam.Vote = Fireteam.Vote or {}

-- ═══════════════════════════════════════
-- 投票主题枚举
-- ═══════════════════════════════════════
Fireteam.Vote.TOPIC = {
    SCENARIO = "scenario",   -- 切换剧本
    MODE     = "mode",       -- 切换 PvP/PvE
}

-- ═══════════════════════════════════════
-- 投票状态枚举
-- ═══════════════════════════════════════
Fireteam.Vote.STATE = {
    NONE   = "none",     -- 无投票
    ACTIVE = "active",   -- 投票进行中
}

-- ═══════════════════════════════════════
-- 配置项注册（运行时可调）
-- ═══════════════════════════════════════
Fireteam.Config.Register("vote.threshold", 0.5, {
    type  = "number",
    desc  = "投票通过所需比例（0~1）",
    min   = 0.1,
    max   = 1.0,
})
Fireteam.Config.Register("vote.timeout", 60, {
    type  = "number",
    desc  = "投票持续时间（秒）",
    min   = 15,
    max   = 300,
})
Fireteam.Config.Register("vote.cooldown", 120, {
    type  = "number",
    desc  = "投票冷却时间（秒，防刷票）",
    min   = 0,
    max   = 600,
})

-- ═══════════════════════════════════════
-- 序列化（net 传输辅助）
-- ═══════════════════════════════════════
function Fireteam.Vote.SerializeOptions(options)
    local out = {}
    for _, opt in ipairs(options) do
        table.insert(out, {
            id    = opt.id,
            label = opt.label or opt.id,
        })
    end
    return out
end
