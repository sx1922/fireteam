-- modules/ai/sh_ai.lua
-- FIRETEAM AI Teammate - Shared Definitions
-- 接口级 AI 队友框架：NextBot 补位、跟随/驻守姿态、路点指令。
-- 战斗行为保持最简（索敌→站桩交火），深度战术 AI 留给后续扩展。

if not Fireteam then Fireteam = {} end
Fireteam.AI = Fireteam.AI or {}

-- ═══════════════════════════════════════
-- 配置
-- ═══════════════════════════════════════
Fireteam.Config.Register("ai.enabled", true, {
    type = "boolean", desc = "AI 队友总开关（接口级框架）"
})
Fireteam.Config.Register("ai.max_per_player", 2, {
    type = "number", min = 0, max = 8,
    desc = "每名玩家最多可部署的 AI 队友数"
})
Fireteam.Config.Register("ai.health", 100, {
    type = "number", min = 1, max = 500, desc = "AI 队友生命值"
})
Fireteam.Config.Register("ai.acquire_range", 1200, {
    type = "number", min = 200, max = 6000, desc = "AI 索敌范围（世界单位）"
})
Fireteam.Config.Register("ai.attack_damage", 8, {
    type = "number", min = 0, max = 100, desc = "AI 开火单发伤害"
})
Fireteam.Config.Register("ai.follow_distance", 150, {
    type = "number", min = 60, max = 800, desc = "跟随姿态下与主人的保持距离"
})
Fireteam.Config.Register("ai.autofill_size", 0, {
    type = "number", min = 0, max = 6,
    desc = "回合开始时自动补位目标人数（0=关闭；按小队人数补到该值）"
})

-- ═══════════════════════════════════════
-- 姿态
-- ═══════════════════════════════════════
Fireteam.AI.STANCE = {
    FOLLOW = "follow",   -- 跟随主人
    HOLD   = "hold",     -- 原地驻守
    GOTO   = "goto"      -- 向路点移动（到达后回到先前姿态）
}

--- 姿态显示名（locale 键 stance_<name>）
function Fireteam.AI.StanceLabel(stance)
    return Fireteam.Locale.Get("stance_" .. tostring(stance))
end

-- 模型池（HL2 内容恒定挂载，零外部依赖）
Fireteam.AI.MODELS = {
    "models/player/group01/male_02.mdl",
    "models/player/group01/male_04.mdl",
    "models/player/group01/male_07.mdl",
    "models/player/group03/male_05.mdl",
}

--- 取某玩家的阵营（rounds 优先，退回小队字段）
function Fireteam.AI.GetPlayerFaction(ply)
    if not IsValid(ply) then return nil end
    if Fireteam.Rounds and Fireteam.Rounds.GetPlayerFaction then
        local f = Fireteam.Rounds.GetPlayerFaction(ply)
        if f then return f end
    end
    local squad = Fireteam.Squad and Fireteam.Squad.GetPlayerSquad(ply)
    return squad and squad.faction or nil
end

print("[FIRETEAM:AI] ✓ Shared definitions loaded")
