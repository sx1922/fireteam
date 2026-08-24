-- modules/adapters/sv_simfphys_adapter.lua
-- FIRETEAM Simfphys Vehicle Adapter

if not simfphys then
    Fireteam.Log.Info("适配器", "未检测到 Simfphys，跳过适配器")
    return
end

Fireteam.Log.Info("适配器", "检测到 Simfphys，开始注册适配器...")

-- ═══════════════════════════════════════
-- 分类映射（simfphys 类别 → FIRETEAM 载具类别）
-- ═══════════════════════════════════════
local function MapCategory(spData, className, printName)
    local combined = (className .. " " .. (printName or "")):lower()

    -- 履带/坦克类
    if spData.istank or spData.tracks or combined:find("tank")
        or combined:find("tracked") then
        return Fireteam.VEHICLE_CATEGORY.TRACKED
    end

    -- 装甲车/运兵车
    if combined:find("apc") or combined:find("bradley") or combined:find("bmp")
        or combined:find("btr") or combined:find("humvee") or combined:find("armored") then
        return Fireteam.VEHICLE_CATEGORY.APC
    end

    -- 越野车/皮卡/吉普
    if combined:find("jeep") or combined:find("truck") or combined:find("pickup")
        or combined:find("buggy") or combined:find("van") or combined:find("4x4")
        or combined:find("offroad") then
        return Fireteam.VEHICLE_CATEGORY.LIGHT
    end

    -- 普通民用轿车
    if combined:find("car") or combined:find("sedan") or combined:find("hatchback") then
        return Fireteam.VEHICLE_CATEGORY.CIVILIAN
    end

    -- 默认：按座位数推断
    local seats = tonumber(spData.podcount) or 1
    if seats >= 6 then
        return Fireteam.VEHICLE_CATEGORY.APC
    elseif seats >= 3 then
        return Fireteam.VEHICLE_CATEGORY.LIGHT
    else
        return Fireteam.VEHICLE_CATEGORY.CIVILIAN
    end
end

-- ═══════════════════════════════════════
-- 注册
-- ═══════════════════════════════════════
hook.Add(Fireteam.HOOKS.VEHICLE_DISCOVER, "FIRETEAM.SimfphysAdapter", function()
    local count = 0
    local vehicles = nil

    if istable(simfphys) and isfunction(simfphys.GetVehicles) then
        vehicles = simfphys.GetVehicles()
    end

    if istable(vehicles) then
        -- 直接 API：vehicles[class] = 数据表
        for className, vData in pairs(vehicles) do
            if not istable(vData) then continue end

            local ftData = {
                base           = className,
                displayName    = vData.PrintName or vData.Name or className,
                category       = MapCategory(vData, className, vData.PrintName),
                tags           = { "simfphys" },
                maxSpeed       = tonumber(vData.MaxSpeed) or 800,
                health         = tonumber(vData.MaxHealth) or 100,
                fuelCapacity   = 100,
                crewCapacity   = math.max(tonumber(vData.podcount) or 1, 1),
                armorLevel     = vData.istank and 5 or 1
            }

            Fireteam.VehicleInterface.Register(ftData)
            count = count + 1
        end
    else
        -- 回退：扫描 scripted_ents.GetList()
        -- 注意：GetList() 返回数组，元素是 {ClassName=..., t=...} 包装表，
        -- 实际 SENT 定义在 entry.t 中，不能按 map 直接读 PrintName/Base
        for _, entry in ipairs(scripted_ents.GetList()) do
            if not istable(entry) then continue end

            local className = entry.ClassName
            local t = istable(entry.t) and entry.t or nil
            if not className or not t then continue end

            local base = tostring(t.Base or "")
            if base:find("simfphys", 1, true) or className:find("gmod_sent_vehicle_fphysics", 1, true) then
                local ftData = {
                    base           = className,
                    displayName    = t.PrintName or className,
                    category       = MapCategory(t, className, t.PrintName),
                    tags           = { "simfphys" },
                    maxSpeed       = tonumber(t.MaxSpeed) or 800,
                    health         = tonumber(t.MaxHealth) or 100,
                    fuelCapacity   = 100,
                    crewCapacity   = math.max(tonumber(t.podcount) or 1, 1),
                    armorLevel     = t.istank and 5 or 1
                }

                Fireteam.VehicleInterface.Register(ftData)
                count = count + 1
            end
        end
    end

    Fireteam.Log.Info("适配器", "Simfphys: 已注册 " .. count .. " 辆载具")
end)

Fireteam.Log.Info("适配器", "✓ Simfphys 适配器就绪")
