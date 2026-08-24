-- modules/class/cl_class.lua
-- FIRETEAM Class System - Client UI

if not Fireteam then Fireteam = {} end
Fireteam.Class = Fireteam.Class or {}

local classPanel = nil

-- 接收职业分配通知
net.Receive(Fireteam.NET.CLASS_ASSIGN, function()
    local ply = net.ReadEntity()
    local classId = net.ReadString()
    if IsValid(ply) and ply == LocalPlayer() then
        LocalPlayer().FT_Class = classId
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
        chat.AddText(Color(255, 100, 100), "[FIRETEAM] Join a squad first to select a class.")
        return
    end

    local availableClasses = Fireteam.Class.GetByFaction(mySquad.faction)

    classPanel = vgui.Create("DFrame")
    classPanel:SetSize(600, 450)
    classPanel:Center()
    classPanel:SetTitle("FIRETEAM - Select Class")
    classPanel:MakePopup()

    local scroll = vgui.Create("DScrollPanel", classPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 10, 10, 10)

    for classId, data in pairs(availableClasses) do
        local btn = scroll:Add("DButton")
        btn:SetTall(50)
        btn:Dock(TOP)
        btn:DockMargin(0, 4, 0, 4)
        btn:SetText(data.name .. " (" .. data.name_zh .. ")")

        -- 高亮当前职业
        if LocalPlayer().FT_Class == classId then
            btn:SetColor(Color(51, 255, 51))
        end

        btn.DoClick = function()
            net.Start("FT_ClassAssign")
                net.WriteString(classId)
            net.SendToServer()
            classPanel:Remove()
        end

        -- 描述标签
        local descLabel = scroll:Add("DLabel")
        descLabel:SetText("  Abilities: " .. table.concat(data.abilities or {}, ", "))
        descLabel:Dock(TOP)
        descLabel:SetTextColor(Color(150, 150, 150))
    end
end

-- F8 打开职业选择
hook.Add("PlayerButtonDown", "Fireteam.Class.OpenKey", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button == KEY_F8 then
        Fireteam.Class.OpenSelectPanel()
    end
end)

print("[FIRETEAM:Class] ✓ Client UI loaded")
