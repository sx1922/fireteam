-- gamemode/api/sh_fireteam_api.lua
-- FIRETEAM Public API — Shared Surface
-- 面向第三方 addon 的稳定查询接口。所有函数经 core/sh_api_registry.lua 注册，
-- 因此同时挂载到 Fireteam.API.<名> 并进入可枚举的 API 注册表。
--
-- 加载时机：本文件在 shared.lua 内于 sh_api_registry 之后 include，
-- 早于各功能模块。故所有实现必须**惰性解析**（调用时才查 Fireteam.X），
-- 不能在文件顶层缓存模块函数引用。

local function Reg(name, fn, desc, args, returns)
    if not (Fireteam.API and Fireteam.API.Register) then return end
    Fireteam.API.Register("Fireteam.API." .. name, fn, desc, args, returns)
end

-- ─────────────────────────────────────
-- 阵营 / 回合
-- ─────────────────────────────────────

Reg("GetFaction", function(ply)
    if not (Fireteam.Rounds and Fireteam.Rounds.GetPlayerFaction) then return nil end
    return Fireteam.Rounds.GetPlayerFaction(ply)
end, "Get a player's faction id (derived from their squad)",
    { { name = "ply", type = "Player" } },
    { { type = "string|nil", desc = "Faction id or nil when squadless" } })

Reg("GetRoundMode", function()
    return Fireteam.Config and Fireteam.Config.Get("rounds.mode") or "pvp"
end, "Current round mode: 'pvp' or 'pve'",
    {}, { { type = "string" } })

Reg("GetScenario", function(id)
    if not Fireteam.Rounds then return nil end
    if id and Fireteam.Rounds.GetScenario then
        return Fireteam.Rounds.GetScenario(id)
    end
    return Fireteam.Rounds.ResolveScenario and Fireteam.Rounds.ResolveScenario() or nil
end, "Get a scenario table by id, or the active scenario when id is omitted",
    { { name = "id", type = "string|nil" } },
    { { type = "table|nil" } })

Reg("GetScenarioList", function()
    if not (Fireteam.Rounds and Fireteam.Rounds.GetScenarioList) then return nil end
    return Fireteam.Rounds.GetScenarioList()
end, "Get the scenario table of the active setting pack (nil = implicit single scenario)",
    {}, { { type = "table|nil" } })

-- ─────────────────────────────────────
-- 语音频道
-- ─────────────────────────────────────

Reg("GetChannelKind", function(channelId)
    if not (Fireteam.Voice and Fireteam.Voice.GetChannelKind) then return nil end
    return Fireteam.Voice.GetChannelKind(channelId)
end, "Resolve a voice channel's listening semantics: local|squad|command|all",
    { { name = "channelId", type = "string" } },
    { { type = "string|nil" } })

Reg("GetChannelDef", function(channelId)
    if not (Fireteam.Voice and Fireteam.Voice.GetChannel) then return nil end
    return Fireteam.Voice.GetChannel(channelId)
end, "Get a voice channel definition (setting pack first, built-in fallback)",
    { { name = "channelId", type = "string" } },
    { { type = "table|nil" } })

-- ─────────────────────────────────────
-- 指挥官（两端实现不同：服务端权威表 / 客户端广播缓存）
-- ─────────────────────────────────────

Reg("GetCommander", function(factionId)
    if not Fireteam.Commander then return nil end
    if SERVER then
        return Fireteam.Commander.GetFactionCommander
            and Fireteam.Commander.GetFactionCommander(factionId) or nil
    end
    return Fireteam.Commander.GetCachedFactionCommander
        and Fireteam.Commander.GetCachedFactionCommander(factionId) or nil
end, "Get the commander of a faction (server: authoritative, client: last broadcast)",
    { { name = "factionId", type = "string" } },
    { { type = "Player|nil" } })

Reg("IsCommander", function(ply)
    if not (Fireteam.Commander and IsValid(ply)) then return false end
    if SERVER then
        return Fireteam.Commander.IsFactionCommander
            and Fireteam.Commander.IsFactionCommander(ply) and true or false
    end
    if not (Fireteam.Rounds and Fireteam.Rounds.GetPlayerFaction) then return false end
    local faction = Fireteam.Rounds.GetPlayerFaction(ply)
    if not faction then return false end
    local cmd = Fireteam.Commander.GetCachedFactionCommander
        and Fireteam.Commander.GetCachedFactionCommander(faction) or nil
    return cmd == ply
end, "Whether a player currently commands their faction",
    { { name = "ply", type = "Player" } },
    { { type = "boolean" } })

-- ─────────────────────────────────────
-- 物品 / 背包（定义层，只读）
-- ─────────────────────────────────────

Reg("GetItemDef", function(itemId)
    if not (Fireteam.Inventory and Fireteam.Inventory.GetItemDef) then return nil end
    return Fireteam.Inventory.GetItemDef(itemId)
end, "Get an item definition from the active setting pack registry",
    { { name = "itemId", type = "string" } },
    { { type = "table|nil" } })

Reg("GetItemSize", function(itemDef)
    if not (Fireteam.Inventory and Fireteam.Inventory.GetItemSize) then return 1, 1 end
    return Fireteam.Inventory.GetItemSize(itemDef)
end, "Grid footprint of an item definition (defaults to 1x1)",
    { { name = "itemDef", type = "table" } },
    { { type = "number", desc = "width" }, { type = "number", desc = "height" } })

-- ─────────────────────────────────────
-- 体征（纯函数层）
-- ─────────────────────────────────────

Reg("HitgroupToLimb", function(hitgroup)
    if not (Fireteam.Vitals and Fireteam.Vitals.HitgroupToPart) then return nil end
    return Fireteam.Vitals.HitgroupToPart(hitgroup)
end, "Map a HITGROUP_* enum to a FIRETEAM limb id",
    { { name = "hitgroup", type = "number" } },
    { { type = "string|nil", desc = "head/thorax/stomach/l_arm/r_arm/l_leg/r_leg" } })

Reg("GetLimbMaxHealth", function()
    if not (Fireteam.Vitals and Fireteam.Vitals.LIMBS) then return nil end
    local out = {}
    for part, hp in pairs(Fireteam.Vitals.LIMBS) do out[part] = hp end
    return out
end, "Base max HP per limb (copy)",
    {}, { { type = "table|nil" } })

Fireteam.Log.Info("API", "✓ 共享 API 表面已注册")
