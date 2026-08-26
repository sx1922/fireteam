-- modules/inventory/sv_inventory.lua
-- FIRETEAM Consumable/Inventory System - Server Logic

if not Fireteam then Fireteam = {} end
Fireteam.Inventory = Fireteam.Inventory or {}

local THROW_COOLDOWN = 1.0   -- 投掷物最短间隔（秒）

local SendSnapshot   -- 前向声明：Reset/Set/Add 在定义之前就会调用

-- ─────────────────────────────────────
-- 玩家物品状态
-- 状态本体挂在玩家实体上（ply.FT_Items），
-- 与回合/重生生命周期对齐：每次 ApplyLoadout 前重置。
-- ─────────────────────────────────────

function Fireteam.Inventory.Reset(ply)
    ply.FT_Items = {}
    ply.FT_ItemCells = {}
    SendSnapshot(ply)
end

-- ─────────────────────────────────────
-- 网格布局层（cells 与计数表保持同数量；
-- 发放空间不足时 Add 截断——背包满了捡不下）
-- ─────────────────────────────────────

local function EnsureCells(ply)
    if not istable(ply.FT_ItemCells) then ply.FT_ItemCells = {} end
    return ply.FT_ItemCells
end

--- 按 itemId 对齐 cells 实例数（正差补空位、负差从尾删）
local function SyncCellsFor(ply, itemId, targetCount)
    local def = Fireteam.Inventory.GetItemDef(itemId)
    if not def then return end
    local w, h = Fireteam.Inventory.GetItemSize(def)
    local cells = EnsureCells(ply)

    -- 从尾删除多余实例
    while true do
        local count = 0
        for _, c in ipairs(cells) do
            if c.id == itemId then count = count + 1 end
        end
        if count <= targetCount then break end
        for i = #cells, 1, -1 do
            if cells[i].id == itemId then
                table.remove(cells, i)
                break
            end
        end
    end

    -- 补缺实例（无空位则止——调用方应已保证空间）
    while true do
        local count = 0
        for _, c in ipairs(cells) do
            if c.id == itemId then count = count + 1 end
        end
        if count >= targetCount then break end
        local x, y = Fireteam.Inventory.FindFreeSpot(cells, w, h)
        if not x then break end
        cells[#cells + 1] = { id = itemId, x = x, y = y, w = w, h = h }
    end
end

function Fireteam.Inventory.Get(ply, itemId)
    return (istable(ply.FT_Items) and ply.FT_Items[itemId]) or 0
end

--- 全量快照副本
function Fireteam.Inventory.GetAll(ply)
    local out = {}
    if istable(ply.FT_Items) then
        for id, count in pairs(ply.FT_Items) do out[id] = count end
    end
    return out
end

--- 设置数量（截断到 max_carry），返回实际写入值
function Fireteam.Inventory.Set(ply, itemId, count)
    local def = Fireteam.Inventory.GetItemDef(itemId)
    if not def then return 0 end
    local value = math.Clamp(math.floor(tonumber(count) or 0), 0, def.max_carry)
    ply.FT_Items = ply.FT_Items or {}
    ply.FT_Items[itemId] = value
    SyncCellsFor(ply, itemId, value)
    SendSnapshot(ply)
    return value
end

--- 增减数量，返回实际增量（受 0..max_carry 与网格剩余空间双重截断）
function Fireteam.Inventory.Add(ply, itemId, delta)
    local def = Fireteam.Inventory.GetItemDef(itemId)
    if not def then return 0 end
    local current = Fireteam.Inventory.Get(ply, itemId)
    local newValue, applied = Fireteam.Inventory.ApplyDelta(current, delta, def.max_carry)

    -- 发放方向：模拟找空位，空间不足截断（背包满捡不下）
    if applied > 0 then
        local w, h = Fireteam.Inventory.GetItemSize(def)
        local sim = {}
        for i, c in ipairs(EnsureCells(ply)) do sim[i] = c end
        local canAdd = 0
        while canAdd < applied do
            local x, y = Fireteam.Inventory.FindFreeSpot(sim, w, h)
            if not x then break end
            sim[#sim + 1] = { id = itemId, x = x, y = y, w = w, h = h }
            canAdd = canAdd + 1
        end
        applied = math.min(applied, canAdd)
        newValue = current + applied
    end

    if applied ~= 0 then
        ply.FT_Items = ply.FT_Items or {}
        ply.FT_Items[itemId] = newValue
        SyncCellsFor(ply, itemId, newValue)
        SendSnapshot(ply)
    end
    return applied
end

--- 消耗一件；不足返回 false
function Fireteam.Inventory.Consume(ply, itemId)
    if Fireteam.Inventory.Get(ply, itemId) <= 0 then return false end
    Fireteam.Inventory.Add(ply, itemId, -1)
    return true
end

-- ─────────────────────────────────────
-- 职业槽位发放（sv_class.ApplyLoadout 调用）
-- ─────────────────────────────────────

--- 按槽位名 + 阵营发放物品。返回是否发放了任何东西。
function Fireteam.Inventory.GrantForSlot(ply, slotName, factionId)
    local itemDefs = Fireteam.Setting.GetData and Fireteam.Setting.GetData("items") or nil
    itemDefs = istable(itemDefs) and itemDefs.items or itemDefs
    if not istable(itemDefs) then return false end

    local matches = Fireteam.Inventory.ResolveSlotItems(itemDefs, slotName, factionId)
    local granted = false
    for _, itemId in ipairs(matches) do
        local def = itemDefs[itemId]
        -- 同步进注册表（保证热切换后注册表与包数据一致）
        Fireteam.Inventory.RegisterItem(itemId, def)
        local amount = math.min(tonumber(def.amount_per_slot) or def.max_carry, def.max_carry)
        if amount > 0 then
            Fireteam.Inventory.Add(ply, itemId, amount)
            granted = true
        end
    end
    return granted
end

-- ─────────────────────────────────────
-- 设定包接入：items.lua 导入注册表并下发客户端
-- ─────────────────────────────────────

local function ImportPackItems()
    Fireteam.Inventory.ClearItems()
    local data = Fireteam.Setting.GetData and Fireteam.Setting.GetData("items") or nil
    local itemDefs = istable(data) and (istable(data.items) and data.items or data) or nil
    if not istable(itemDefs) then return end

    for itemId, def in pairs(itemDefs) do
        Fireteam.Inventory.RegisterItem(itemId, def)
    end
    Fireteam.Log.Info("背包", "✓ 物品导入完成: " .. table.Count(itemDefs) .. " 种")
end

SendSnapshot = function(ply)
    -- 手写字段序列化（背包快照随每次拾取/消耗触发，不走泛型 WriteTable 反射）
    local defs = Fireteam.Inventory.GetAllItemDefs()
    local defList = {}
    for id in pairs(defs) do defList[#defList + 1] = id end
    table.sort(defList)

    local countList = {}
    if istable(ply.FT_Items) then
        for id, count in pairs(ply.FT_Items) do
            countList[#countList + 1] = { id, count }
        end
    end

    local cells = EnsureCells(ply)

    net.Start(Fireteam.NET.INVENTORY_SYNC)
    net.WriteUInt(#defList, 8)
    for _, id in ipairs(defList) do
        local d = defs[id]
        net.WriteString(id)
        net.WriteString(d.name or id)
        net.WriteString(d.name_zh or d.name or id)
        net.WriteString(d.category or "consumable")
        net.WriteUInt(math.Clamp(math.Round((d.use_time or 0) * 10), 0, 1023), 10)
        net.WriteUInt(math.Clamp(d.max_carry or 1, 0, 255), 8)
        local hasSize = istable(d.size)
        net.WriteBool(hasSize)
        if hasSize then
            local sw, sh = Fireteam.Inventory.GetItemSize(d)
            net.WriteUInt(sw, 4)
            net.WriteUInt(sh, 4)
        end
    end
    net.WriteUInt(#countList, 8)
    for _, item in ipairs(countList) do
        net.WriteString(item[1])
        net.WriteUInt(math.Clamp(item[2], 0, 255), 8)
    end
    net.WriteUInt(#cells, 7)
    for _, c in ipairs(cells) do
        net.WriteString(c.id)
        net.WriteUInt(c.x or 0, 4)
        net.WriteUInt(c.y or 0, 4)
        net.WriteUInt(c.w or 1, 4)
        net.WriteUInt(c.h or 1, 4)
    end
    net.Send(ply)
end

hook.Add(Fireteam.HOOKS.SETTING_LOADED, "Fireteam.Inventory.PackImport", function()
    ImportPackItems()
    -- 包切换后向所有玩家重发定义与空计数
    for _, ply in ipairs(player.GetAll()) do
        Fireteam.Inventory.Reset(ply)
    end
end)

hook.Add("PlayerInitialSpawn", "Fireteam.Inventory.Init", function(ply)
    ply.FT_Items = {}
    timer.Simple(2, function()
        if IsValid(ply) then SendSnapshot(ply) end
    end)
end)

-- ─────────────────────────────────────
-- 使用流程
-- ─────────────────────────────────────

local function IsBusy(ply)
    return ply.FT_ItemBusyUntil and ply.FT_ItemBusyUntil > CurTime() or false
end

local function ThrowProjectile(ply, def)
    local throw = def.throw or {}
    local ent = ents.Create("ft_grenade_proj")
    if not IsValid(ent) then return false end

    local src = ply:GetShootPos() + ply:GetAimVector() * 16
    ent:SetPos(src)
    ent:SetAngles(ply:GetAngles())
    ent:SetModel(throw.model or "models/weapons/w_grenade.mdl")
    ent:SetFuse(tonumber(throw.fuse) or 3.0)
    ent:SetBlastRadius(tonumber(throw.radius) or 350)
    ent:SetBlastDamage(tonumber(throw.damage) or 90)
    ent.Owner_ = ply
    ent:Spawn()

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        local vel = ply:GetAimVector() * (tonumber(throw.throw_speed) or 900)
        vel = vel + Vector(0, 0, 120)   -- 上抛补偿，手感接近徒手投掷
        phys:ApplyForceCenter(vel * phys:GetMass())
    end
    return true
end

--- 使用入口（net 与控制台命令共用）
function Fireteam.Inventory.TryUse(ply, itemId)
    if not IsValid(ply) or not ply:Alive() then return false end
    -- 倒地状态禁止使用物品（体征系统接管时）
    if Fireteam.Vitals and Fireteam.Vitals.IsDowned and Fireteam.Vitals.IsDowned(ply) then
        return false
    end
    if IsBusy(ply) then return false end

    local def = Fireteam.Inventory.GetItemDef(itemId)
    if not def then
        ply:ChatPrint("[FIRETEAM] " .. Fireteam.Locale.Get("item_not_found"))
        return false
    end
    if Fireteam.Inventory.Get(ply, itemId) <= 0 then
        ply:ChatPrint("[FIRETEAM] " .. Fireteam.Locale.Get("item_none_left"))
        return false
    end

    local ok = false
    local busyTime = def.use_time

    if def.category == Fireteam.INVENTORY_CATEGORY.THROWABLE then
        ok = ThrowProjectile(ply, def)
        busyTime = math.max(busyTime, THROW_COOLDOWN)
    else
        local handler = Fireteam.Inventory.GetUseHandler(def.category)
        if handler then
            ok = handler(ply, itemId, def) and true or false
        else
            ply:ChatPrint("[FIRETEAM] " .. Fireteam.Locale.Get("item_no_effect"))
            return false
        end
    end

    if not ok then return false end

    Fireteam.Inventory.Consume(ply, itemId)
    ply.FT_ItemBusyUntil = CurTime() + busyTime
    hook.Run(Fireteam.HOOKS.ITEM_USED, ply, itemId)
    return true
end

-- 其他模块按大类插拔使用效果：
--   Fireteam.Inventory.RegisterUseHandler(Fireteam.INVENTORY_CATEGORY.CONSUMABLE, fn)
-- P5b 医疗 / P5d 补给各自接管绷带、医疗包、弹药盒。

net.Receive(Fireteam.NET.ITEM_USE, function(_, ply)
    -- C→S 输入校验：截断超长物品 id
    Fireteam.Inventory.TryUse(ply, string.sub(net.ReadString(), 1, 64))
end)

-- 网格拖拽落位（服务端权威碰撞校验）
net.Receive(Fireteam.NET.ITEM_MOVE, function(_, ply)
    local itemId = net.ReadString()
    local cellIndex = net.ReadUInt(6)
    local x = net.ReadUInt(4)
    local y = net.ReadUInt(4)
    local cells = ply.FT_ItemCells
    local cell = istable(cells) and cells[cellIndex] or nil
    if not istable(cell) or cell.id ~= itemId then return end
    if Fireteam.Inventory.CanPlaceCells(cells, x, y, cell.w or 1, cell.h or 1, cellIndex) then
        cell.x, cell.y = x, y
        SendSnapshot(ply)
    end
end)

-- 丢弃一件（一期直接销毁；落地拾取实体列后续）
net.Receive(Fireteam.NET.ITEM_DROP, function(_, ply)
    local itemId = string.sub(net.ReadString(), 1, 64)
    if not IsValid(ply) or not ply:Alive() then return end
    local def = Fireteam.Inventory.GetItemDef(itemId)
    if Fireteam.Inventory.Consume(ply, itemId) then
        local name = def and def.name or itemId
        ply:ChatPrint("[FIRETEAM] " .. string.format(Fireteam.Locale.Get("inventory_dropped"), name))
    end
end)

print("[FIRETEAM:Inventory] ✓ 服务端逻辑已加载")
