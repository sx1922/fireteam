-- modules/squad/cl_squad_ui.lua
-- FIRETEAM Squad System - Client UI
-- 面板走 UI Kit 主题壳层，文案经 Fireteam.Locale。

if not Fireteam then Fireteam = {} end
Fireteam.Squad = Fireteam.Squad or {}

local kit = Fireteam.UI
local L = Fireteam.Locale.Get

local cachedSquads = {}
local squadPanel = nil

-- 数据全量广播到达时重建已打开的面板（0.25s 节流防抖）
local lastPanelRebuild = 0
local function RebuildPanelSoon()
    if not IsValid(squadPanel) then return end
    if CurTime() - lastPanelRebuild < 0.25 then return end
    lastPanelRebuild = CurTime()
    Fireteam.Squad.OpenPanel()
end
Fireteam.Squad.RebuildPanelSoon = RebuildPanelSoon

-- ═══════════════════════════════════════
-- 接收同步数据（手写字段反序列化，与 sv_squad.SyncToAll 严格配对）
-- ═══════════════════════════════════════
local ROLE_NAME = { [0] = "member", [1] = "leader", [2] = "specialist" }

net.Receive(Fireteam.NET.SQUAD_UPDATE, function()
    local out = {}
    local squadCount = net.ReadUInt(5)
    for _ = 1, squadCount do
        local id = net.ReadUInt(8)
        local name = net.ReadString()
        local faction = net.ReadString()
        local state = net.ReadString()
        local locked = net.ReadBool()
        local leaderIdx = net.ReadUInt(8)

        local members = {}
        local memberCount = net.ReadUInt(5)
        for i = 1, memberCount do
            local class = net.ReadString()
            members[i] = {
                idx   = net.ReadUInt(8),
                name  = net.ReadString(),
                role  = ROLE_NAME[net.ReadUInt(2)] or "member",
                class = class ~= "" and class or nil,
                ready = net.ReadBool(),
                alive = net.ReadBool(),
                hp    = net.ReadUInt(10),
                maxhp = net.ReadUInt(10),
            }
        end

        out[id] = {
            id = id, name = name, faction = faction,
            state = state, locked = locked,
            leaderIdx = leaderIdx, members = members,
        }
    end
    cachedSquads = out
    RebuildPanelSoon()
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
    -- 本阵营指挥官 EntIndex（commander 模块加载前安全探测）
    local cmdrIdx = Fireteam.Commander
        and Fireteam.Commander.GetCachedFactionCommander
        and Fireteam.Commander.GetCachedFactionCommander(mySquad.faction) or nil
    for i, info in ipairs(members) do
        local rowY = y + math.Round(36 * scale) + (i - 1) * rowH + rowH / 2
        local isLeader = info.idx == mySquad.leaderIdx
        local isCmdr = cmdrIdx ~= nil and info.idx == cmdrIdx

        -- 存活状态圆点（死亡灰暗）
        draw.NoTexture()
        surface.DrawCircle(x + 16, rowY, math.Round(4 * scale),
            info.alive and kit.Color("squad_ally") or kit.Color("text_muted"))

        -- 前缀体系：◆ 队长 · ★ 阵营指挥官
        local nameX = x + 26
        if isCmdr then
            draw.SimpleText("★", kit.Font("small"), nameX, rowY,
                kit.ColorA("warning", 250 * fx), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            nameX = nameX + 14
        end
        if isLeader then
            draw.SimpleText("◆", kit.Font("small"), nameX, rowY,
                kit.ColorA("squad_leader", 240 * fx), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            nameX = nameX + 14
        end

        -- 名字（指挥官金色；死亡划暗）
        local nameCol = isCmdr and "warning"
            or (isLeader and "squad_leader" or (info.alive and "squad_ally" or "danger"))
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
--- 指挥官动作快捷发送
local function CmdAction(action, entIdx)
    net.Start(Fireteam.NET.COMMANDER_ACTION)
        net.WriteString(action)
    if entIdx then net.WriteUInt(entIdx, 8) end
    net.SendToServer()
end

--- 面板顶部指挥官区：现任展示 / 就任·挑战·让位按钮 / 进行中选举投票组
local function BuildCommanderSection(scroll)
    if not Fireteam.Commander then return end

    local mySquad = Fireteam.Squad.GetMySquad()
    local myFaction = mySquad and mySquad.faction or nil
    local state = Fireteam.Commander.GetClientState and Fireteam.Commander.GetClientState() or nil
    local fs = myFaction and state and state[myFaction] or nil

    local lbl = scroll:Add("DLabel")
    lbl:SetText(L("ui_cmd_section"))
    kit.StyleLabel(lbl, { font = "medium", color = "text_muted" })
    lbl:Dock(TOP)
    lbl:DockMargin(0, 4, 0, 3)
    lbl:SizeToContentsY()

    -- 只渲染与本玩家相关阵营的区；无小队时只看不动手
    local cmdrName = nil
    if fs and fs.cmdIdx and IsValid(Entity(fs.cmdIdx)) then
        cmdrName = Entity(fs.cmdIdx):Nick()
    end
    local statusLine = scroll:Add("DLabel")
    if not myFaction then
        statusLine:SetText(L("ui_cmd_none"))
    elseif cmdrName then
        statusLine:SetText(L("ui_cmd_current", "★ " .. cmdrName))
    else
        statusLine:SetText(L("ui_cmd_vacant"))
    end
    kit.StyleLabel(statusLine, { font = "small", color = "text" })
    statusLine:Dock(TOP)
    statusLine:DockMargin(0, 0, 0, 5)
    statusLine:SizeToContentsY()

    -- 资格判定：本阵营某小队的队长
    local amILeaderOfMyFaction = false
    if mySquad and Fireteam.Squad.IsMySquadLeader(mySquad) then
        amILeaderOfMyFaction = true
    end
    local myIdx = LocalPlayer():EntIndex()
    local iAmCommander = fs and fs.cmdIdx == myIdx or false

    -- 进行中选举：倒计时 + 投票按钮组
    if fs and fs.voting then
        local remain = math.max(0, math.floor(fs.endsIn or 0))
        local candNames = {}
        for _, idx in ipairs(fs.candidates or {}) do
            table.insert(candNames, IsValid(Entity(idx)) and Entity(idx):Nick() or ("#" .. idx))
        end
        local voteLine = scroll:Add("DLabel")
        voteLine:SetText(L("ui_cmd_election", remain, table.concat(candNames, " / ")))
        kit.StyleLabel(voteLine, { font = "small", color = "warning" })
        voteLine:Dock(TOP)
        voteLine:DockMargin(0, 0, 0, 4)
        voteLine:SizeToContentsY()

        if amILeaderOfMyFaction then
            for _, idx in ipairs(fs.candidates or {}) do
                local name = IsValid(Entity(idx)) and Entity(idx):Nick() or ("#" .. idx)
                local voteBtn = scroll:Add("DButton")
                voteBtn:SetTall(28)
                voteBtn:Dock(TOP)
                voteBtn:DockMargin(40, 2, 40, 2)
                voteBtn:SetText(L("ui_cmd_vote", name))
                kit.StyleButton(voteBtn, { style = "ghost", font = "small" })
                voteBtn.DoClick = function() CmdAction("vote", idx) end
            end
        end
    elseif amILeaderOfMyFaction and not iAmCommander then
        local volBtn = scroll:Add("DButton")
        volBtn:SetTall(30)
        volBtn:Dock(TOP)
        volBtn:DockMargin(120, 2, 120, 4)
        volBtn:SetText(cmdrName and L("ui_cmd_challenge") or L("ui_cmd_volunteer"))
        kit.StyleButton(volBtn, { style = "primary", font = "small" })
        volBtn.DoClick = function() CmdAction("volunteer") end
    elseif iAmCommander then
        local relBtn = scroll:Add("DButton")
        relBtn:SetTall(30)
        relBtn:Dock(TOP)
        relBtn:DockMargin(120, 2, 120, 4)
        relBtn:SetText(L("ui_cmd_relinquish"))
        kit.StyleButton(relBtn, { style = "danger", font = "small" })
        relBtn.DoClick = function() CmdAction("relinquish") end
    end

    local pad = scroll:Add("DPanel")
    pad:SetTall(6)
    pad:Dock(TOP)
    pad.Paint = nil
end

function Fireteam.Squad.OpenPanel()
    if IsValid(squadPanel) then
        squadPanel:Remove()
    end

    local W, H = math.Round(520 * (ScrW() / 1920)), math.Round(560 * (ScrH() / 1080))
    squadPanel = kit.CreateFrame(L("ui_squad_title"), W, H, {
        blur = true,
        hints = { L("ui_hint_esc_close") }
    })

    local scroll = vgui.Create("DScrollPanel", squadPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(12, squadPanel.ftContentTop, 12, squadPanel.ftContentBottom + 6)

    -- ── 指挥官区（常驻顶部）──
    BuildCommanderSection(scroll)

    -- 当前小队信息
    local mySquad = Fireteam.Squad.GetMySquad()
    if mySquad then
        local infoLabel = scroll:Add("DLabel")
        infoLabel:SetText(L("ui_current_squad", mySquad.name, mySquad.faction)
            .. (mySquad.locked and "  🔒" or ""))
        kit.StyleLabel(infoLabel, { font = "medium", color = "primary" })
        infoLabel:Dock(TOP)
        infoLabel:DockMargin(0, 0, 0, 4)
        infoLabel:SizeToContentsY()

        local stateLabel = scroll:Add("DLabel")
        stateLabel:SetText(L("ui_member_count", #(mySquad.members or {})))
        kit.StyleLabel(stateLabel, { font = "small", color = "text_muted" })
        stateLabel:Dock(TOP)
        stateLabel:DockMargin(0, 0, 0, 8)
        stateLabel:SizeToContentsY()

        -- 就绪切换（服务端 SetReady 全员就绪时自动 FORMING→READY）
        local meInfo = nil
        for _, m in ipairs(mySquad.members or {}) do
            if m.idx == LocalPlayer():EntIndex() then meInfo = m break end
        end
        local readyBtn = scroll:Add("DButton")
        readyBtn:SetTall(32)
        readyBtn:Dock(TOP)
        readyBtn:DockMargin(140, 2, 140, 4)
        readyBtn:SetText(meInfo and meInfo.ready and L("ui_squad_unready") or L("ui_squad_ready"))
        kit.StyleButton(readyBtn, { style = "ghost" })
        readyBtn.DoClick = function()
            net.Start(Fireteam.NET.SQUAD_READY)
                net.WriteBool(not (meInfo and meInfo.ready))
            net.SendToServer()
        end

        -- 队长专用区
        if Fireteam.Squad.IsMySquadLeader(mySquad) then
            local lockBtn = scroll:Add("DButton")
            lockBtn:SetTall(32)
            lockBtn:Dock(TOP)
            lockBtn:DockMargin(140, 2, 140, 8)
            lockBtn:SetText(mySquad.locked and L("ui_squad_unlock") or L("ui_squad_lock"))
            kit.StyleButton(lockBtn, { style = "ghost" })
            lockBtn.DoClick = function()
                net.Start(Fireteam.NET.SQUAD_LOCK)
                    net.WriteBool(not mySquad.locked)
                net.SendToServer()
            end

            -- 成员行：◆ 队长标记 · 就绪态 · 踢出按钮
            for _, m in ipairs(mySquad.members or {}) do
                if m.idx ~= LocalPlayer():EntIndex() then
                    local row = scroll:Add("DPanel")
                    row:SetTall(26)
                    row:Dock(TOP)
                    row:DockMargin(20, 1, 20, 1)
                    row.Paint = function(s, w, h)
                        draw.SimpleText((m.idx == mySquad.leaderIdx and "◆ " or "") .. m.name,
                            kit.Font("small"), 6, h / 2,
                            kit.ColorA(m.alive and "squad_ally" or "danger", 220),
                            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        draw.SimpleText(m.ready and L("ui_ready_tag") or "",
                            kit.Font("small"), w - 70, h / 2,
                            kit.ColorA("success", 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end

                    local kickBtn = vgui.Create("DButton", row)
                    kickBtn:SetText("")
                    kickBtn:SetSize(52, 20)
                    kickBtn:SetPos(row:GetWide() - 58, 3)
                    kit.StyleButton(kickBtn, { style = "danger", font = "small" })
                    kickBtn:SetText(L("ui_kick_btn"))
                    kickBtn.DoClick = function()
                        net.Start(Fireteam.NET.SQUAD_KICK)
                            net.WriteUInt(m.idx, 8)
                        net.SendToServer()
                    end
                end
            end
        end

        -- 离开按钮
        local leaveBtn = scroll:Add("DButton")
        leaveBtn:SetTall(36)
        leaveBtn:Dock(TOP)
        leaveBtn:DockMargin(120, 10, 120, 16)
        leaveBtn:SetText(L("ui_leave_squad"))
        kit.StyleButton(leaveBtn, { style = "danger" })
        leaveBtn.DoClick = function()
            net.Start(Fireteam.NET.SQUAD_LEAVE)
            net.SendToServer()
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
        local lockTag = squad.locked and ("  🔒 " .. L("ui_locked_tag")) or ""
        joinBtn:SetText(squad.name .. " [" .. squad.faction .. "] · "
            .. L("ui_member_count", #(squad.members or {})) .. lockTag)
        kit.StyleButton(joinBtn, { style = squad.locked and "ghost" or "primary" })
        if squad.locked then
            joinBtn:SetAlpha(120)
            joinBtn:SetCursor("no")
        end
        joinBtn.DoClick = function()
            if squad.locked then
                chat.AddText(kit.Color("warning"), "[FIRETEAM] " .. L("squad_locked"))
                return
            end
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

print("[FIRETEAM:Squad] ✓ 客户端 UI 已加载")
