-- modules/ballistics/sh_ballistics.lua
-- FIRETEAM Ballistics System

if not Fireteam then Fireteam = {} end
Fireteam.Ballistics = Fireteam.Ballistics or {}

-- 物理常量
Fireteam.Ballistics.GRAVITY = 600        -- GMod 默认重力
Fireteam.Ballistics.METER_TO_UNITS = 52.5 -- 1 米 ≈ 52.5 单位

-- ═══════════════════════════════════════
-- 计算子弹下坠
-- ═══════════════════════════════════════
--- @param muzzleVel number   枪口速度 (m/s)
--- @param distance number    距离 (units)
--- @return number            下坠量 (units)
function Fireteam.Ballistics.CalcDrop(muzzleVel, distance)
    if not Fireteam.Config.Get("ballistics.bullet_drop") then
        return 0
    end

    local distMeters = distance / Fireteam.Ballistics.METER_TO_UNITS
    local flightTime = distMeters / muzzleVel
    local dropMeters = 0.5 * 9.81 * flightTime * flightTime
    return dropMeters * Fireteam.Ballistics.METER_TO_UNITS
end

-- ═══════════════════════════════════════
-- 计算飞行时间
-- ═══════════════════════════════════════
--- @param muzzleVel number   枪口速度 (m/s)
--- @param distance number    距离 (units)
--- @return number            飞行时间 (秒)
function Fireteam.Ballistics.CalcFlightTime(muzzleVel, distance)
    local distMeters = distance / Fireteam.Ballistics.METER_TO_UNITS
    return distMeters / muzzleVel
end

-- ═══════════════════════════════════════
-- 计算伤害衰减
-- ═══════════════════════════════════════
--- @param baseDamage number    基础伤害
--- @param distance number      距离 (units)
--- @param effectiveRange number 有效射程 (units)
--- @return number              实际伤害
function Fireteam.Ballistics.CalcDamage(baseDamage, distance, effectiveRange)
    if distance <= effectiveRange then
        return baseDamage
    end

    -- 超出有效射程后线性衰减
    local falloff = math.Clamp(1 - (distance - effectiveRange) / (effectiveRange * 2), 0.2, 1)
    return baseDamage * falloff
end

-- ═══════════════════════════════════════
-- 服务端：拦截射击事件应用弹道
-- （注意：EntityFireBullets 回调返回 true 会取消默认开火，
--   这里只修改 data.Ang，绝不 return true）
-- ═══════════════════════════════════════
if SERVER then
    hook.Add("EntityFireBullets", "Fireteam.Ballistics.Apply", function(ply, data)
        if not Fireteam.Config.Get("ballistics.bullet_drop") then return end

        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) then return end

        -- 从武器接口获取数据
        local ftData = Fireteam.WeaponInterface.Get(weapon:GetClass())
        if not ftData then return end

        -- 应用下坠（估算枪口速度：有效射程单位 → 米，近似作 m/s）
        local muzzleVel = math.max((ftData.effectiveRange or 300) / 52.5, 100)
        local trace = ply:GetEyeTrace()
        local dist = ply:GetShootPos():Distance(trace.HitPos)

        local drop = Fireteam.Ballistics.CalcDrop(muzzleVel, dist)
        if drop > 0.5 then
            -- 抬高枪口补偿下坠（向下偏移弹着点 → 反向抬高射角）
            local src = data.Src or ply:GetShootPos()
            local angle = (trace.HitPos - src):Angle()
            angle.p = angle.p + math.deg(math.atan(drop / math.max(dist, 1)))
            data.Ang = angle
        end
        -- 无返回值：让引擎继续按修改后的弹道发射
    end)

    -- 伤害修正
    hook.Add("ScalePlayerDamage", "Fireteam.Ballistics.DamageFalloff", function(ply, hitgroup, dmginfo)
        local attacker = dmginfo:GetAttacker()
        if not IsValid(attacker) or not attacker:IsPlayer() then return end

        local weapon = attacker:GetActiveWeapon()
        if not IsValid(weapon) then return end

        local ftData = Fireteam.WeaponInterface.Get(weapon:GetClass())
        if not ftData then return end

        local dist = attacker:GetShootPos():Distance(ply:GetPos())
        local newDamage = Fireteam.Ballistics.CalcDamage(
            dmginfo:GetDamage(), dist, ftData.effectiveRange or 300
        )
        dmginfo:SetDamage(newDamage)
    end)
end

Fireteam.Log.Info("Ballistics", "✓ 系统已加载")
