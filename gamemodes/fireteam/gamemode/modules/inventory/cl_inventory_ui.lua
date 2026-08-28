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

    -- ─── 页签：装备 / 名单 ───
    -- Tab（ScoreboardShow）已被背包接管，原版计分板不再出现，
    -- 因此把玩家名单作为本面板的第二页补回来。
    local tabs = vgui.Create("DPropertySheet", invPanel)
    tabs:SetPos(8, invPanel.ftContentTop)
    tabs:SetSize(W - 16, H - invPanel.ftContentTop - invPanel.ftContentBottom - 8)
    tabs.Paint = nil

    local gearPage = vgui.Create("DPanel", tabs)
    gearPage.Paint = nil
    tabs:AddSheet(L("ui_inventory_tab_gear"), gearPage, "icon16/briefcase.png")

    local rosterPage = vgui.Create("DPanel", tabs)
    rosterPage.Paint = function(s, w, h) Fireteam.Inventory.PaintRoster(s, w, h) end
    tabs:AddSheet(L("ui_inventory_tab_roster"), rosterPage, "icon16/group.png")

    local pageH = gearPage:GetTall()

    -- ─── 左侧：当前武器 + 健康检查 ───
    local left = vgui.Create("DPanel", gearPage)
    left:SetPos(4, 4)
    left:SetSize(leftW, pageH - 8)
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
    local grid = vgui.Create("DPanel", gearPage)
    grid:SetPos(leftW + 16, 4)
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
                net.WriteUInt(dragState.index, 7)
                net.WriteUInt(math.Clamp(gx, 0, 15), 4)
                net.WriteUInt(math.Clamp(gy, 0, 15), 4)
            net.SendToServer()
        end
        dragState = nil
    end

    -- ─── 底部：快捷栏（右键物品绑定 1-4 槽；键位由 core/sh_keybinds.lua 分配）───
    local hotbar = vgui.Create("DPanel", gearPage)
    hotbar:SetPos(leftW + 16, 4 + gridH + 12)
    hotbar:SetSize(gridW, cp + 22)
    hotbar.Paint = function(s, w, h)
        draw.SimpleText(L("ui_inventory_hotbar_hint"), kit.Font("small"), 2, 0,
            kit.Color("text_muted"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        for slot = 1, Fireteam.Inventory.HOTBAR_SIZE do
            local x = (slot - 1) * (cp + 8)
            draw.RoundedBox(3, x, 20, cp, cp, kit.ColorA("background", 230))
            surface.SetDrawColor(kit.ColorA("border", 190))
            surface.DrawOutlinedRect(x, 20, cp, cp, 1)

            -- 槽位提示显示「当前实际绑定键」，玩家重绑后自动跟随
            local bound = input.LookupBinding("ft_item_slot" .. slot)
            draw.SimpleText(bound and string.upper(bound) or tostring(slot),
                kit.Font("small"), x + 5, 24,
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

-- ═══════════════════════════════════════
-- 名单页（替代被背包接管的原版计分板）
-- 数据来源：SQUAD_UPDATE 快照（小队/职业/血量）+ 本地 player.GetAll()（昵称/ping）
--          + ROUNDS_STATE 快照（阵营比分）；无小队玩家一并列出
-- ═══════════════════════════════════════
function Fireteam.Inventory.PaintRoster(panel, w, h)
    local scale = ScrH() / 1080
    local rowH = math.Round(24 * scale)
    local y = 6

    -- 阵营比分行
    local rc = Fireteam.Rounds and Fireteam.Rounds.Client or nil
    if istable(rc) and istable(rc.scores) and next(rc.scores) then
        local parts = {}
        for fid, sc in pairs(rc.scores) do
            parts[#parts + 1] = { id = fid, score = sc }
        end
        table.sort(parts, function(a, b) return a.score > b.score end)

        local x = 8
        for _, p in ipairs(parts) do
            draw.SimpleText(p.id .. " " .. p.score, kit.Font("small"), x, y,
                kit.Color("warning"), TEXT_ALIGN_LEFT)
            x = x + math.Round(120 * scale)
        end
        y = y + rowH
    end

    -- 表头
    local colName  = 8
    local colSquad = math.Round(w * 0.34)
    local colClass = math.Round(w * 0.56)
    local colState = math.Round(w * 0.76)
    local colPing  = w - 12

    kit.DrawDivider(4, y + rowH - 4, w - 8)
    draw.SimpleText(L("admin_col_name"),    kit.Font("small"), colName,  y, kit.Color("text_muted"), TEXT_ALIGN_LEFT)
    draw.SimpleText(L("admin_col_squad"),   kit.Font("small"), colSquad, y, kit.Color("text_muted"), TEXT_ALIGN_LEFT)
    draw.SimpleText(L("admin_col_class"),   kit.Font("small"), colClass, y, kit.Color("text_muted"), TEXT_ALIGN_LEFT)
    draw.SimpleText(L("admin_col_faction"), kit.Font("small"), colState, y, kit.Color("text_muted"), TEXT_ALIGN_LEFT)
    draw.SimpleText(L("admin_col_ping"),    kit.Font("small"), colPing,  y, kit.Color("text_muted"), TEXT_ALIGN_RIGHT)
    y = y + rowH + 4

    -- 建索引：EntIndex → { squadName, faction, class, alive }
    local info = {}
    for _, sq in pairs(Fireteam.Squad and Fireteam.Squad.GetCachedSquads() or {}) do
        for _, m in ipairs(sq.members or {}) do
            info[m.idx] = {
                squad   = sq.name or "-",
                faction = sq.faction or "-",
                class   = m.class or "-",
                alive   = m.alive,
                leader  = m.idx == sq.leaderIdx,
            }
        end
    end

    local vitals = Fireteam.Vitals and Fireteam.Vitals.Client or {}

    for _, p in ipairs(player.GetAll()) do
        if not IsValid(p) then continue end
        if y > h - rowH then break end

        local idx = p:EntIndex()
        local e = info[idx]
        local downed = istable(vitals[idx]) and vitals[idx].state == "downed"

        local nameCol = "text"
        if downed then nameCol = "danger"
        elseif e and e.leader then nameCol = "squad_leader"
        elseif e and not e.alive then nameCol = "text_muted" end

        local prefix = (e and e.leader) and "◆ " or ""
        draw.SimpleText(prefix .. p:Nick(), kit.Font("small"), colName, y,
            kit.Color(nameCol), TEXT_ALIGN_LEFT)
        draw.SimpleText(e and e.squad or "-", kit.Font("small"), colSquad, y,
            kit.Color("text_muted"), TEXT_ALIGN_LEFT)
        draw.SimpleText(e and e.class or "-", kit.Font("small"), colClass, y,
            kit.Color("text_muted"), TEXT_ALIGN_LEFT)

        local stateText = e and e.faction or "-"
        if downed then stateText = L("ui_command_downed") end
        draw.SimpleText(stateText, kit.Font("small"), colState, y,
            kit.Color(downed and "danger" or "text_muted"), TEXT_ALIGN_LEFT)

        draw.SimpleText(tostring(p:Ping()), kit.Font("small"), colPing, y,
            kit.Color("text_muted"), TEXT_ALIGN_RIGHT)
        y = y + rowH
    end
end

function Fireteam.Inventory.CloseBackpack()
    if IsValid(invPanel) then invPanel:Remove() end
    dragState = nil
end

function Fireteam.Inventory.ToggleBackpack()
    if IsValid(invPanel) then
        Fireteam.Inventory.CloseBackpack()
    else
        Fireteam.Inventory.OpenBackpack()
    end
end

-- 面板开关由 core/sh_keybinds.lua 统一分配
-- （引擎 ScoreboardShow=Tab 接管为背包，名单页在面板内；命令 ft_backpack）

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

Fireteam.Log.Info("Inventory", "✓ 客户端 UI 已加载")
