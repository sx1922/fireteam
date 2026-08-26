-- modules/vitals/sv_vitals.lua
-- FIRETEAM Vitals System - Server Logic
-- 伤害部位倍率与出血累积 → HP 归零不立即死亡而是倒地（bleed-out 计时）：
-- 队友按 E 可稳定伤势（暂停计时），医疗兵持医疗包读条复活；超时或被
-- 足量补刀才真正死亡（走引擎 Kill → 现有 PlayerDeath 计分/观战链不受影响）。
-- 倒地单位不计入目标判定（sh_objectives 经 IsDowned 排除），PvE bot 不参与本系统。

if not Fireteam then Fireteam = {} end
Fireteam.Vitals = Fireteam.Vitals or {}

local TICK_INTERVAL = 1        -- 出血/失血过世结算周期
local RESCUE_SCAN   = 0.25     -- 救援交互扫描周期
local CHANNEL_RANGE = 100      -- 救援交互最大距离
local CHANNEL_MOVE  = 60       -- 读条期间允许的最大位移

-- ─────────────────────────────────────
-- 状态存取
-- ─────────────────────────────────────

local function EnsureState(ply)
    ply.FT_Vitals = ply.FT_Vitals or {
        state = Fireteam.Vitals.STATE.NORMAL,
        bleed = 0,
        stabilized = false,
    }
    return ply.FT_Vitals
end

function Fireteam.Vitals.GetState(ply)
    return (istable(ply.FT_Vitals) and ply.FT_Vitals.state) or Fireteam.Vitals.STATE.NORMAL
end

function Fireteam.Vitals.IsDowned(ply)
    return Fireteam.Vitals.GetState(ply) == Fireteam.Vitals.STATE.DOWNED
end

--- 广播全员快照（人数级小表，状态变化时才发）
local function BroadcastAll()
    local out = {}
    local now = CurTime()
    for _, p in ipairs(player.GetAll()) do
        local st = p.FT_Vitals
        if istable(st) then
            local entry = {
                idx        = p:EntIndex(),
                state      = st.state,
                bleed      = st.bleed or 0,
                stabilized = st.stabilized and true or false,
                pos        = { x = math.floor(p:GetPos().x), y = math.floor(p:GetPos().y), z = math.floor(p:GetPos().z) },
            }
            if st.state == Fireteam.Vitals.STATE.DOWNED and st.bleedoutEnds then
                entry.remain = math.max(st.bleedoutEnds - now, 0)
            end
            if Fireteam.Stamina and Fireteam.Stamina.SnapshotEntry then
                local stam = Fireteam.Stamina.SnapshotEntry(p)
                if stam then entry.stam, entry.stamMax = stam.value, stam.max end
            end
            local ch = p.FT_ReviveChannel
            if ch then
                entry.reviving = { tgtIdx = ch.target:EntIndex(), kind = ch.kind,
                                   ends = math.Round(ch.ends - now, 1) }
            end
            out[#out + 1] = entry
        end
    end
    Fireteam.Net.SendToAll(Fireteam.NET.VITALS_UPDATE, out)
end

--- 供关联模块（stamina 等）触发快照重播；内部沿用本地实现
function Fireteam.Vitals.BroadcastAll()
    BroadcastAll()
end

--- 重置到正常（重生/新回合）
function Fireteam.Vitals.Reset(ply)
    ply.FT_Vitals = nil
    ply.FT_DownedWeapons = nil
    ply.FT_SpeedSave = nil
    ply.FT_ReviveChannel = nil
    BroadcastAll()
end

function Fireteam.Vitals.IsEnabled()
    return Fireteam.Vitals.GetParam("enabled") == true
end

-- ─────────────────────────────────────
-- 倒地 / 死亡 / 复活
-- ─────────────────────────────────────

local function FactionChat(factionId, text)
    for _, p in ipairs(player.GetAll()) do
        if Fireteam.Rounds.GetPlayerFaction and Fireteam.Rounds.GetPlayerFaction(p) == factionId then
            p:ChatPrint(text)
        end
    end
end

local BASE_WALK, BASE_RUN = 200, 400   -- 与 class.ApplyStats 同基准

--- 职业 speed_mult（速度基准一律由职业数据推导，避免与 stamina 等改速模块互相污染）
local function ClassSpeedMult(ply)
    local cd = Fireteam.Class and Fireteam.Class.GetPlayerClassData
        and Fireteam.Class.GetPlayerClassData(ply) or nil
    if istable(cd) and istable(cd.stats) and tonumber(cd.stats.speed_mult) then
        return tonumber(cd.stats.speed_mult)
    end
    return 1
end

local function EnterDowned(ply, attacker)
    local st = EnsureState(ply)
    if st.state ~= Fireteam.Vitals.STATE.NORMAL then return end

    st.state = Fireteam.Vitals.STATE.DOWNED
    st.stabilized = false
    st.bleedoutEnds = CurTime() + (tonumber(Fireteam.Vitals.GetParam("bleedout_time")) or 60)

    -- 缴械但保存清单，复活后原样归还（消耗品计数不受 StripWeapons 影响）
    ply.FT_DownedWeapons = {}
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) then table.insert(ply.FT_DownedWeapons, wep:GetClass()) end
    end
    ply:StripWeapons()

    -- 匍匐机动：压到爬行档（跳力先存待还原；速度基准由职业数据推导）
    ply.FT_SpeedSave = { jump = ply:GetJumpPower(), mult = ClassSpeedMult(ply) }
    local spd = tonumber(Fireteam.Vitals.GetParam("downed_speed")) or 40
    ply:SetWalkSpeed(spd)
    ply:SetRunSpeed(spd)
    ply:SetJumpPower(0)

    local vName = ply:Nick()
    local f = Fireteam.Rounds.GetPlayerFaction and Fireteam.Rounds.GetPlayerFaction(ply) or nil
    if f then
        FactionChat(f, "[FIRETEAM] " .. string.format(Fireteam.Locale.Get("vitals_teammate_downed"), vName))
    end

    hook.Run(Fireteam.HOOKS.VITALS_STATE_CHANGED, ply,
        Fireteam.Vitals.STATE.NORMAL, Fireteam.Vitals.STATE.DOWNED)
    BroadcastAll()
end

local function TrueDeath(ply)
    local st = EnsureState(ply)
    if st.state == Fireteam.Vitals.STATE.DEAD then return end

    local prevState = st.state
    st.state = Fireteam.Vitals.STATE.DEAD
    ply:Kill()   -- 引擎死亡事件 → 既有计分/观战/重生等待链原样生效

    hook.Run(Fireteam.HOOKS.VITALS_STATE_CHANGED, ply, prevState, Fireteam.Vitals.STATE.DEAD)
    BroadcastAll()
end

local function RevivePlayer(target, healer)
    local st = EnsureState(target)
    if st.state ~= Fireteam.Vitals.STATE.DOWNED then return false end

    st.state = Fireteam.Vitals.STATE.NORMAL
    st.bleed = 0
    st.stabilized = false
    st.bleedoutEnds = nil
    target.FT_ReviveChannel = nil

    local maxHp = math.max(target:GetMaxHealth(), 1)
    local frac = tonumber(Fireteam.Vitals.GetParam("revive_health_frac")) or 0.4
    target:SetHealth(math.max(math.floor(maxHp * frac), 1))

    -- 恢复机动力（按职业推导的基准）与武器
    local saved = target.FT_SpeedSave
    local mult = (istable(saved) and tonumber(saved.mult)) or ClassSpeedMult(target)
    target:SetWalkSpeed(BASE_WALK * mult)
    target:SetRunSpeed(BASE_RUN * mult)
    if istable(saved) and tonumber(saved.jump) then
        target:SetJumpPower(tonumber(saved.jump))
    end
    target.FT_SpeedSave = nil
    if istable(target.FT_DownedWeapons) then
        for _, cls in ipairs(target.FT_DownedWeapons) do
            target:Give(cls)
        end
    end
    target.FT_DownedWeapons = nil

    if IsValid(healer) and healer:IsPlayer() then
        local f = Fireteam.Rounds.GetPlayerFaction and Fireteam.Rounds.GetPlayerFaction(target) or nil
        if f then
            FactionChat(f, "[FIRETEAM] " .. string.format(Fireteam.Locale.Get("vitals_revived_chat"),
                healer:Nick(), target:Nick()))
        end
    end

    hook.Run(Fireteam.HOOKS.VITALS_STATE_CHANGED, target,
        Fireteam.Vitals.STATE.DOWNED, Fireteam.Vitals.STATE.NORMAL)
    BroadcastAll()
    return true
end

-- ─────────────────────────────────────
-- 伤害管线
-- ─────────────────────────────────────

-- 部位倍率 + 出血累积
hook.Add("ScalePlayerDamage", "Fireteam.Vitals.ScaleDamage", function(ply, hitgroup, dmginfo)
    if not Fireteam.Vitals.IsEnabled() then return end
    local st = EnsureState(ply)   -- 首次受击惰性建档（出生复位后为 nil）
    if st.state ~= Fireteam.Vitals.STATE.NORMAL then return end

    local mults = {
        head_mult    = Fireteam.Vitals.GetParam("head_mult"),
        chest_mult   = Fireteam.Vitals.GetParam("chest_mult"),
        stomach_mult = Fireteam.Vitals.GetParam("stomach_mult"),
        limb_mult    = Fireteam.Vitals.GetParam("limb_mult"),
    }
    dmginfo:SetDamage(Fireteam.Vitals.ScaleHitgroupDamage(dmginfo:GetDamage(), hitgroup, mults))

    if not dmginfo:IsDamageType(DMG_FALL) and not dmginfo:IsDamageType(DMG_DROWN) then
        st.bleed = Fireteam.Vitals.AddBleedStack(st.bleed, 1,
            tonumber(Fireteam.Vitals.GetParam("max_bleed_stacks")) or 5)
    end
end)

-- 致命伤害拦截：normal→截断留 1 点转倒地；downed→小伤无效，足量补刀放行给引擎
hook.Add("EntityTakeDamage", "Fireteam.Vitals.LethalIntercept", function(ent, dmginfo)
    if not Fireteam.Vitals.IsEnabled() then return end
    if not IsValid(ent) or not ent:IsPlayer() then return end

    local st = EnsureState(ent)   -- 同上：无档案的玩家也要能触发倒地
    local attacker = dmginfo:GetAttacker()

    if st.state == Fireteam.Vitals.STATE.NORMAL then
        if ent:Alive() and ent:Health() - dmginfo:GetDamage() <= 0 then
            -- 截断到 1 点血，本帧末转入倒地
            dmginfo:SetDamage(math.max(ent:Health() - 1, 0))
            timer.Simple(0, function()
                if IsValid(ent) and ent:Alive()
                    and Fireteam.Vitals.GetState(ent) == Fireteam.Vitals.STATE.NORMAL
                    and ent:Health() <= 1 then
                    EnterDowned(ent, attacker)
                end
            end)
        end
    elseif st.state == Fireteam.Vitals.STATE.DOWNED then
        local threshold = tonumber(Fireteam.Vitals.GetParam("finish_damage")) or 25
        if dmginfo:GetDamage() >= threshold then
            -- 放行致死伤害：引擎击杀触发 PlayerDeath，计分归功自然正确
            st.state = Fireteam.Vitals.STATE.DEAD
            BroadcastAll()
        else
            dmginfo:SetDamage(0)   -- 小额伤害不消耗倒地者
        end
    end
end)

-- 引擎真实死亡（补刀 / 自杀 / 控制台 kill）：同步内部状态
hook.Add("PlayerDeath", "Fireteam.Vitals.OnRealDeath", function(victim)
    local st = victim.FT_Vitals
    if istable(st) and st.state ~= Fireteam.Vitals.STATE.DEAD then
        st.state = Fireteam.Vitals.STATE.DEAD
        BroadcastAll()
    end
end)

-- ─────────────────────────────────────
-- 周期结算：出血掉血 / 倒地计时
-- ─────────────────────────────────────

timer.Create("Fireteam.Vitals.Tick", TICK_INTERVAL, 0, function()
    if not Fireteam.Vitals.IsEnabled() then return end
    local now = CurTime()
    local dirty = false

    for _, ply in ipairs(player.GetAll()) do
        local st = ply.FT_Vitals
        if istable(st) and ply:Alive() then
            if st.state == Fireteam.Vitals.STATE.NORMAL and (st.bleed or 0) > 0 then
                local dmg = Fireteam.Vitals.BleedTickDamage(
                    st.bleed,
                    tonumber(Fireteam.Vitals.GetParam("bleed_dps_per_stack")) or 1.2,
                    TICK_INTERVAL)
                local hp = ply:Health() - dmg
                if hp <= 1 then
                    ply:SetHealth(1)
                    EnterDowned(ply, ply)   -- 失血倒地
                else
                    ply:SetHealth(hp)
                end
                dirty = true
            elseif st.state == Fireteam.Vitals.STATE.DOWNED then
                if not st.stabilized and st.bleedoutEnds and now >= st.bleedoutEnds then
                    TrueDeath(ply)
                end
            end
        end
    end

    if dirty then BroadcastAll() end
end)

-- ─────────────────────────────────────
-- 救援交互：准星对准倒地队友按住 E
-- 有医疗包 → 复活（revive）；无 → 稳定伤势（stabilize）
-- ─────────────────────────────────────

local function ClearChannel(actor)
    actor.FT_ReviveChannel = nil
end

local function FindRescueTarget(actor)
    local tr = actor:GetEyeTrace()
    local tgt = tr.Entity
    if not IsValid(tgt) or not tgt:IsPlayer() then return nil, nil end
    if not Fireteam.Vitals.IsDowned(tgt) then return nil, nil end
    if actor:GetPos():Distance(tgt:GetPos()) > CHANNEL_RANGE then return nil, nil end

    local hasMedkit = Fireteam.Inventory.Get(actor, "medkit") > 0
    local kind = Fireteam.Vitals.ResolveRescueKind(hasMedkit,
        Fireteam.Vitals.GetState(tgt), tgt.FT_Vitals and tgt.FT_Vitals.stabilized or false)
    return tgt, kind
end

timer.Create("Fireteam.Vitals.Rescue", RESCUE_SCAN, 0, function()
    if not Fireteam.Vitals.IsEnabled() then return end
    local now = CurTime()

    for _, actor in ipairs(player.GetAll()) do
        local ch = actor.FT_ReviveChannel

        -- 中断条件：松开 E / 目标失效 / 自己失去能力 / 移位过大
        if ch then
            local tgt = ch.target
            local valid = IsValid(tgt) and actor:Alive()
                and Fireteam.Vitals.IsDowned(tgt)
                and actor:KeyDown(IN_USE)
                and actor:GetPos():DistToSqr(ch.anchorPos) <= CHANNEL_MOVE * CHANNEL_MOVE
            if not valid then
                ClearChannel(actor)
                BroadcastAll()
            elseif now >= ch.ends then
                if ch.kind == "revive" then
                    if Fireteam.Inventory.Consume(actor, "medkit") then
                        RevivePlayer(tgt, actor)
                    end
                else
                    tgt.FT_Vitals.stabilized = true
                    tgt.FT_Vitals.bleedoutEnds = CurTime() + (tonumber(Fireteam.Vitals.GetParam("bleedout_time")) or 60)
                    tgt:ChatPrint("[FIRETEAM] " .. Fireteam.Locale.Get("vitals_stabilized_self"))
                    BroadcastAll()
                end
                ClearChannel(actor)
            end
        else
            -- 发起新通道：按住 E 且准星有合法救援对象
            if actor:Alive()
                and not Fireteam.Vitals.IsDowned(actor)
                and actor:KeyDown(IN_USE) then
                local tgt, kind = FindRescueTarget(actor)
                if tgt and kind then
                    local duration = tonumber(Fireteam.Vitals.GetParam(
                        kind == "revive" and "revive_time" or "stabilize_time")) or 3
                    actor.FT_ReviveChannel = {
                        target = tgt, kind = kind,
                        ends = now + duration,
                        anchorPos = actor:GetPos(),
                    }
                    BroadcastAll()
                end
            end
        end
    end
end)

-- ─────────────────────────────────────
-- 生命周期衔接
-- ─────────────────────────────────────

hook.Add("PlayerSpawn", "Fireteam.Vitals.SpawnReset", function(ply)
    if istable(ply.FT_Vitals) and ply.FT_Vitals.state ~= Fireteam.Vitals.STATE.NORMAL then
        Fireteam.Vitals.Reset(ply)
    else
        ply.FT_Vitals = nil
    end
end)

-- 新回合简报：全员体征复位
hook.Add(Fireteam.HOOKS.ROUND_STATE_CHANGED, "Fireteam.Vitals.RoundReset", function(newState)
    if newState == Fireteam.Rounds.STATE.BRIEFING
        or newState == Fireteam.Rounds.STATE.WARMUP then
        for _, ply in ipairs(player.GetAll()) do
            ply.FT_Vitals = nil
            ply.FT_DownedWeapons = nil
            ply.FT_SpeedSave = nil
            ply.FT_ReviveChannel = nil
        end
        BroadcastAll()
    end
end)

hook.Add("PlayerDisconnected", "Fireteam.Vitals.Cleanup", function(ply)
    ply.FT_Vitals = nil
end)

Fireteam.Log.Info("体征", "✓ 健康/倒地系统服务端已加载")
