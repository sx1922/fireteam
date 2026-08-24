-- modules/squad/cl_squad_ui.lua
-- FIRETEAM Squad System - Client UI

if not Fireteam then Fireteam = {} end
Fireteam.Squad = Fireteam.Squad or {}

local cachedSquads = {}
local squadPanel = nil

-- ═══════════════════════════════════════
-- 接收同步数据
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.SQUAD_UPDATE, function()
    cachedSquads = net.ReadTable()
end)

-- ═══════════════════════════════════════
-- 获取缓存数据
-- （服务端 ply.FT_SquadData 不会自动网络同步，
--   客户端一律从缓存按 EntIndex 推断自己的小队）
-- ═══════════════════════════════════════
function Fireteam.Squad.GetCachedSquads()
    return cachedSquads
end

function Fireteam.Squad.GetMySquad()
    if not IsValid(LocalPlayer()) then return nil end
    local myIdx = LocalPlayer():EntIndex()
    for _, squad in pairs(cachedSquads) do
        for _, m in ipairs(squad.members or {}) do
            if m.idx == myIdx then return squad end
        end
    end
    return nil
end

--- 当前玩家是否为自己小队的队长
function Fireteam.Squad.IsMySquadLeader(squad)
    squad = squad or Fireteam.Squad.GetMySquad()
    if not squad then return false end
    return squad.leaderIdx == LocalPlayer():EntIndex()
end

-- ═══════════════════════════════════════
-- HUD 小队状态栏（左侧）
-- ═══════════════════════════════════════
local function DrawSquadHUD()
    local mySquad = Fireteam.Squad.GetMySquad()
    if not mySquad then return end

    local startX, startY = 20, ScrH() * 0.3
    local lineHeight = 28
    local memberCount = #((mySquad.members or {}))

    -- 背景
    draw.RoundedBox(4, startX - 8, startY - 8, 220, lineHeight * (memberCount + 1) + 16, Color(10, 10, 10, 180))

    -- 小队名
    draw.SimpleText(mySquad.name or "Squad", "DermaDefault", startX, startY, Color(51, 255, 51), TEXT_ALIGN_LEFT)
    startY = startY + lineHeight

    -- 成员列表
    for _, info in ipairs(mySquad.members or {}) do
        local color = Color(200, 200, 200)
        if info.idx == mySquad.leaderIdx then
            color = Color(255, 255, 51)  -- 队长黄色
        elseif not info.alive then
            color = Color(255, 50, 50)   -- 死亡红色
        end

        local prefix = info.idx == mySquad.leaderIdx and "★ " or "  "
        draw.SimpleText(prefix .. info.name, "DermaDefault", startX, startY, color, TEXT_ALIGN_LEFT)
        startY = startY + lineHeight
    end
end

hook.Add("HUDPaint", "Fireteam.Squad.DrawHUD", DrawSquadHUD)

-- ═══════════════════════════════════════
-- 小队管理面板（按 F7 打开）
-- ═══════════════════════════════════════
function Fireteam.Squad.OpenPanel()
    if IsValid(squadPanel) then
        squadPanel:Remove()
    end

    squadPanel = vgui.Create("DFrame")
    squadPanel:SetSize(500, 400)
    squadPanel:Center()
    squadPanel:SetTitle("FIRETEAM - Squad Management")
    squadPanel:SetDraggable(true)
    squadPanel:ShowCloseButton(true)
    squadPanel:MakePopup()

    local scroll = vgui.Create("DScrollPanel", squadPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 10, 10, 10)

    -- 当前小队信息
    local mySquad = Fireteam.Squad.GetMySquad()
    if mySquad then
        local infoLabel = scroll:Add("DLabel")
        infoLabel:SetText("Current Squad: " .. mySquad.name .. " [" .. mySquad.faction .. "]")
        infoLabel:Dock(TOP)
        infoLabel:DockMargin(0, 0, 0, 10)

        -- 离开按钮
        local leaveBtn = scroll:Add("DButton")
        leaveBtn:SetText("Leave Squad")
        leaveBtn:Dock(TOP)
        leaveBtn:DockMargin(0, 0, 0, 20)
        leaveBtn.DoClick = function()
            net.Start("FT_SquadLeave")
            net.SendToServer()
            squadPanel:Remove()
        end
    else
        -- 创建小队
        local nameLabel = scroll:Add("DLabel")
        nameLabel:SetText("Squad Name:")
        nameLabel:Dock(TOP)

        local nameEntry = scroll:Add("DTextEntry")
        nameEntry:Dock(TOP)
        nameEntry:SetPlaceholderText("Enter squad name...")
        nameEntry:DockMargin(0, 4, 0, 10)

        local createBtn = scroll:Add("DButton")
        createBtn:SetText("Create Squad")
        createBtn:Dock(TOP)
        createBtn:DockMargin(0, 0, 0, 20)
        createBtn.DoClick = function()
            net.Start("FT_SquadCreate")
                net.WriteString(nameEntry:GetText() or "New Squad")
                net.WriteString("western_alliance")
            net.SendToServer()
            squadPanel:Remove()
        end
    end

    -- 可用小队列表
    local listLabel = scroll:Add("DLabel")
    listLabel:SetText("Available Squads:")
    listLabel:Dock(TOP)
    listLabel:DockMargin(0, 10, 0, 5)

    for id, squad in pairs(cachedSquads) do
        local joinBtn = scroll:Add("DButton")
        joinBtn:SetText(squad.name .. " [" .. squad.faction .. "] - " .. #(squad.members or {}) .. " members")
        joinBtn:Dock(TOP)
        joinBtn:DockMargin(0, 2, 0, 2)
        joinBtn.DoClick = function()
            net.Start("FT_SquadJoin")
                net.WriteInt(id, 8)
            net.SendToServer()
            squadPanel:Remove()
        end
    end
end

-- F7 打开小队面板
hook.Add("PlayerButtonDown", "Fireteam.Squad.OpenKey", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button == KEY_F7 then
        Fireteam.Squad.OpenPanel()
    end
end)

print("[FIRETEAM:Squad] ✓ Client UI loaded")
