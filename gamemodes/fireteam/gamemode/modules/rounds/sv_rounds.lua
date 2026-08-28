-- modules/rounds/sv_rounds.lua
-- FIRETEAM Rounds Framework - Server
-- 状态机驱动 + 计分引擎 + 快照广播。任务内容全部来自设定包 map_rules.rounds。

local STATE = Fireteam.Rounds.STATE

local machine = {
    state           = STATE.IDLE,
    stateUntil      = 0,
    roundNumber     = 0,
    scores          = {},     -- faction -> points（每回合清零）
    objectiveCtx    = nil,    -- 目标实例上下文
    winner          = nil,    -- 结算胜者 faction / nil=平局
    reason          = "",     -- 结束原因（objective/timeout/score_limit/admin）
    factionsAtStart = {},     -- 本回合参战阵营
    lastBroadcast   = 0,
}

-- ═══════════════════════════════════════
-- 快照广播
-- ═══════════════════════════════════════
local function BuildSnapshot()
    local obj = nil
    if machine.objectiveCtx then
        local ctx = machine.objectiveCtx
        obj = {
            type     = ctx.template.type,
            name     = ctx.template.name or "",
            name_zh  = ctx.template.name_zh or "",
            label    = ctx.def.label or "",
            progress = math.Clamp(ctx.def.getProgress and ctx.def.getProgress(ctx) or 0, 0, 1),
            params   = ctx.def.describe and ctx.def.describe(ctx) or nil,
        }
    end
    local scenario = Fireteam.Rounds.ResolveScenario()
    return {
        state    = machine.state,
        endTime  = machine.stateUntil,
        round    = machine.roundNumber,
        scores   = machine.scores,
        winner   = machine.winner,
        reason   = machine.reason,
        objective = obj,
        scenario = scenario and {
            id      = scenario.id,
            name    = scenario.name,
            name_zh = scenario.name_zh,
        } or nil,
        mode     = Fireteam.Config.Get("rounds.mode") or "pvp",
        campaign = Fireteam.PvE and Fireteam.PvE.GetCampaignInfo() or nil,
    }
end

--- @param target Player|nil  指定则单发（CLIENT_READY 补齐用），缺省全场广播
local function BroadcastSnapshot(target)
    net.Start(Fireteam.NET.ROUNDS_STATE)
    net.WriteTable(BuildSnapshot())
    if IsValid(target) then net.Send(target) else net.Broadcast() end
    if not IsValid(target) then machine.lastBroadcast = CurTime() end
end

--- 单发当前回合快照（供 CLIENT_READY 握手补齐）
function Fireteam.Rounds.SendSnapshotTo(ply)
    if IsValid(ply) then BroadcastSnapshot(ply) end
end

-- ═══════════════════════════════════════
-- 出生点与冻结
-- ═══════════════════════════════════════
local function GetFactionSpawns(factionId)
    local scenario = Fireteam.Rounds.ResolveScenario()
    if not scenario or not istable(scenario.spawns) then return {} end
    local list = scenario.spawns[factionId]
    return istable(list) and list or {}
end

--- 从上方找地面（锚点偏移量是示意值，不能假设正好落在地表）
local function GroundPos(pos)
    local t = util.TraceLine({
        start  = pos + Vector(0, 0, 256),
        endpos = pos - Vector(0, 0, 4096),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    if t.Hit then return t.HitPos + Vector(0, 0, 8) end
    return pos
end

--- 把玩家传回阵营出生点（round-robin），无配置则原地不动
local function TeleportToSpawn(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local faction = Fireteam.Rounds.GetPlayerFaction(ply)
    if not faction then return end

    local spawns = GetFactionSpawns(faction)
    if #spawns == 0 then return end

    ply.spawnCursor = ((ply.spawnCursor or 0) % #spawns) + 1
    local spec = spawns[ply.spawnCursor]
    local pos = Fireteam.Rounds.ResolvePos(spec.pos or spec)
    if pos then ply:SetPos(GroundPos(pos)) end
end

local function SetAllFrozen(frozen)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then ply:Freeze(frozen) end
    end
end

-- ═══════════════════════════════════════
-- 状态切换
-- ═══════════════════════════════════════
-- 前置声明：击杀归功在其定义之前即需引用
local EndRound, EvaluateWinner

local function SetState(newState, duration)
    local old = machine.state
    machine.state = newState
    machine.stateUntil = CurTime() + (duration or 0)

    hook.Run(Fireteam.HOOKS.ROUND_STATE_CHANGED, old, newState, machine.roundNumber)
    Fireteam.Log.Info("回合", string.format("%s → %s（%.0fs）", tostring(old), tostring(newState), duration or 0))
    BroadcastSnapshot()
end

--- 击杀归功：af 阵营 +kill_points，达分数上限提前结算
local function AddKillPoints(af)
    local cfg = Fireteam.Rounds.GetPackConfig() or {}
    local killPoints = tonumber(cfg.kill_points) or 1
    machine.scores[af] = (machine.scores[af] or 0) + killPoints

    local limit = tonumber(cfg.score_limit)
    if limit and machine.scores[af] >= limit then
        EndRound(EvaluateWinner(nil), "score_limit")
    end
end

local function PickObjectiveTemplate(roundNumber)
    local templates = Fireteam.Rounds.GetObjectiveTemplates()
    if #templates == 0 then return nil end

    -- PvE 战役：按关卡顺序取目标（关卡推进由 pve 模块在回合结算时管理）
    if (Fireteam.Config.Get("rounds.mode") or "pvp") == "pve"
        and Fireteam.PvE and Fireteam.PvE.GetCurrentStageIndex then
        local idx = math.Clamp(Fireteam.PvE.GetCurrentStageIndex(), 1, #templates)
        local t = templates[idx]
        if t and t.type and Fireteam.Rounds.Objectives[t.type] then
            return t
        end
        return nil
    end

    -- 轮转取模板；模板 type 未注册则顺延，全不可用返回 nil
    for i = 0, #templates - 1 do
        local t = templates[((roundNumber - 1 + i) % #templates) + 1]
        if t and t.type and Fireteam.Rounds.Objectives[t.type] then
            return t
        end
    end
    return nil
end

local function EnterBriefing(nextRound)
    if nextRound then machine.roundNumber = machine.roundNumber + 1 end

    -- 地图-剧本绑定校验：若当前地图不在剧本声明的 maps 列表中，跳过该剧本
    local scenario = Fireteam.Rounds.ResolveScenario()
    if scenario and scenario.maps and #scenario.maps > 0 then
        local curMap = game.GetMap()
        local mapOK = false
        for _, m in ipairs(scenario.maps) do
            if m == curMap then mapOK = true break end
        end
        if not mapOK then
            Fireteam.Log.Warn("回合", string.format("当前地图 %s 不在剧本 %s 的地图列表中（要求: %s），回退到默认剧本",
                curMap, scenario.id, table.concat(scenario.maps, ", ")))
            Fireteam.Config.Set("rounds.scenario", "")  -- 清空指定，回到 default_scenario
            scenario = Fireteam.Rounds.ResolveScenario() -- 重新解析
        end
    end

    -- PvE：先布设 AI 单位再构建目标——eliminate 的参战方快照必须包含 AI 阵营
    if Fireteam.PvE then Fireteam.PvE.OnEnterBriefing() end

    -- 复活全员并就位
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:UnSpectate()
            ply:Spawn()
            timer.Simple(0.05, function()
                if IsValid(ply) then TeleportToSpawn(ply) end
            end)
        end
    end

    -- 构建目标实例
    machine.objectiveCtx = nil
    local template = PickObjectiveTemplate(math.max(1, machine.roundNumber))
    if template then
        local ctx = Fireteam.Rounds.BuildObjectiveContext(template)
        if ctx then
            machine.objectiveCtx = ctx
            if ctx.def.onStart then ctx.def.onStart(ctx) end
            Fireteam.Log.Info("回合", string.format("第 %d 回合目标: %s", machine.roundNumber, template.type))
        end
    else
        Fireteam.Log.Warn("回合", "设定包未提供可用目标模板，本回合仅计分")
    end

    SetState(STATE.BRIEFING, Fireteam.Rounds.GetTimings().briefing)
    timer.Simple(0.1, function() if machine.state == STATE.BRIEFING then SetAllFrozen(true) end end)
end

local function EnterActive()
    machine.factionsAtStart = Fireteam.Rounds.GetActiveFactions()
    if Fireteam.PvE then Fireteam.PvE.OnEnterActive() end
    SetAllFrozen(false)
    SetState(STATE.ACTIVE, Fireteam.Rounds.GetTimings().round_time)
end

--- 结算胜负：目标胜者优先，其次比分，最后平局
function EvaluateWinner(objWinner)
    if objWinner then return objWinner end

    local best, bestScore, tie = nil, -math.huge, false
    for _, f in ipairs(machine.factionsAtStart) do
        local s = machine.scores[f] or 0
        if s > bestScore then
            best, bestScore, tie = f, s, false
        elseif s == bestScore then
            tie = true
        end
    end
    if tie then return nil end
    return best
end

function EndRound(winner, reason)
    machine.winner = winner
    machine.reason = reason or ""

    -- PvE：战役关卡推进/重试与 AI 单位清理由 pve 模块接管
    if Fireteam.PvE then Fireteam.PvE.OnRoundEnded(winner, reason) end

    SetAllFrozen(false)
    hook.Run(Fireteam.HOOKS.ROUND_ENDED, winner, machine.reason, machine.scores)
    SetState(STATE.ENDED, Fireteam.Rounds.GetTimings().ended)
end

local function EnterWarmup()
    machine.roundNumber = 0
    machine.scores = {}
    machine.winner = nil
    machine.reason = ""
    machine.objectiveCtx = nil
    SetState(STATE.WARMUP, Fireteam.Rounds.GetTimings().warmup)
end

local function EnterIdle()
    machine.state = STATE.IDLE
    machine.stateUntil = 0
    machine.objectiveCtx = nil
    if Fireteam.PvE then Fireteam.PvE.OnRoundEnded(nil, "idle") end
    SetAllFrozen(false)
    BroadcastSnapshot()
end

-- ═══════════════════════════════════════
-- 主循环
-- ═══════════════════════════════════════
hook.Add("Think", "Fireteam.Rounds.Machine", function()
    if not Fireteam.Rounds.IsEnabled() then
        if machine.state ~= STATE.IDLE then EnterIdle() end
        return
    elseif machine.state == STATE.IDLE then
        EnterWarmup()
        return
    end

    local now = CurTime()

    -- ACTIVE 阶段推进目标逻辑
    if machine.state == STATE.ACTIVE and machine.objectiveCtx then
        local ctx = machine.objectiveCtx
        ctx.def.think(ctx, FrameTime())

        local done, objWinner = ctx.def.isComplete(ctx)
        if done then
            -- 目标完成方加分并直接结算
            local cfg = Fireteam.Rounds.GetPackConfig() or {}
            local points = tonumber(cfg.objective_points) or 3
            if objWinner then
                machine.scores[objWinner] = (machine.scores[objWinner] or 0) + points
            end
            EndRound(EvaluateWinner(objWinner), "objective")
            return
        end
    end

    -- 进度快照节流广播（ACTIVE 每秒一次，其余状态靠转换时广播）
    if machine.state == STATE.ACTIVE and now - machine.lastBroadcast >= 1 then
        BroadcastSnapshot()
    end

    -- 到点转移
    if now < machine.stateUntil then return end

    if machine.state == STATE.WARMUP then
        EnterBriefing(true)
    elseif machine.state == STATE.BRIEFING then
        EnterActive()
    elseif machine.state == STATE.ACTIVE then
        EndRound(EvaluateWinner(nil), "timeout")
    elseif machine.state == STATE.ENDED then
        SetState(STATE.INTERMISSION, Fireteam.Rounds.GetTimings().intermission)
    elseif machine.state == STATE.INTERMISSION then
        machine.scores = {}
        machine.winner = nil
        machine.reason = ""
        EnterBriefing(true)
    end
end)

-- ═══════════════════════════════════════
-- 计分：击杀（跨阵营；攻击方为玩家或 AI bot 均可归功）
-- ═══════════════════════════════════════
hook.Add("PlayerDeath", "Fireteam.Rounds.KillScore", function(victim, inflictor, attacker)
    if machine.state ~= STATE.ACTIVE then return end
    if not IsValid(attacker) or attacker == victim then return end

    local vf = Fireteam.Rounds.GetPlayerFaction(victim)
    local af = Fireteam.Rounds.GetEntityFaction(attacker)
    if not vf or not af or vf == af then return end

    AddKillPoints(af)
end)

hook.Add(Fireteam.HOOKS.BOT_KILLED, "Fireteam.Rounds.BotKilledScore", function(bot, attacker)
    if machine.state ~= STATE.ACTIVE then return end
    if not IsValid(attacker) or attacker == bot then return end

    local vf = Fireteam.Rounds.GetEntityFaction(bot)
    local af = Fireteam.Rounds.GetEntityFaction(attacker)
    if not vf or not af or vf == af then return end

    AddKillPoints(af)
end)

-- ═══════════════════════════════════════
-- 摧毁类目标的伤害归功（玩家与 AI bot 均可记功）
-- ═══════════════════════════════════════
hook.Add("EntityTakeDamage", "Fireteam.Rounds.DestroyCredit", function(ent, dmginfo)
    if machine.state ~= STATE.ACTIVE or not machine.objectiveCtx then return end
    local def = machine.objectiveCtx.def
    if def.id ~= "destroy_entity" or not def.noteDamage then return end

    local attacker = dmginfo:GetAttacker()
    if IsValid(attacker) and Fireteam.Rounds.GetEntityFaction(attacker) then
        def.noteDamage(machine.objectiveCtx, ent, attacker)
    end
end)

-- ═══════════════════════════════════════
-- 阵亡管控：ACTIVE/BRIEFING/ENDED 期间禁止自行重生，等下回合
-- ═══════════════════════════════════════
hook.Add("PlayerDeathThink", "Fireteam.Rounds.BlockRespawn", function(ply)
    if machine.state == STATE.ACTIVE
        or machine.state == STATE.BRIEFING
        or machine.state == STATE.ENDED then
        return false
    end
end)

-- 简报阶段加入的玩家同样冻结就位
hook.Add("PlayerInitialSpawn", "Fireteam.Rounds.LateJoiner", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        if machine.state == STATE.BRIEFING then
            ply:Spawn()
            timer.Simple(0.05, function()
                if IsValid(ply) then
                    TeleportToSpawn(ply)
                    ply:Freeze(true)
                end
            end)
        end
    end)
end)

-- ═══════════════════════════════════════
-- 外部模块查询接口（观察者模式等判断"阵亡待机"窗口）
-- ═══════════════════════════════════════
function Fireteam.Rounds.IsRespawnBlocked()
    return machine.state == STATE.ACTIVE
        or machine.state == STATE.BRIEFING
        or machine.state == STATE.ENDED
end

function Fireteam.Rounds.GetState()
    return machine.state
end

--- 模式信息（管理面板 / 调试）：当前模式 + 战役进度
function Fireteam.Rounds.GetModeInfo()
    return {
        mode     = Fireteam.Config.Get("rounds.mode") or "pvp",
        campaign = Fireteam.PvE and Fireteam.PvE.GetCampaignInfo() or nil,
    }
end

--- 当前目标的锚点位置（PvE advance 行为的推进目的地）；无目标或无位置返回 nil
function Fireteam.Rounds.GetObjectivePos()
    local ctx = machine.objectiveCtx
    if not ctx or not ctx.def.describe then return nil end
    local params = ctx.def.describe(ctx)
    if istable(params) and istable(params.pos) and params.pos.x and params.pos.y then
        return Vector(tonumber(params.pos.x), tonumber(params.pos.y), tonumber(params.pos.z) or 0)
    end
    return nil
end

--- 管理接口：立即触发到点转移（供 F10 面板复用）
function Fireteam.Rounds.AdminAdvance()
    machine.stateUntil = CurTime() - 1
end

--- 管理接口：强制结算。winner 为 faction id / "draw" / nil(按比分)
--- winner 必须是当前回合的合法阵营，否则回退到比分结算（防胜者字符串注入）
function Fireteam.Rounds.AdminEnd(winner)
    if machine.state ~= STATE.ACTIVE then return false end
    local w
    if winner == "draw" then
        w = nil
    elseif winner then
        -- 校验 winner 是否属于当前回合的有效阵营
        local valid = false
        for _, f in ipairs(machine.factionsAtStart) do
            if f == winner then valid = true break end
        end
        if not valid then
            Fireteam.Log.Warn("回合", "AdminEnd 拒绝非法胜者: " .. tostring(winner))
            w = EvaluateWinner(nil)
        else
            w = winner
        end
    else
        w = EvaluateWinner(nil)
    end
    EndRound(w, "admin")
    return true
end

-- ═══════════════════════════════════════
-- 设定包切换 / 开局启动
-- ═══════════════════════════════════════
hook.Add(Fireteam.HOOKS.SETTING_LOADED, "Fireteam.Rounds.PackReloaded", function()
    machine.roundNumber = 0
    if Fireteam.PvE then Fireteam.PvE.OnPackChanged() end
    if Fireteam.Rounds.IsEnabled() then
        EnterWarmup()
    else
        EnterIdle()
    end
end)

hook.Add("InitPostEntity", "Fireteam.Rounds.Boot", function()
    timer.Simple(5, function()
        if Fireteam.Rounds.IsEnabled() then EnterWarmup() end
    end)
end)

-- ═══════════════════════════════════════
-- 管理指令（测试与 F10 面板前置）
-- ═══════════════════════════════════════
local function AdminAllowed(ply)
    return not IsValid(ply) or ply:IsAdmin()
end

concommand.Add("ft_round_state", function(ply)
    if not AdminAllowed(ply) then return end
    local msg = string.format("state=%s round=%d until=%.0f scores=%s",
        machine.state, machine.roundNumber, machine.stateUntil,
        table.ToString(machine.scores, "scores", "|"))
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else Fireteam.Log.Info("系统", "" .. msg) end
end)

-- ═══════════════════════════════════════
-- 剧本切换（config rounds.scenario）
-- 进行中的回合不打断：新剧本在下一回合简报生效
-- ═══════════════════════════════════════
hook.Add(Fireteam.HOOKS.CONFIG_CHANGED, "Fireteam.Rounds.ScenarioChanged", function(key, oldVal, newVal)
    if key ~= "rounds.scenario" then return end

    local list = Fireteam.Rounds.GetScenarioList()
    if list and newVal and newVal ~= "" and not list[newVal] then
        Fireteam.Log.Warn("回合", "剧本 '" .. tostring(newVal) .. "' 不在当前设定包中，将回落到默认剧本")
        return
    end
    local scenario = Fireteam.Rounds.ResolveScenario()
    if scenario then
        Fireteam.Log.Info("回合", string.format("剧本切换: %s → %s（下一回合简报生效）",
            tostring(oldVal), scenario.id))
        BroadcastSnapshot()   -- 让面板/横幅立即反映即将使用的剧本
        hook.Run(Fireteam.HOOKS.SCENARIO_CHANGED, scenario.id)   -- 第三方定制挂点
    end
end)

concommand.Add("ft_scenario", function(ply, cmd, args)
    -- 服务器控制台或管理员可用；无参列出可选剧本
    if IsValid(ply) and not ply:IsAdmin() then return end

    local list = Fireteam.Rounds.GetScenarioList()
    if not list then
        Fireteam.Log.Info("系统", "当前设定包未定义 scenarios（使用隐式单剧本）")
        return
    end

    local id = args[1]
    if not id then
        Fireteam.Log.Info("系统", "可用剧本:")
        for sid in pairs(list) do
            print("  " .. sid .. (sid == (Fireteam.Config.Get("rounds.scenario") or "") and "  ← 当前指定" or ""))
        end
        return
    end

    if not list[id] then
        Fireteam.Log.Info("系统", "未找到剧本 '" .. id .. "'")
        return
    end
    Fireteam.Config.Set("rounds.scenario", id)
end)

concommand.Add("ft_round_next", function(ply)
    if not AdminAllowed(ply) then return end
    Fireteam.Rounds.AdminAdvance()
end)

concommand.Add("ft_round_end", function(ply, cmd, args)
    if not AdminAllowed(ply) then return end
    Fireteam.Rounds.AdminEnd(args[1])
end)

concommand.Add("ft_mode", function(ply, cmd, args)
    if not AdminAllowed(ply) then return end

    local want = args[1]
    if not want then
        local msg = string.format("mode=%s（用法: ft_mode pvp|pve）",
            tostring(Fireteam.Config.Get("rounds.mode")))
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else Fireteam.Log.Info("系统", "" .. msg) end
        return
    end

    if want ~= "pvp" and want ~= "pve" then return end
    Fireteam.Config.Set("rounds.mode", want)
end)

Fireteam.Log.Info("回合", "✓ 回合框架服务端已加载")
