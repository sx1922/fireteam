-- modules/marker/cl_marker.lua
-- FIRETEAM Marker System - Client Rendering

if not Fireteam then Fireteam = {} end
Fireteam.Marker = Fireteam.Marker or {}

local kit = Fireteam.UI
local L = Fireteam.Locale.Get

local cachedMarkers = {}

-- 接收标记数据
net.Receive(Fireteam.NET.MARKER_ADD, function()
    cachedMarkers = net.ReadTable()
end)

--- 客户端标记缓存访问器（战术地图等模块复用）
function Fireteam.Marker.GetClientMarkers()
    return cachedMarkers
end

-- ═══════════════════════════════════════
-- 3D 标记渲染
-- ═══════════════════════════════════════
hook.Add("PostDrawTranslucentRenderables", "Fireteam.Marker.Draw3D", function()
    local mySquad = Fireteam.Squad.GetMySquad()
    if not mySquad then return end

    for _, marker in pairs(cachedMarkers) do
        -- 小队级标记只画本队；阵营级标记（指挥官放置）对本阵营全队可见
        local mine = marker.squadId == mySquad.id
            or (marker.faction and marker.faction == mySquad.faction)
        if not mine then continue end

        local pos = marker.pos
        if not isvector(pos) then continue end

        local color = Fireteam.Marker.GetTypeColor(marker.type)
        local screenPos = pos:ToScreen()

        if screenPos.visible then
            -- 绘制图标
            local size = 20
            local dist = LocalPlayer():GetPos():Distance(pos)
            size = math.Clamp(800 / dist * 10, 8, 32)

            draw.SimpleText("▼", kit.Font("medium"), screenPos.x, screenPos.y,
                color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- 标签
            if marker.label and marker.label ~= "" then
                draw.SimpleText(marker.label, kit.Font("small"),
                    screenPos.x, screenPos.y - size - 4,
                    color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            end

            -- 距离
            local distText = math.floor(dist / 52.5) .. "m"
            draw.SimpleText(distText, kit.Font("small"),
                screenPos.x, screenPos.y + size + 4,
                kit.Color("text_muted"), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    end
end)

-- ═══════════════════════════════════════
-- 放置标记（按 F6）
-- ═══════════════════════════════════════
hook.Add("PlayerButtonDown", "Fireteam.Marker.PlaceKey", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button == KEY_F6 and kit.CanTogglePanel() then
        -- 射线检测准星指向位置
        local tr = LocalPlayer():GetEyeTrace()
        local pos = tr.HitPos + tr.HitNormal * 5

        net.Start(Fireteam.NET.MARKER_PLACE)
            net.WriteVector(pos)
            net.WriteString(Fireteam.Marker.TYPE.WAYPOINT)
            net.WriteString("")
            net.WriteBool(false)   -- 小队级标记；指挥官经战术地图发阵营级
        net.SendToServer()

        chat.AddText(kit.Color("info"), "[FIRETEAM] " .. L("marker_placed"))
    end
end)

Fireteam.Log.Info("Marker", "✓ 客户端渲染已加载")
