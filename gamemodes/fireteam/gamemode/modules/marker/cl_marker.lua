-- modules/marker/cl_marker.lua
-- FIRETEAM Marker System - Client Rendering

if not Fireteam then Fireteam = {} end
Fireteam.Marker = Fireteam.Marker or {}

local cachedMarkers = {}

-- 接收标记数据
net.Receive(Fireteam.NET.MARKER_ADD, function()
    cachedMarkers = net.ReadTable()
end)

-- ═══════════════════════════════════════
-- 3D 标记渲染
-- ═══════════════════════════════════════
hook.Add("PostDrawTranslucentRenderables", "Fireteam.Marker.Draw3D", function()
    local mySquad = Fireteam.Squad.GetMySquad()
    if not mySquad then return end

    for _, marker in pairs(cachedMarkers) do
        if marker.squadId ~= mySquad.id then continue end

        local pos = marker.pos
        if not isvector(pos) then continue end

        local color = Fireteam.Marker.COLORS[marker.type] or Color(255, 255, 255)
        local screenPos = pos:ToScreen()

        if screenPos.visible then
            -- 绘制图标
            local size = 20
            local dist = LocalPlayer():GetPos():Distance(pos)
            size = math.Clamp(800 / dist * 10, 8, 32)

            draw.SimpleText("▼", "DermaDefault", screenPos.x, screenPos.y,
                color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- 标签
            if marker.label and marker.label ~= "" then
                draw.SimpleText(marker.label, "DermaDefault",
                    screenPos.x, screenPos.y - size - 4,
                    color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            end

            -- 距离
            local distText = math.floor(dist / 52.5) .. "m"
            draw.SimpleText(distText, "DermaDefault",
                screenPos.x, screenPos.y + size + 4,
                Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    end
end)

-- ═══════════════════════════════════════
-- 放置标记（按 F6）
-- ═══════════════════════════════════════
hook.Add("PlayerButtonDown", "Fireteam.Marker.PlaceKey", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button == KEY_F6 then
        -- 射线检测准星指向位置
        local tr = LocalPlayer():GetEyeTrace()
        local pos = tr.HitPos + tr.HitNormal * 5

        net.Start("FT_MarkerPlace")
            net.WriteVector(pos)
            net.WriteString(Fireteam.Marker.TYPE.WAYPOINT)
            net.WriteString("")
        net.SendToServer()

        chat.AddText(Color(100, 200, 255), "[FIRETEAM] Marker placed.")
    end
end)

print("[FIRETEAM:Marker] ✓ Client rendering loaded")
