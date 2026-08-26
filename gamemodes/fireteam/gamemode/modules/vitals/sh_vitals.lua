-- modules/vitals/sh_vitals.lua
-- FIRETEAM Vitals System - Shared（健康/出血/倒地）
-- 参数三级解析：剧本 scenario.vitals > 包级 map_rules.vitals > config 兜底。
-- 机制归框架，数值归数据（与 pve 的 GetPackPvE 同一模式）。

if not Fireteam then Fireteam = {} end
Fireteam.Vitals = Fireteam.Vitals or {}

Fireteam.Vitals.STATE = {
    NORMAL = "normal",
    DOWNED = "downed",   -- 倒地濒死：可被补刀 / 稳定 / 复活
    DEAD   = "dead"
}

-- ═══════════════════════════════════════
-- 配置兜底（F10 可调；设定包可整体覆盖）
-- ═══════════════════════════════════════
Fireteam.Config.Register("vitals.enabled", true, {
    type = "boolean",
    desc = "Vitals system master switch (bleeding/downed/revive)"
})
Fireteam.Config.Register("vitals.head_mult", 2.5, {
    type = "number", min = 0, max = 10,
    desc = "Headshot damage multiplier"
})
Fireteam.Config.Register("vitals.chest_mult", 1.0, {
    type = "number", min = 0, max = 10,
    desc = "Chest damage multiplier"
})
Fireteam.Config.Register("vitals.stomach_mult", 0.85, {
    type = "number", min = 0, max = 10,
    desc = "Stomach damage multiplier"
})
Fireteam.Config.Register("vitals.limb_mult", 0.6, {
    type = "number", min = 0, max = 10,
    desc = "Limb damage multiplier"
})
Fireteam.Config.Register("vitals.max_bleed_stacks", 5, {
    type = "number", min = 0, max = 20,
    desc = "Max bleeding stacks"
})
Fireteam.Config.Register("vitals.bleed_dps_per_stack", 1.2, {
    type = "number", min = 0, max = 20,
    desc = "HP loss per second per bleeding stack"
})
Fireteam.Config.Register("vitals.bleedout_time", 60, {
    type = "number", min = 10, max = 600,
    desc = "Downed bleed-out timer (seconds)"
})
Fireteam.Config.Register("vitals.stabilize_time", 3.5, {
    type = "number", min = 1, max = 30,
    desc = "Channel time to stabilize a downed teammate"
})
Fireteam.Config.Register("vitals.revive_time", 7, {
    type = "number", min = 1, max = 60,
    desc = "Medic revive channel time (consumes medkit)"
})
Fireteam.Config.Register("vitals.revive_health_frac", 0.4, {
    type = "number", min = 0.05, max = 1,
    desc = "HP fraction restored on revive"
})
Fireteam.Config.Register("vitals.downed_speed", 40, {
    type = "number", min = 10, max = 150,
    desc = "Move speed while downed"
})
Fireteam.Config.Register("vitals.finish_damage", 25, {
    type = "number", min = 1, max = 200,
    desc = "Single hit damage that finishes a downed player"
})

--- 参数解析：剧本 vitals 块 > 包级 vitals 块 > config
function Fireteam.Vitals.GetParam(name)
    local ok, scenario = pcall(function()
        return Fireteam.Rounds.ResolveScenario()
    end)
    if ok and istable(scenario) and istable(scenario.vitals) and scenario.vitals[name] ~= nil then
        return scenario.vitals[name]
    end

    local mr = Fireteam.Setting.GetData and Fireteam.Setting.GetData("map_rules") or nil
    if istable(mr) and istable(mr.vitals) and mr.vitals[name] ~= nil then
        return mr.vitals[name]
    end

    return Fireteam.Config.Get("vitals." .. name)
end

-- ═══════════════════════════════════════
-- 纯函数（harness 可测）
-- ═══════════════════════════════════════

--- 部位倍率结算。hitgroup 为 GMod HITGROUP_* 枚举。
function Fireteam.Vitals.ScaleHitgroupDamage(damage, hitgroup, mults)
    mults = mults or {}
    local mult = 1
    if hitgroup == HITGROUP_HEAD then
        mult = tonumber(mults.head_mult) or 1
    elseif hitgroup == HITGROUP_STOMACH then
        mult = tonumber(mults.stomach_mult) or 1
    elseif hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM
        or hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG then
        mult = tonumber(mults.limb_mult) or 1
    else
        mult = tonumber(mults.chest_mult) or 1   -- 胸部与通用兜底
    end
    return damage * mult
end

--- 出血层数累积上限
function Fireteam.Vitals.AddBleedStack(current, add, maxStacks)
    return math.Clamp((tonumber(current) or 0) + (tonumber(add) or 0), 0, maxStacks or 0)
end

--- 每跳出血伤害
function Fireteam.Vitals.BleedTickDamage(stacks, dpsPerStack, interval)
    return (tonumber(stacks) or 0) * (tonumber(dpsPerStack) or 0) * (tonumber(interval) or 1)
end

--- 决定对倒地者的救援方式：
--- 有医疗包 → revive；否则未稳定 → stabilize；否则无事可做。
--- @return string|nil kind
function Fireteam.Vitals.ResolveRescueKind(hasMedkit, targetState, targetStabilized)
    if targetState ~= Fireteam.Vitals.STATE.DOWNED then return nil end
    if hasMedkit then return "revive" end
    if not targetStabilized then return "stabilize" end
    return nil
end

print("[FIRETEAM:Vitals] ✓ Shared definitions loaded")
