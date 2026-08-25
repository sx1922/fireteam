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
-- 剧本选择："" = 按设定包 default_scenario 自动；切换在下一回合简报生效
Fireteam.Config.Register("rounds.scenario", "", {
    type = "string",
    desc = "Scenario override (empty = pack default)"
})

-- ═══════════════════════════════════════
-- 设定包读取
-- ═══════════════════════════════════════

--- 设定包 map_rules.rounds 配置（nil 表示该包无回合内容）
function Fireteam.Rounds.GetPackConfig()
    local rules = Fireteam.Setting.GetData("map_rules")
    return rules and rules.rounds or nil
end

--- 节奏参数（设定包可覆盖，缺省值在此兜底；剧本级 timings 再覆盖一层）
function Fireteam.Rounds.GetTimings()
    local cfg = Fireteam.Rounds.GetPackConfig() or {}
    local scenario = Fireteam.Rounds.ResolveScenario() or {}
    local st = scenario.timings or {}
    -- 注意不能用 ipairs({...})：首参为 nil 时会整表零迭代，未覆盖项将丢失兜底
    local function num(...)
        for i = 1, select("#", ...) do
            local n = tonumber((select(i, ...)))
            if n then return n end
        end
    end
    return {
        warmup       = num(st.warmup, cfg.warmup_time, 30),
        briefing     = num(st.briefing, cfg.briefing_time, 10),
        round_time   = num(st.round_time, cfg.round_time, 600),
        ended        = num(st.ended, cfg.ended_time, 10),
        intermission = num(st.intermission, cfg.intermission_time, 15),
    }
end

--- 总开关：config 运行时开关 ∧ 设定包内容开关
function Fireteam.Rounds.IsEnabled()
    if Fireteam.Config.Get("rounds.enabled") == false then return false end
    local cfg = Fireteam.Rounds.GetPackConfig()
    return cfg ~= nil and cfg.enabled ~= false
end

-- ═══════════════════════════════════════
-- 剧本（scenarios）解析
-- ═══════════════════════════════════════
--- 设定包声明的剧本表 { [id] = { name, name_zh, objectives, spawns, timings? } }
--- 未声明时返回 nil（旧结构走隐式单剧本）
function Fireteam.Rounds.GetScenarioList()
    local cfg = Fireteam.Rounds.GetPackConfig()
    return cfg and istable(cfg.scenarios) and cfg.scenarios or nil
end

--- 当前生效剧本：
--- config rounds.scenario 显式指定 > 包 default_scenario > 第一个剧本；
--- 无 scenarios 表时把旧平铺结构包成隐式单剧本（向后兼容，老包零破坏）
function Fireteam.Rounds.ResolveScenario()
    local cfg = Fireteam.Rounds.GetPackConfig()
    if not cfg then return nil end

    local scenarios = istable(cfg.scenarios) and cfg.scenarios or nil
    if not scenarios then
        return {
            id         = "default",
            name       = "Default",
            name_zh    = "默认",
            objectives = istable(cfg.objectives) and cfg.objectives or {},
            spawns     = istable(cfg.spawns) and cfg.spawns or {},
            timings    = nil,
        }
    end

    local want = Fireteam.Config.Get("rounds.scenario")
    if not (want and want ~= "" and scenarios[want]) then
        want = nil
        if cfg.default_scenario and scenarios[cfg.default_scenario] then
            want = cfg.default_scenario
        else
            want = next(scenarios)   -- pairs 顺序不定，但仅作兜底
        end
    end

    local s = scenarios[want]
    if not istable(s) then return nil end
    return {
        id         = want,
        name       = s.name or want,
        name_zh    = s.name_zh or s.name or want,
        objectives = istable(s.objectives) and s.objectives or {},
        spawns     = istable(s.spawns) and s.spawns or {},
        timings    = istable(s.timings) and s.timings or nil,
    }
end

--- 目标模板列表（当前剧本的）
function Fireteam.Rounds.GetObjectiveTemplates()
    local scenario = Fireteam.Rounds.ResolveScenario()
    return scenario and scenario.objectives or {}
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
