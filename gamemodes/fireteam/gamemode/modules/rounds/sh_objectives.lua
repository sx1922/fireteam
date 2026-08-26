-- modules/rounds/sh_objectives.lua
-- FIRETEAM Rounds - Objective Interface + Built-in Types
-- 由 sh_rounds.lua 手动 include。逻辑函数由服务端驱动；客户端只消费快照。

Fireteam.Rounds.Objectives = Fireteam.Rounds.Objectives or {}

--- 注册目标类型
--- def 字段：
---   label                   显示用 locale key
---   onStart(ctx)            构建实例数据（可选）
---   think(ctx, dt)          服务端逐帧推进（必需）
---   isComplete(ctx)         -> done(bool), winnerFaction(string|nil)
---   getProgress(ctx)        -> 0..1（HUD 进度条）
---   describe(ctx)           -> 发给客户端的渲染参数表（可选）
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
        if standing == 0 then return true, nil end              -- 全灭平局
        if standing < #startList then return true, lastFaction end
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
