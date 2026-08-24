-- core/sh_api_registry.lua
-- FIRETEAM Public API Registry
-- 所有对外暴露的函数必须在此注册，保证命名一致、可文档化

if not Fireteam then Fireteam = {} end
Fireteam.API = Fireteam.API or {}

local apiRegistry = {}  -- { name = { fn, desc, args, returns } }

-- ─────────────────────────────────────
-- 注册 API 函数
-- ─────────────────────────────────────
--- @param name string       完整函数名 "Fireteam.API.GetSquad"
--- @param fn function       实际函数
--- @param desc string       描述
--- @param args table        参数列表 { {name, type, desc}, ... }
--- @param returns table     返回值描述
function Fireteam.API.Register(name, fn, desc, args, returns)
    if apiRegistry[name] then
        Fireteam.Log.Warn("API", "重复注册: " .. name)
        return
    end
    apiRegistry[name] = {
        fn      = fn,
        desc    = desc or "",
        args    = args or {},
        returns = returns or {}
    }
    -- 动态挂载到 Fireteam.API 上（跳过完整路径中的 "Fireteam.API." 前缀）
    local parts = string.Explode(".", name)
    local startIdx = 1
    if parts[1] == "Fireteam" and parts[2] == "API" then
        startIdx = 3
    end
    local target = Fireteam.API
    for i = startIdx, #parts - 1 do
        target[parts[i]] = target[parts[i]] or {}
        target = target[parts[i]]
    end
    target[parts[#parts]] = fn
end

-- ─────────────────────────────────────
-- 获取所有已注册 API（文档生成用）
-- ─────────────────────────────────────
function Fireteam.API.GetRegistry()
    return apiRegistry
end

-- ─────────────────────────────────────
-- 核心 API 预注册
-- ─────────────────────────────────────

-- 小队相关
Fireteam.API.Register("Fireteam.API.GetSquad", function(ply)
    return ply.FT_Squad
end, "Get player's current squad table",
    { { name = "ply", type = "Player", desc = "Target player" } },
    { { type = "table|nil", desc = "Squad table or nil" } })

Fireteam.API.Register("Fireteam.API.GetSquadMembers", function(squadId)
    local members = {}
    for _, p in ipairs(player.GetAll()) do
        if p.FT_Squad and p.FT_Squad.id == squadId then
            table.insert(members, p)
        end
    end
    return members
end, "Get all members of a squad",
    { { name = "squadId", type = "number", desc = "Squad ID" } },
    { { type = "table", desc = "Array of Players" } })

-- 职业相关
Fireteam.API.Register("Fireteam.API.GetClass", function(ply)
    return ply.FT_Class
end, "Get player's assigned class ID",
    { { name = "ply", type = "Player", desc = "Target player" } },
    { { type = "string|nil", desc = "Class ID or nil" } })

Fireteam.API.Register("Fireteam.API.AssignClass", function(ply, classId)
    if not SERVER then return false end
    local classes = Fireteam.Setting.GetData("classes")
    if not classes or not classes[classId] then return false end
    ply.FT_Class = classId
    hook.Run(Fireteam.HOOKS.CLASS_ASSIGNED, ply, classId)
    return true
end, "Assign a class to a player",
    { { name = "ply", type = "Player" }, { name = "classId", type = "string" } },
    { { type = "boolean", desc = "Success" } })

-- 武器接口相关
Fireteam.API.Register("Fireteam.API.GetWeaponData", function(entity)
    return Fireteam.WeaponInterface.Get(entity)
end, "Get FIRETEAM weapon data for an entity",
    { { name = "entity", type = "Entity" } },
    { { type = "table|nil", desc = "FTWeaponData" } })

-- 载具接口相关
Fireteam.API.Register("Fireteam.API.GetVehicleData", function(entity)
    return Fireteam.VehicleInterface.Get(entity)
end, "Get FIRETEAM vehicle data for an entity",
    { { name = "entity", type = "Entity" } },
    { { type = "table|nil", desc = "FTVehicleData" } })

-- 设定包查询
Fireteam.API.Register("Fireteam.API.GetActiveSetting", function()
    return Fireteam.Setting.Active
end, "Get currently active setting pack metadata",
    {}, { { type = "table|nil" } })

Fireteam.API.Register("Fireteam.API.GetSettingData", function(fileName)
    return Fireteam.Setting.GetData(fileName)
end, "Get data file from active setting pack",
    { { name = "fileName", type = "string", desc = "e.g. 'factions', 'classes'" } },
    { { type = "table|nil" } })

Fireteam.Log.Info("API", "✓ API 注册表就绪 (" .. table.Count(apiRegistry) .. " 个函数)")
