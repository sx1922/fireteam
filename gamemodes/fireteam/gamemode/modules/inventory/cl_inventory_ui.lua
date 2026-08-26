-- modules/inventory/cl_inventory_ui.lua
-- FIRETEAM Consumables HUD Bar
-- 主题驱动的消耗品栏：底部居中一排「名称 ×数量」芯片，
-- 使用中显示读条进度。布局消费 hud_theme.json elements.consumables。

if not Fireteam then Fireteam = {} end
Fireteam.Inventory = Fireteam.Inventory or {}

local kit = Fireteam.UI

hook.Add("HUDPaint", "Fireteam.Inventory.HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if not next(Fireteam.Inventory.ClientCounts) then return end

    -- 收集有存货的物品（按 id 稳定排序）
    local shown = {}
    for itemId, count in pairs(Fireteam.Inventory.ClientCounts) do
        if (tonumber(count) or 0) > 0 and Fireteam.Inventory.ClientDefs[itemId] then
            table.insert(shown, itemId)
        end
    end
    if #shown == 0 then return end
    table.sort(shown)

    -- ─── 度量：按文本实测宽度排布芯片 ───
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
        totalW, chipH + 18)

    -- 绑定提示（小字，仅一行）
    draw.SimpleText(Fireteam.Locale.Get("inventory_bind_hint"),
        kit.Font("small"), x + totalW / 2, y - 2,
        kit.ColorA("text_muted", 200 * kit.EffectsAlpha()),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

    -- ─── 芯片绘制 ───
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
            kit.ColorA("text", 235 * kit.EffectsAlpha()),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        x = x + w + gap
    end
end)

print("[FIRETEAM:Inventory] ✓ Client HUD loaded")
