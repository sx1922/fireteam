-- modules/admin/cl_admin_ui.lua
-- FIRETEAM Admin Panel - Client UI
-- F10 开关；四个页签（配置/回合/玩家/设定包）；所有改动经 ADMIN_ACTION 提交，
-- 服务端执行后回发快照，界面以服务端真实值为准重绘。

local kit = Fireteam.UI
local L = function(key, ...)
    return Fireteam.Locale and Fireteam.Locale.Get(key, ...) or key
end

local state = nil          -- 服务端快照
local panel = nil
local activeTab = "config"
local tabButtons = {}

--- 提交动作（服务端会回发新状态）
local function Act(tbl)
    Fireteam.Net.SendToServer(Fireteam.NET.ADMIN_ACTION, tbl)
end

net.Receive(Fireteam.NET.ADMIN_STATE, function()
    state = net.ReadTable()
    if IsValid(panel) then panel:Rebuild() end
end)

-- ═══════════════════════════════════════
-- 页签内容构建器
-- ═══════════════════════════════════════
local TABS = {
    { id = "config", label = "ui_admin_tab_config" },
    { id = "rounds", label = "ui_admin_tab_rounds" },
    { id = "players", label = "ui_admin_tab_players" },
    { id = "packs",  label = "ui_admin_tab_packs" },
    { id = "coldwar_tool", label = "ui_admin_tab_coldwar_tool" },
}

local function SortKeys(cfgs)
    local keys = {}
    for k in pairs(cfgs or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

--- 配置行：按类型渲染编辑器
local function BuildConfigRow(parent, key, meta)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(4, 2, 4, 2)
    row:SetTall(26)

    row.Paint = function(s, w, h)
        draw.RoundedBox(2, 0, 0, w, h, kit.ColorA("surface", 140))
    end

    local label = vgui.Create("DLabel", row)
    label:SetText("")
    label:SetPos(8, 4)
    label:SetSize(240, 18)
    kit.StyleLabel(label, { font = "small" })
    label:SetText(key .. (meta.desc ~= "" and ("  — " .. meta.desc) or ""))
    label:SetTooltip(meta.desc)

    local apply = vgui.Create("DButton", row)
    apply:SetText("")
    apply:SetSize(52, 20)
    local editor

    if meta.type == "boolean" then
        editor = vgui.Create("DButton", row)
        local function refreshBtn()
            editor:SetText(tostring(meta.value) == "true" and "ON" or "OFF")
        end
        kit.StyleButton(editor, { style = "ghost", font = "small" })
        refreshBtn()
        editor.DoClick = function(s)
            -- 本地乐观取反，提交后以服务端回包为准
            meta.value = not (tostring(meta.value) == "true")
            s:SetText(tostring(meta.value) == "true" and "ON" or "OFF")
            Act({ type = "set_config", key = key, value = meta.value })
        end
    elseif meta.options then
        editor = vgui.Create("DComboBox", row)
        for _, opt in ipairs(meta.options) do
            editor:AddChoice(opt)
        end
        editor:SetValue(tostring(meta.value))
        editor.OnSelect = function(_, _, val)
            Act({ type = "set_config", key = key, value = val })
        end
    elseif meta.type == "number" then
        editor = kit.CreateEntry(row)
        editor:SetValue(tostring(meta.value))
    else
        editor = kit.CreateEntry(row)
        editor:SetValue(tostring(meta.value))
    end

    if editor.SetPlaceholderText then editor:SetPlaceholderText("") end

    -- 布局：label 左，editor 中右，apply 最右（boolean 的编辑器即按钮，无独立 apply）
    if meta.type == "boolean" then
        editor:SetSize(64, 20)
        editor:SetPos(row:GetWide() - 72, 3)
        apply:SetVisible(false)
    else
        apply.DoClick = function()
            local raw = editor:GetValue()
            local value = raw
            if meta.type == "number" then value = tonumber(raw) end
            if value == nil then return end
            Act({ type = "set_config", key = key, value = value })
        end
        kit.StyleButton(apply, { font = "small" })
        apply:SetText(L("admin_apply"))

        editor:SetSize(150, 22)
        editor:SetPos(row:GetWide() - 216, 2)

        apply:SetPos(row:GetWide() - 60, 3)
    end

    -- 重置按钮
    local reset = vgui.Create("DButton", row)
    reset:SetText("")
    reset:SetSize(24, 20)
    reset:SetPos(meta.type == "boolean" and row:GetWide() - 100 or row:GetWide() - 244, 3)
    reset:SetTooltip(L("admin_reset"))
    reset.Paint = function(s, w, h)
        draw.SimpleText("↺", kit.Font("small"), w / 2, h / 2,
            s:IsHovered() and kit.Color("warning") or kit.Color("text_muted"),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    reset.DoClick = function() Act({ type = "reset_config", key = key }) end

    return row
end

local function BuildConfigTab(content)
    if not (state and state.configs) then return end

    local scroll = vgui.Create("DScrollPanel", content)
    scroll:Dock(FILL)

    for _, key in ipairs(SortKeys(state.configs)) do
        BuildConfigRow(scroll, key, state.configs[key])
    end
end

local function BuildRoundsTab(content)
    local rs = (state and state.rounds) or {}
    local wrap = vgui.Create("DPanel", content)
    wrap:Dock(TOP)
    wrap:SetTall(150)
    wrap.Paint = nil

    local info = vgui.Create("DLabel", wrap)
    info:SetText("")
    info:Dock(TOP)
    info:DockMargin(8, 6, 8, 10)
    kit.StyleLabel(info, { font = "medium" })
    info:SetText(L("admin_round_state", tostring(rs.state or "-")))

    -- 模式与战役进度（PvE 时附第 X/Y 关）
    local modeLine = vgui.Create("DLabel", wrap)
    modeLine:SetText("")
    modeLine:Dock(TOP)
    modeLine:DockMargin(8, 0, 8, 6)
    kit.StyleLabel(modeLine, { font = "small", color = "text_muted" })
    local modeText = string.upper(tostring(rs.mode or "pvp"))
    if istable(rs.campaign) and rs.campaign.total then
        modeText = modeText .. " · " .. L("admin_round_campaign", rs.campaign.stage or 1, rs.campaign.total)
    end
    modeLine:SetText(L("admin_round_mode", modeText))

    local btnNext = vgui.Create("DButton", wrap)
    btnNext:SetText("")
    btnNext:Dock(TOP)
    btnNext:DockMargin(8, 0, 8, 6)
    btnNext:SetTall(28)
    kit.StyleButton(btnNext, {})
    btnNext:SetText(L("admin_round_advance"))
    btnNext.DoClick = function() Act({ type = "round_next" }) end

    local btnEnd = vgui.Create("DButton", wrap)
    btnEnd:SetText("")
    btnEnd:Dock(TOP)
    btnEnd:DockMargin(8, 0, 8, 6)
    btnEnd:SetTall(28)
    kit.StyleButton(btnEnd, { style = "danger" })
    btnEnd:SetText(L("admin_round_end_score"))
    btnEnd.DoClick = function() Act({ type = "round_end" }) end

    local btnDraw = vgui.Create("DButton", wrap)
    btnDraw:SetText("")
    btnDraw:Dock(TOP)
    btnDraw:DockMargin(8, 0, 8, 6)
    btnDraw:SetTall(28)
    kit.StyleButton(btnDraw, { style = "ghost" })
    btnDraw:SetText(L("admin_round_end_draw"))
    btnDraw.DoClick = function() Act({ type = "round_end", arg = "draw" }) end
end

local function BuildPlayersTab(content)
    local list = vgui.Create("DPanel", content)
    list:Dock(TOP)
    list:SetTall(#((state and state.players) or {}) * 24 + 34)
    list.Paint = nil

    local header = vgui.Create("DLabel", list)
    header:SetText("")
    header:SetPos(8, 4)
    header:SetSize(560, 18)
    kit.StyleLabel(header, { font = "small", color = "text_muted" })
    header:SetText(string.format("%-20s %-16s %-20s %-14s %s",
        L("admin_col_name"), L("admin_col_squad"),
        L("admin_col_class"), L("admin_col_faction"), L("admin_col_ping")))

    for i, p in ipairs((state and state.players) or {}) do
        local row = vgui.Create("DLabel", list)
        row:SetText("")
        row:SetPos(8, 26 + (i - 1) * 24)
        row:SetSize(560, 20)
        kit.StyleLabel(row, { font = "small",
            color = p.alive and "text" or "text_muted" })
        row:SetText(string.format("%-20.20s %-16.16s %-20.20s %-14.14s %d",
            p.name, p.squad, p.classId or "-", p.faction, p.ping))
    end
end

local function BuildPacksTab(content)
    for _, pack in ipairs((state and state.packs) or {}) do
        local row = vgui.Create("DPanel", content)
        row:Dock(TOP)
        row:DockMargin(4, 2, 4, 2)
        row:SetTall(30)
        row.Paint = function(s, w, h)
            draw.RoundedBox(2, 0, 0, w, h, kit.ColorA("surface", 140))
        end

        local isActive = state.activePack == pack.id

        local lbl = vgui.Create("DLabel", row)
        lbl:SetText("")
        lbl:SetPos(8, 6)
        lbl:SetSize(360, 18)
        kit.StyleLabel(lbl, { font = "small",
            color = isActive and "success" or "text" })
        lbl:SetText(pack.id .. "  —  " .. pack.name
            .. (isActive and ("  [" .. L("admin_active_pack") .. "]") or ""))

        local btn = vgui.Create("DButton", row)
        btn:SetText("")
        btn:SetSize(84, 22)
        btn:SetPos(row:GetWide() - 92, 4)
        kit.StyleButton(btn, { style = isActive and "ghost" or "primary", font = "small" })
        btn:SetText(isActive and L("admin_reload_pack") or L("admin_activate"))
        btn.DoClick = function() Act({ type = "switch_pack", id = pack.id }) end
    end
end

-- ═════════════════════════════════════════
-- Cold War Tool Tab
-- ═════════════════════════════════════════
local function BuildColdWarToolTab(content)
    -- Initialize selection storage if not exists
    if not Fireteam.ColdWarTool then
        Fireteam.ColdWarTool = {
            Selection = { scenario = nil, faction = nil, role = nil, spawn = nil }
        }
    end
    local tool = Fireteam.ColdWarTool

    -- Helper functions to get data
    local function GetScenarios()
        local list = Fireteam.Rounds.GetScenarioList()
        if not list then return {} end
        -- Return sorted list of scenario IDs
        local ids = {}
        for id, _ in pairs(list) do table.insert(ids, id) end
        table.sort(ids)
        return ids
    end

    local function GetFactions()
        local factions = Fireteam.Setting.GetData("factions")
        if not factions then return {} end
        local ids = {}
        for id, _ in pairs(factions) do table.insert(ids, id) end
        table.sort(ids)
        return ids
    end

    local function GetVehicleRolesForFaction(factionId)
        local vehicles = Fireteam.VehicleInterface.GetAll()
        if not vehicles then return {} end
        local roles = {}
        local factionData = Fireteam.Setting.GetData("factions")
        local factionInfo = factionData and factionData[factionId] or {}
        local factionTags = factionInfo.tags or {}
        -- Also include coldwar and nato/warsaw tags based on faction
        -- We'll just filter vehicles that have ANY of the faction's tags
        for _, vData in pairs(vehicles) do
            if istable(vData.tags) then
                local match = false
                for _, tag in ipairs(vData.tags) do
                    if table.HasValue(factionTags, tag) then
                        match = true
                        break
                    end
                end
                if match and vData.role then
                    roles[vData.role] = true
                end
            end
        end
        -- Convert to sorted list
        local list = {}
        for role, _ in pairs(roles) do table.insert(list, role) end
        table.sort(list)
        return list
    end

    local function GetSpawnPointsForScenarioAndFaction(scenarioId, factionId)
        -- Temporarily set scenario to get spawns, then restore?
        -- Actually GetScenarioSpawns uses resolved scenario, so we need to set the scenario temporarily.
        -- We'll use a helper that forces scenario lookup without changing global state.
        local scenarioList = Fireteam.Rounds.GetScenarioList()
        if not scenarioList or not scenarioList[scenarioId] then return {} end
        local scenarioData = scenarioList[scenarioId]
        if not scenarioData.spawns then return {} end
        local spawns = scenarioData.spawns[factionId]
        if not spawns then return {} end
        return spawns
    end

    -- UI Elements
    local form = vgui.Create("DPanel", content)
    form:Dock(FILL)
    form:DockMargin(20, 20, 20, 20)
    form.Paint = nil

    -- Title
    local title = vgui.Create("DLabel", form)
    title:SetText(L("ui_cwt_title"))  -- We'll add this locale key later
    title:SetFont("Fireteam.Medium")
    title:SetTextColor(kit.Color("text"))
    title:Dock(TOP)
    title:SetTall(30)
    title:SetContentAlignment(5)

    -- Spacer
    local spacer1 = vgui.Create("DPanel", form)
    spacer1:SetTall(10)
    spacer1:Dock(TOP)

    -- Scenario selector
    local lblScenario = vgui.Create("DLabel", form)
    lblScenario:SetText(L("ui_cwt_scenario"))
    lblScenario:SetFont("Fireteam.Small")
    lblScenario:SetTextColor(kit.Color("text_muted"))
    lblScenario:Dock(TOP)
    lblScenario:SetTall(20)

    local comboScenario = vgui.Create("DComboBox", form)
    comboScenario:SetTall(25)
    comboScenario:Dock(TOP)
    comboScenario:SetSortItems(false)
    comboScenario.OnSelect = function(_, index, value)
        -- Clear dependent selections when scenario changes
        comboFaction:Clear()
        comboFaction:SetValue("")
        comboRole:Clear()
        comboRole:SetValue("")
        comboSpawn:Clear()
        comboSpawn:SetValue("")
        -- Populate factions
        local factions = GetFactions()
        for _, fid in ipairs(factions) do
            comboFaction:AddChoice(fid)
        end
    end
    -- Populate scenarios initially
    local scenarios = GetScenarios()
    for _, sid in ipairs(scenarios) do
        comboScenario:AddChoice(sid)
    end

    -- Spacer
    local spacer2 = vgui.Create("DPanel", form)
    spacer2:SetTall(10)
    spacer2:Dock(TOP)

    -- Faction selector
    local lblFaction = vgui.Create("DLabel", form)
    lblFaction:SetText(L("ui_cwt_faction"))
    lblFaction:SetFont("Fireteam.Small")
    lblFaction:SetTextColor(kit.Color("text_muted"))
    lblFaction:Dock(TOP)
    lblFaction:SetTall(20)

    local comboFaction = vgui.Create("DComboBox", form)
    comboFaction:SetTall(25)
    comboFaction:Dock(TOP)
    comboFaction:SetSortItems(false)
    comboFaction.OnSelect = function(_, index, value)
        -- Clear dependent selections when faction changes
        comboRole:Clear()
        comboRole:SetValue("")
        comboSpawn:Clear()
        comboSpawn:SetValue("")
        -- Populate vehicle roles based on selected faction
        local scenarioId = comboScenario:GetValue()
        if scenarioId and scenarioId ~= "" then
            local roles = GetVehicleRolesForFaction(value)
            for _, role in ipairs(roles) do
                comboRole:AddChoice(role)
            end
        end
    end

    -- Spacer
    local spacer3 = vgui.Create("DPanel", form)
    spacer3:SetTall(10)
    spacer3:Dock(TOP)

    -- Vehicle Role selector
    local lblRole = vgui.Create("DLabel", form)
    lblRole:SetText(L("ui_cwt_role"))
    lblRole:SetFont("Fireteam.Small")
    lblRole:SetTextColor(kit.Color("text_muted"))
    lblRole:Dock(TOP)
    lblRole:SetTall(20)

    local comboRole = vgui.Create("DComboBox", form)
    comboRole:SetTall(25)
    comboRole:Dock(TOP)
    comboRole:SetSortItems(false)
    comboRole.OnSelect = function(_, index, value)
        -- Clear spawn selection when role changes
        comboSpawn:Clear()
        comboSpawn:SetValue("")
        -- Populate spawn points based on selected scenario, faction, and role
        local scenarioId = comboScenario:GetValue()
        local factionId = comboFaction:GetValue()
        if scenarioId and scenarioId ~= "" and factionId and factionId ~= "" then
            local spawns = GetSpawnPointsForScenarioAndFaction(scenarioId, factionId)
            for i, spawn in ipairs(spawns) do
                -- Use a readable label for spawn point
                local label = string.format("Spawn %d", i)
                comboSpawn:AddChoice(label, spawn)  -- store spawn data as user data
            end
        end
    end

    -- Spacer
    local spacer4 = vgui.Create("DPanel", form)
    spacer4:SetTall(10)
    spacer4:Dock(TOP)

    -- Spawn Point selector
    local lblSpawn = vgui.Create("DLabel", form)
    lblSpawn:SetText(L("ui_cwt_spawn"))
    lblSpawn:SetFont("Fireteam.Small")
    lblSpawn:SetTextColor(kit.Color("text_muted"))
    lblSpawn:Dock(TOP)
    lblSpawn:SetTall(20)

    local comboSpawn = vgui.Create("DComboBox", form)
    comboSpawn:SetTall(25)
    comboSpawn:Dock(TOP)
    comboSpawn:SetSortItems(false)

    -- Spacer before button
    local spacer5 = vgui.Create("DPanel", form)
    spacer5:SetTall(20)
    spacer5:Dock(TOP)

    -- Apply Button
    local btnApply = vgui.Create("DButton", form)
    btnApply:SetTall(35)
    btnApply:Dock(TOP)
    btnApply:SetText(L("ui_cwt_apply"))
    kit.StyleButton(btnApply, { style = "primary" })
    btnApply.DoClick = function()
        local scenarioId = comboScenario:GetValue()
        local factionId = comboFaction:GetValue()
        local role = comboRole:GetValue()
        local spawnIndex, spawnData = comboSpawn:GetSelected()
        if not scenarioId or scenarioId == "" then
            chat.AddText(kit.Color("warning"), "[ColdWarTool] " .. L("ui_cwt_err_scenario"))
            return
        end
        if not factionId or factionId == "" then
            chat.AddText(kit.Color("warning"), "[ColdWarTool] " .. L("ui_cwt_err_faction"))
            return
        end
        if not role or role == "" then
            chat.AddText(kit.Color("warning"), "[ColdWarTool] " .. L("ui_cwt_err_role"))
            return
        end
        if not spawnData then
            chat.AddText(kit.Color("warning"), "[ColdWarTool] " .. L("ui_cwt_err_spawn"))
            return
        end
        -- Store selection
        tool.Selection.scenario = scenarioId
        tool.Selection.faction = factionId
        tool.Selection.role = role
        tool.Selection.spawn = spawnData
        -- Feedback
        chat.AddText(kit.Color("success"), "[ColdWarTool] " .. L("ui_cwt_applied"))
        -- Optionally, we could trigger a rediscover or notify other systems
        -- For now just close the admin panel? Or leave open.
        -- Fireteam.Admin.Open()  -- rebuild to reflect any changes if needed
    end
    end
local BUILDERS = {
    config  = BuildConfigTab,
    rounds  = BuildRoundsTab,
    players = BuildPlayersTab,
    packs   = BuildPacksTab,
    coldwar_tool = BuildColdWarToolTab,
}

-- ═══════════════════════════════════════
-- 面板骨架
-- ═══════════════════════════════════════
function Fireteam.Admin.Open()
    if IsValid(panel) then
        panel:Remove()
        return
    end
    if not LocalPlayer():IsAdmin() then
        chat.AddText(kit.Color("danger"), "[FIRETEAM] " .. L("admin_denied"))
        return
    end

    local W, H = math.Round(ScrW() * 0.62), math.Round(ScrH() * 0.66)
    panel = kit.CreateFrame(L("ui_admin_title"), W, H, {
        blur = true,
        hints = { L("ui_hint_f10_close"), L("ui_hint_esc_close") }
    })

    -- 页签按钮行
    local tabBar = vgui.Create("DPanel", panel)
    tabBar:Dock(TOP)
    tabBar:DockMargin(8, panel.ftContentTop + 2, 8, 4)
    tabBar:SetTall(30)
    tabBar.Paint = nil

    tabButtons = {}
    for _, tab in ipairs(TABS) do
        local b = vgui.Create("DButton", tabBar)
        b:SetText("")
        b:Dock(LEFT)
        b:DockMargin(0, 0, 6, 0)
        b:SetWide(math.Round(W / #TABS) - 8)

        b.tabId = tab.id
        b.tabLabelKey = tab.label
        tabButtons[tab.id] = b

        b.DoClick = function()
            activeTab = tab.id
            panel:Rebuild()
        end
    end

    -- 内容容器
    local content = vgui.Create("DPanel", panel)
    content:Dock(FILL)
    content:DockMargin(8, 0, 8, panel.ftContentBottom + 8)
    content.Paint = nil

    function panel:RefreshTabs()
        for id, b in pairs(tabButtons) do
            if IsValid(b) then
                kit.StyleButton(b, { style = id == activeTab and "primary" or "ghost" })
                b:SetText(L(b.tabLabelKey))
            end
        end
    end

    function panel:Rebuild()
        if not IsValid(content) then return end
        content:Clear()
        panel:RefreshTabs()

        local builder = BUILDERS[activeTab]
        if builder then builder(content) end
    end

    panel:Rebuild()
    Act({ type = "refresh" })   -- 首次打开拉取服务端真实状态；后续由动作回包驱动
end

function Fireteam.Admin.Close()
    if IsValid(panel) then panel:Remove() end
end

hook.Add("PlayerButtonDown", "Fireteam.Admin.Toggle", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button ~= KEY_F10 then return end
    if not kit.CanTogglePanel() then return end
    Fireteam.Admin.Open()
end)
