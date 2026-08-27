-- modules/packeditor/cl_packeditor_ui.lua
-- FIRETEAM Setting Pack Editor - Client UI
-- F9 开关；schema 驱动表单 + 调色板/元素布局特化编辑器。
-- 编辑在客户端内存进行，导出时整体发回服务端落盘。

local kit = Fireteam.UI
local PE  = Fireteam.PackEditor
local L = function(key, ...)
    return Fireteam.Locale and Fireteam.Locale.Get(key, ...) or key
end

-- 编辑态：{ packs={id=name}, id=当前包, files={ pack={}, hud_theme={}, ... } }
local editData   = { packs = {} }
local panel      = nil
local packCombo  = nil   -- 顶栏设定包下拉（列表回包后刷新选项）

-- ═══════════════════════════════════════
-- 网络回包
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.PACK_EDITOR_DATA, function()
    local data = net.ReadTable()
    if not istable(data) then return end

    if data.packs then
        editData.packs = data.packs
        if IsValid(packCombo) then
            packCombo:Clear()
            for pid, name in pairs(data.packs) do
                packCombo:AddChoice(pid .. " — " .. name)
            end
        end
    end
    if data.error then
        chat.AddText(Color(255, 100, 100), "[FIRETEAM] " .. L("pe_no_pack"))
        return
    end
    if data.id and istable(data.files) then
        editData.id    = data.id
        editData.files = data.files
        if IsValid(panel) then panel:Rebuild() end
    end
end)

-- ═══════════════════════════════════════
-- 行构建器
-- ═══════════════════════════════════════
local function Row(parent, labelText)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(4, 2, 4, 2)
    row:SetTall(26)
    row.Paint = function(s, w, h)
        draw.RoundedBox(2, 0, 0, w, h, kit.ColorA("surface", 120))
    end

    local label = vgui.Create("DLabel", row)
    label:Dock(LEFT)
    label:SetWide(230)
    label:DockPadding(8, 0, 0, 0)
    label:SetText(labelText)
    label:SetTextColor(kit.Color("text"))
    label:SetFont(kit.Font("small"))

    return row, label
end

--- 文本/数字输入行
local function BuildValueRow(scroll, tbl, path, meta)
    local cur = PE.PathGet(tbl, path)
    local row = Row(scroll, path)

    local entry = kit.CreateEntry(row)
    entry:Dock(FILL)
    entry:DockMargin(6, 3, 6, 3)
    entry:SetValue(cur ~= nil and tostring(cur) or "")
    entry.OnEnter = function(s)
        local raw = s:GetValue()
        local value = raw
        if meta.type == "number" then value = tonumber(raw) end
        if value ~= nil then
            PE.PathSet(tbl, path, value)
        elseif meta.type == "number" then
            -- 数字留空 = 删除该键（对应 lua 的 nil，如 score_limit）
            local t = tbl
            local segs = string.Explode(".", path)
            for i = 1, #segs - 1 do t = istable(t) and t[segs[i]] or nil end
            if istable(t) then t[segs[#segs]] = nil end
        end
    end
end

--- 布尔行
local function BuildBoolRow(scroll, tbl, path)
    local row = Row(scroll, path)
    local check = vgui.Create("DCheckBox", row)
    check:Dock(LEFT)
    check:DockMargin(6, 5, 0, 5)
    check:SetValue(PE.PathGet(tbl, path) == true)
    check.OnChange = function(_, v) PE.PathSet(tbl, path, v) end
end

--- 枚举行（下拉）
local function BuildEnumRow(scroll, tbl, path, options)
    local row = Row(scroll, path)
    local combo = vgui.Create("DComboBox", row)
    combo:Dock(FILL)
    combo:DockMargin(6, 3, 6, 3)
    for _, opt in ipairs(options) do combo:AddChoice(opt) end
    combo:SetValue(tostring(PE.PathGet(tbl, path) or ""))
    combo.OnSelect = function(_, _, val) PE.PathSet(tbl, path, val) end
end

--- 调色板：每色一行 swatch，点击弹出取色器
local function BuildColorMap(scroll, themeTbl)
    local palette = themeTbl.palette or {}
    local keys = {}
    for k in pairs(palette) do keys[#keys + 1] = k end
    table.sort(keys)

    for _, key in ipairs(keys) do
        local row = Row(scroll, "palette." .. key)
        local hex = palette[key]
        local col = PE.HexToColor(hex)

        local swatch = vgui.Create("DButton", row)
        swatch:Dock(FILL)
        swatch:DockMargin(6, 3, 6, 3)
        swatch:SetText("")
        swatch.Paint = function(s, w, h)
            draw.RoundedBox(2, 0, 0, w, h, col)
            draw.SimpleText(hex or "?", kit.Font("small"), w / 2, h / 2,
                Color(0, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        swatch.DoClick = function()
            local popup = vgui.Create("DFrame")
            popup:SetSize(260, 220)
            popup:Center()
            popup:SetTitle(L("pe_pick_color") .. " — " .. key)
            popup:MakePopup()

            local mixer = vgui.Create("DColorMixer", popup)
            mixer:Dock(FILL)
            mixer:SetPalette(true)
            mixer:SetAlphaBar(false)
            mixer:SetWangs(true)
            mixer:SetColor(col)
            function mixer:ValueChanged(c)
                col = c
                palette[key] = PE.ColorToHex(c)
            end
        end
    end
end

--- 元素布局：每个 element 一行 style / position / open_key
local function BuildElementMap(scroll, themeTbl)
    local elements = themeTbl.elements or {}
    local keys = {}
    for k in pairs(elements) do keys[#keys + 1] = k end
    table.sort(keys)

    for _, key in ipairs(keys) do
        local el = elements[key]
        if not istable(el) then continue end

        local header = Row(scroll, "elements." .. key)
        header:SetTall(20)
        header.Paint = function(s, w, h)
            draw.SimpleText("elements." .. key, kit.Font("small"), 8, h / 2,
                kit.Color("accent"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        for _, prop in ipairs({ "style", "position", "open_key" }) do
            if el[prop] ~= nil then
                local row = Row(scroll, prop)
                local entry = kit.CreateEntry(row)
                entry:Dock(FILL)
                entry:DockMargin(6, 3, 6, 3)
                entry:SetValue(tostring(el[prop]))
                entry.OnEnter = function(s) el[prop] = s:GetValue() end
            end
        end
    end
end

-- ═══════════════════════════════════════
-- 主面板
-- ═══════════════════════════════════════
function Fireteam.PackEditor.Open()
    if not LocalPlayer():IsAdmin() then
        chat.AddText(Color(255, 100, 100), "[FIRETEAM] " .. L("admin_denied"))
        return
    end
    if not Fireteam.Config.Get("packeditor.enabled") then return end
    if IsValid(panel) then panel:Remove() end

    local W, H = math.min(940, ScrW() - 80), math.min(660, ScrH() - 80)
    panel = kit.CreateFrame(L("ui_packeditor_title"), W, H,
        { blur = true, hints = { "ui_hint_f9_close", "ui_hint_esc_close" } })
    panel:Center()
    -- CreateFrame 内部已 MakePopup，此处不再重复调用

    -- ── 顶栏：选择设定包 / 载入 / 导出 ──
    local top = vgui.Create("DPanel", panel)
    top:Dock(TOP)
    top:SetTall(panel.ftContentTop or 40)
    top.Paint = nil

    packCombo = vgui.Create("DComboBox", top)
    packCombo:Dock(LEFT)
    packCombo:SetWide(240)
    packCombo:DockMargin(8, 8, 4, 8)
    for pid, name in pairs(editData.packs) do
        packCombo:AddChoice(pid .. " — " .. name)
    end

    local loadBtn = vgui.Create("DButton", top)
    loadBtn:Dock(LEFT)
    loadBtn:SetWide(90)
    loadBtn:DockMargin(0, 8, 4, 8)
    kit.StyleButton(loadBtn, { font = "small" })
    loadBtn:SetText(L("pe_load"))
    loadBtn.DoClick = function()
        local sel = packCombo:GetSelected() or ""
        local pid = string.match(sel, "^([%w_%-]+)")
        if pid then
            Fireteam.Net.SendToServer(Fireteam.NET.PACK_EDITOR_PULL, pid)
        end
    end

    local exportBtn = vgui.Create("DButton", top)
    exportBtn:Dock(RIGHT)
    exportBtn:SetWide(90)
    exportBtn:DockMargin(4, 8, 8, 8)
    kit.StyleButton(exportBtn, { style = "primary", font = "small" })
    exportBtn:SetText(L("pe_export"))
    exportBtn.DoClick = function()
        if not editData.id or not istable(editData.files) then return end
        Fireteam.Net.SendToServer(Fireteam.NET.PACK_EDITOR_EXPORT, {
            id    = editData.id,
            files = editData.files,
        })
    end

    -- 打开即请求列表
    Fireteam.Net.SendToServer(Fireteam.NET.PACK_EDITOR_PULL, "")

    -- ── 滚动表单区 ──
    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(6, 0, 6, (panel.ftContentBottom or 28) + 4)

    function panel:Rebuild()
        for _, c in ipairs(scroll:GetCanvas():GetChildren()) do c:Remove() end

        if not editData.files then
            local hint = vgui.Create("DLabel", scroll)
            hint:Dock(TOP)
            hint:DockMargin(12, 12, 12, 12)
            hint:SetText(L("pe_pick_pack_hint"))
            hint:SetTextColor(kit.Color("text_muted"))
            return
        end

        for _, section in ipairs(PE.SCHEMA) do
            local tbl = editData.files[section.file]
            if not istable(tbl) then continue end

            -- 区块标题
            local head = vgui.Create("DPanel", scroll)
            head:Dock(TOP)
            head:SetTall(30)
            head.Paint = function(s, w, h)
                draw.RoundedBox(2, 0, 0, w, h, kit.ColorA("surface", 200))
                draw.SimpleText(L(section.title_key), kit.Font("medium"),
                    10, h / 2, kit.Color("accent"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            for _, field in ipairs(section.fields) do
                if field.type == "colormap" then
                    BuildColorMap(scroll, tbl)
                elseif field.type == "elementmap" then
                    BuildElementMap(scroll, tbl)
                elseif field.type == "boolean" then
                    BuildBoolRow(scroll, tbl, field.path)
                elseif field.type == "enum" then
                    BuildEnumRow(scroll, tbl, field.path, field.options or {})
                else
                    BuildValueRow(scroll, tbl, field.path, field)
                end
            end
        end
    end

    panel:Rebuild()
end

function Fireteam.PackEditor.Close()
    if IsValid(panel) then panel:Remove() end
end

--- 面板开关由 core/sh_keybinds.lua 统一分配（命令 ft_packeditor）
function Fireteam.PackEditor.Toggle()
    if not Fireteam.Config.Get("packeditor.enabled") then return end
    if IsValid(panel) then
        Fireteam.PackEditor.Close()
    else
        Fireteam.PackEditor.Open()
    end
end

Fireteam.Log.Info("PackEditor", "✓ 客户端 UI 已加载")
