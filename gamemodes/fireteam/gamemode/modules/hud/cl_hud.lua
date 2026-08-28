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
    if not IsValid(ply) then return end

    -- FPS 计数（可选，左上角）
    if Fireteam.Config.Get("hud.show_fps") then
        local fps = math.floor(1 / math.max(FrameTime(), 1e-4))
        draw.SimpleText("FPS " .. fps, kit.Font("small"),
            kit.MARGIN, kit.MARGIN, kit.Color("text_muted"), TEXT_ALIGN_LEFT)
    end

    if not ply:Alive() then return end

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
    -- 扩散源：基础 + 移动（蹲姿收敛）+ 压制 + 臂部损伤（塔科夫式，止痛药屏蔽）
    local speed = ply:GetVelocity():Length2D()
    local moveSpread = math.min(speed / 400 * 12, 14)
    if ply:Crouching() then moveSpread = moveSpread * 0.4 end
    local vt = Fireteam.Vitals and Fireteam.Vitals.Client
        and Fireteam.Vitals.Client[ply:EntIndex()] or nil
    if istable(vt) and not vt.pain and istable(vt.limbs) then
        if (vt.limbs.l_arm or 1) <= 0 or (vt.limbs.r_arm or 1) <= 0 then
            moveSpread = moveSpread + 10
        end
    end
    local gap = 6 + moveSpread + (Fireteam.HUD.SuppressionSpread or 0)
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

    local panelW, panelH = math.Round(210 * (ScrW() / 1920)), math.Round(70 * (ScrH() / 1080))
    local elem = kit.GetElement("ammo")
    local x, y = kit.ResolveAnchor(elem.position, panelW, panelH)
    local fx = kit.EffectsAlpha()

    -- Squad 式无底板：大号弹匣数 + 备弹 + 武器名（带阴影）
    local clipText = clip >= 0 and tostring(clip) or "--"
    local clipColorName = "primary"
    if clip >= 0 and clip <= 5 then clipColorName = "danger"
    elseif clip >= 0 and clip <= 10 then clipColorName = "warning" end
    local col = kit.Color(clipColorName)

    draw.SimpleText(clipText, kit.Font("title"), x + 3, y + 3,
        Color(0, 0, 0, 190 * fx), TEXT_ALIGN_LEFT)
    draw.SimpleText(clipText, kit.Font("title"), x + 2, y + 2,
        Color(col.r, col.g, col.b, 240 * fx), TEXT_ALIGN_LEFT)

    surface.SetFont(kit.Font("title"))
    local clipW = select(1, surface.GetTextSize(clipText))
    local resText = "/ " .. tostring(math.max(reserve, 0))
    local muted = kit.Color("text_muted")
    draw.SimpleText(resText, kit.Font("body"), x + 10 + clipW + 3, y + 26 + 3,
        Color(0, 0, 0, 190 * fx), TEXT_ALIGN_LEFT)
    draw.SimpleText(resText, kit.Font("body"), x + 10 + clipW, y + 26,
        Color(muted.r, muted.g, muted.b, 220 * fx), TEXT_ALIGN_LEFT)

    local wName = language.GetPhrase(weapon.PrintName or weapon:GetClass())
    draw.SimpleText(wName, kit.Font("small"), x + 3, y + 54 + 2,
        Color(0, 0, 0, 190 * fx), TEXT_ALIGN_LEFT)
    draw.SimpleText(wName, kit.Font("small"), x + 2, y + 54,
        Color(muted.r, muted.g, muted.b, 220 * fx), TEXT_ALIGN_LEFT)
end

-- ═══════════════════════════════════════
-- 生命 / 护甲
-- ═══════════════════════════════════════
function Fireteam.HUD.DrawHealth(ply)
    local panelW, panelH = math.Round(210 * (ScrW() / 1920)), math.Round(78 * (ScrH() / 1080))
    local elem = kit.GetElement("health")
    local x, y = kit.ResolveAnchor(elem.position or "bottom_left", panelW, panelH)

    kit.DrawPanel(x, y, panelW, panelH, { fillAlpha = 180 })
    kit.DrawCornerBracket(x, y, 8, "tl", "primary")
    kit.DrawCornerBracket(x + panelW, y + panelH, 8, "br", "primary")

    local padX, padY = 12, 10

    -- 医疗箱图标装饰
    local hpIcon = kit.Material("fireteam/items/medkit")
    local iconSize = math.Round(14 * (ScrH() / 1080))
    if hpIcon and not hpIcon:IsError() then
        kit.DrawIcon(hpIcon, x + panelW - padX - iconSize, y + padY - 2, iconSize, kit.ColorA("text_muted", 140))
    end

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
-- 指南针（Squad 式 bearing tape：方位字母 + 15° 数字刻度 + 中央高亮框 + 方位投影）
-- ═══════════════════════════════════════
local CARDINAL = {
    [0] = "N", [45] = "NE", [90] = "E", [135] = "SE",
    [180] = "S", [225] = "SW", [270] = "W", [315] = "NW"
}

--- 收集罗盘方位投影：存活队友（三角）/ 本小队标记（菱形）/ 回合目标（方框）
local function CollectCompassMarkers(ply, mySquad)
    local markers = {}

    if mySquad then
        for _, m in ipairs(mySquad.members or {}) do
            if m.idx ~= ply:EntIndex() and m.alive then
                local p = Entity(m.idx)
                if IsValid(p) and p:IsPlayer() and p:Alive() then
                    markers[#markers + 1] = {
                        deg   = (p:GetPos() - ply:GetPos()):Angle().y,
                        color = "squad_ally",
                        shape = "triangle"
                    }
                end
            end
        end
    end

    if Fireteam.Marker and Fireteam.Marker.GetClientMarkers then
        for _, mk in pairs(Fireteam.Marker.GetClientMarkers()) do
            if mySquad and mk.squadId == mySquad.id and isvector(mk.pos) then
                markers[#markers + 1] = {
                    deg   = (mk.pos - ply:GetPos()):Angle().y,
                    color = Fireteam.Marker.GetTypeColor(mk.type),
                    shape = "diamond"
                }
            end
        end
    end

    local obj = Fireteam.Rounds and Fireteam.Rounds.Client and Fireteam.Rounds.Client.objective or nil
    local params = obj and obj.params or nil
    if istable(params) and istable(params.pos) and params.pos.x then
        markers[#markers + 1] = {
            deg   = (Vector(params.pos.x, params.pos.y, params.pos.z) - ply:GetPos()):Angle().y,
            color = "marker_objective",
            shape = "square"
        }
    end

    return markers
end

function Fireteam.HUD.DrawCompass(ply)
    local scale = ScrW() / 1920
    local width = math.Round(520 * scale)
    local halfRange = 60                       -- 视窗 ±60°
    local pxPerDeg = width / (halfRange * 2)
    local elem = kit.GetElement("compass")
    local x, y = kit.ResolveAnchor(elem.position or "bottom_center", width, 36)
    local cx = x + width / 2
    local bandY = y + 18

    local ang = ply:EyeAngles().y
    local fx = kit.EffectsAlpha()

    kit.DrawPanel(x, y, width, 36, { fillAlpha = 130, borderColor = false })
    kit.DrawCornerBracket(x, y, 8, "tl", "primary")
    kit.DrawCornerBracket(x + width, y + 36, 8, "br", "primary")

    -- 刻度：每 5° 短线，每 15° 数字 / 方位字母（边缘 20° 渐隐）
    for deg = 0, 345, 5 do
        local diff = math.AngleDifference(deg, ang)
        if math.abs(diff) < halfRange then
            local px = cx + diff * pxPerDeg
            local fade = math.Clamp((halfRange - math.abs(diff)) / 20, 0, 1)
            if deg % 15 == 0 then
                local label = CARDINAL[deg]
                if label then
                    local col = (#label == 1) and kit.Color("primary") or kit.Color("secondary")
                    draw.SimpleText(label, kit.Font(#label == 1 and "medium" or "small"),
                        px, bandY - 6, Color(col.r, col.g, col.b, 255 * fade * fx),
                        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                else
                    local muted = kit.Color("text_muted")
                    draw.SimpleText(string.format("%03d", deg), kit.Font("small"),
                        px, bandY - 6, Color(muted.r, muted.g, muted.b, 235 * fade * fx),
                        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                surface.SetDrawColor(kit.ColorA("text_muted", 200 * fade * fx))
                surface.DrawRect(px - 1, bandY + 6, 2, 7)
            else
                surface.SetDrawColor(kit.ColorA("text_muted", 120 * fade * fx))
                surface.DrawRect(px, bandY + 8, 1, 5)
            end
        end
    end

    -- 方位投影标记（画在刻度带上方边缘）
    local mySquad = Fireteam.Squad and Fireteam.Squad.GetMySquad
        and Fireteam.Squad.GetMySquad() or nil
    for _, mk in ipairs(CollectCompassMarkers(ply, mySquad)) do
        local diff = math.AngleDifference(mk.deg, ang)
        if math.abs(diff) < halfRange - 2 then
            local px = cx + diff * pxPerDeg
            local col = kit.Color(mk.color)
            local a = math.Round(255 * math.Clamp((halfRange - math.abs(diff)) / 20, 0, 1) * fx)
            surface.SetDrawColor(col.r, col.g, col.b, a)
            draw.NoTexture()
            if mk.shape == "triangle" then
                surface.DrawPoly({
                    { x = px,     y = y + 4 },
                    { x = px - 5, y = y + 11 },
                    { x = px + 5, y = y + 11 },
                })
            elseif mk.shape == "diamond" then
                surface.DrawPoly({
                    { x = px,     y = y + 3 },
                    { x = px - 5, y = y + 8 },
                    { x = px,     y = y + 13 },
                    { x = px + 5, y = y + 8 },
                })
            else
                surface.DrawOutlinedRect(px - 5, y + 3, 10, 10, 1)
            end
        end
    end

    -- 中央高亮当前角度（白框 + 底色遮盖下方刻度）
    local boxW = math.Round(38 * scale)
    surface.SetDrawColor(kit.ColorA("background", 235))
    surface.DrawRect(cx - boxW / 2, y + 2, boxW, 32)
    surface.SetDrawColor(kit.ColorA("text", 210 * fx))
    surface.DrawOutlinedRect(cx - boxW / 2, y + 2, boxW, 32, 1)
    local display = string.format("%03d", math.Round((360 - ang) % 360) % 360)
    draw.SimpleText(display, kit.Font("small"), cx, bandY - 6,
        kit.Color("text"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- ═══════════════════════════════════════
-- 战场氛围特效层（暗角 / 颗粒 / 胶片闪烁）
-- 全部由 UI Kit 提供，参数来自主题 effects.*
-- ═══════════════════════════════════════
function Fireteam.HUD.DrawEffects(theme)
    if not theme.effects then return end
    local fx = theme.effects

    -- 旧式胶片闪烁：偶发暗帧叠加（由主题 effects.flicker 控制）
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

Fireteam.Log.Info("HUD", "✓ 客户端渲染已加载")
