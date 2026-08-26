-- modules/adapters/sv_lvs_adapter.lua
-- FIRETEAM LVS Vehicle Base Adapter

if not LVS then
    print("[FIRETEAM:Adapter] 未检测到 LVS，跳过适配器")
    return
end

print("[FIRETEAM:Adapter] 检测到 LVS，注册适配器……")

-- ═══════════════════════════════════════
-- 角色推断
-- ═══════════════════════════════════════
local function InferRole(vData, className)
    local name = (vData.PrintName or ""):lower()
    local category = (vData.Category or ""):lower()
    local classId = (className or ""):lower()
    local combined = name .. " " .. category .. " " .. classId

    if combined:find("tank") or combined:find("armor") then
        return Fireteam.VEHICLE_ROLE.TANK
    elseif combined:find("apc") or combined:find("carrier") or combined:find("ifv") then
        return Fireteam.VEHICLE_ROLE.APC
    elseif combined:find("recon") or combined:find("scout") or combined:find("jeep") then
        return Fireteam.VEHICLE_ROLE.RECON
    elseif combined:find("helicopter") or combined:find("heli") or combined:find("air") then
        return Fireteam.VEHICLE_ROLE.AIR
    elseif combined:find("truck") or combined:find("transport") or combined:find("bus") then
        return Fireteam.VEHICLE_ROLE.TRANSPORT
    else
        return Fireteam.VEHICLE_ROLE.UTILITY
    end
end

-- ═══════════════════════════════════════
-- Tag 生成
-- ═══════════════════════════════════════
local function GenerateTags(vData, className)
    local tags = { "lvs" }
    local name = (vData.PrintName or ""):lower()
    local category = (vData.Category or ""):lower()
    local classId = (className or ""):lower()
    local combined = name .. " " .. category .. " " .. classId

    -- 阵营
    if combined:find("m113") or combined:find("m1") or combined:find("humvee")
        or combined:find("abrams") or combined:find("bradley") or combined:find("sheridan")
        -- LVS 北约军机/直升机
        or combined:find("chinook") or combined:find("uh_60") or combined:find("uh60")
        or combined:find("blackhawk") or combined:find("apache") or combined:find("cobra") then
        table.insert(tags, "nato")
        table.insert(tags, "coldwar_west")
    end

    if combined:find("btr") or combined:find("bmp") or combined:find("t-54")
        or combined:find("t-55") or combined:find("t-62") or combined:find("t-72")
        or combined:find("brdm") or combined:find("uaz") or combined:find("gaz")
        -- LVS 华约军机/直升机
        or combined:find("mi_24") or combined:find("mi24") or combined:find("mi_8")
        or combined:find("mi8") or combined:find("hind") or combined:find("hip") then
        table.insert(tags, "warsaw_pact")
        table.insert(tags, "coldwar_east")
    end

    -- 冷战时代
    table.insert(tags, "coldwar")

    -- 类型
    local role = InferRole(vData, className)
    table.insert(tags, role)

    -- 轮式/履带
    if combined:find("wheel") or combined:find("truck") or combined:find("jeep")
        or combined:find("btr") or combined:find("brdm") then
        table.insert(tags, "wheeled")
    else
        table.insert(tags, "tracked")
    end

    return tags
end

-- ═══════════════════════════════════════
-- 速度分级
-- ═══════════════════════════════════════
local function CategorizeSpeed(vData)
    local maxSpeed = tonumber(vData.MaxSpeed) or 50
    if maxSpeed < 40 then return "slow"
    elseif maxSpeed < 80 then return "medium"
    else return "fast"
    end
end

-- ═══════════════════════════════════════
-- 设定包覆盖配置加载
-- ═══════════════════════════════════════
local function LoadVehicleOverrides()
    if Fireteam.Setting and Fireteam.Setting.GetData then
        return Fireteam.Setting.GetData("vehicle_overrides") or {}
    end
    return {}
end

local function ApplyOverrides(ftData, className, overrides)
    local ov = overrides[className]
    if not istable(ov) then return end
    if istable(ov.tags) then ftData.tags = ov.tags end
    if ov.role and Fireteam.VEHICLE_ROLE[ov.role] then
        ftData.role = Fireteam.VEHICLE_ROLE[ov.role]
    end
end

-- ═══════════════════════════════════════
-- 注册
-- （scripted_ents.GetList() 返回数组，元素为 { ClassName, t } 包装表，
--   实际实体表数据在 entry.t 中）
-- ═══════════════════════════════════════
hook.Add(Fireteam.HOOKS.VEHICLE_DISCOVER, "FIRETEAM.LVSAdapter", function(vehicleList)
    local count = 0
    local overrides = LoadVehicleOverrides()

    for _, entry in pairs(scripted_ents.GetList()) do
        if istable(entry) and isstring(entry.ClassName) and istable(entry.t) then
            local className = entry.ClassName
            local vData = entry.t

            -- 只处理 LVS 载具（基类标记或类名前缀）
            local isLVS = false
            if vData.LVS == true then
                isLVS = true
            elseif className:find("lvs_", 1, true) then
                isLVS = true
            end

            if isLVS then
                local capacity = tonumber(vData.MaxPassengers)
                    or (istable(vData.Seats) and #vData.Seats or nil)
                    or 1

                local ftData = {
                    base          = className,
                    displayName   = vData.PrintName or className,
                    role          = InferRole(vData, className),
                    tags          = GenerateTags(vData, className),
                    seats         = {},
                    capacity      = capacity,
                    armorLevel    = math.Clamp(math.floor((tonumber(vData.Armor) or 0) / 100), 0, 3),
                    speedTier     = CategorizeSpeed(vData),
                    radioChannels = { "squad", "command" },
                    weapons       = {}
                }

                ApplyOverrides(ftData, className, overrides)

                Fireteam.VehicleInterface.Register(ftData)
                count = count + 1
            end
        end
    end

    print("[FIRETEAM:Adapter] LVS: 已注册 " .. count .. " 辆载具")
end)

print("[FIRETEAM:Adapter] ✓ LVS 适配器就绪")
