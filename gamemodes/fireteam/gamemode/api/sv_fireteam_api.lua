-- gamemode/api/sv_fireteam_api.lua
-- FIRETEAM Public API — Server Surface
-- 面向第三方 addon 的服务端可写接口（回合控制 / 物品发放 / 指挥席位）。
-- 与 sh_fireteam_api.lua 同为惰性解析：模块尚未加载时返回 false 而不报错。
--
-- 权限说明：本层不做管理员校验——调用方是服务端 Lua，已在信任边界内。
-- 面向玩家的入口（concommand / net 消息）各模块自带 AdminAllowed 校验。

if not SERVER then return end

local function Reg(name, fn, desc, args, returns)
    if not (Fireteam.API and Fireteam.API.Register) then return end
    Fireteam.API.Register("Fireteam.API." .. name, fn, desc, args, returns)
end

-- ─────────────────────────────────────
-- 回合控制
-- ─────────────────────────────────────

Reg("SetRoundMode", function(mode)
    if mode ~= "pvp" and mode ~= "pve" then return false end
    if not (Fireteam.Config and Fireteam.Config.Set) then return false end
    Fireteam.Config.Set("rounds.mode", mode)
    return true
end, "Switch PvP/PvE mode (takes effect next round)",
    { { name = "mode", type = "string", desc = "'pvp' or 'pve'" } },
    { { type = "boolean", desc = "Success" } })

Reg("SetScenario", function(scenarioId)
    if not isstring(scenarioId) then return false end
    if Fireteam.Rounds and Fireteam.Rounds.GetScenarioList then
        local list = Fireteam.Rounds.GetScenarioList()
        if list and scenarioId ~= "" and not list[scenarioId] then return false end
    end
    if not (Fireteam.Config and Fireteam.Config.Set) then return false end
    Fireteam.Config.Set("rounds.scenario", scenarioId)
    return true
end, "Select the scenario used from the next briefing onward",
    { { name = "scenarioId", type = "string" } },
    { { type = "boolean" } })

Reg("AdvanceRound", function()
    if not (Fireteam.Rounds and Fireteam.Rounds.AdminAdvance) then return false end
    Fireteam.Rounds.AdminAdvance()
    return true
end, "Immediately advance the round state machine to its next phase",
    {}, { { type = "boolean" } })

Reg("EndRound", function(winner)
    if not (Fireteam.Rounds and Fireteam.Rounds.AdminEnd) then return false end
    return Fireteam.Rounds.AdminEnd(winner) and true or false
end, "Force the active round to settle",
    { { name = "winner", type = "string|nil", desc = "faction id / 'draw' / nil = by score" } },
    { { type = "boolean" } })

-- ─────────────────────────────────────
-- 物品发放（受 max_carry 与背包网格空间双重截断）
-- ─────────────────────────────────────

Reg("GiveItem", function(ply, itemId, count)
    if not (IsValid(ply) and Fireteam.Inventory and Fireteam.Inventory.Add) then return 0 end
    return Fireteam.Inventory.Add(ply, itemId, math.max(tonumber(count) or 1, 0))
end, "Grant items; returns the amount actually added (grid space may truncate)",
    { { name = "ply", type = "Player" }, { name = "itemId", type = "string" },
      { name = "count", type = "number|nil", desc = "default 1" } },
    { { type = "number", desc = "Amount actually granted" } })

Reg("TakeItem", function(ply, itemId, count)
    if not (IsValid(ply) and Fireteam.Inventory and Fireteam.Inventory.Add) then return 0 end
    local removed = Fireteam.Inventory.Add(ply, itemId, -math.max(tonumber(count) or 1, 0))
    return -removed
end, "Remove items; returns the amount actually removed",
    { { name = "ply", type = "Player" }, { name = "itemId", type = "string" },
      { name = "count", type = "number|nil", desc = "default 1" } },
    { { type = "number" } })

Reg("GetItemCount", function(ply, itemId)
    if not (IsValid(ply) and Fireteam.Inventory and Fireteam.Inventory.Get) then return 0 end
    return Fireteam.Inventory.Get(ply, itemId)
end, "How many of an item a player currently carries",
    { { name = "ply", type = "Player" }, { name = "itemId", type = "string" } },
    { { type = "number" } })

-- ─────────────────────────────────────
-- 体征
-- ─────────────────────────────────────

Reg("IsDowned", function(ply)
    if not (Fireteam.Vitals and Fireteam.Vitals.IsDowned) then return false end
    return Fireteam.Vitals.IsDowned(ply) and true or false
end, "Whether a player is in the downed (bleeding-out) state",
    { { name = "ply", type = "Player" } },
    { { type = "boolean" } })

Reg("ResetVitals", function(ply)
    if not (IsValid(ply) and Fireteam.Vitals and Fireteam.Vitals.Reset) then return false end
    Fireteam.Vitals.Reset(ply)
    return true
end, "Clear a player's vitals record (limbs / bleeding / downed timers)",
    { { name = "ply", type = "Player" } },
    { { type = "boolean" } })

-- ─────────────────────────────────────
-- 指挥席位
-- ─────────────────────────────────────

Reg("RelinquishCommand", function(ply)
    if not (IsValid(ply) and Fireteam.Commander and Fireteam.Commander.Relinquish) then return false end
    return Fireteam.Commander.Relinquish(ply) and true or false
end, "Make a commander step down, vacating the faction seat",
    { { name = "ply", type = "Player" } },
    { { type = "boolean" } })

Fireteam.Log.Info("API", "✓ 服务端 API 表面已注册")
