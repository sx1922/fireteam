-- modules/stamina/sh_stamina.lua
-- FIRETEAM Stamina System - Shared（冲刺体力）
-- 上限取职业 stats.stamina（激活 classes.lua 的死数据）；耗尽禁冲刺+移速惩罚。
-- 数值并入 FT_VitalsUpdate 快照（不另开 net 消息）；速度基准与职业数据推导对齐。

if not Fireteam then Fireteam = {} end
Fireteam.Stamina = Fireteam.Stamina or {}

Fireteam.Config.Register("stamina.enabled", true, {
    type = "boolean",
    desc = "Stamina system master switch"
})
Fireteam.Config.Register("stamina.default_max", 100, {
    type = "number", min = 20, max = 500,
    desc = "Max stamina when class has no stats.stamina"
})
Fireteam.Config.Register("stamina.drain_per_sec", 9, {
    type = "number", min = 0, max = 50,
    desc = "Stamina drain per second while sprinting"
})
Fireteam.Config.Register("stamina.regen_per_sec", 12, {
    type = "number", min = 0, max = 60,
    desc = "Stamina regen per second (after delay)"
})
Fireteam.Config.Register("stamina.regen_delay", 1.5, {
    type = "number", min = 0, max = 10,
    desc = "Seconds after last sprint before regen starts"
})
Fireteam.Config.Register("stamina.exhausted_frac", 0.15, {
    type = "number", min = 0, max = 1,
    desc = "Stamina fraction below which sprint is disabled"
})
Fireteam.Config.Register("stamina.recover_frac", 0.4, {
    type = "number", min = 0, max = 1,
    desc = "Fraction required to recover from exhaustion (hysteresis)"
})
Fireteam.Config.Register("stamina.low_speed_mult", 0.7, {
    type = "number", min = 0.1, max = 1,
    desc = "Walk speed multiplier while exhausted"
})

--- 职业体力上限；无职业数据回落 config
function Fireteam.Stamina.GetMax(ply)
    local cd = Fireteam.Class and Fireteam.Class.GetPlayerClassData
        and Fireteam.Class.GetPlayerClassData(ply) or nil
    if istable(cd) and istable(cd.stats) and tonumber(cd.stats.stamina) then
        return tonumber(cd.stats.stamina)
    end
    return tonumber(Fireteam.Config.Get("stamina.default_max")) or 100
end

--- 增减一步并夹取 [0, max]
function Fireteam.Stamina.Step(cur, delta, max)
    return math.Clamp((tonumber(cur) or 0) + (tonumber(delta) or 0), 0, math.max(tonumber(max) or 0, 0))
end

--- 力竭滞回状态机：跌破 exhausted_frac 进入力竭，须回升到 recover_frac 才解除
function Fireteam.Stamina.UpdateExhaustion(frac, exhausted)
    frac = tonumber(frac) or 0
    if exhausted then
        return frac < (tonumber(Fireteam.Config.Get("stamina.recover_frac")) or 0.4)
    end
    return frac <= (tonumber(Fireteam.Config.Get("stamina.exhausted_frac")) or 0.15)
end

--- 力竭时走路速度乘数（跑步压到与走路同速 → 等效禁冲刺）
function Fireteam.Stamina.ExhaustSpeedMult()
    return tonumber(Fireteam.Config.Get("stamina.low_speed_mult")) or 0.7
end

--- 职业 speed_mult（与 class.ApplyStats / vitals 同一推导）
function Fireteam.Stamina.ClassSpeedMult(ply)
    local cd = Fireteam.Class and Fireteam.Class.GetPlayerClassData
        and Fireteam.Class.GetPlayerClassData(ply) or nil
    if istable(cd) and istable(cd.stats) and tonumber(cd.stats.speed_mult) then
        return tonumber(cd.stats.speed_mult)
    end
    return 1
end
