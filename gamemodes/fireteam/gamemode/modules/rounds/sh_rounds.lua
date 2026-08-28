-- modules/rounds/sh_rounds.lua
-- FIRETEAM Rounds Framework - Shared（模块入口，含目标接口与四种内置目标）
-- 回合状态机 WARMUP→BRIEFING→ACTIVE→ENDED→INTERMISSION + 目标接口 + 计分引擎。
-- 具体任务内容来自设定包 map_rules.rounds（决策 D3：框架只管流程，内容归数据）。
--
-- ⚠ 目标定义（原 sh_objectives.lua）已并入本文件末尾：模块自动加载器只认
-- sh_<dir>/sv_<dir>/cl_<dir> 三件套，子文件手动 include 在 GMA 分发下因
-- AddCSLuaFile 缺失 + include 基准目录歧义而双端失败（worklog 040）。

if not Fireteam then Fireteam = {} end
Fireteam.Rounds = Fireteam.Rounds or {}

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
-- 【第三方 DIY 入口】新增一个可选的完整剧本（如把 "berlin" 改成你自己的战役）。
--   data 形状与设定包 map_rules.rounds.scenarios 里的条目一致：
--     Fireteam.Rounds.RegisterScenario("my_battle", {
--         name = "My Battle", name_zh = "我的战役",
--         timings  = { round_time = 300, briefing = 10 },
--         spawns   = { usa = { { pos = { anchor = "map_center", offset = { x = -500, y = 0, z = 64 } } } } },
--         objectives = { { name = "Hold X", type = "hold_zone",
--                          zone = { anchor = "map_center", offset = { x = 0, y = 0 } },
--                          radius = 200, capture_time = 30 } },
--         pve      = { player_factions = {"usa"}, ai_factions = {"ussr"}, ai_behavior = "advance" },
--     })
--   data 被框架引用，注册后请勿原地修改；改字段请用下方 AddScenarioObjective/SetScenarioTimings 系列。
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

-- ═══════════════════════════════════════
-- 目标接口与四种内置目标（原 sh_objectives.lua，已并入本文件）
-- ═══════════════════════════════════════

Fireteam.Rounds.Objectives = Fireteam.Rounds.Objectives or {}

--- 注册目标类型
-- 【第三方 DIY 入口】自定义一种「任务目标」类型（占区/歼灭/摧毁/撤离之外的新玩法）。
--   def 字段：
--     label                 显示用 locale key（客户端据此显示目标名）
--     onStart(ctx)          可选，构建实例数据（存 ctx.data.X）
--     think(ctx, dt)        服务端逐帧推进（必需，dt 为帧间隔）
--     isComplete(ctx)       -> done(bool), winnerFaction(string|nil)（必需，判定完成）
--     getProgress(ctx)      -> 0..1（HUD 进度条，可选）
--     describe(ctx)         -> 客户端渲染参数表（可选，发给 cl_rounds_ui）
--   def 字段：label 显示名；think/isComplete 见下。
-- 示例（占领圈目标的最小实现）：
--     Fireteam.Rounds.RegisterObjective("my_hold", {
--         label = "objective_my_hold",
--         onStart = function(ctx) ctx.data.progress = 0 end,
--         think   = function(ctx, dt) ctx.data.progress = math.min(1, ctx.data.progress + dt) end,
--         isComplete = function(ctx) return ctx.data.progress >= 1, "usa" end,
--         getProgress = function(ctx) return ctx.data.progress or 0 end,
--     })
-- 注册后即可在剧本 objectives 里用 type = "my_hold" 引用。
function Fireteam.Rounds.RegisterObjective(id, def)
    def.id = id
    Fireteam.Rounds.Objectives[id] = def
end

--- 由设定包模板创建实例上下文
function Fireteam.Rounds.BuildObjectiveContext(template)
    local def = Fireteam.Rounds.Objectives[template.type]
    if not def then return nil end
    return {
        def       = def,
        template  = template,
        startedAt = CurTime(),
        data      = {},
    }
end

-- ═══════════════════════════════════════
-- 位置解析：设定包不绑地图，支持绝对坐标与锚点两种写法
-- ═══════════════════════════════════════

local function GetNavBounds()
    -- 服务端专用：由 navmesh 推算可玩区域包围盒
    if not SERVER then return nil, nil end
    local ok, areas = pcall(navmesh.GetAllAreas)
    if not ok or not istable(areas) or not next(areas) then return nil, nil end
    local vmin, vmax
    for _, area in pairs(areas) do
        local c = area:GetCenter()
        vmin = vmin or Vector(c.x, c.y, c.z)
        vmax = vmax or Vector(c.x, c.y, c.z)
        vmin = Vector(math.min(vmin.x, c.x), math.min(vmin.y, c.y), math.min(vmin.z, c.z))
        vmax = Vector(math.max(vmax.x, c.x), math.max(vmax.y, c.y), math.max(vmax.z, c.z))
    end
    return vmin, vmax
end

local function GetMapCenter()
    local bmin, bmax = Fireteam.TacMap.GetPackBounds()
    if not bmin then bmin, bmax = GetNavBounds() end
    if bmin and bmax then
        return Vector((bmin.x + bmax.x) / 2, (bmin.y + bmax.y) / 2, (bmin.z + bmax.z) / 2)
    end
    return vector_origin
end

--- spec 形式：
---   { x=, y=, z= }                       绝对世界坐标
---   { anchor="map_center", offset={} }   地图中心 + 偏移
---   { anchor="nav_random", offset={} }   随机导航区 + 偏移（仅服务端）
function Fireteam.Rounds.ResolvePos(spec)
    if isvector(spec) then return spec end
    if not istable(spec) then return nil end

    local offset = Vector(tonumber(spec.offset and spec.offset.x) or 0,
        tonumber(spec.offset and spec.offset.y) or 0,
        tonumber(spec.offset and spec.offset.z) or 0)

    if spec.anchor == "nav_random" then
        if SERVER then
            local ok, areas = pcall(navmesh.GetAllAreas)
            if ok and istable(areas) and next(areas) then
                local picked
                local n = 0
                local target = math.random(1, table.Count(areas))
                for _, area in pairs(areas) do
                    n = n + 1
                    if n == target then
                        picked = area
                        break
                    end
                end
                if IsValid(picked) then return picked:GetCenter() + offset end
            end
        end
        return nil
    end

    -- 绝对坐标写法
    if spec.x and spec.y then
        return Vector(tonumber(spec.x), tonumber(spec.y), tonumber(spec.z) or 0)
    end
    -- 缺省按 map_center 处理
    return GetMapCenter() + offset
end

-- ═══════════════════════════════════════
-- 内部工具：存活战斗单位（玩家 + ft_bot 系列 NextBot）
-- 目标判定与占区计数对两者一视同仁——PvE 的 AI 阵营由此进入目标逻辑
-- ═══════════════════════════════════════
local function AliveCombatants()
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            -- 倒地单位不计入占区/歼灭判定（仍可被补刀终结）
            if Fireteam.Vitals and Fireteam.Vitals.IsDowned and Fireteam.Vitals.IsDowned(ply) then
                continue
            end
            local f = Fireteam.Rounds.GetPlayerFaction(ply)
            if f then out[#out + 1] = { faction = f, pos = ply:GetPos(), ent = ply } end
        end
    end
    if SERVER then
        for _, b in ipairs(ents.FindByClass("ft_bot_teammate")) do
            if IsValid(b) and not b.FT_Dying and b.GetFaction then
                local f = b:GetFaction()
                if f then out[#out + 1] = { faction = f, pos = b:GetPos(), ent = b } end
            end
        end
    end
    return out
end

local function CountFactionInZone(zonePos, radius)
    local byFaction = {}
    if not isvector(zonePos) then return byFaction end
    local r2 = radius * radius
    for _, c in ipairs(AliveCombatants()) do
        if zonePos:DistToSqr(c.pos) <= r2 then
            byFaction[c.faction] = (byFaction[c.faction] or 0) + 1
        end
    end
    return byFaction
end

local function ZoneParams(ctx)
    local pos = ctx.data.zonePos
    if not (pos and isvector(pos)) then return nil end
    return {
        kind   = "zone",
        pos    = { x = pos.x, y = pos.y, z = pos.z },
        radius = tonumber(ctx.template.radius) or 200,
    }
end

-- ═══════════════════════════════════════
-- 目标 1：hold_zone 占区（争夺制：多方在场僵持，空场缓慢回落）
-- 模板字段：zone{...}, radius=200, capture_time=30
-- ═══════════════════════════════════════
Fireteam.Rounds.RegisterObjective("hold_zone", {
    label = "objective_hold_zone",

    onStart = function(ctx)
        ctx.data.zonePos   = Fireteam.Rounds.ResolvePos(ctx.template.zone)
        ctx.data.progress  = 0
        ctx.data.capturing = nil
        ctx.data.capturedBy = nil
    end,

    think = function(ctx, dt)
        if ctx.data.capturedBy then return end
        if not isvector(ctx.data.zonePos) then return end
        local radius      = tonumber(ctx.template.radius) or 200
        local captureTime = tonumber(ctx.template.capture_time) or 30
        local counts      = CountFactionInZone(ctx.data.zonePos, radius)

        local present = {}
        for f, n in pairs(counts) do
            if n > 0 then present[#present + 1] = f end
        end

        if #present == 1 then
            local f = present[1]
            if ctx.data.capturing ~= f and ctx.data.progress > 0 then
                -- 敌方接管：先衰减既有进度再换人推进
                ctx.data.progress = math.max(0, ctx.data.progress - dt / captureTime * 2)
                if ctx.data.progress == 0 then ctx.data.capturing = nil end
            else
                ctx.data.capturing = f
                ctx.data.progress = math.min(1, ctx.data.progress + dt / captureTime)
            end
        elseif #present == 0 then
            ctx.data.progress = math.max(0, ctx.data.progress - dt / captureTime * 0.5)
            if ctx.data.progress == 0 then ctx.data.capturing = nil end
        end
        -- #present >= 2：僵持，进度冻结

        if ctx.data.progress >= 1 and ctx.data.capturing then
            ctx.data.capturedBy = ctx.data.capturing
        end
    end,

    isComplete = function(ctx)
        if ctx.data.capturedBy then return true, ctx.data.capturedBy end
        return false
    end,

    getProgress = function(ctx) return ctx.data.progress or 0 end,
    describe    = function(ctx) return ZoneParams(ctx) end,
})

-- ═══════════════════════════════════════
-- 目标 2：eliminate 歼灭（一方全灭即结束；同归于尽判平局）
-- 模板字段：无额外字段
-- ═══════════════════════════════════════
Fireteam.Rounds.RegisterObjective("eliminate", {
    label = "objective_eliminate",

    onStart = function(ctx)
        -- 记录开局参战阵营，避免"某阵营没人来"直接误判
        ctx.data.factionsAtStart = Fireteam.Rounds.GetActiveFactions()
    end,

    think = function(ctx) end, -- 状态由死亡事件驱动，isComplete 即时判定

    isComplete = function(ctx)
        local startList = ctx.data.factionsAtStart or {}
        local alive = {}
        for _, c in ipairs(AliveCombatants()) do
            alive[c.faction] = true
        end
        local standing, lastFaction = 0, nil
        for _, f in ipairs(startList) do
            if alive[f] then
                standing = standing + 1
                lastFaction = f
            end
        end
        -- 结束条件 = 恰好剩一方（standing == 1）。
        -- 旧写法 standing < #startList 在 3+ 阵营下任意一方被灭即结束，
        -- 且 lastFaction 只是字母序最后一个存活方（胜者记录错误）。
        if standing == 0 then return true, nil end              -- 全灭平局
        if standing == 1 then return true, lastFaction end      -- 唯一幸存方获胜
        return false
    end,

    getProgress = function(ctx)
        -- 歼灭进度 ≈ 已失去战斗力的参战方占比（与 isComplete 同一口径）
        local startList = ctx.data.factionsAtStart or {}
        if #startList == 0 then return 0 end
        local alive = {}
        for _, c in ipairs(AliveCombatants()) do
            alive[c.faction] = true
        end
        local standing = 0
        for _, f in ipairs(startList) do
            if alive[f] then standing = standing + 1 end
        end
        return 1 - standing / #startList
    end,
})

-- ═══════════════════════════════════════
-- 目标 3：destroy_entity 摧毁实体（最后一击方得胜）
-- 模板字段：target_class 或 target_classes{...}，
--          可选 spawn{pos=..., model="..."}（场上无实例时尝试生成 prop_physics）
-- ═══════════════════════════════════════
Fireteam.Rounds.RegisterObjective("destroy_entity", {
    label = "objective_destroy",

    onStart = function(ctx)
        local t = ctx.template
        local classes = {}
        if t.target_classes then
            for _, c in ipairs(t.target_classes) do classes[#classes + 1] = c end
        elseif t.target_class then
            classes[#classes + 1] = t.target_class
        end

        ctx.data.targets = {}
        for _, class in ipairs(classes) do
            for _, ent in ipairs(ents.FindByClass(class)) do
                ctx.data.targets[#ctx.data.targets + 1] = ent
            end
        end

        -- 场上没有实例且模板允许时生成替身 prop（设定包实体内容缺失时的降级路径）
        if #ctx.data.targets == 0 and t.spawn and t.spawn.model then
            local pos = Fireteam.Rounds.ResolvePos(t.spawn.pos)
            if pos then
                local ent = ents.Create("prop_physics")
                if IsValid(ent) then
                    ent:SetModel(t.spawn.model)
                    ent:SetPos(pos + Vector(0, 0, 24))
                    ent:Spawn()
                    ctx.data.targets[#ctx.data.targets + 1] = ent
                    ctx.data.spawnedProp = true
                end
            end
        end

        ctx.data.destroyed = {}   -- ent -> 最后伤害方 faction
        ctx.data.unreachable = #ctx.data.targets == 0
        if ctx.data.unreachable then
            Fireteam.Log.Warn("回合", "destroy_entity 目标未找到且无法生成，本目标将不可完成")
        end
    end,

    --- 由服务端伤害事件调用：记录对目标的最后伤害方（玩家或 bot）
    noteDamage = function(ctx, ent, attacker)
        if not ctx.data.targets or #ctx.data.targets == 0 then return end
        local f = Fireteam.Rounds.GetEntityFaction(attacker)
        if not f then return end
        for _, tgt in ipairs(ctx.data.targets) do
            if tgt == ent then
                ctx.data.lastAttacker = f
                return
            end
        end
    end,

    think = function(ctx)
        -- 轮询目标存活状态（被摧毁/移除即从列表剔除并记功）
        for i = #ctx.data.targets, 1, -1 do
            local ent = ctx.data.targets[i]
            if not IsValid(ent) then
                table.remove(ctx.data.targets, i)
                ctx.data.destroyedCount = (ctx.data.destroyedCount or 0) + 1
            end
        end
    end,

    isComplete = function(ctx)
        if ctx.data.unreachable then return false end
        if (ctx.data.destroyedCount or 0) > 0 and #ctx.data.targets == 0 then
            return true, ctx.data.lastAttacker
        end
        return false
    end,

    getProgress = function(ctx)
        local total = (ctx.data.destroyedCount or 0) + #ctx.data.targets
        if total == 0 then return 0 end
        return (ctx.data.destroyedCount or 0) / total
    end,

    describe = function(ctx)
        if IsValid(ctx.data.targets and ctx.data.targets[1]) then
            local p = ctx.data.targets[1]:GetPos()
            return {
                kind = "point",
                pos = { x = p.x, y = p.y, z = p.z },
                radius = tonumber(ctx.template.radius) or 120,
            }
        end
        return nil
    end,
})

-- ═══════════════════════════════════════
-- 目标 4：extract 撤离（各阵营独立累积在场时长，先到者胜，无回落）
-- 模板字段：zone{...}, radius=200, hold_time=45
-- ═══════════════════════════════════════
Fireteam.Rounds.RegisterObjective("extract", {
    label = "objective_extract",

    onStart = function(ctx)
        ctx.data.zonePos  = Fireteam.Rounds.ResolvePos(ctx.template.zone)
        ctx.data.presence = {}     -- faction -> 累计秒数
        ctx.data.doneBy   = nil
    end,

    think = function(ctx, dt)
        if ctx.data.doneBy then return end
        if not isvector(ctx.data.zonePos) then return end
        local radius   = tonumber(ctx.template.radius) or 200
        local holdTime = tonumber(ctx.template.hold_time) or 45
        local counts   = CountFactionInZone(ctx.data.zonePos, radius)

        for f, n in pairs(counts) do
            if n > 0 then
                ctx.data.presence[f] = (ctx.data.presence[f] or 0) + dt * n
                if ctx.data.presence[f] >= holdTime then
                    ctx.data.doneBy = f
                    return
                end
            end
        end
    end,

    isComplete = function(ctx)
        if ctx.data.doneBy then return true, ctx.data.doneBy end
        return false
    end,

    getProgress = function(ctx)
        local holdTime = tonumber(ctx.template.hold_time) or 45
        local best = 0
        for _, secs in pairs(ctx.data.presence or {}) do
            best = math.max(best, secs)
        end
        return math.min(1, best / holdTime)
    end,

    describe = function(ctx) return ZoneParams(ctx) end,
})
