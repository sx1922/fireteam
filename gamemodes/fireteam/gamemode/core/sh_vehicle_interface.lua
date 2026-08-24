-- core/sh_vehicle_interface.lua
-- FIRETEAM Vehicle Abstraction Layer

if not Fireteam then Fireteam = {} end
Fireteam.VehicleInterface = Fireteam.VehicleInterface or {}

local vehicleCache = {}  -- { className = FTVehicleData }

-- ─────────────────────────────────────
-- 数据结构
-- ─────────────────────────────────────
--- @class FTVehicleData
--- @field base string           原始实体类名
--- @field displayName string    显示名
--- @field role string           Fireteam.VEHICLE_ROLE
--- @field tags string[]         标签
--- @field seats table           [{role, weapon, exitPos}]
--- @field capacity number       运载人数
--- @field armorLevel number     0-3
--- @field speedTier string      "slow"|"medium"|"fast"
--- @field radioChannels table   支持的频道
--- @field weapons table         载具武器 [{type, ammo}]

-- ─────────────────────────────────────
-- 注册
-- ─────────────────────────────────────
function Fireteam.VehicleInterface.Register(data)
    if not data or not data.base then return false end

    data.displayName   = data.displayName or data.base
    data.role          = data.role or Fireteam.VEHICLE_ROLE.TRANSPORT
    data.tags          = data.tags or {}
    data.seats         = data.seats or {}
    data.capacity      = data.capacity or 0
    data.armorLevel    = data.armorLevel or 0
    data.speedTier     = data.speedTier or "medium"
    data.radioChannels = data.radioChannels or { "squad" }
    data.weapons       = data.weapons or {}

    vehicleCache[data.base] = data
    return true
end

-- ─────────────────────────────────────
-- 查询
-- ─────────────────────────────────────
function Fireteam.VehicleInterface.Get(className)
    return vehicleCache[className]
end

function Fireteam.VehicleInterface.GetAll()
    local result = {}
    for _, data in pairs(vehicleCache) do
        table.insert(result, data)
    end
    return result
end

function Fireteam.VehicleInterface.FilterByTags(requiredTags, bannedTags)
    local result = {}
    for _, data in pairs(vehicleCache) do
        local hasAll = true
        for _, tag in ipairs(requiredTags or {}) do
            if not table.HasValue(data.tags, tag) then
                hasAll = false; break
            end
        end
        if hasAll then
            local isBanned = false
            for _, tag in ipairs(bannedTags or {}) do
                if table.HasValue(data.tags, tag) then
                    isBanned = true; break
                end
            end
            if not isBanned then
                table.insert(result, data)
            end
        end
    end
    return result
end

function Fireteam.VehicleInterface.FilterByRole(role)
    local result = {}
    for _, data in pairs(vehicleCache) do
        if data.role == role then
            table.insert(result, data)
        end
    end
    return result
end

-- ─────────────────────────────────────
-- 发现
-- ─────────────────────────────────────
function Fireteam.VehicleInterface.RunDiscovery()
    vehicleCache = {}
    hook.Run(Fireteam.HOOKS.VEHICLE_DISCOVER, vehicleCache)
    Fireteam.Log.Info("载具接口", "✓ 载具发现完成: 共注册 " .. table.Count(vehicleCache) .. " 辆载具")
end

if SERVER then
    hook.Add("Fireteam.Setting.Loaded", "VehicleInterface.Rediscover", function()
        Fireteam.VehicleInterface.RunDiscovery()
    end)
end

Fireteam.Log.Info("载具接口", "✓ 载具接口就绪")
