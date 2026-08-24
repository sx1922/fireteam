-- modules/hud/cl_hud.lua
-- FIRETEAM HUD System - Client Rendering

if not Fireteam then Fireteam = {} end
Fireteam.HUD = Fireteam.HUD or {}

-- ═══════════════════════════════════════
-- 隐藏默认 HUD 元素
-- ═══════════════════════════════════════
local hideDefault = {
    ["CHudAmmo"] = true,
    ["CHudHealth"] = true,
    ["CHudBattery"] = true,
    ["DarkRP_HUD"] = true,
    ["DarkRP_EntityDisplay"] = true,
    ["DarkRP_LocalPlayerHUD"] = true,
    ["DarkRP_HungerBackground"] = true
}

hook.Add("HUDShouldDraw", "Fireteam.HUD.HideDefault", function(name)
    if hideDefault[name] then return false end
end)

-- ═══════════════════════════════════════
-- 主绘制
-- ═══════════════════════════════════════
hook.Add("HUDPaint", "Fireteam.HUD.Draw", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local theme = Fireteam.HUD.GetTheme()
    if not theme then return end

    local colPrimary = Fireteam.HUD.GetColor("primary")
    local colSecondary = Fireteam.HUD.GetColor("secondary")
    local colBg = Fireteam.HUD.GetColor("background")

    local fontSize = (theme.font and theme.font.size_base) or 16

    -- ═══ 准星 ═══
    Fireteam.HUD.DrawCrosshair(ply, colPrimary)

    -- ═══ 弹药（右下）═══
    Fireteam.HUD.DrawAmmo(ply, colPrimary, colSecondary, colBg)

    -- ═══ 生命/护甲（左下）═══
    Fireteam.HUD.DrawHealth(ply, colPrimary, Fireteam.HUD.GetColor("danger"), colBg)

    -- ═══ 指南针（顶部中央）═══
    Fireteam.HUD.DrawCompass(ply, colPrimary, colSecondary)

    -- ═══ 特效层 ═══
    Fireteam.HUD.DrawEffects(theme)
end)

-- ═══════════════════════════════════════
-- 准星
-- ═══════════════════════════════════════
function Fireteam.HUD.DrawCrosshair(ply, color)
    local cx, cy = ScrW() / 2, ScrH() / 2
    local gap = 6 + (Fireteam.HUD.SuppressionSpread or 0)
    local len = 8

    surface.SetDrawColor(color.r, color.g, color.b, 200)

    -- 上下左右
    surface.DrawRect(cx - 1, cy - gap - len, 2, len)   -- 上
    surface.DrawRect(cx - 1, cy + gap, 2, len)          -- 下
    surface.DrawRect(cx - gap - len, cy - 1, len, 2)   -- 左
    surface.DrawRect(cx + gap, cy - 1, len, 2)          -- 右

    -- 中心点
    surface.DrawRect(cx - 1, cy - 1, 2, 2)
end

-- ═══════════════════════════════════════
-- 弹药
-- ═══════════════════════════════════════
function Fireteam.HUD.DrawAmmo(ply, colPrimary, colSecondary, colBg)
    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) then return end

    local clip = weapon:Clip1()
    local reserve = ply:GetAmmoCount(weapon:GetPrimaryAmmoType())

    if clip < 0 and reserve < 0 then return end

    local x, y = ScrW() - 200, ScrH() - 80
    draw.RoundedBox(4, x - 10, y - 10, 200, 70, Color(colBg.r, colBg.g, colBg.b, 180))

    -- 弹匣（无弹匣武器 clip=-1，显示为 "--"）
    local clipText = clip >= 0 and tostring(clip) or "--"
    local clipColor = colPrimary
    if clip >= 0 and clip <= 5 then clipColor = Color(255, 50, 50)
    elseif clip >= 0 and clip <= 10 then clipColor = Color(255, 200, 50)
    end

    draw.SimpleText(clipText, "DermaLarge", x, y, clipColor, TEXT_ALIGN_LEFT)
    draw.SimpleText("/ " .. tostring(math.max(reserve, 0)), "DermaDefault", x + 60, y + 10, colSecondary, TEXT_ALIGN_LEFT)

    -- 武器名
    local wName = language.GetPhrase(weapon.PrintName or weapon:GetClass())
    draw.SimpleText(wName, "DermaDefault", x, y + 42, Color(180, 180, 180), TEXT_ALIGN_LEFT)
end

-- ═══════════════════════════════════════
-- 生命 / 护甲
-- ═══════════════════════════════════════
function Fireteam.HUD.DrawHealth(ply, colPrimary, colDanger, colBg)
    local x, y = 20, ScrH() - 80
    draw.RoundedBox(4, x - 10, y - 10, 200, 70, Color(colBg.r, colBg.g, colBg.b, 180))

    local hp = ply:Health()
    local maxHp = math.max(ply:GetMaxHealth(), 1)
    local armor = ply:Armor()

    local hpColor = colPrimary
    if hp <= 25 then hpColor = colDanger
    elseif hp <= 50 then hpColor = Color(255, 200, 50)
    end

    draw.SimpleText("HP " .. hp .. " / " .. maxHp, "DermaDefault", x, y, hpColor, TEXT_ALIGN_LEFT)
    draw.SimpleText("AR " .. armor, "DermaDefault", x, y + 24, Color(100, 180, 255), TEXT_ALIGN_LEFT)

    -- 生命条
    local barW = 180
    local barH = 6
    local barY = y + 48
    surface.SetDrawColor(40, 40, 40, 200)
    surface.DrawRect(x, barY, barW, barH)
    surface.SetDrawColor(hpColor.r, hpColor.g, hpColor.b, 220)
    surface.DrawRect(x, barY, barW * math.Clamp(hp / maxHp, 0, 1), barH)
end

-- ═══════════════════════════════════════
-- 指南针
-- ═══════════════════════════════════════
function Fireteam.HUD.DrawCompass(ply, colPrimary, colSecondary)
    local cx = ScrW() / 2
    local y = 30
    local width = 300

    local ang = ply:EyeAngles().y
    local directions = {
        { angle = 0,   label = "N" },
        { angle = 45,  label = "NE" },
        { angle = 90,  label = "E" },
        { angle = 135, label = "SE" },
        { angle = 180, label = "S" },
        { angle = 225, label = "SW" },
        { angle = 270, label = "W" },
        { angle = 315, label = "NW" }
    }

    -- 背景条
    draw.RoundedBox(2, cx - width / 2, y - 12, width, 24, Color(10, 10, 10, 150))

    for _, dir in ipairs(directions) do
        local diff = math.AngleDifference(dir.angle, ang)
        local px = cx + diff * (width / 120)

        if math.abs(diff) < 60 then
            local alpha = 255 * (1 - math.abs(diff) / 60)
            local isCardinal = (#dir.label == 1)
            local color = isCardinal and colPrimary or colSecondary

            draw.SimpleText(dir.label, "DermaDefault", px, y,
                Color(color.r, color.g, color.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- 中心指针
    surface.SetDrawColor(colPrimary.r, colPrimary.g, colPrimary.b, 220)
    surface.DrawRect(cx - 1, y - 14, 2, 28)

    -- 角度数字
    local displayAngle = math.floor((360 - ang) % 360)
    draw.SimpleText(displayAngle .. "\176", "DermaDefault", cx, y + 18,
        Color(200, 200, 200), TEXT_ALIGN_CENTER)
end

-- ═══════════════════════════════════════
-- 特效层（扫描线、暗角）
-- ═══════════════════════════════════════
function Fireteam.HUD.DrawEffects(theme)
    if not theme.effects then return end

    -- 扫描线
    if theme.effects.scanlines then
        surface.SetDrawColor(0, 0, 0, 15)
        for y = 0, ScrH(), 4 do
            surface.DrawRect(0, y, ScrW(), 1)
        end
    end

    -- 暗角
    if theme.effects.vignette and theme.effects.vignette > 0 then
        local strength = theme.effects.vignette * 80
        local gradient = Material("fireteam/vignette.png")
        if gradient and not gradient:IsError() then
            surface.SetDrawColor(0, 0, 0, strength)
            surface.SetMaterial(gradient)
            surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
        end
    end
end

-- ═══════════════════════════════════════
-- 接收主题同步
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.HUD_THEME, function()
    Fireteam.HUD.CurrentTheme = nil  -- 强制重新加载
    chat.AddText(Color(51, 255, 51), "[FIRETEAM] HUD theme updated.")
end)

print("[FIRETEAM:HUD] ✓ Client rendering loaded")
