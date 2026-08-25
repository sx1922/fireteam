-- modules/squad/cl_squad_ui.lua
-- FIRETEAM Squad System - Client UI
-- 面板走 UI Kit 主题壳层，文案经 Fireteam.Locale。

if not Fireteam then Fireteam = {} end
Fireteam.Squad = Fireteam.Squad or {}

local kit = Fireteam.UI
local L = Fireteam.Locale.Get

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
-- HUD 小队状态栏（位置由 elements.squad_status 决定）
-- ═══════════════════════════════════════
local function DrawSquadHUD()
    local mySquad = Fireteam.Squad.GetMySquad()
    if not mySquad then return end

    local members = mySquad.members or {}
    local lineHeight = 24
    local panelW = math.Round(230 * (ScrW() / 1920))
    local panelH = lineHeight * (#members + 1) + 20
    local elem = kit.GetElement("squad_status")
    local x, y = kit.ResolveAnchor(elem.position or "left", panelW, panelH)

    kit.DrawPanel(x, y, panelW, panelH, { fillAlpha = 180 })

    -- 小队名
    draw.SimpleText(mySquad.name or "Squad", kit.Font("medium"),
        x + 10, y + 10, kit.Color("primary"), TEXT_ALIGN_LEFT)
    kit.DrawDivider(x + 8, y + 34, panelW - 16)

    -- 成员列表
    local rowY = y + 42
    for _, info in ipairs(members) do
        local colorName = "squad_ally"
        if info.idx == mySquad.leaderIdx then
            colorName = "squad_leader"
        elseif not info.alive then
            colorName = "danger"
        end

        local prefix = info.idx == mySquad.leaderIdx and "★ " or "   "
        draw.SimpleText(prefix .. info.name, kit.Font("small"),
            x + 10, rowY, kit.Color(colorName), TEXT_ALIGN_LEFT)
        rowY = rowY + lineHeight
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

    local W, H = math.Round(520 * (ScrW() / 1920)), math.Round(430 * (ScrH() / 1080))
    squadPanel = kit.CreateFrame(L("ui_squad_title"), W, H, {
        blur = true,
        hints = { L("ui_hint_esc_close") }
    })

    local scroll = vgui.Create("DScrollPanel", squadPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(12, squadPanel.ftContentTop, 12, squadPanel.ftContentBottom + 6)

    -- 当前小队信息
    local mySquad = Fireteam.Squad.GetMySquad()
    if mySquad then
        local infoLabel = scroll:Add("DLabel")
        infoLabel:SetText(L("ui_current_squad", mySquad.name, mySquad.faction))
        kit.StyleLabel(infoLabel, { font = "medium", color = "primary" })
        infoLabel:Dock(TOP)
        infoLabel:DockMargin(0, 0, 0, 4)
        infoLabel:SizeToContentsY()

        local stateLabel = scroll:Add("DLabel")
        stateLabel:SetText(L("ui_member_count", #(mySquad.members or {})))
        kit.StyleLabel(stateLabel, { font = "small", color = "text_muted" })
        stateLabel:Dock(TOP)
        stateLabel:DockMargin(0, 0, 0, 12)
        stateLabel:SizeToContentsY()

        -- 离开按钮
        local leaveBtn = scroll:Add("DButton")
        leaveBtn:SetTall(36)
        leaveBtn:Dock(TOP)
        leaveBtn:DockMargin(120, 8, 120, 20)
        leaveBtn:SetText(L("ui_leave_squad"))
        kit.StyleButton(leaveBtn, { style = "danger" })
        leaveBtn.DoClick = function()
            net.Start(Fireteam.NET.SQUAD_LEAVE)
            net.SendToServer()
            squadPanel:Remove()
        end
    else
        -- 创建小队
        local nameLabel = scroll:Add("DLabel")
        nameLabel:SetText(L("ui_squad_name"))
        kit.StyleLabel(nameLabel, { font = "body" })
        nameLabel:Dock(TOP)
        nameLabel:SizeToContentsY()

        local nameEntry = scroll:Add("DTextEntry")
        nameEntry:SetTall(32)
        nameEntry:Dock(TOP)
        nameEntry:SetPlaceholderText(L("ui_squad_name_placeholder"))
        nameEntry:DockMargin(0, 6, 0, 10)

        -- 阵营选择（数据来自设定包 factions）
        local factionLabel = scroll:Add("DLabel")
        factionLabel:SetText(L("ui_select_faction"))
        kit.StyleLabel(factionLabel, { font = "body" })
        factionLabel:Dock(TOP)
        factionLabel:DockMargin(0, 6, 0, 4)
        factionLabel:SizeToContentsY()

        local selectedFaction = nil
        local factionCombo = scroll:Add("DComboBox")
        factionCombo:SetTall(30)
        factionCombo:Dock(TOP)
        factionCombo:DockMargin(0, 2, 0, 10)

        local factions = Fireteam.Setting.GetData("factions") or {}
        local firstId = nil
        for factionId, def in pairs(factions) do
            local displayName = (def.name_zh or def.name or factionId)
                .. " (" .. factionId .. ")"
            factionCombo:AddChoice(displayName, factionId)
            firstId = firstId or factionId
        end
        if firstId then
            factionCombo:ChooseOptionValue(firstId)
            selectedFaction = firstId
        end
        factionCombo.OnSelect = function(_, _, _, value)
            selectedFaction = value
        end

        local createBtn = scroll:Add("DButton")
        createBtn:SetTall(36)
        createBtn:Dock(TOP)
        createBtn:DockMargin(120, 8, 120, 20)
        createBtn:SetText(L("ui_create_squad"))
        kit.StyleButton(createBtn, { style = "primary" })
        createBtn.DoClick = function()
            net.Start(Fireteam.NET.SQUAD_CREATE)
                net.WriteString(nameEntry:GetText() or "New Squad")
                net.WriteString(selectedFaction or firstId or "")
            net.SendToServer()
            squadPanel:Remove()
        end
    end

    -- 可用小队列表
    local listLabel = scroll:Add("DLabel")
    listLabel:SetText(L("ui_available_squads"))
    kit.StyleLabel(listLabel, { font = "medium", color = "text_muted" })
    listLabel:Dock(TOP)
    listLabel:DockMargin(0, 10, 0, 5)
    listLabel:SizeToContentsY()

    local ids = {}
    for id in pairs(cachedSquads) do
        ids[#ids + 1] = id
    end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local squad = cachedSquads[id]
        local joinBtn = scroll:Add("DButton")
        joinBtn:SetTall(34)
        joinBtn:Dock(TOP)
        joinBtn:DockMargin(40, 3, 40, 3)
        joinBtn:SetText(squad.name .. " [" .. squad.faction .. "] · "
            .. L("ui_member_count", #(squad.members or {})))
        kit.StyleButton(joinBtn, { style = "ghost" })
        joinBtn.DoClick = function()
            net.Start(Fireteam.NET.SQUAD_JOIN)
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
