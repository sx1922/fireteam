-- modules/ai/sv_ai.lua
-- FIRETEAM AI Teammate - Server Logic
-- 部署/回收 NextBot 队友；路点指令挂接标记系统；回合补位接口。

if not Fireteam then Fireteam = {} end
Fireteam.AI = Fireteam.AI or {}

local L = function(key, ...)
    return Fireteam.Locale.Get(key, ...)
end

-- 存活 AI 名册 { [bot] = ownerPlayer }
local roster = {}

function Fireteam.AI.Unregister(bot)
    if bot ~= nil then roster[bot] = nil end
end

--- 某玩家名下的全部存活 AI
function Fireteam.AI.GetBotsFor(ply)
    local out = {}
    for bot, owner in pairs(roster) do
        if IsValid(bot) and owner == ply then
            table.insert(out, bot)
        elseif not IsValid(bot) then
            roster[bot] = nil
        end
    end
    return out
end

local function CountFor(ply)
    local n = 0
    for bot, owner in pairs(roster) do
        if IsValid(bot) and owner == ply then
            n = n + 1
        elseif not IsValid(bot) then
            roster[bot] = nil
        end
    end
    return n
end

-- ═══════════════════════════════════════
-- 部署 / 回收
-- ═══════════════════════════════════════
--- 地面吸附，避免生成在空中/墙里
local function GroundPos(pos)
    local tr = util.TraceLine({
        start  = pos + Vector(0, 0, 64),
        endpos = pos - Vector(0, 0, 512),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    return tr.Hit and tr.HitPos + Vector(0, 0, 8) or pos
end

--- @return table|nil 生成的 bot（失败返回 nil）
function Fireteam.AI.Deploy(ply)
    if not Fireteam.Config.Get("ai.enabled") then
        ply:ChatPrint("[FIRETEAM] " .. L("ai_disabled"))
        return nil
    end
    if not IsValid(ply) or not ply:Alive() then return nil end

    local squad = Fireteam.Squad.GetPlayerSquad(ply)
    if not squad then
        ply:ChatPrint("[FIRETEAM] " .. L("ai_need_squad"))
        return nil
    end

    local cap = Fireteam.Config.Get("ai.max_per_player") or 2
    if CountFor(ply) >= cap then
        ply:ChatPrint("[FIRETEAM] " .. L("ai_limit_reached", cap))
        return nil
    end

    -- 主人身后扇形落位，多个 AI 不重叠
    local idx = CountFor(ply)
    local ang = (ply:GetAimVector():Angle().yaw - 140 + idx * 40)
    local dir = Angle(0, ang, 0):Forward()
    local spawnPos = GroundPos(ply:GetPos() + dir * 80)

    local bot = ents.Create("ft_bot_teammate")
    if not IsValid(bot) then return nil end
    bot:SetPos(spawnPos)
    bot:SetAngles(Angle(0, ang + 180, 0))
    bot:SetModel(Fireteam.AI.MODELS[math.random(#Fireteam.AI.MODELS)])
    bot:Spawn()
    bot:Bind(ply)

    roster[bot] = ply

    -- 名字带主人缩写便于辨认
    bot:SetNW2String("ftOwnerName", ply:Nick())
    bot:SetNW2String("ftStance", Fireteam.AI.STANCE.FOLLOW)

    hook.Run("Fireteam.AI.Deployed", ply, bot)
    return bot
end

--- 回收某玩家的全部 AI
function Fireteam.AI.RemoveAll(ply)
    local bots = Fireteam.AI.GetBotsFor(ply)
    for _, bot in ipairs(bots) do
        if IsValid(bot) then bot:Remove() end
    end
    return #bots
end

--- 设置某玩家全部 AI 的姿态
function Fireteam.AI.SetStance(ply, stance)
    if stance ~= Fireteam.AI.STANCE.FOLLOW
        and stance ~= Fireteam.AI.STANCE.HOLD then
        return false
    end
    local n = 0
    for _, bot in ipairs(Fireteam.AI.GetBotsFor(ply)) do
        bot:SetStance(stance)
        n = n + 1
    end
    return n > 0
end

-- ═══════════════════════════════════════
-- 路点指令：挂接标记系统
-- ═══════════════════════════════════════
--- 收到本小队 waypoint/rally 标记时，AI 前往该位置
--- （rally 到达后驻守，waypoint 到达后恢复原姿态）
hook.Add(Fireteam.HOOKS.MARKER_ADDED, "Fireteam.AI.MarkerOrder", function(ply, marker)
    if not Fireteam.Config.Get("ai.enabled") then return end
    if not IsValid(ply) or not istable(marker) then return end
    if marker.type ~= Fireteam.Marker.TYPE.WAYPOINT
        and marker.type ~= Fireteam.Marker.TYPE.RALLY then
        return
    end

    local holdHere = (marker.type == Fireteam.Marker.TYPE.RALLY)
    for _, bot in ipairs(Fireteam.AI.GetBotsFor(ply)) do
        bot:OrderMoveTo(marker.pos, holdHere)
    end
end)

-- ═══════════════════════════════════════
-- 回合补位框架
-- ═══════════════════════════════════════
--- 把小队"人数"补到 target：只统计真人成员，差额由绑给队长的 AI 补齐。
--- AI 不写入 squad.members（避免队长转移/就绪判定被 bot 干扰），
--- 只记录 FT_SquadId 供阵营与 UI 查询。
function Fireteam.AI.FillSquad(squad, target)
    if not squad then return 0 end
    target = math.floor(target or 0)
    if target <= 0 then return 0 end

    local leader = squad.leader
    if not IsValid(leader) or not leader:Alive() then return 0 end

    local humans = 0
    for member in pairs(squad.members) do
        if IsValid(member) and member:IsPlayer() then humans = humans + 1 end
    end

    local spawned = 0
    while humans + CountFor(leader) + spawned < target
        and CountFor(leader) + spawned < (Fireteam.Config.Get("ai.max_per_player") or 2) * 4 do
        local bot = Fireteam.AI.Deploy(leader)
        if not IsValid(bot) then break end
        if squad.id then bot:SetNW2Int("ftSquadId", squad.id) end
        spawned = spawned + 1
    end
    return spawned
end

hook.Add(Fireteam.HOOKS.ROUND_STATE_CHANGED, "Fireteam.AI.Autofill", function(oldState, newState)
    if newState ~= "active" then return end
    local target = Fireteam.Config.Get("ai.autofill_size") or 0
    if target <= 0 or not Fireteam.Config.Get("ai.enabled") then return end

    for _, squad in pairs(Fireteam.Squad.GetAll()) do
        local n = Fireteam.AI.FillSquad(squad, target)
        if n > 0 then
            squad.leader:ChatPrint("[FIRETEAM] " .. L("ai_filled", n))
        end
    end
end)

-- ═══════════════════════════════════════
-- 清理
-- ═══════════════════════════════════════
hook.Add("PlayerDisconnected", "Fireteam.AI.Cleanup", function(ply)
    Fireteam.AI.RemoveAll(ply)
end)

-- ═══════════════════════════════════════
-- 控制台命令
-- ═══════════════════════════════════════
concommand.Add("ft_ai_add", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local n = math.Clamp(tonumber(args[1]) or 1, 1, 8)
    local spawned = 0
    for _ = 1, n do
        if Fireteam.AI.Deploy(ply) then spawned = spawned + 1 end
    end
    if spawned > 0 then
        ply:ChatPrint("[FIRETEAM] " .. L("ai_deployed", spawned))
    end
end)

concommand.Add("ft_ai_remove", function(ply)
    if not IsValid(ply) then return end
    local n = Fireteam.AI.RemoveAll(ply)
    if n > 0 then ply:ChatPrint("[FIRETEAM] " .. L("ai_removed", n)) end
end)

concommand.Add("ft_ai_stance", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local stance = args[1]
    if Fireteam.AI.SetStance(ply, stance) then
        ply:ChatPrint("[FIRETEAM] " .. L("ai_stance_set", L("stance_" .. stance)))
    end
end)

concommand.Add("ft_ai_fill", function(ply, cmd, args)
    -- 管理员手动触发全体补位（无参时读 ai.autofill_size）
    if IsValid(ply) and not ply:IsAdmin() then return end
    local target = tonumber(args[1]) or Fireteam.Config.Get("ai.autofill_size") or 0
    if target <= 0 then return end
    for _, squad in pairs(Fireteam.Squad.GetAll()) do
        Fireteam.AI.FillSquad(squad, target)
    end
end)

Fireteam.Log.Info("AI队友", "✓ AI 队友框架服务端已加载")
