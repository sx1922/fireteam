-- modules/suppression/sv_suppression.lua
-- FIRETEAM Suppression System - Server

if not Fireteam then Fireteam = {} end
Fireteam.Suppression = Fireteam.Suppression or {}

local suppressionValues = {}  -- [Player] = { value, lastHit }

-- ═══════════════════════════════════════
-- 子弹飞过时增加压制
-- ═══════════════════════════════════════
hook.Add("EntityFireBullets", "Fireteam.Suppression.TrackShots", function(ply, data)
    -- 记录射击事件用于后续检测
    ply.FT_LastShotTime = CurTime()
    ply.FT_LastShotPos = data.Src
    ply.FT_LastShotAng = data.Ang
end)

-- 定时检测子弹是否经过附近玩家
timer.Create("Fireteam.Suppression.Update", 0.1, 0, function()
    for _, shooter in ipairs(player.GetAll()) do
        if not shooter.FT_LastShotTime then continue end
        if CurTime() - shooter.FT_LastShotTime > 0.15 then continue end

        local src = shooter.FT_LastShotPos
        local ang = shooter.FT_LastShotAng
        if not src or not ang then continue end

        local dir = ang:Forward()
        local maxLen = 5000

        for _, target in ipairs(player.GetAll()) do
            if target == shooter then continue end
            if not target:Alive() then continue end

            -- 计算目标到射线的距离
            local targetPos = target:GetPos() + Vector(0, 0, 40)
            local closest = src + dir * math.Clamp(
                (targetPos - src):Dot(dir), 0, maxLen
            )
            local distToLine = targetPos:Distance(closest)

            -- 距离 < 100 单位视为"子弹飞过"
            if distToLine < 100 then
                Fireteam.Suppression.Add(target, 0.3 * (1 - distToLine / 100))
            end
        end

        shooter.FT_LastShotTime = nil
    end
end)

-- ═══════════════════════════════════════
-- 增加压制值
-- ═══════════════════════════════════════
function Fireteam.Suppression.Add(ply, amount)
    if not IsValid(ply) then return end

    if not suppressionValues[ply] then
        suppressionValues[ply] = { value = 0, lastHit = 0 }
    end

    suppressionValues[ply].value = math.Clamp(suppressionValues[ply].value + amount, 0, 1)
    suppressionValues[ply].lastHit = CurTime()

    -- 同步给客户端
    net.Start(Fireteam.NET.SUPPRESSION_UPDATE)
        net.WriteFloat(suppressionValues[ply].value)
    net.Send(ply)
end

-- ═══════════════════════════════════════
-- 衰减
-- ═══════════════════════════════════════
timer.Create("Fireteam.Suppression.Decay", 0.5, 0, function()
    for ply, data in pairs(suppressionValues) do
        if not IsValid(ply) then
            suppressionValues[ply] = nil
            continue
        end

        -- 3 秒无新压制则开始衰减
        if CurTime() - data.lastHit > 3 then
            data.value = math.max(0, data.value - 0.1)

            net.Start(Fireteam.NET.SUPPRESSION_UPDATE)
                net.WriteFloat(data.value)
            net.Send(ply)

            if data.value <= 0 then
                suppressionValues[ply] = nil
            end
        end
    end
end)

-- 玩家断开清理
hook.Add("PlayerDisconnected", "Fireteam.Suppression.Cleanup", function(ply)
    suppressionValues[ply] = nil
end)

Fireteam.Log.Info("Suppression", "✓ 服务端逻辑已加载")
