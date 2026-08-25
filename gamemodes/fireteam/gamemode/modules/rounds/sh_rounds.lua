-- modules/rounds/sh_rounds.lua
-- FIRETEAM Rounds Framework - Shared（模块入口）
-- 回合状态机 WARMUP→BRIEFING→ACTIVE→ENDED→INTERMISSION + 目标接口 + 计分引擎。
-- 具体任务内容来自设定包 map_rules.rounds（决策 D3：框架只管流程，内容归数据）。

if not Fireteam then Fireteam = {} end
Fireteam.Rounds = Fireteam.Rounds or {}

-- 子文件手动 include（决策 D5）；include() 基准目录随加载上下文变化，故双路兜底
local function IncludeSub(fileName)
    local ok = pcall(include, "modules/rounds/" .. fileName)
    if not ok then
        local contents = file.Read("gamemodes/fireteam/gamemode/modules/rounds/" .. fileName, "GAME")
        if contents then CompileString(contents, fileName)() end
    end
end
IncludeSub("sh_objectives.lua")

-- ═══════════════════════════════════════
-- 状态枚举
-- ═══════════════════════════════════════
Fireteam.Rounds.STATE = {
    IDLE         = "idle",         -- 未启用（无设定包数据或总开关关闭）
    WARMUP       = "warmup",       -- 自由热身，可随意出生
    BRIEFING     = "briefing",     -- 任务简报，冻结待命
    ACTIVE       = "active",       -- 回合进行中，阵亡等待下回合
    ENDED        = "ended",        -- 结算屏展示中
    INTERMISSION = "intermission"  -- 幕间休整，随后进入下一回合简报
}

-- 配置项（运行时总开关；节奏参数由设定包驱动）
Fireteam.Config.Register("rounds.enabled", true, {
    type = "boolean",
    desc = "Master switch for the round system"
})

-- ═══════════════════════════════════════
-- 设定包读取
-- ═══════════════════════════════════════

--- 设定包 map_rules.rounds 配置（nil 表示该包无回合内容）
function Fireteam.Rounds.GetPackConfig()
    local rules = Fireteam.Setting.GetData("map_rules")
    return rules and rules.rounds or nil
end

--- 节奏参数（设定包可覆盖，缺省值在此兜底）
function Fireteam.Rounds.GetTimings()
    local cfg = Fireteam.Rounds.GetPackConfig() or {}
    return {
        warmup       = tonumber(cfg.warmup_time) or 30,
        briefing     = tonumber(cfg.briefing_time) or 10,
        round_time   = tonumber(cfg.round_time) or 600,
        ended        = tonumber(cfg.ended_time) or 10,
        intermission = tonumber(cfg.intermission_time) or 15,
    }
end

--- 总开关：config 运行时开关 ∧ 设定包内容开关
function Fireteam.Rounds.IsEnabled()
    if Fireteam.Config.Get("rounds.enabled") == false then return false end
    local cfg = Fireteam.Rounds.GetPackConfig()
    return cfg ~= nil and cfg.enabled ~= false
end

--- 目标模板列表
function Fireteam.Rounds.GetObjectiveTemplates()
    local cfg = Fireteam.Rounds.GetPackConfig()
    return cfg and istable(cfg.objectives) and cfg.objectives or {}
end

-- ═══════════════════════════════════════
-- 阵营工具
-- ═══════════════════════════════════════

--- 玩家阵营：跟随其小队的 faction；无小队返回 nil
function Fireteam.Rounds.GetPlayerFaction(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return nil end
    local squad = Fireteam.Squad.GetPlayerSquad and Fireteam.Squad.GetPlayerSquad(ply)
    return squad and squad.faction or nil
end

--- 本局参战阵营列表（有存活/在场玩家的 factions）
function Fireteam.Rounds.GetActiveFactions()
    local set = {}
    for _, ply in ipairs(player.GetAll()) do
        local f = Fireteam.Rounds.GetPlayerFaction(ply)
        if f then set[f] = true end
    end
    local out = {}
    for f in pairs(set) do out[#out + 1] = f end
    table.sort(out)
    return out
end

print("[FIRETEAM:Rounds] ✓ Shared definitions loaded")
