-- modules/stamina/sv_stamina.lua
-- FIRETEAM Stamina System - Server
-- 冲刺耗力/间歇回复；力竭（滞回）禁冲刺+移速惩罚。速度一律按职业数据推导写入，
-- 与 vitals 倒地改速互不保存对方状态；vitals 状态翻转后强制重新对账。
-- 数值经 Fireteam.Vitals.BroadcastAll 并入 FT_VitalsUpdate 快照。

if not Fireteam then Fireteam = {} end
Fireteam.Stamina = Fireteam.Stamina or {}

local TICK      = 0.25
local BASE_WALK = 200   -- 与 class.ApplyStats 同基准

local function IsEnabled()
    return Fireteam.Config.Get("stamina.enabled") == true
end

local function EnsureState(ply)
    ply.FT_Stamina = ply.FT_Stamina or {
        value     = Fireteam.Stamina.GetMax(ply),
        exhausted = false,
        applied   = nil,       -- 速度惩罚应用状态（nil=待对账）
        lastSprint = 0,
    }
    return ply.FT_Stamina
end

--- 快照字段（vitals BroadcastAll 消费）；无档案返回 nil
function Fireteam.Stamina.SnapshotEntry(ply)
    if not istable(ply.FT_Stamina) then return nil end
    return {
        value = math.Round(ply.FT_Stamina.value),
        max   = Fireteam.Stamina.GetMax(ply),
    }
end

--- 力竭查询（vitals.RecalcSpeed 统一速度收口消费）
function Fireteam.Stamina.IsExhausted(ply)
    local st = ply.FT_Stamina
    return istable(st) and st.exhausted == true or false
end

function Fireteam.Stamina.Reset(ply)
    ply.FT_Stamina = nil
end

-- ─────────────────────────────────────
-- 速度套用（水平触发：applied 与 exhausted 不一致才写速度）
-- ─────────────────────────────────────

local function ApplySpeedState(ply, st)
    -- 速度统一收口到 vitals.RecalcSpeed（叠加腿伤/倒地）；vitals 不可用时回退本模块规则
    if Fireteam.Vitals and Fireteam.Vitals.RecalcSpeed then
        Fireteam.Vitals.RecalcSpeed(ply)
    else
        local mult = Fireteam.Stamina.ClassSpeedMult(ply)
        if st.exhausted then
            local low = Fireteam.Stamina.ExhaustSpeedMult()
            ply:SetWalkSpeed(BASE_WALK * mult * low)
            ply:SetRunSpeed(BASE_WALK * mult)   -- 跑=走 → 等效禁冲刺
        else
            ply:SetWalkSpeed(BASE_WALK * mult)
            ply:SetRunSpeed(400 * mult)
        end
    end
    st.applied = st.exhausted
end

timer.Create("Fireteam.Stamina.Tick", TICK, 0, function()
    if not IsEnabled() then return end
    local now   = CurTime()
    local drain = (tonumber(Fireteam.Config.Get("stamina.drain_per_sec")) or 9) * TICK
    local regen = (tonumber(Fireteam.Config.Get("stamina.regen_per_sec")) or 12) * TICK
    local delay = tonumber(Fireteam.Config.Get("stamina.regen_delay")) or 1.5
    local dirty = false

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive()
            and not (Fireteam.Vitals and Fireteam.Vitals.IsDowned and Fireteam.Vitals.IsDowned(ply)) then
            local st  = EnsureState(ply)
            local max = Fireteam.Stamina.GetMax(ply)

            -- 冲刺判定：引擎冲刺态且实际在移动
            local sprinting = ply:IsSprinting() and ply:GetVelocity():Length() > 10
            local before = math.Round(st.value)
            if sprinting and not st.exhausted then
                st.value = Fireteam.Stamina.Step(st.value, -drain, max)
                st.lastSprint = now
            elseif now - st.lastSprint >= delay and st.value < max then
                st.value = Fireteam.Stamina.Step(st.value, regen, max)
            end

            st.exhausted = Fireteam.Stamina.UpdateExhaustion(
                max > 0 and st.value / max or 0, st.exhausted)

            -- 速度对账：状态翻转或被外部改动（vitals 复活归位）后重套
            if st.applied ~= st.exhausted then
                ApplySpeedState(ply, st)
            end

            if math.Round(st.value) ~= before then dirty = true end
        end
    end

    if dirty and Fireteam.Vitals and Fireteam.Vitals.BroadcastAll then
        Fireteam.Vitals.BroadcastAll()
    end
end)

-- vitals 状态翻转（倒地缴械/复活归速）后，本模块强制重新对账一次
hook.Add(Fireteam.HOOKS.VITALS_STATE_CHANGED, "Fireteam.Stamina.Reapply", function(ply)
    local st = ply.FT_Stamina
    if istable(st) then st.applied = nil end
end)

hook.Add("PlayerSpawn", "Fireteam.Stamina.SpawnReset", function(ply)
    ply.FT_Stamina = nil   -- 下个 tick 以满体力重建
end)

hook.Add(Fireteam.HOOKS.ROUND_STATE_CHANGED, "Fireteam.Stamina.RoundReset", function(newState)
    if newState == Fireteam.Rounds.STATE.BRIEFING
        or newState == Fireteam.Rounds.STATE.WARMUP then
        for _, ply in ipairs(player.GetAll()) do
            ply.FT_Stamina = nil
        end
    end
end)

hook.Add("PlayerDisconnected", "Fireteam.Stamina.Cleanup", function(ply)
    ply.FT_Stamina = nil
end)

Fireteam.Log.Info("体力", "✓ 体力系统服务端已加载")
