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

print("[FIRETEAM:Inventory] ✓ Shared definitions loaded")
