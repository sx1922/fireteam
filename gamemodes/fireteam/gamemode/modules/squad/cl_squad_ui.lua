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
-- HUD 小队状态栏（Squad 风格：编号徽章 + 存活点 + 队长菱形 + 血量条）
-- 位置由 elements.squad_status 决定；bottom_left 时自动堆叠在血量块上方
-- ═══════════════════════════════════════
local squadHUDVisible = true   -- 玩家本地开关（H 键切换）

local function DrawSquadHUD()
    if not squadHUDVisible then return end
    if Fireteam.Config.Get("hud.squad_panel") == false then return end

    local mySquad = Fireteam.Squad.GetMySquad()
    if not mySquad then return end

    local scale = ScrW() / 1920
    local members = mySquad.members or {}
    local rowH = math.Round(26 * scale)
    local panelW = math.Round(252 * scale)
    local panelH = rowH * #members + math.Round(34 * scale)

    local elem = kit.GetElement("squad_status")
    local posName = elem.position or "bottom_left"
    local x, y = kit.ResolveAnchor(posName, panelW, panelH)
    if posName:find("^bottom") then
        -- 贴底锚点：向上让出自身血量块（78 高）与间距
        y = y - panelH - math.Round(78 * (ScrH() / 1080)) - math.Round(8 * scale)
    end

    kit.DrawPanel(x, y, panelW, panelH, { fillAlpha = 165, borderColor = false })

    -- 标题行：绿色圆形小队编号徽章 + 队名
    local badgeR = math.Round(10 * scale)
    local badgeX, badgeY = x + 12 + badgeR, y + math.Round(17 * scale)
    draw.NoTexture()
    surface.DrawCircle(badgeX, badgeY, badgeR, kit.Color("success"))
    draw.SimpleText(tostring(mySquad.id or "?"), kit.Font("small"),
        badgeX, badgeY, kit.Color("background"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(mySquad.name or "Squad", kit.Font("medium"),
        badgeX + badgeR + 8, badgeY, kit.Color("primary"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    kit.DrawDivider(x + 8, y + math.Round(30 * scale), panelW - 16)

    -- 成员行
    local fx = kit.EffectsAlpha()
    local barW = math.Round(56 * scale)
    for i, info in ipairs(members) do
        local rowY = y + math.Round(36 * scale) + (i - 1) * rowH + rowH / 2
        local isLeader = info.idx == mySquad.leaderIdx

        -- 存活状态圆点（死亡灰暗）
        draw.NoTexture()
        surface.DrawCircle(x + 16, rowY, math.Round(4 * scale),
            info.alive and kit.Color("squad_ally") or kit.Color("text_muted"))

        -- 队长菱形 / 普通成员留空
        local nameX = x + 26
        if isLeader then
            draw.SimpleText("◆", kit.Font("small"), nameX, rowY,
                kit.ColorA("squad_leader", 240 * fx), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            nameX = nameX + 14
        end

        -- 名字（死亡划暗）
        local nameCol = isLeader and "squad_leader" or (info.alive and "squad_ally" or "danger")
        local nameAlpha = info.alive and 235 or 120
        draw.SimpleText(info.name, kit.Font("small"), nameX, rowY,
            kit.ColorA(nameCol, nameAlpha * fx), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- 说话喇叭（P5 语音频道接入；当前仅安全探测）
        local speaking = Fireteam.Voice
            and Fireteam.Voice.GetSpeakerChannel
            and Fireteam.Voice.GetSpeakerChannel(info.idx) or nil
        if speaking then
            draw.SimpleText("🔊", kit.Font("small"), x + panelW - barW - 22, rowY,
                kit.ColorA("primary", 240 * fx), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- 血量迷你条（右侧）
        local hpMax = math.max(info.maxhp or 100, 1)
        local frac = info.alive and math.Clamp((info.hp or 0) / hpMax, 0, 1) or 0
        local barColor = "squad_ally"
        if not info.alive then barColor = "text_muted"
        elseif frac <= 0.3 then barColor = "danger"
        elseif frac <= 0.6 then barColor = "warning" end
        kit.DrawProgressBar(x + panelW - 10 - barW, rowY - 3, barW, 6, frac, barColor)
    end
end

hook.Add("HUDPaint", "Fireteam.Squad.DrawHUD", DrawSquadHUD)

-- H 键：本地开/关小队栏（输入框聚焦时不触发）
hook.Add("PlayerButtonDown", "Fireteam.Squad.HUDToggle", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button ~= KEY_H then return end
    if not kit.CanTogglePanel() then return end
    squadHUDVisible = not squadHUDVisible
    chat.AddText(kit.Color("primary"), "[FIRETEAM] ",
        kit.Color("text"),
        L(squadHUDVisible and "hud_squad_panel_shown" or "hud_squad_panel_hidden"))
end)

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

        local nameEntry = kit.CreateEntry(scroll)
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

-- F7 打开小队面板（输入框聚焦时不触发，防中文输入误关）
hook.Add("PlayerButtonDown", "Fireteam.Squad.OpenKey", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button == KEY_F7 and kit.CanTogglePanel() then
        Fireteam.Squad.OpenPanel()
    end
end)

print("[FIRETEAM:Squad] ✓ Client UI loaded")
