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

-- 对战模式：pvp 全员玩家对峙；pve 由设定包 pve 配置生成 AI 阵营
-- options 枚举使 F10 配置页自动渲染下拉框
Fireteam.Config.Register("rounds.mode", "pvp", {
    type    = "string",
    options = { "pvp", "pve" },
    desc    = "PvP or PvE campaign mode"
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
-- 剧本（scenarios）解析与运行时扩展 API
-- 设定包数据保持只读：第三方用 RegisterScenario 注册全新剧本，
-- 或经 Add*/Remove*/Set* 系列在「扩展层」定制既有剧本；
-- 解析时按 基础(自定义>设定包>隐式单剧本) ← 扩展层 合成出新表，
-- 重载设定包或调用 ClearScenarioExtensions 即全部还原。
-- ═══════════════════════════════════════

Fireteam.Rounds.CustomScenarios = {}      -- [id] = 完整剧本表（RegisterScenario 写入）
Fireteam.Rounds.ScenarioExtensions = {}   -- [id] = { objectives, removed, spawns, timings, vitals, pve }

local function ExtFor(id)
    local ext = Fireteam.Rounds.ScenarioExtensions[id]
    if not ext then
        ext = { objectives = {}, removed = {}, spawns = {}, timings = {}, vitals = {}, pve = {} }
        Fireteam.Rounds.ScenarioExtensions[id] = ext
    end
    return ext
end

--- 浅合并 a←b；两者皆空返回 nil
local function MergeShallow(a, b)
    if not istable(a) and not istable(b) then return nil end
    local out = {}
    if istable(a) then for k, v in pairs(a) do out[k] = v end end
    if istable(b) then for k, v in pairs(b) do out[k] = v end end
    return next(out) and out or nil
end

--- 合成单个剧本（含扩展层叠加）。总是返回新表，绝不回改数据源。
function Fireteam.Rounds.GetScenario(id)
    local cfg = Fireteam.Rounds.GetPackConfig()

    local base
    if istable(Fireteam.Rounds.CustomScenarios[id]) then
        base = Fireteam.Rounds.CustomScenarios[id]
    elseif cfg and istable(cfg.scenarios) then
        base = istable(cfg.scenarios[id]) and cfg.scenarios[id] or nil
    elseif cfg and not istable(cfg.scenarios) and id == "default" then
        -- 旧平铺结构的隐式单剧本（向后兼容，老包零破坏）
        base = {
            name       = "Default",
            name_zh    = "默认",
            objectives = istable(cfg.objectives) and cfg.objectives or {},
            spawns     = istable(cfg.spawns) and cfg.spawns or {},
        }
    end
    if not istable(base) then return nil end

    local ext = istable(Fireteam.Rounds.ScenarioExtensions[id])
        and Fireteam.Rounds.ScenarioExtensions[id] or nil

    -- 目标：base 浅拷贝 → 剔除 removed（按 objective.name 匹配）→ 追加扩展目标
    local objectives = {}
    for _, o in ipairs(istable(base.objectives) and base.objectives or {}) do
        objectives[#objectives + 1] = o
    end
    if ext then
        for i = #objectives, 1, -1 do
            if ext.removed[objectives[i].name] then table.remove(objectives, i) end
        end
        for _, o in ipairs(ext.objectives) do objectives[#objectives + 1] = o end
    end

    -- 出生点：按阵营拼接数组
    local spawns = {}
    for faction, arr in pairs(istable(base.spawns) and base.spawns or {}) do
        spawns[faction] = {}
        for _, s in ipairs(arr) do spawns[faction][#spawns[faction] + 1] = s end
    end
    if ext then
        for faction, arr in pairs(ext.spawns) do
            spawns[faction] = spawns[faction] or {}
            for _, s in ipairs(arr) do spawns[faction][#spawns[faction] + 1] = s end
        end
    end

    return {
        id         = id,
        name       = base.name or id,
        name_zh    = base.name_zh or base.name or id,
        objectives = objectives,
        spawns     = spawns,
        timings    = MergeShallow(base.timings, ext and ext.timings),
        vitals     = MergeShallow(base.vitals, ext and ext.vitals),
        pve        = MergeShallow(base.pve, ext and ext.pve),
    }
end

--- 可选剧本总表：设定包 scenarios ∪ 自定义注册剧本（同 id 时自定义覆盖）
--- 全空返回 nil（调用方据此走隐式单剧本）
function Fireteam.Rounds.GetScenarioList()
    local out = {}
    local cfg = Fireteam.Rounds.GetPackConfig()
    if cfg and istable(cfg.scenarios) then
        for sid, data in pairs(cfg.scenarios) do out[sid] = data end
    end
    for sid, data in pairs(Fireteam.Rounds.CustomScenarios) do out[sid] = data end
    return next(out) and out or nil
end

--- 当前生效剧本：config rounds.scenario 显式指定 > 包 default_scenario > 任一可用
function Fireteam.Rounds.ResolveScenario()
    local cfg = Fireteam.Rounds.GetPackConfig()
    if not cfg then return nil end

    local list = Fireteam.Rounds.GetScenarioList()
    if not list then
        return Fireteam.Rounds.GetScenario("default")   -- 隐式单剧本（可被扩展层定制）
    end

    local want = Fireteam.Config.Get("rounds.scenario")
    if not (want and want ~= "" and list[want]) then
        if cfg.default_scenario and list[cfg.default_scenario] then
            want = cfg.default_scenario
        else
            want = next(list)   -- pairs 顺序不定，仅作兜底
        end
    end
    return Fireteam.Rounds.GetScenario(want)
end

-- ─────────────────────────────────────
-- 第三方扩展入口（用法见 README「剧本扩展 API」）
-- ─────────────────────────────────────

--- 注册/替换一个完整剧本；id 与内置冲突时覆盖内置。data 由框架引用，注册后勿再原地修改。
function Fireteam.Rounds.RegisterScenario(id, data)
    if not isstring(id) or not istable(data) then return false end
    Fireteam.Rounds.CustomScenarios[id] = data
    return true
end

function Fireteam.Rounds.UnregisterScenario(id)
    local existed = Fireteam.Rounds.CustomScenarios[id] ~= nil
    Fireteam.Rounds.CustomScenarios[id] = nil
    return existed
end

--- 追加一个目标模板到剧本末尾（type 须为 RegisterObjective 已注册类型）
function Fireteam.Rounds.AddScenarioObjective(scenarioId, objectiveDef)
    if not istable(objectiveDef) then return false end
    table.insert(ExtFor(tostring(scenarioId)).objectives, objectiveDef)
    return true
end

--- 按 objective.name 从剧本剔除一个目标（不动设定包文件）
function Fireteam.Rounds.RemoveScenarioObjective(scenarioId, objectiveName)
    ExtFor(tostring(scenarioId)).removed[tostring(objectiveName)] = true
    return true
end

--- 给某阵营追加出生点条目（结构同 map_rules.spawns：{ pos = {...} }）
function Fireteam.Rounds.AddScenarioSpawn(scenarioId, factionId, spawnEntry)
    if not istable(spawnEntry) then return false end
    local ext = ExtFor(tostring(scenarioId))
    ext.spawns[tostring(factionId)] = ext.spawns[tostring(factionId)] or {}
    table.insert(ext.spawns[tostring(factionId)], spawnEntry)
    return true
end

--- 覆盖节奏参数（warmup/briefing/round_time/ended/intermission，浅合并）
function Fireteam.Rounds.SetScenarioTimings(scenarioId, timings)
    if not istable(timings) then return false end
    local ext = ExtFor(tostring(scenarioId))
    for k, v in pairs(timings) do ext.timings[k] = v end
    return true
end

--- 覆盖体征参数（vitals 三级解析的最上层，如 { bleedout_time = 30 }）
function Fireteam.Rounds.OverrideScenarioVitals(scenarioId, params)
    if not istable(params) then return false end
    local ext = ExtFor(tostring(scenarioId))
    for k, v in pairs(params) do ext.vitals[k] = v end
    return true
end

--- 覆盖 PvE 战役配置（player_factions/ai_factions/ai_behavior/bots_per_faction）
function Fireteam.Rounds.SetScenarioPvE(scenarioId, pve)
    if not istable(pve) then return false end
    local ext = ExtFor(tostring(scenarioId))
    for k, v in pairs(pve) do ext.pve[k] = v end
    return true
end

--- 清空全部自定义剧本与运行时扩展（恢复设定包原样）
function Fireteam.Rounds.ClearScenarioExtensions()
    Fireteam.Rounds.CustomScenarios = {}
    Fireteam.Rounds.ScenarioExtensions = {}
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

--- 本局参战阵营列表（有存活/在场玩家的 factions + PvE AI 阵营）
function Fireteam.Rounds.GetActiveFactions()
    local set = {}
    for _, ply in ipairs(player.GetAll()) do
        local f = Fireteam.Rounds.GetPlayerFaction(ply)
        if f then set[f] = true end
    end
    -- PvE AI 阵营即使没有人类玩家也计入参战方
    if SERVER and Fireteam.PvE then
        for _, f in ipairs(Fireteam.PvE.GetAIFactions()) do
            set[f] = true
        end
    end
    local out = {}
    for f in pairs(set) do out[#out + 1] = f end
    table.sort(out)
    return out
end

--- 实体阵营：玩家走小队；ft_bot_teammate 走显式/主人阵营。非战斗单位返回 nil
function Fireteam.Rounds.GetEntityFaction(ent)
    if not IsValid(ent) then return nil end
    if ent:IsPlayer() then return Fireteam.Rounds.GetPlayerFaction(ent) end
    if ent.GetFaction then return ent:GetFaction() end
    return nil
end

--- 当前剧本下某阵营的出生点列表（供 PvE 生成等复用）
function Fireteam.Rounds.GetScenarioSpawns(factionId)
    local scenario = Fireteam.Rounds.ResolveScenario()
    if not scenario or not istable(scenario.spawns) then return {} end
    local list = scenario.spawns[factionId]
    return istable(list) and list or {}
end

Fireteam.Log.Info("Rounds", "✓ 共享定义已加载")
