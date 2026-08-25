-- modules/tacmap/cl_tacmap_ui.lua
-- FIRETEAM Tactical Map - Client UI
-- M 键开关；程序化纸质图纸画布：网格/折痕/小队成员/标记/点击放路点。
-- 边界优先级：设定包 map_rules.map.bounds > 服务端 MAP_INFO > navmesh 推算 > 兜底方框。

if not Fireteam then Fireteam = {} end
Fireteam.TacMap = Fireteam.TacMap or {}

local kit = Fireteam.UI
local L = Fireteam.Locale.Get

-- ═══════════════════════════════════════
-- 地图边界
-- ═══════════════════════════════════════
local serverBounds = nil   -- 服务端 MAP_INFO 下发的包定义边界

net.Receive(Fireteam.NET.MAP_INFO, function()
    if net.ReadBool() then
        local vmin = net.ReadVector()
        local vmax = net.ReadVector()
        serverBounds = { vmin = vmin, vmax = vmax }
    else
        serverBounds = nil
    end
end)

--- 解析最终可用边界（三级回退）
local function ResolveBounds()
    if serverBounds then return serverBounds.vmin, serverBounds.vmax end

    -- navmesh 自动推算（有导航网格的地图精度不错）
    if navmesh and navmesh.GetAllAreas then
        local ok, areas = pcall(navmesh.GetAllAreas)
        if ok and istable(areas) and next(areas) then
            local minx, miny = math.huge, math.huge
            local maxx, maxy = -math.huge, -math.huge
            for _, area in pairs(areas) do
                local c = area:GetCenter()
                minx, miny = math.min(minx, c.x), math.min(miny, c.y)
                maxx, maxy = math.max(maxx, c.x), math.max(maxy, c.y)
            end
            local pad = 512
            return Vector(minx - pad, miny - pad, 0), Vector(maxx + pad, maxy + pad, 0)
        end
    end

    local he = Fireteam.TacMap.FALLBACK_HALF_EXTENT
    return Vector(-he, -he, 0), Vector(he, he, 0)
end

-- ═══════════════════════════════════════
-- 世界 ↔ 图纸 线性投影
-- ═══════════════════════════════════════
local function BuildTransform(vmin, vmax, px, py, pw, ph)
    local worldW = math.max(vmax.x - vmin.x, 1)
    local worldH = math.max(vmax.y - vmin.y, 1)
    local scale = math.min(pw / worldW, ph / worldH) * 0.94

    local offX = px + (pw - worldW * scale) / 2
    local offY = py + (ph - worldH * scale) / 2

    local t = {}
    t.ToScreen = function(pos)
        return offX + (pos.x - vmin.x) * scale,
               offY + (pos.y - vmin.y) * scale
    end
    t.ToWorld = function(sx, sy)
        return Vector(vmin.x + (sx - offX) / scale,
                      vmin.y + (sy - offY) / scale, 0)
    end
    t.scale = scale
    t.offX, t.offY = offX, offY
    t.w, t.h = worldW * scale, worldH * scale
    return t
end

-- 标记类型符号与说明
local MARKER_GLYPH = {
    waypoint  = "◆",
    enemy     = "✖",
    objective = "◎",
    danger    = "!",
    rally     = "⚑",
    medical   = "+"
}

-- ═══════════════════════════════════════
-- 面板
-- ═══════════════════════════════════════
local tacmapPanel = nil
local canvas = nil

local function CloseMap()
    if IsValid(tacmapPanel) then
        tacmapPanel:Remove()
    end
end

function Fireteam.TacMap.Open()
    if not Fireteam.Config.Get("tacmap.enabled") then return end
    if IsValid(tacmapPanel) then return end

    local W = math.Round(ScrW() * 0.86)
    local H = math.Round(ScrH() * 0.86)
    tacmapPanel = kit.CreateFrame(L("ui_tacmap_title"), W, H, {
        blur = false,
        draggable = false,
        hints = { L("ui_hint_m_close"),
                  L("ui_hint_click_place") }
    })

    canvas = vgui.Create("DPanel", tacmapPanel)
    canvas:Dock(FILL)
    canvas:DockMargin(10, tacmapPanel.ftContentTop + 4, 10, tacmapPanel.ftContentBottom + 8)
    canvas:SetCursor("crosshair")

    local mySquadAtBuild = Fireteam.Squad.GetMySquad()

    canvas.Paint = function(s, pw, ph)
        local vmin, vmax = ResolveBounds()
        local tf = BuildTransform(vmin, vmax, 0, 0, pw, ph)
        s.ftTransform = tf

        local x0, y0 = tf.offX, tf.offY
        local x1, y1 = tf.offX + tf.w, tf.offY + tf.h
        local effectsAlpha = kit.EffectsAlpha()

        -- ── 纸面底色 ──
        draw.RoundedBox(2, x0, y0, tf.w, tf.h, kit.ColorA("background", 235))

        -- paper_fold 折痕（三等分纵折痕 + 微弱对角晕影）
        local style = (kit.GetElement("map").style or "")
        if style == "paper_fold" or style == "" then
            surface.SetDrawColor(kit.ColorA("border", 45))
            for i = 1, 2 do
                surface.DrawRect(x0 + tf.w * i / 3, y0, 1, tf.h)
            end
        end

        -- ── 网格 ──
        local gridStep = Fireteam.Config.Get("tacmap.grid_step") or 1024
        local screenStep = gridStep * tf.scale
        if screenStep >= 24 then
            surface.SetDrawColor(kit.ColorA("border", 60))
            local gx = x0 % screenStep
            while gx <= x1 do
                if gx >= x0 then surface.DrawRect(gx, y0, 1, tf.h) end
                gx = gx + screenStep
            end
            local gy = y0 % screenStep
            while gy <= y1 do
                if gy >= y0 then surface.DrawRect(x0, gy, tf.w, 1) end
                gy = gy + screenStep
            end
        end

        -- ── 比例尺（右下）──
        local metersPerGrid = math.Round(gridStep / 52.5)
        draw.SimpleText(L("ui_tacmap_scale", metersPerGrid),
            kit.Font("small"), x1 - 6, y1 + 6,
            kit.Color("text_muted"), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        -- ── 指北标 ──
        draw.SimpleText("N ▲", kit.Font("small"),
            x0 + 6, y0 - 16, kit.Color("text_muted"),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

        local meIdx = LocalPlayer():EntIndex()

        -- ── 小队成员 ──
        local mySquad = Fireteam.Squad.GetMySquad() or mySquadAtBuild
        if mySquad then
            for _, m in ipairs(mySquad.members or {}) do
                local ent = Entity(m.idx)
                if IsValid(ent) and ent:IsPlayer() then
                    local sx, sy = tf.ToScreen(ent:GetPos())
                    if sx >= x0 and sx <= x1 and sy >= y0 and sy <= y1 then
                        local colorName = m.idx == meIdx and "primary"
                            or m.idx == mySquad.leaderIdx and "squad_leader"
                            or "squad_ally"
                        if not ent:Alive() then colorName = "danger" end

                        local col = kit.Color(colorName)
                        -- 头部朝向短线
                        local yaw = math.rad(ent:EyeAngles().y + 90)
                        surface.SetDrawColor(col.r, col.g, col.b, 230)
                        surface.DrawLine(sx, sy,
                            sx + math.cos(yaw) * 10, sy + math.sin(yaw) * 10)
                        -- 圆点（近似：实心小方块 + 头部朝向线）
                        draw.RoundedBox(0, sx - 3, sy - 3, 6, 6, col)
                    end
                end
            end
        end

        -- ── 标记 ──
        local markers = Fireteam.Marker.GetClientMarkers and Fireteam.Marker.GetClientMarkers() or {}
        for _, marker in pairs(markers) do
            if not mySquad or marker.squadId ~= mySquad.id then continue end
            if not isvector(marker.pos) then continue end

            local sx, sy = tf.ToScreen(marker.pos)
            if sx < x0 or sx > x1 or sy < y0 or sy > y1 then continue end

            local col = Fireteam.Marker.GetTypeColor(marker.type)
            local glyph = MARKER_GLYPH[marker.type] or "?"
            local remaining = marker.expiresAt and (marker.expiresAt - CurTime()) or nil

            -- 底片
            draw.RoundedBox(3, sx - 9, sy - 9, 18, 18,
                Color(col.r, col.g, col.b, 60))
            surface.SetDrawColor(col.r, col.g, col.b, 220)
            surface.DrawOutlinedRect(sx - 9, sy - 9, 18, 18, 1)
            draw.SimpleText(glyph, kit.Font("body"), sx, sy - 1,
                col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- 标签 + 剩余时间
            local label = marker.label and marker.label ~= "" and marker.label or nil
            if label then
                draw.SimpleText(label, kit.Font("small"),
                    sx, sy + 12, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end
            if remaining and remaining > 0 and remaining < 30 then
                draw.SimpleText(tostring(math.ceil(remaining)) .. "s",
                    kit.Font("small"), sx, sy + (label and 24 or 12),
                    kit.ColorA("warning", 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end
        end

        -- ── 回合目标区域（rounds 模块可选联动）──
        if Fireteam.Rounds and Fireteam.Rounds.IsEnabled
            and Fireteam.Rounds.Client and Fireteam.Rounds.Client.objective then
            local obj = Fireteam.Rounds.Client.objective
            local prm = obj.params
            if istable(prm) and istable(prm.pos) and prm.pos.x then
                local wx, wy = tf.ToScreen(Vector(tonumber(prm.pos.x), tonumber(prm.pos.y), tonumber(prm.pos.z) or 0))
                local pr = (tonumber(prm.radius) or 120) * tf.scale
                local col = kit.Color("marker_objective")
                surface.SetDrawColor(col.r, col.g, col.b, 210)
                local segs = 40
                local px0, py0
                for i = 0, segs do
                    local a = i / segs * math.pi * 2
                    local px, py = wx + math.cos(a) * pr, wy + math.sin(a) * pr
                    if px0 then surface.DrawLine(px0, py0, px, py) end
                    px0, py0 = px, py
                end
                draw.SimpleText("◎", kit.Font("body"), wx, wy - 1, col,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                if obj.name and obj.name ~= "" then
                    draw.SimpleText(obj.name, kit.Font("small"),
                        wx, wy + pr + 4, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end
            end
        end

        -- ── 外框（双线）──
        surface.SetDrawColor(kit.ColorA("primary", 180))
        surface.DrawOutlinedRect(x0, y0, tf.w, tf.h, 1)
        surface.DrawOutlinedRect(x0 - 4, y0 - 4, tf.w + 8, tf.h + 8, 1)
    end

    -- 点击放路点
    canvas.OnMousePressed = function(s, code)
        if code ~= MOUSE_LEFT then return end
        if not Fireteam.Config.Get("tacmap.allow_click_place") then return end
        if not Fireteam.Squad.GetMySquad() then
            chat.AddText(kit.Color("danger"), "[FIRETEAM] "
                .. L("marker_need_squad"))
            return
        end

        local mx, my = s:CursorPos()
        local tf = s.ftTransform
        if not tf then return end

        local wx, wy = tf.ToWorld(mx, my)
        -- 从空中向下打地面
        local tr = util.TraceLine({
            start = Vector(wx, wy, 32000),
            endpos = Vector(wx, wy, -32000),
            mask = MASK_SOLID_BRUSHONLY
        })
        local pos = tr.HitPos + tr.HitNormal * 5

        net.Start(Fireteam.NET.MARKER_PLACE)
            net.WriteVector(pos)
            net.WriteString(Fireteam.Marker.TYPE.WAYPOINT)
            net.WriteString("")
        net.SendToServer()

        chat.AddText(kit.Color("info"), "[FIRETEAM] " .. L("marker_placed"))
        timer.Simple(0.3, CloseMap)
    end
end

function Fireteam.TacMap.Toggle()
    if IsValid(tacmapPanel) then
        CloseMap()
    else
        Fireteam.TacMap.Open()
    end
end

-- 开关按键：读主题 elements.map.open_key（缺省 M）
local cachedKeyCode = nil
local function GetOpenKey()
    if not cachedKeyCode then
        local keyName = kit.GetElement("map").open_key or "M"
        local code = input.GetKeyCode and input.GetKeyCode(keyName)
        cachedKeyCode = code or KEY_M
    end
    return cachedKeyCode
end

hook.Add("PlayerButtonDown", "Fireteam.TacMap.OpenKey", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button == GetOpenKey() then
        Fireteam.TacMap.Toggle()
    end
end)

print("[FIRETEAM:TacMap] ✓ Client UI loaded")
