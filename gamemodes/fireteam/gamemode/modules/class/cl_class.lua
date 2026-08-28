-- modules/class/cl_class.lua
-- FIRETEAM Class System - Client UI
-- 面板走 UI Kit 主题壳层，文案经 Fireteam.Locale。
-- 冷战军事风格：图标 + 装备槽 + 属性条 + 能力标签

if not Fireteam then Fireteam = {} end
Fireteam.Class = Fireteam.Class or {}

local kit = Fireteam.UI
local L = Fireteam.Locale.Get

local classPanel = nil

-- 贴图路径前缀（data.icon 已含完整路径，无需再拼前缀）
local TEX_CLASS = "fireteam/classes/"

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
-- 职业选择面板（按 F3 打开）
-- ═══════════════════════════════════════
function Fireteam.Class.OpenSelectPanel()
    if IsValid(classPanel) then
        classPanel:Remove()
        return
    end

    local mySquad = Fireteam.Squad.GetMySquad()
    if not mySquad then
        chat.AddText(kit.Color("danger"), "[FIRETEAM] "
            .. L("ui_join_squad_first"))
        return
    end

    local availableClasses = Fireteam.Class.GetByFaction(mySquad.faction)

    local W = math.Round(700 * (ScrW() / 1920))
    local H = math.Round(560 * (ScrH() / 1080))
    classPanel = kit.CreateFrame(L("ui_class_title"), W, H, {
        blur = true,
        hints = { L("ui_hint_esc_close") }
    })

    local scroll = vgui.Create("DScrollPanel", classPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(14, classPanel.ftContentTop, 14, classPanel.ftContentBottom + 6)

    -- 排序：当前职业排在最前
    local sorted = {}
    for classId, data in pairs(availableClasses) do
        sorted[#sorted + 1] = { id = classId, data = data }
    end
    table.sort(sorted, function(a, b)
        local aCur = (LocalPlayer().FT_Class == a.id)
        local bCur = (LocalPlayer().FT_Class == b.id)
        if aCur ~= bCur then return aCur end
        return (a.data.name or a.id) < (b.data.name or b.id)
    end)

    for _, entry in ipairs(sorted) do
        local classId = entry.id
        local data = entry.data
        local isCurrent = (LocalPlayer().FT_Class == classId)

        -- 加载职业图标（data.icon 已含完整路径 + .png 后缀，需去掉后缀让 Material() 解析 .vmt）
        local iconMat = nil
        if data.icon then
            local iconPath = string.gsub(data.icon, "%.png$", "")
            iconMat = Material(iconPath)
        end

        -- 职业卡片（DButton + 自定义 Paint）
        local card = scroll:Add("DButton")
        card:SetTall(86)
        card:Dock(TOP)
        card:DockMargin(8, isCurrent and 8 or 4, 8, 4)
        card:SetText("")
        card.DoClick = function()
            net.Start(Fireteam.NET.CLASS_ASSIGN)
                net.WriteString(classId)
            net.SendToServer()
            classPanel:Remove()
        end

        card.Paint = function(s, w, h)
            s.ftHoverLerp = Lerp(FrameTime() * 12, s.ftHoverLerp or 0, s:IsHovered() and 1 or 0)
            local hover = s.ftHoverLerp

            local accentName = isCurrent and "primary" or "primary"
            local accent = kit.Color(accentName)

            -- 底色
            local fillA = isCurrent and (25 + hover * 20) or (10 + hover * 30)
            surface.SetDrawColor(Color(accent.r, accent.g, accent.b, fillA))
            surface.DrawRect(0, 0, w, h)

            -- 左侧高亮条
            local barW = isCurrent and 3 or (2 + hover * 2)
            surface.SetDrawColor(Color(accent.r, accent.g, accent.b, isCurrent and 200 or (60 + hover * 120)))
            surface.DrawRect(0, 0, barW, h)

            -- 边框
            surface.SetDrawColor(Color(accent.r, accent.g, accent.b, isCurrent and 180 or (50 + hover * 60)))
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            -- ─── 左栏：图标 + 名称 ───
            local iconSize = 48
            local iconX = 14
            local iconY = (h - iconSize) / 2
            if iconMat and not iconMat:IsError() then
                surface.SetMaterial(iconMat)
                local ic = kit.ColorA("text", 220)
                surface.SetDrawColor(ic.r, ic.g, ic.b, ic.a)
                surface.DrawTexturedRect(iconX, iconY, iconSize, iconSize)
            else
                -- 文字占位
                local initials = string.sub(data.name or classId, 1, 2)
                surface.SetDrawColor(kit.ColorA("border", 120))
                surface.DrawRect(iconX, iconY, iconSize, iconSize)
                draw.SimpleText(string.upper(initials), kit.Font("small"),
                    iconX + iconSize / 2, iconY + iconSize / 2,
                    kit.ColorA("text_muted", 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            local nameX = iconX + iconSize + 12
            draw.SimpleText(data.name or classId, kit.Font("body"),
                nameX, 16, kit.ColorA("text", 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if data.name_zh then
                draw.SimpleText(data.name_zh, kit.Font("small"),
                    nameX, 34, kit.ColorA("text_muted", 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            -- 当前职业标记
            if isCurrent then
                local tag = "✓ " .. L("ui_current")
                surface.SetFont(kit.Font("small"))
                local tagW = select(1, surface.GetTextSize(tag))
                local tagX = w - tagW - 14
                surface.SetDrawColor(kit.ColorA("primary", 50))
                surface.DrawRect(tagX - 6, 10, tagW + 12, 18)
                draw.SimpleText(tag, kit.Font("small"),
                    tagX + tagW / 2, 19, kit.Color("primary"),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            -- ─── 中栏：属性条 ───
            local statsX = nameX
            local statsY = 52
            local statsW = 120
            if data.stats then
                local stats = data.stats
                local function DrawStatBar(label, frac, valText, colName)
                    if not frac then return end
                    draw.SimpleText(label, kit.Font("small"), statsX, statsY,
                        kit.ColorA("text_muted", 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    local barX = statsX + 30
                    local barW = 60
                    surface.SetDrawColor(kit.ColorA("background", 180))
                    surface.DrawRect(barX, statsY - 3, barW, 6)
                    surface.SetDrawColor(kit.ColorA(colName or "primary", 200))
                    surface.DrawRect(barX, statsY - 3, barW * math.Clamp(frac, 0, 1), 6)
                    surface.SetDrawColor(kit.ColorA("border", 160))
                    surface.DrawOutlinedRect(barX, statsY - 3, barW, 6, 1)
                    if valText then
                        draw.SimpleText(valText, kit.Font("small"), barX + barW + 6, statsY,
                            kit.ColorA("text", 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                    statsY = statsY + 12
                end

                -- 速度
                if stats.speed then
                    DrawStatBar("速度", stats.speed / 1.1, string.format("%.2fx", stats.speed))
                end
                -- 护甲
                if stats.armor then
                    DrawStatBar("护甲", stats.armor / 3, tostring(stats.armor))
                end
                -- 无线电
                if stats.radio then
                    local radioText = stats.radio >= 2 and "小队+指挥" or "小队"
                    draw.SimpleText("无线电: " .. radioText, kit.Font("small"),
                        statsX, statsY, kit.ColorA("success", 200),
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end

            -- ─── 右栏：装备槽 + 能力 ───
            local rightX = w - 230
            if rightX < statsX + 130 then rightX = statsX + 130 end

            -- 装备槽
            if data.loadout then
                local slotY = 14
                draw.SimpleText("装备", kit.Font("small"), rightX, slotY,
                    kit.ColorA("text_muted", 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                slotY = slotY + 14

                for slotName, slotData in pairs(data.loadout) do
                    if istable(slotData) and slotData.label then
                        local label = slotData.label
                        local opt = slotData.optional
                        local slotText = (opt and "▪ " or "▪ ") .. label
                        if opt then slotText = slotText .. " ?" end
                        draw.SimpleText(slotText, kit.Font("small"), rightX, slotY,
                            kit.ColorA(opt and "text_muted" or "text", opt and 150 or 200),
                            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        slotY = slotY + 12
                        if slotY > h - 22 then break end
                    end
                end
            end

            -- 能力标签
            if data.abilities and #data.abilities > 0 then
                local abY = h - 18
                local abX = rightX
                for i = #data.abilities, 1, -1 do
                    local ab = data.abilities[i]
                    surface.SetFont(kit.Font("small"))
                    local abW = select(1, surface.GetTextSize(ab))
                    local tagW = abW + 8
                    abX = abX - tagW
                    if abX < rightX - 100 then break end
                    surface.SetDrawColor(kit.ColorA("accent", 40))
                    surface.DrawRect(abX, abY, tagW, 14)
                    surface.SetDrawColor(kit.ColorA("accent", 80))
                    surface.DrawOutlinedRect(abX, abY, tagW, 14, 1)
                    draw.SimpleText(ab, kit.Font("small"), abX + tagW / 2, abY + 7,
                        kit.ColorA("text", 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    abX = abX - 4
                end
            end
        end
    end
end

-- 面板开关由 core/sh_keybinds.lua 统一分配（命令 ft_class / 引擎 ShowSpare1=F3）

Fireteam.Log.Info("Class", "✓ 客户端 UI 已加载")
