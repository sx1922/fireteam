-- modules/class/cl_class.lua
-- FIRETEAM Class System - Client UI
-- 面板走 UI Kit 主题壳层，文案经 Fireteam.Locale。

if not Fireteam then Fireteam = {} end
Fireteam.Class = Fireteam.Class or {}

local kit = Fireteam.UI
local L = Fireteam.Locale.Get

local classPanel = nil

-- 接收职业分配通知
net.Receive(Fireteam.NET.CLASS_ASSIGN, function()
    local ply = net.ReadEntity()
    local classId = net.ReadString()
    if IsValid(ply) and ply == LocalPlayer() then
        LocalPlayer().FT_Class = classId
        chat.AddText(kit.Color("primary"), "[FIRETEAM] "
            .. L("class_selected", classId))
    end
end)

-- ═══════════════════════════════════════
-- 职业选择面板（按 F8 打开）
-- ═══════════════════════════════════════
function Fireteam.Class.OpenSelectPanel()
    if IsValid(classPanel) then
        classPanel:Remove()
    end

    local mySquad = Fireteam.Squad.GetMySquad()
    if not mySquad then
        chat.AddText(kit.Color("danger"), "[FIRETEAM] "
            .. L("ui_join_squad_first"))
        return
    end

    local availableClasses = Fireteam.Class.GetByFaction(mySquad.faction)

    local W = math.Round(620 * (ScrW() / 1920))
    local H = math.Round(470 * (ScrH() / 1080))
    classPanel = kit.CreateFrame(L("ui_class_title"), W, H, {
        blur = true,
        hints = { L("ui_hint_esc_close") }
    })

    local scroll = vgui.Create("DScrollPanel", classPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(14, classPanel.ftContentTop, 14, classPanel.ftContentBottom + 6)

    for classId, data in pairs(availableClasses) do
        local isCurrent = (LocalPlayer().FT_Class == classId)

        -- 职业卡片按钮
        local btn = scroll:Add("DButton")
        btn:SetTall(46)
        btn:Dock(TOP)
        btn:DockMargin(30, isCurrent and 8 or 4, 30, 2)
        btn:SetText((data.name or classId)
            .. (data.name_zh and (" · " .. data.name_zh) or "")
            .. (isCurrent and ("   ✓ " .. L("ui_current")) or ""))
        kit.StyleButton(btn, { style = isCurrent and "primary" or "ghost" })

        -- 描述标签（能力）
        local descLabel = scroll:Add("DLabel")
        descLabel:SetText("  " .. L("ui_abilities", table.concat(data.abilities or {}, ", ")))
        kit.StyleLabel(descLabel, { font = "small", color = "text_muted" })
        descLabel:Dock(TOP)
        descLabel:DockMargin(38, 0, 38, 6)
        descLabel:SizeToContentsY()

        btn.DoClick = function()
            net.Start(Fireteam.NET.CLASS_ASSIGN)
                net.WriteString(classId)
            net.SendToServer()
            classPanel:Remove()
        end
    end
end

-- F8 打开职业选择
hook.Add("PlayerButtonDown", "Fireteam.Class.OpenKey", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button == KEY_F8 and Fireteam.UI.CanTogglePanel() then
        Fireteam.Class.OpenSelectPanel()
    end
end)

print("[FIRETEAM:Class] ✓ 客户端 UI 已加载")
