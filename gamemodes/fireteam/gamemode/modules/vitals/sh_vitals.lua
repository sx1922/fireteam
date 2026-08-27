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
Fireteam.Config.Register("vitals.limbs_enabled", true, {
    type = "boolean",
    desc = "Tarkov-style per-limb HP model (black-limb debuffs / overflow to thorax)"
})
Fireteam.Config.Register("vitals.fracture_chance", 0.25, {
    type = "number", min = 0, max = 1,
    desc = "Chance of leg fracture when hit (black leg always fractures)"
})
Fireteam.Config.Register("vitals.painkiller_time", 60, {
    type = "number", min = 0, max = 300,
    desc = "Painkiller duration (seconds) — masks limp and arm sway"
})
Fireteam.Config.Register("vitals.leg_speed_mult", 0.55, {
    type = "number", min = 0.1, max = 1,
    desc = "Move speed multiplier with one leg black/fractured"
})
Fireteam.Config.Register("vitals.both_legs_speed_mult", 0.35, {
    type = "number", min = 0.1, max = 1,
    desc = "Move speed multiplier with both legs black/fractured"
})
Fireteam.Config.Register("vitals.medkit_heal_frac", 0.5, {
    type = "number", min = 0.1, max = 1,
    desc = "Fraction of max limb HP restored by a medkit"
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

-- ═══════════════════════════════════════
-- 塔科夫式七部位模型（部位基础血量；黑部位 debuff，头/胸黑 = 死亡）
-- ═══════════════════════════════════════
Fireteam.Vitals.LIMBS = {
    head    = 35,
    thorax  = 85,
    stomach = 70,
    l_arm   = 60,
    r_arm   = 60,
    l_leg   = 65,
    r_leg   = 65,
}
Fireteam.Vitals.LIMB_ORDER = { "head", "thorax", "stomach", "l_arm", "r_arm", "l_leg", "r_leg" }

--- 全新部位血量表（出生/重置用）
function Fireteam.Vitals.DefaultLimbs()
    local t = {}
    for part, hp in pairs(Fireteam.Vitals.LIMBS) do t[part] = hp end
    return t
end

--- HITGROUP → 部位 id（CHEST/GENERIC 兜底 thorax）
function Fireteam.Vitals.HitgroupToPart(hitgroup)
    if hitgroup == HITGROUP_HEAD then return "head" end
    if hitgroup == HITGROUP_STOMACH then return "stomach" end
    if hitgroup == HITGROUP_LEFTARM then return "l_arm" end
    if hitgroup == HITGROUP_RIGHTARM then return "r_arm" end
    if hitgroup == HITGROUP_LEFTLEG then return "l_leg" end
    if hitgroup == HITGROUP_RIGHTLEG then return "r_leg" end
    return "thorax"
end

--- 部位伤害入账（就地修改 limbs 表）：
--- 已黑部位的伤害整笔转移 thorax（塔科夫规则）；
--- head 或 thorax 归零返回 true（部位致死，跳过倒地）。
function Fireteam.Vitals.ApplyPartDamage(limbs, part, dmg)
    dmg = tonumber(dmg) or 0
    if part ~= "thorax" and (limbs[part] or 0) <= 0 then
        part = "thorax"
    end
    local hp = (limbs[part] or 0) - dmg
    if hp < 0 then hp = 0 end
    limbs[part] = hp
    return (limbs.head or 1) <= 0 or (limbs.thorax or 1) <= 0
end

Fireteam.Log.Info("Vitals", "✓ 共享定义已加载")
