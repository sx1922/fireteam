-- modules/inventory/cl_inventory_ui.lua
-- FIRETEAM Inventory - Tarkov-style Grid Backpack (Tab) + Hotbar HUD
-- 计数表为真源；网格实例（ClientCells）由服务端权威布局，拖拽经 ITEM_MOVE 校验。

if not Fireteam then Fireteam = {} end
Fireteam.Inventory = Fireteam.Inventory or {}

local kit = Fireteam.UI
local L = Fireteam.Locale.Get

-- ═══════════════════════════════════════
-- Tab 背包面板
-- ═══════════════════════════════════════
local invPanel = nil
local dragState = nil   -- { index, id, w, h, offX, offY }
local lastClick = { time = 0, index = 0 }

local function CellPx()
    return math.Round(52 * math.Clamp(ScrW() / 1920, 0.7, 1.2))
end

local function CellAtMouse(gx, gy)
    local cells = Fireteam.Inventory.ClientCells or {}
    for i, cell in ipairs(cells) do
        if gx >= cell.x and gx < cell.x + (cell.w or 1)
            and gy >= cell.y and gy < cell.y + (cell.h or 1) then
            return i, cell
        end
    end
    return nil
end

function Fireteam.Inventory.OpenBackpack()
    if IsValid(invPanel) then return end

    local scaleW = ScrW() / 1920
    local W, H = math.Round(900 * scaleW), math.Round(620 * (ScrH() / 1080))
    invPanel = kit.CreateFrame(L("ui_inventory_title"), W, H, { blur = true })

    local cp = CellPx()
    local gridW = Fireteam.Inventory.GRID_W * cp
    local gridH = Fireteam.Inventory.GRID_H * cp
    local leftW = math.Round(230 * scaleW)

    -- ─── 左侧：当前武器 + 健康检查 ───
    local left = vgui.Create("DPanel", invPanel)
    left:SetPos(12, invPanel.ftContentTop + 8)
    left:SetSize(leftW, H - invPanel.ftContentTop - invPanel.ftContentBottom - 16)
    left.Paint = function(s, w, h)
        draw.SimpleText(L("ui_inventory_weapons"), kit.Font("small"), 8, 6,
            kit.Color("text_muted"), TEXT_ALIGN_LEFT)
        local y = 28
        local lp = LocalPlayer()
        if IsValid(lp) then
            for _, wep in ipairs(lp:GetWeapons()) do
                draw.SimpleText(language.GetPhrase(wep.PrintName or wep:GetClass()),
                    kit.Font("small"), 8, y, kit.Color("text"), TEXT_ALIGN_LEFT)
                y = y + 20
                if y > h * 0.42 then break end
            end
        end

        local healthY = h * 0.48
        draw.SimpleText(L("ui_inventory_health"), kit.Font("small"), 8, healthY,
            kit.Color("text_muted"), TEXT_ALIGN_LEFT)
        local vy = healthY + 22
        local vt = Fireteam.Vitals and Fireteam.Vitals.Client
            and Fireteam.Vitals.Client[LocalPlayer():EntIndex()] or nil
        if istable(vt) and istable(vt.limbs) then
            for _, part in ipairs(Fireteam.Vitals.LIMB_ORDER or {}) do
                local hp = tonumber(vt.limbs[part]) or 0
                local maxHp = Fireteam.Vitals.LIMBS[part] or 1
                local frac = math.Clamp(hp / maxHp, 0, 1)
                local col = "squad_ally"
                if frac <= 0 then col = "danger"
                elseif frac <= 0.4 then col = "warning" end
                draw.SimpleText(Fireteam.Locale.Get("vitals_limb_" .. part),
                    kit.Font("small"), 8, vy, kit.Color("text"), TEXT_ALIGN_LEFT)
                kit.DrawProgressBar(72, vy + 3, 110, 8, frac, col)
                if istable(vt.fractures) and vt.fractures[part] then
                    draw.SimpleText("✕", kit.Font("small"), 190, vy,
                        kit.Color("danger"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
                vy = vy + 24
            end
        end
    end

    -- ─── 右侧：10×6 网格 ───
    local grid = vgui.Create("DPanel", invPanel)
    grid:SetPos(leftW + 24, invPanel.ftContentTop + 8)
    grid:SetSize(gridW, gridH)
    grid.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, kit.ColorA("background", 210))

        surface.SetDrawColor(kit.ColorA("border", 110))
        for gx = 0, Fireteam.Inventory.GRID_W do
            surface.DrawRect(gx * cp, 0, 1, h)
        end
        for gy = 0, Fireteam.Inventory.GRID_H do
            surface.DrawRect(0, gy * cp, w, 1)
        end

        -- 物品实例（拖拽中的跳过）
        for i, cell in ipairs(Fireteam.Inventory.ClientCells or {}) do
            if not (dragState and dragState.index == i) then
                local x, y = cell.x * cp, cell.y * cp
                local cw, ch = (cell.w or 1) * cp, (cell.h or 1) * cp
                draw.RoundedBox(3, x + 2, y + 2, cw - 4, ch - 4, kit.ColorA("surface", 245))
                surface.SetDrawColor(kit.ColorA("primary", 150))
                surface.DrawOutlinedRect(x + 2, y + 2, cw - 4, ch - 4, 1)
                local name = Fireteam.Inventory.GetDisplayName(cell.id)
                draw.SimpleText(name, kit.Font("small"), x + cw / 2, y + ch / 2,
                    kit.ColorA("text", 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        -- 拖拽跟随
        if dragState then
            local mx, my = s:CursorPos()
            local x, y = mx - dragState.offX, my - dragState.offY
            local cw, ch = dragState.w * cp, dragState.h * cp
            draw.RoundedBox(3, x + 2, y + 2, cw - 4, ch - 4, kit.ColorA("primary", 80))
            surface.SetDrawColor(kit.ColorA("primary", 220))
            surface.DrawOutlinedRect(x + 2, y + 2, cw - 4, ch - 4, 1)
        end
    end

    grid.OnMousePressed = function(s, code)
        if code == MOUSE_LEFT then
            s:MouseCapture(true)
        end
        local mx, my = s:CursorPos()
        local gx, gy = math.floor(mx / cp), math.floor(my / cp)
        local index, cell = CellAtMouse(gx, gy)
        if not index then return end

        if code == MOUSE_LEFT then
            -- 双击 = 使用
            if lastClick.index == index and CurTime() - lastClick.time < 0.35 then
                lastClick = { time = 0, index = 0 }
                Fireteam.Inventory.UseItem(cell.id)
                return
            end
            lastClick = { time = CurTime(), index = index }
            dragState = {
                index = index, id = cell.id, w = cell.w or 1, h = cell.h or 1,
                offX = mx - cell.x * cp, offY = my - cell.y * cp,
            }
        elseif code == MOUSE_RIGHT then
            local menu = DermaMenu()
            menu:AddOption(L("ui_inventory_use"), function()
                Fireteam.Inventory.UseItem(cell.id)
            end)
            menu:AddOption(L("ui_inventory_drop"), function()
                net.Start(Fireteam.NET.ITEM_DROP)
                    net.WriteString(cell.id)
                net.SendToServer()
            end)
            for slot = 1, Fireteam.Inventory.HOTBAR_SIZE do
                menu:AddOption(string.format(L("ui_inventory_bind"), slot), function()
                    Fireteam.Inventory.BindHotbar(slot, cell.id)
                end)
            end
            menu:Open()
        end
    end

    grid.OnMouseReleased = function(s, code)
        if code ~= MOUSE_LEFT or not dragState then return end
        local mx, my = s:CursorPos()
        local gx = math.floor((mx - dragState.offX) / cp + 0.5)
        local gy = math.floor((my - dragState.offY) / cp + 0.5)
        local cells = Fireteam.Inventory.ClientCells
        if istable(cells) and cells[dragState.index]
            and Fireteam.Inventory.CanPlaceCells(cells, gx, gy, dragState.w, dragState.h, dragState.index) then
            net.Start(Fireteam.NET.ITEM_MOVE)
                net.WriteString(dragState.id)
                net.WriteUInt(dragState.index, 6)
                net.WriteUInt(math.Clamp(gx, 0, 15), 4)
                net.WriteUInt(math.Clamp(gy, 0, 15), 4)
            net.SendToServer()
        end
        dragState = nil
    end

    -- ─── 底部：快捷栏（右键物品可绑定 1-4 槽，数字 7/8/9/0 触发）───
    local hotbar = vgui.Create("DPanel", invPanel)
    hotbar:SetPos(leftW + 24, invPanel.ftContentTop + 8 + gridH + 12)
    hotbar:SetSize(gridW, cp + 22)
    hotbar.Paint = function(s, w, h)
        draw.SimpleText(L("ui_inventory_hotbar_hint"), kit.Font("small"), 2, 0,
            kit.Color("text_muted"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local keys = { 7, 8, 9, 0 }
        for slot = 1, Fireteam.Inventory.HOTBAR_SIZE do
            local x = (slot - 1) * (cp + 8)
            draw.RoundedBox(3, x, 20, cp, cp, kit.ColorA("background", 230))
            surface.SetDrawColor(kit.ColorA("border", 190))
            surface.DrawOutlinedRect(x, 20, cp, cp, 1)
            draw.SimpleText(tostring(keys[slot]), kit.Font("small"), x + 5, 24,
                kit.ColorA("text_muted", 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            local itemId = Fireteam.Inventory.Hotbar[slot]
            if itemId then
                local cnt = Fireteam.Inventory.ClientCounts[itemId] or 0
                draw.SimpleText(Fireteam.Inventory.GetDisplayName(itemId), kit.Font("small"),
                    x + cp / 2, 20 + cp / 2 + 4,
                    kit.ColorA(cnt > 0 and "text" or "text_muted", 230),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    invPanel.OnRemove = function() dragState = nil end
end

function Fireteam.Inventory.CloseBackpack()
    if IsValid(invPanel) then invPanel:Remove() end
    dragState = nil
end

function Fireteam.Inventory.ToggleBackpack()
    if IsValid(invPanel) then
        Fireteam.Inventory.CloseBackpack()
    elseif Fireteam.UI.CanTogglePanel() then
        Fireteam.Inventory.OpenBackpack()
    end
end

-- Tab 完全让给背包面板（屏蔽默认计分板）
hook.Add("ScoreboardShow", "Fireteam.Inventory.BlockScoreboard", function()
    return false
end)

hook.Add("PlayerButtonDown", "Fireteam.Inventory.TabKey", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button == KEY_TAB then
        Fireteam.Inventory.ToggleBackpack()
    end
end)

-- ═══════════════════════════════════════
-- HUD：快捷栏 4 槽（consumables 锚点上方）+ 消耗品芯片行
-- ═══════════════════════════════════════
hook.Add("HUDPaint", "Fireteam.Inventory.HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local hasItems = next(Fireteam.Inventory.ClientCounts) ~= nil
    local hasHotbar = false
    for i = 1, Fireteam.Inventory.HOTBAR_SIZE do
        if Fireteam.Inventory.Hotbar[i] then hasHotbar = true break end
    end
    if not hasItems and not hasHotbar then return end

    -- ─── 度量（芯片行宽用于 hotbar 居中）───
    local shown = {}
    for itemId, count in pairs(Fireteam.Inventory.ClientCounts) do
        if (tonumber(count) or 0) > 0 and Fireteam.Inventory.ClientDefs[itemId] then
            table.insert(shown, itemId)
        end
    end
    table.sort(shown)

    surface.SetFont(kit.Font("small"))
    local chipH, padX, gap = math.Round(30 * (ScrH() / 1080)), 10, 6
    chipH = math.max(chipH, 24)
    local widths, totalW = {}, 0
    for i, itemId in ipairs(shown) do
        local label = Fireteam.Inventory.GetDisplayName(itemId)
            .. " x" .. Fireteam.Inventory.ClientCounts[itemId]
        local tw = select(1, surface.GetTextSize(label)) or 60
        widths[i] = tw + padX * 2
        totalW = totalW + widths[i]
        if i > 1 then totalW = totalW + gap end
    end

    local elem = kit.GetElement("consumables")
    local x, y = kit.ResolveAnchor(elem.position or "bottom_center",
        math.max(totalW, 200), chipH + 18)
    local fx = kit.EffectsAlpha()

    -- ─── 快捷栏（4 槽，数字 7/8/9/0 触发）───
    local slotSize = math.Round(44 * (ScrH() / 1080))
    local hbW = Fireteam.Inventory.HOTBAR_SIZE * slotSize + (Fireteam.Inventory.HOTBAR_SIZE - 1) * 6
    local hbX, hbY = x + math.max(totalW, 200) / 2 - hbW / 2, y - slotSize - 10
    local keys = { 7, 8, 9, 0 }
    for slot = 1, Fireteam.Inventory.HOTBAR_SIZE do
        local sx = hbX + (slot - 1) * (slotSize + 6)
        kit.DrawPanel(sx, hbY, slotSize, slotSize, { fillAlpha = 165, borderColor = false })
        draw.SimpleText(tostring(keys[slot]), kit.Font("small"), sx + 5, hbY + 3,
            kit.ColorA("text_muted", 170 * fx), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local itemId = Fireteam.Inventory.Hotbar[slot]
        if itemId then
            local cnt = Fireteam.Inventory.ClientCounts[itemId] or 0
            draw.SimpleText(Fireteam.Inventory.GetDisplayName(itemId), kit.Font("small"),
                sx + slotSize / 2, hbY + slotSize / 2 + 2,
                kit.ColorA(cnt > 0 and "text" or "text_muted", 225 * fx),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("x" .. cnt, kit.Font("small"), sx + slotSize - 4, hbY + slotSize - 3,
                kit.ColorA("text_muted", 200 * fx), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        end
    end

    if #shown == 0 then return end

    -- 绑定提示
    draw.SimpleText(Fireteam.Locale.Get("inventory_bind_hint"),
        kit.Font("small"), x + totalW / 2, y - 2,
        kit.ColorA("text_muted", 200 * fx),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

    -- ─── 芯片行 ───
    local busyItem = Fireteam.Inventory.ClientBusyItem
    for i, itemId in ipairs(shown) do
        local w = widths[i]
        kit.DrawPanel(x, y, w, chipH, { fillAlpha = 170 })

        if Fireteam.Inventory.IsBusy() and itemId == busyItem then
            local frac = 1 - math.Clamp(
                ((Fireteam.Inventory.ClientBusyUntil or 0) - CurTime())
                / math.max(tonumber((Fireteam.Inventory.ClientDefs[itemId] or {}).use_time) or 1, 0.25), 0, 1)
            kit.DrawProgressBar(x + 3, y + chipH - 5, w - 6, 3, frac, "warning")
        end

        local label = Fireteam.Inventory.GetDisplayName(itemId)
            .. " x" .. Fireteam.Inventory.ClientCounts[itemId]
        draw.SimpleText(label, kit.Font("small"), x + w / 2, y + chipH / 2,
            kit.ColorA("text", 235 * fx),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        x = x + w + gap
    end
end)

print("[FIRETEAM:Inventory] ✓ 客户端 UI 已加载")
