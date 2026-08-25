-- modules/suppression/cl_suppression.lua
-- FIRETEAM Suppression System - Client Effects

if not Fireteam then Fireteam = {} end
Fireteam.Suppression = Fireteam.Suppression or {}
-- 模块加载顺序随机，此处自持防护（HUD 模块读取该字段）
Fireteam.HUD = Fireteam.HUD or {}

local currentSuppression = 0
Fireteam.HUD.SuppressionSpread = 0  -- 供 HUD 准星使用

-- 接收压制值
net.Receive(Fireteam.NET.SUPPRESSION_UPDATE, function()
    currentSuppression = net.ReadFloat()
end)

-- ═══════════════════════════════════════
-- 视觉/音频效果
-- ═══════════════════════════════════════
hook.Add("RenderScreenspaceEffects", "Fireteam.Suppression.Effects", function()
    if currentSuppression <= 0.1 then return end

    local level = Fireteam.Suppression.GetLevel(currentSuppression)

    -- 模糊（中等以上）
    if level >= 2 then
        local blurAmount = (currentSuppression - 0.2) * 15
        DrawMotionBlur(0.1, blurAmount, 0.01)
    end

    -- 边缘变暗（严重）
    if level >= 3 then
        local vignetteStrength = currentSuppression * 120
        surface.SetDrawColor(0, 0, 0, vignetteStrength)
        surface.DrawRect(0, 0, ScrW(), 60)
        surface.DrawRect(0, ScrH() - 60, ScrW(), 60)
        surface.DrawRect(0, 0, 60, ScrH())
        surface.DrawRect(ScrW() - 60, 0, 60, ScrH())
    end
end)

-- ═══════════════════════════════════════
-- 准星扩散（供 HUD 模块读取）
-- ═══════════════════════════════════════
hook.Add("Think", "Fireteam.Suppression.UpdateSpread", function()
    Fireteam.HUD.SuppressionSpread = currentSuppression * 30
end)

-- ═══════════════════════════════════════
-- 屏幕震动（严重/压制）
-- ═══════════════════════════════════════
hook.Add("CalcView", "Fireteam.Suppression.Shake", function(ply, pos, angles, fov)
    if currentSuppression < 0.6 then return end

    local intensity = (currentSuppression - 0.6) * 8
    local time = CurTime() * 15

    angles.p = angles.p + math.sin(time) * intensity * 0.3
    angles.y = angles.y + math.cos(time * 1.3) * intensity * 0.2
    angles.r = angles.r + math.sin(time * 0.7) * intensity * 0.1

    return { origin = pos, angles = angles, fov = fov }
end)

-- ═══════════════════════════════════════
-- 压制提示
-- ═══════════════════════════════════════
hook.Add("HUDPaint", "Fireteam.Suppression.Indicator", function()
    if currentSuppression < 0.3 then return end

    local level = Fireteam.Suppression.GetLevel(currentSuppression)
    local texts = { "", "SUPPRESSED", "HEAVY FIRE", "PINNED DOWN", "PINNED DOWN" }
    local colors = {
        Color(255, 255, 255, 0),
        Color(255, 200, 50),
        Color(255, 120, 0),
        Color(255, 50, 50),
        Color(255, 50, 50)
    }

    local text = texts[level + 1] or ""
    local color = colors[level + 1] or Color(255, 255, 255)

    if text ~= "" then
        local alpha = 150 + math.sin(CurTime() * 5) * 100
        draw.SimpleText(text, "DermaLarge", ScrW() / 2, ScrH() * 0.35,
            Color(color.r, color.g, color.b, alpha), TEXT_ALIGN_CENTER)
    end
end)

print("[FIRETEAM:Suppression] ✓ Client effects loaded")
