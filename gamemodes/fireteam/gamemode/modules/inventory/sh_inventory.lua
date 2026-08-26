-- modules/inventory/sh_inventory.lua
-- FIRETEAM Consumable/Inventory System - Shared
-- 物品定义来自设定包 items.lua；框架只管机制（注册/计数/使用通道/投掷物），
-- 使用效果由各模块经 RegisterUseHandler 插拔。

if not Fireteam then Fireteam = {} end
Fireteam.Inventory = Fireteam.Inventory or {}

-- 物品大类（决定使用行为由谁处理）
Fireteam.INVENTORY_CATEGORY = {
    CONSUMABLE = "consumable",   -- 读完条生效：绷带/医疗包等（效果由其他模块注册）
    THROWABLE  = "throwable",    -- 投掷物：手雷（本模块内置抛掷）
    DEPLOYABLE = "deployable"    -- 可放置物：弹药盒等（效果由其他模块注册）
}

local itemRegistry = {}   -- { itemId = itemDef }
local useHandlers = {}    -- { category = handlerFn(ply, itemId, itemDef) -> boolean }

--- 注册物品定义（设定包激活时由本模块批量导入）
function Fireteam.Inventory.RegisterItem(itemId, def)
    if not isstring(itemId) or not istable(def) then return false end

    def.max_carry = math.max(tonumber(def.max_carry) or 1, 1)
    def.use_time  = math.max(tonumber(def.use_time) or 0, 0)
    def.category  = def.category or Fireteam.INVENTORY_CATEGORY.CONSUMABLE
    def.slots     = istable(def.slots) and def.slots or {}
    if not istable(def.size) then def.size = nil end   -- 网格占格（缺省 1×1）

    itemRegistry[itemId] = def
    return true
end

function Fireteam.Inventory.GetItemDef(itemId)
    return itemRegistry[itemId]
end

function Fireteam.Inventory.GetAllItemDefs()
    local out = {}
    for id, def in pairs(itemRegistry) do out[id] = def end
    return out
end

--- 清空物品表（设定包卸载/重载时调用）
function Fireteam.Inventory.ClearItems()
    itemRegistry = {}
end

--- 注册某大类的使用处理器；返回 false 表示拒绝消耗（例如无目标可治）
function Fireteam.Inventory.RegisterUseHandler(category, fn)
    useHandlers[category] = fn
end

--- 查询大类处理器（供 sv 使用流程调用；local 表跨文件不可见，须经此入口）
function Fireteam.Inventory.GetUseHandler(category)
    return useHandlers[category]
end

-- ═══════════════════════════════════════
-- 纯函数（harness 可测）
-- ═══════════════════════════════════════

--- 解析某装备槽位可用的物品列表。
--- 匹配规则：itemDef.slots 含 slotName，且 itemDef.factions（若声明）含 factionId。
--- @return string[] 按注册顺序排列的 itemId 列表
function Fireteam.Inventory.ResolveSlotItems(itemDefs, slotName, factionId)
    local out = {}
    for itemId, def in pairs(itemDefs or {}) do
        if table.HasValue(def.slots or {}, slotName) then
            if not def.factions or factionId == nil or table.HasValue(def.factions, factionId) then
                table.insert(out, itemId)
            end
        end
    end
    table.sort(out)
    return out
end

--- 计算职业 loadout 应发放的物品计划 { itemId = count }。
--- 同一物品被多个槽位声明时取最大值；超过 max_carry 截断。
function Fireteam.Inventory.BuildLoadoutPlan(itemDefs, classData)
    local plan = {}
    local loadout = istable(classData) and classData.loadout or nil
    if not loadout then return plan end

    for slotName in pairs(loadout) do
        for _, itemId in ipairs(Fireteam.Inventory.ResolveSlotItems(itemDefs, slotName, classData.faction)) do
            local def = itemDefs[itemId]
            local grant = math.min(math.max(tonumber(def.amount_per_slot) or def.max_carry, 0), def.max_carry)
            plan[itemId] = math.max(plan[itemId] or 0, grant)
        end
    end
    return plan
end

--- 应用数量增减并按 max_carry 截断。返回 (新值, 实际增量)。
function Fireteam.Inventory.ApplyDelta(current, delta, maxCarry)
    current = tonumber(current) or 0
    delta = tonumber(delta) or 0
    local target = math.Clamp(current + delta, 0, maxCarry or math.huge)
    return target, target - current
end

-- ═══════════════════════════════════════
-- 塔科夫式网格背包（10×6；计数表为真源，cells 为其空间投影）
-- ═══════════════════════════════════════
Fireteam.Inventory.GRID_W = 10
Fireteam.Inventory.GRID_H = 6

--- 物品占格尺寸（def.size = {w,h}，缺省 1×1，截断到网格内）
function Fireteam.Inventory.GetItemSize(def)
    local s = istable(def) and istable(def.size) and def.size or nil
    local w = math.Clamp(math.floor(tonumber(s and s.w) or 1), 1, Fireteam.Inventory.GRID_W)
    local h = math.Clamp(math.floor(tonumber(s and s.h) or 1), 1, Fireteam.Inventory.GRID_H)
    return w, h
end

--- (x,y,w,h) 是否可放入 cells（边界 + 与其他实例不重叠；ignoreIndex 用于拖动自身）
function Fireteam.Inventory.CanPlaceCells(cells, x, y, w, h, ignoreIndex)
    if x < 0 or y < 0
        or x + w > Fireteam.Inventory.GRID_W or y + h > Fireteam.Inventory.GRID_H then
        return false
    end
    for i, cell in ipairs(cells or {}) do
        if i ~= ignoreIndex then
            local cw, ch = cell.w or 1, cell.h or 1
            if x < cell.x + cw and cell.x < x + w and y < cell.y + ch and cell.y < y + h then
                return false
            end
        end
    end
    return true
end

--- 扫描第一个能放下 (w,h) 的空位；返回 x,y 或 nil
function Fireteam.Inventory.FindFreeSpot(cells, w, h)
    for y = 0, Fireteam.Inventory.GRID_H - h do
        for x = 0, Fireteam.Inventory.GRID_W - w do
            if Fireteam.Inventory.CanPlaceCells(cells, x, y, w, h) then
                return x, y
            end
        end
    end
    return nil
end

print("[FIRETEAM:Inventory] ✓ 共享定义已加载")
