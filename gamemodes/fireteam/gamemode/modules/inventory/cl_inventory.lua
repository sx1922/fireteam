-- modules/inventory/cl_inventory.lua
-- FIRETEAM Consumable/Inventory System - Client Data
-- 接收服务端全量快照（定义 + 持有计数），生成 ft_item_<id> 快捷命令。

if not Fireteam then Fireteam = {} end
Fireteam.Inventory = Fireteam.Inventory or {}

Fireteam.Inventory.ClientDefs = {}    -- { itemId = {name, name_zh, category, use_time, max_carry, size} }
Fireteam.Inventory.ClientCounts = {}  -- { itemId = count }
Fireteam.Inventory.ClientCells = {}   -- { {id,x,y,w,h}... } 网格实例（服务端权威布局）

-- 快捷栏（4 槽；本地绑定，数字 7/8/9/0 触发）
Fireteam.Inventory.HOTBAR_SIZE = 4
Fireteam.Inventory.Hotbar = Fireteam.Inventory.Hotbar or {}

function Fireteam.Inventory.BindHotbar(slot, itemId)
    slot = math.floor(tonumber(slot) or 0)
    if slot < 1 or slot > Fireteam.Inventory.HOTBAR_SIZE then return false end
    Fireteam.Inventory.Hotbar[slot] = (itemId ~= nil and itemId ~= "") and itemId or nil
    return true
end

--- 发起使用请求；本地同步记录忙碌窗口供 HUD 进度显示（服务端权威校验）
function Fireteam.Inventory.UseItem(itemId)
    local def = Fireteam.Inventory.ClientDefs[itemId]
    if not def then return false end

    Fireteam.Net.SendToServer(Fireteam.NET.ITEM_USE, itemId)
    local busyTime = math.max(tonumber(def.use_time) or 0,
        def.category == "throwable" and 1.0 or 0.25)
    Fireteam.Inventory.ClientBusyUntil = CurTime() + busyTime
    Fireteam.Inventory.ClientBusyItem = itemId
    return true
end

function Fireteam.Inventory.IsBusy()
    return Fireteam.Inventory.ClientBusyUntil ~= nil
        and Fireteam.Inventory.ClientBusyUntil > CurTime() or false
end

--- 物品显示名：跟随框架语言选择（zh-CN 用包内 name_zh）
function Fireteam.Inventory.GetDisplayName(itemId)
    local def = Fireteam.Inventory.ClientDefs[itemId]
    if not def then return itemId end
    if Fireteam.Locale.GetLanguage() == "zh-CN" then
        return def.name_zh or def.name or itemId
    end
    return def.name or itemId
end

-- ─────────────────────────────────────
-- 快捷命令生成
-- ─────────────────────────────────────

local generatedCommands = {}

local function EnsureCommands()
    for itemId in pairs(Fireteam.Inventory.ClientDefs) do
        if not generatedCommands[itemId] then
            generatedCommands[itemId] = true
            concommand.Add("ft_item_" .. itemId, function()
                Fireteam.Inventory.UseItem(itemId)
            end)
        end
    end
end

concommand.Add("ft_item", function(_, _, args)
    if args[1] then Fireteam.Inventory.UseItem(args[1]) end
end)

-- ─────────────────────────────────────
-- 快照接收
-- ─────────────────────────────────────
net.Receive(Fireteam.NET.INVENTORY_SYNC, function()
    Fireteam.Inventory.ClientDefs = net.ReadTable()
    Fireteam.Inventory.ClientCounts = net.ReadTable()
    Fireteam.Inventory.ClientCells = net.ReadTable()
    EnsureCommands()
    hook.Run("Fireteam.Inventory.ClientUpdated")
end)

-- ─────────────────────────────────────
-- 快捷栏热键（7/8/9/0 → 触发绑定物品；输入框聚焦时不触发）
-- ─────────────────────────────────────
local HOTBAR_KEYS = { KEY_7, KEY_8, KEY_9, KEY_0 }

hook.Add("PlayerButtonDown", "Fireteam.Inventory.HotbarKeys", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if not Fireteam.UI.CanTogglePanel() then return end
    for slot, key in ipairs(HOTBAR_KEYS) do
        if button == key then
            local itemId = Fireteam.Inventory.Hotbar[slot]
            if itemId then Fireteam.Inventory.UseItem(itemId) end
            return
        end
    end
end)

print("[FIRETEAM:Inventory] ✓ Client data loaded")
