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
    return ply.FT_SquadData
end, "Get player's current squad table",
    { { name = "ply", type = "Player", desc = "Target player" } },
    { { type = "table|nil", desc = "Squad table or nil" } })

Fireteam.API.Register("Fireteam.API.GetSquadMembers", function(squadId)
    local members = {}
    for _, p in ipairs(player.GetAll()) do
        if p.FT_SquadData and p.FT_SquadData.id == squadId then
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

-- 剧本扩展 API（运行时叠加层，不改设定包文件）
local function R(fn) return Fireteam.Rounds and Fireteam.Rounds[fn] end

Fireteam.API.Register("Fireteam.API.RegisterScenario", function(id, data)
    return R("RegisterScenario") and Fireteam.Rounds.RegisterScenario(id, data)
end, "Register a full custom scenario (overrides built-in on id collision)",
    { { name = "id", type = "string" }, { name = "data", type = "table", desc = "Same shape as map_rules.scenarios entry" } },
    { { type = "boolean", desc = "Success" } })

Fireteam.API.Register("Fireteam.API.AddScenarioObjective", function(scenarioId, objectiveDef)
    return R("AddScenarioObjective") and Fireteam.Rounds.AddScenarioObjective(scenarioId, objectiveDef)
end, "Append an objective template to a scenario",
    { { name = "scenarioId", type = "string" }, { name = "objectiveDef", type = "table" } },
    { { type = "boolean" } })

Fireteam.API.Register("Fireteam.API.RemoveScenarioObjective", function(scenarioId, objectiveName)
    return R("RemoveScenarioObjective") and Fireteam.Rounds.RemoveScenarioObjective(scenarioId, objectiveName)
end, "Remove an objective (by its name field) from a scenario",
    { { name = "scenarioId", type = "string" }, { name = "objectiveName", type = "string" } },
    { { type = "boolean" } })

Fireteam.API.Register("Fireteam.API.AddScenarioSpawn", function(scenarioId, factionId, spawnEntry)
    return R("AddScenarioSpawn") and Fireteam.Rounds.AddScenarioSpawn(scenarioId, factionId, spawnEntry)
end, "Append a spawn point entry for a faction",
    { { name = "scenarioId", type = "string" }, { name = "factionId", type = "string" }, { name = "spawnEntry", type = "table" } },
    { { type = "boolean" } })

Fireteam.API.Register("Fireteam.API.SetScenarioTimings", function(scenarioId, timings)
    return R("SetScenarioTimings") and Fireteam.Rounds.SetScenarioTimings(scenarioId, timings)
end, "Override scenario timing params (shallow merge)",
    { { name = "scenarioId", type = "string" }, { name = "timings", type = "table" } },
    { { type = "boolean" } })

Fireteam.API.Register("Fireteam.API.OverrideScenarioVitals", function(scenarioId, params)
    return R("OverrideScenarioVitals") and Fireteam.Rounds.OverrideScenarioVitals(scenarioId, params)
end, "Override vitals params for a scenario (top tier of the 3-level resolution)",
    { { name = "scenarioId", type = "string" }, { name = "params", type = "table" } },
    { { type = "boolean" } })

Fireteam.API.Register("Fireteam.API.SetScenarioPvE", function(scenarioId, pve)
    return R("SetScenarioPvE") and Fireteam.Rounds.SetScenarioPvE(scenarioId, pve)
end, "Override PvE campaign config for a scenario",
    { { name = "scenarioId", type = "string" }, { name = "pve", type = "table" } },
    { { type = "boolean" } })

Fireteam.API.Register("Fireteam.API.ClearScenarioExtensions", function()
    if R("ClearScenarioExtensions") then Fireteam.Rounds.ClearScenarioExtensions() end
end, "Clear all custom scenarios and runtime extensions (restore pack as-is)",
    {}, {})

Fireteam.API.Register("Fireteam.API.GetSettingData", function(fileName)
    return Fireteam.Setting.GetData(fileName)
end, "Get data file from active setting pack",
    { { name = "fileName", type = "string", desc = "e.g. 'factions', 'classes'" } },
    { { type = "table|nil" } })

Fireteam.Log.Info("API", "✓ API 注册表就绪 (" .. table.Count(apiRegistry) .. " 个函数)")
