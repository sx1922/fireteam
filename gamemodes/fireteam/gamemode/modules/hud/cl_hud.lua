-- modules/hud/cl_hud.lua
-- FIRETEAM HUD System - Client Rendering
-- 全部颜色经 Fireteam.UI.Color 语义名获取，布局消费 hud_theme.json elements.*。

if not Fireteam then Fireteam = {} end
Fireteam.HUD = Fireteam.HUD or {}

local kit = Fireteam.UI

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

    -- ═══ 准星 ═══
    Fireteam.HUD.DrawCrosshair(ply, kit.Color("primary"))

    -- ═══ 弹药（位置由 elements.ammo 决定）═══
    Fireteam.HUD.DrawAmmo(ply)

    -- ═══ 生命/护甲（位置由 elements.health 决定）═══
    Fireteam.HUD.DrawHealth(ply)

    -- ═══ 指南针（位置由 elements.compass 决定）═══
    Fireteam.HUD.DrawCompass(ply)

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

    surface.SetDrawColor(color.r, color.g, color.b, 200 * kit.EffectsAlpha())

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
function Fireteam.HUD.DrawAmmo(ply)
    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) then return end

    local clip = weapon:Clip1()
    local reserve = ply:GetAmmoCount(weapon:GetPrimaryAmmoType())
    if clip < 0 and reserve < 0 then return end

    local panelW, panelH = math.Round(210 * (ScrW() / 1920)), math.Round(78 * (ScrH() / 1080))
    local elem = kit.GetElement("ammo")
    local x, y = kit.ResolveAnchor(elem.position, panelW, panelH)

    kit.DrawPanel(x, y, panelW, panelH, { fillAlpha = 180 })

    local padX, padY = 12, 10
    local textX, textY = x + padX, y + padY

    -- 弹匣（无弹匣武器 clip=-1，显示为 "--"）
    local clipText = clip >= 0 and tostring(clip) or "--"
    local clipColorName = "primary"
    if clip >= 0 and clip <= 5 then clipColorName = "danger"
    elseif clip >= 0 and clip <= 10 then clipColorName = "warning"
    end

    draw.SimpleText(clipText, kit.Font("num"), textX, textY,
        kit.Color(clipColorName), TEXT_ALIGN_LEFT)
    draw.SimpleText("/ " .. tostring(math.max(reserve, 0)), kit.Font("body"),
        textX + 64, textY + 10, kit.Color("secondary"), TEXT_ALIGN_LEFT)

    -- 武器名
    local wName = language.GetPhrase(weapon.PrintName or weapon:GetClass())
    draw.SimpleText(wName, kit.Font("small"), textX, textY + 42,
        kit.Color("text_muted"), TEXT_ALIGN_LEFT)
end

-- ═══════════════════════════════════════
-- 生命 / 护甲
-- ═══════════════════════════════════════
function Fireteam.HUD.DrawHealth(ply)
    local panelW, panelH = math.Round(210 * (ScrW() / 1920)), math.Round(78 * (ScrH() / 1080))
    local elem = kit.GetElement("health")
    local x, y = kit.ResolveAnchor(elem.position or "bottom_left", panelW, panelH)

    kit.DrawPanel(x, y, panelW, panelH, { fillAlpha = 180 })

    local padX, padY = 12, 10
    local hp = ply:Health()
    local maxHp = math.max(ply:GetMaxHealth(), 1)
    local armor = ply:Armor()

    local hpColorName = "primary"
    if hp <= 25 then hpColorName = "danger"
    elseif hp <= 50 then hpColorName = "warning"
    end

    draw.SimpleText("HP " .. hp .. " / " .. maxHp, kit.Font("body"),
        x + padX, y + padY, kit.Color(hpColorName), TEXT_ALIGN_LEFT)
    draw.SimpleText("AR " .. armor, kit.Font("body"),
        x + padX, y + padY + 24, kit.Color("info"), TEXT_ALIGN_LEFT)

    kit.DrawProgressBar(x + padX, y + padY + 48, panelW - padX * 2, 6,
        hp / maxHp, hpColorName)
end

-- ═══════════════════════════════════════
-- 指南针
-- ═══════════════════════════════════════
function Fireteam.HUD.DrawCompass(ply)
    local width = math.Round(320 * (ScrW() / 1920))
    local elem = kit.GetElement("compass")
    local x, y = kit.ResolveAnchor(elem.position or "top_center", width, 44)
    local cx = x + width / 2
    local bandY = y + 12

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
    kit.DrawPanel(x, bandY - 12, width, 24, { fillAlpha = 150, borderColor = false })

    for _, dir in ipairs(directions) do
        local diff = math.AngleDifference(dir.angle, ang)
        local px = cx + diff * (width / 120)

        if math.abs(diff) < 60 then
            local alpha = 255 * (1 - math.abs(diff) / 60)
            local isCardinal = (#dir.label == 1)
            local col = isCardinal and kit.Color("primary") or kit.Color("secondary")

            draw.SimpleText(dir.label, kit.Font(isCardinal and "medium" or "small"), px, bandY,
                Color(col.r, col.g, col.b, alpha * kit.EffectsAlpha()),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- 中心指针
    surface.SetDrawColor(kit.ColorA("primary", 220 * kit.EffectsAlpha()))
    surface.DrawRect(cx - 1, bandY - 14, 2, 28)

    -- 角度数字
    local displayAngle = math.floor((360 - ang) % 360)
    draw.SimpleText(displayAngle .. "\176", kit.Font("small"), cx, bandY + 20,
        kit.Color("text_muted"), TEXT_ALIGN_CENTER)
end

-- ═══════════════════════════════════════
-- 特效层（扫描线 / 暗角 / 颗粒 / CRT 闪烁）
-- 全部由 UI Kit 提供，参数来自主题 effects.*
-- ═══════════════════════════════════════
function Fireteam.HUD.DrawEffects(theme)
    if not theme.effects then return end
    local fx = theme.effects

    -- CRT 整体闪烁：偶发暗帧叠加
    local flickerAlpha = 0
    if fx.flicker then
        local t = CurTime()
        if math.sin(t * 13.7) > 0.995 then
            flickerAlpha = 26
        elseif math.sin(t * 3.1 + 1.7) > 0.999 then
            flickerAlpha = 14
        end
    end
    if flickerAlpha > 0 then
        surface.SetDrawColor(0, 0, 0, flickerAlpha)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end

    if fx.scanlines then
        kit.DrawScanlines(math.Round(15 * kit.EffectsAlpha()))
    end

    if fx.vignette and fx.vignette > 0 then
        kit.DrawVignette(fx.vignette)
    end

    if fx.grain and fx.grain > 0 then
        kit.DrawGrain(fx.grain)
    end
end

-- ═══════════════════════════════════════
-- 接收主题同步
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.HUD_THEME, function()
    Fireteam.HUD.ResetThemeCache()
    chat.AddText(kit.Color("primary"), "[FIRETEAM] "
        .. Fireteam.Locale.Get("hud_theme_updated"))
end)

print("[FIRETEAM:HUD] ✓ Client rendering loaded")
