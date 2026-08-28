-- core/sh_weapon_interface.lua
-- FIRETEAM Weapon Abstraction Layer

if not Fireteam then Fireteam = {} end
Fireteam.WeaponInterface = Fireteam.WeaponInterface or {}

local weaponCache = {}  -- { className = FTWeaponData }

-- ─────────────────────────────────────
-- 数据结构定义（文档用）
-- ─────────────────────────────────────
--- @class FTWeaponData
--- @field base string           原始实体类名
--- @field displayName string    显示名
--- @field tags string[]         标签列表
--- @field category string       分类 (Fireteam.WEAPON_CATEGORY)
--- @field suppression number    压制值 0-1
--- @field effectiveRange number 有效射程 (units)
--- @field fireModes table       {"semi","auto","burst"}
--- @field opticType string      "iron"|"scope"|"red_dot"|"night_vision"
--- @field weight number         重量 kg
--- @field noiseLevel number     噪音 0-1
--- @field magazineSize number   弹匣容量
--- @field damage number         基础伤害

-- ─────────────────────────────────────
-- 注册武器（由适配器调用）
-- ─────────────────────────────────────
function Fireteam.WeaponInterface.Register(data)
    if not data or not data.base then
        Fireteam.Log.Error("武器接口", "Register 收到无效数据（缺少 base 字段）")
        return false
    end
    -- 补全默认值
    data.displayName   = data.displayName or data.base
    data.tags          = data.tags or {}
    data.category      = data.category or Fireteam.WEAPON_CATEGORY.RIFLE
    data.suppression   = data.suppression or 0.5
    data.effectiveRange = data.effectiveRange or 300
    data.fireModes     = data.fireModes or { "semi" }
    data.opticType     = data.opticType or "iron"
    data.weight        = data.weight or 3.5
    data.noiseLevel    = data.noiseLevel or 0.7
    data.magazineSize  = data.magazineSize or 30
    data.damage        = data.damage or 25

    weaponCache[data.base] = data
    return true
end

-- ─────────────────────────────────────
-- 查询
-- ─────────────────────────────────────
function Fireteam.WeaponInterface.Get(className)
    return weaponCache[className]
end

function Fireteam.WeaponInterface.GetAll()
    local result = {}
    for _, data in pairs(weaponCache) do
        table.insert(result, data)
    end
    return result
end

-- 按 Tag 过滤
function Fireteam.WeaponInterface.FilterByTags(requiredTags, bannedTags)
    local result = {}
    local settingData = Fireteam.Setting and Fireteam.Setting.GetData and Fireteam.Setting.GetData("weapons") or nil
    local globalFilter = istable(settingData) and settingData.global_filter or nil
    local allowedEra = istable(globalFilter) and globalFilter.allowed_era or nil
    local globalBanned = istable(globalFilter) and globalFilter.banned_tags or nil
    local aliases = {
        carbine = { "carbine", "assault_rifle", "rifle" },
        rifle = { "rifle", "assault_rifle" },
    }
    local function hasTag(tags, wanted)
        if table.HasValue(tags, wanted) then return true end
        for _, alias in ipairs(aliases[wanted] or {}) do
            if table.HasValue(tags, alias) then return true end
        end
        return false
    end
    local function hasAnyTag(tags, wantedTags)
        for _, wanted in ipairs(wantedTags or {}) do
            if table.HasValue(tags, wanted) then return true end
        end
        return false
    end
    for _, data in pairs(weaponCache) do
        local hasAll = true
        for _, tag in ipairs(requiredTags or {}) do
            if not hasTag(data.tags, tag) then
                hasAll = false
                break
            end
        end
        if hasAll then
            local isBanned = false
            local allBanned = {}
            for _, tag in ipairs(globalBanned or {}) do table.insert(allBanned, tag) end
            for _, tag in ipairs(bannedTags or {}) do table.insert(allBanned, tag) end
            for _, tag in ipairs(allBanned) do
                if table.HasValue(data.tags, tag) then
                    isBanned = true
                    break
                end
            end
            local eraAllowed = not allowedEra or hasAnyTag(data.tags, allowedEra)
            if not isBanned and eraAllowed then
                table.insert(result, data)
            end
        end
    end
    return result
end

-- 按分类过滤
function Fireteam.WeaponInterface.FilterByCategory(category)
    local result = {}
    for _, data in pairs(weaponCache) do
        if data.category == category then
            table.insert(result, data)
        end
    end
    return result
end

-- ─────────────────────────────────────
-- 触发发现钩子（所有适配器响应）
-- ─────────────────────────────────────
function Fireteam.WeaponInterface.RunDiscovery()
    weaponCache = {}
    hook.Run(Fireteam.HOOKS.WEAPON_DISCOVER, weaponCache)
    Fireteam.Log.Info("武器接口", "✓ 武器发现完成: 共注册 " .. table.Count(weaponCache) .. " 把武器")
end

-- 服务端启动时执行
if SERVER then
    hook.Add(Fireteam.HOOKS.SETTING_LOADED, "WeaponInterface.Rediscover", function()
        Fireteam.WeaponInterface.RunDiscovery()
    end)
end

Fireteam.Log.Info("武器接口", "✓ 武器接口就绪")
