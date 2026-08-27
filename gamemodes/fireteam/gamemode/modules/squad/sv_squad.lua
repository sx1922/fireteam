-- modules/squad/sv_squad.lua
-- FIRETEAM Squad System - Server Logic

if not Fireteam then Fireteam = {} end
Fireteam.Squad = Fireteam.Squad or {}

local squads = {}       -- { [id] = FTSquad }
local nextSquadId = 1

-- ═══════════════════════════════════════
-- 创建小队
-- ═══════════════════════════════════════
--- @param ply Player       创建者（自动成为队长）
--- @param name string      小队名
--- @param faction string   阵营 ID
--- @return table|nil       创建的小队或失败
--- 默认阵营：当前设定包的第一个阵营（数据驱动，不硬编码）
local function DefaultFaction()
    local factions = Fireteam.Setting.GetData and Fireteam.Setting.GetData("factions") or nil
    if istable(factions) then
        local id = next(factions)
        if id then return id end
    end
    return "unaffiliated"
end

function Fireteam.Squad.Create(ply, name, faction)
    if not IsValid(ply) then return nil end
    if Fireteam.Squad.GetPlayerSquad(ply) then
        ply:ChatPrint("[FIRETEAM] You are already in a squad. Leave first.")
        return nil
    end
    -- 阵营必须存在于当前设定包（防伪造 net 消息创建幽灵阵营小队）
    local packFactions = Fireteam.Setting.GetData and Fireteam.Setting.GetData("factions") or nil
    if istable(packFactions) and faction and not packFactions[faction] then
        ply:ChatPrint("[FIRETEAM] Unknown faction.")
        return nil
    end
    -- 用当前存活小队数判断（nextSquadId 只增不减，直接比较会永久锁死）
    if table.Count(squads) >= Fireteam.Squad.MAX_SQUADS then
        ply:ChatPrint("[FIRETEAM] Maximum squad limit reached.")
        return nil
    end

    local squad = {
        id        = nextSquadId,
        name      = name or ("Squad " .. nextSquadId),
        faction   = faction or DefaultFaction(),
        leader    = ply,
        members   = {},
        locked    = false,
        state     = Fireteam.Squad.STATE.FORMING,
        createdAt = CurTime()
    }
    nextSquadId = nextSquadId + 1

    squads[squad.id] = squad
    ply.FT_SquadData = squad
    squad.members[ply] = {
        role  = Fireteam.Squad.ROLE.LEADER,
        class = nil,
        ready = false
    }

    hook.Run(Fireteam.HOOKS.PLAYER_JOINED_SQUAD, ply, squad)
    Fireteam.Squad.SyncToAll()

    print("[FIRETEAM:Squad] Created '" .. squad.name .. "' by " .. ply:Nick())
    return squad
end

-- ═══════════════════════════════════════
-- 加入小队
-- ═══════════════════════════════════════
function Fireteam.Squad.Join(ply, squadId)
    if not IsValid(ply) then return false end

    local squad = squads[squadId]
    if not squad then
        ply:ChatPrint("[FIRETEAM] Squad not found.")
        return false
    end
    if Fireteam.Squad.GetPlayerSquad(ply) then
        ply:ChatPrint("[FIRETEAM] You are already in a squad.")
        return false
    end
    if Fireteam.Squad.IsFull(squad) then
        ply:ChatPrint("[FIRETEAM] Squad is full.")
        return false
    end
    if squad.state == Fireteam.Squad.STATE.DISBANDED then
        ply:ChatPrint("[FIRETEAM] Squad has been disbanded.")
        return false
    end
    if squad.locked then
        ply:ChatPrint("[FIRETEAM] Squad is locked by its leader.")
        return false
    end

    ply.FT_SquadData = squad
    squad.members[ply] = {
        role  = Fireteam.Squad.ROLE.MEMBER,
        class = nil,
        ready = false
    }

    hook.Run(Fireteam.HOOKS.PLAYER_JOINED_SQUAD, ply, squad)
    Fireteam.Squad.SyncToAll()

    ply:ChatPrint("[FIRETEAM] Joined squad: " .. squad.name)
    return true
end

-- ═══════════════════════════════════════
-- 离开小队
-- ═══════════════════════════════════════
function Fireteam.Squad.Leave(ply)
    if not IsValid(ply) then return false end

    local squad = Fireteam.Squad.GetPlayerSquad(ply)
    if not squad then return false end

    squad.members[ply] = nil
    ply.FT_SquadData = nil

    hook.Run(Fireteam.HOOKS.PLAYER_LEFT_SQUAD, ply, squad)

    -- 如果队长离开，转移给第一个成员
    if squad.leader == ply then
        local newLeader = nil
        for member, _ in pairs(squad.members) do
            if IsValid(member) then
                newLeader = member
                break
            end
        end
        if newLeader then
            squad.leader = newLeader
            squad.members[newLeader].role = Fireteam.Squad.ROLE.LEADER
            newLeader:ChatPrint("[FIRETEAM] You are now squad leader.")
        else
            -- 没人了，解散
            Fireteam.Squad.Disband(squad.id)
            return true
        end
    end

    Fireteam.Squad.SyncToAll()
    ply:ChatPrint("[FIRETEAM] Left squad: " .. squad.name)
    return true
end

-- ═══════════════════════════════════════
-- 解散小队
-- ═══════════════════════════════════════
function Fireteam.Squad.Disband(squadId)
    local squad = squads[squadId]
    if not squad then return false end

    squad.state = Fireteam.Squad.STATE.DISBANDED

    for member, _ in pairs(squad.members) do
        if IsValid(member) then
            member.FT_SquadData = nil
            member:ChatPrint("[FIRETEAM] Squad '" .. squad.name .. "' has been disbanded.")
            hook.Run(Fireteam.HOOKS.PLAYER_LEFT_SQUAD, member, squad)
        end
    end

    squads[squadId] = nil
    Fireteam.Squad.SyncToAll()

    print("[FIRETEAM:Squad] Disbanded '" .. squad.name .. "'")
    return true
end

-- ═══════════════════════════════════════
-- 踢出成员（仅队长）
-- ═══════════════════════════════════════
function Fireteam.Squad.Kick(leaderPly, targetPly)
    local squad = Fireteam.Squad.GetPlayerSquad(leaderPly)
    if not squad then return false end
    if squad.leader ~= leaderPly then return false end
    if targetPly == leaderPly then return false end
    if not IsValid(targetPly) then return false end
    -- 只能踢本队现有成员，防止伪造消息清掉任意玩家的小队引用
    if not squad.members[targetPly] then return false end

    squad.members[targetPly] = nil
    targetPly.FT_SquadData = nil
    targetPly:ChatPrint("[FIRETEAM] You have been kicked from the squad.")
    hook.Run(Fireteam.HOOKS.PLAYER_LEFT_SQUAD, targetPly, squad)
    Fireteam.Squad.SyncToAll()
    return true
end

-- ═══════════════════════════════════════
-- 锁队开关（仅队长）：锁定后新玩家无法加入
-- ═══════════════════════════════════════
function Fireteam.Squad.SetLocked(ply, locked)
    local squad = Fireteam.Squad.GetPlayerSquad(ply)
    if not squad then return false end
    if squad.leader ~= ply then return false end

    squad.locked = locked and true or false
    Fireteam.Squad.SyncToAll()
    return true
end

-- ═══════════════════════════════════════
-- 设置就绪状态
-- ═══════════════════════════════════════
function Fireteam.Squad.SetReady(ply, ready)
    local squad = Fireteam.Squad.GetPlayerSquad(ply)
    if not squad then return false end
    if not squad.members[ply] then return false end

    squad.members[ply].ready = ready
    Fireteam.Squad.SyncToAll()

    -- 检查是否全员就绪
    local allReady = true
    for _, info in pairs(squad.members) do
        if not info.ready then
            allReady = false
            break
        end
    end
    if allReady and squad.state == Fireteam.Squad.STATE.FORMING then
        squad.state = Fireteam.Squad.STATE.READY
        Fireteam.Squad.SyncToAll()
        print("[FIRETEAM:Squad] Squad '" .. squad.name .. "' is READY")
    end

    return true
end

-- ═══════════════════════════════════════
-- 查询
-- ═══════════════════════════════════════
function Fireteam.Squad.GetAll()
    return squads
end

function Fireteam.Squad.GetById(id)
    return squads[id]
end

function Fireteam.Squad.GetByFaction(factionId)
    local result = {}
    for _, squad in pairs(squads) do
        if squad.faction == factionId then
            table.insert(result, squad)
        end
    end
    return result
end

-- ═══════════════════════════════════════
-- 网络同步
-- 快照为纯数据表：成员以 EntIndex + 昵称表示（不序列化 Player 实体引用），
-- 序列化为手写字段（高频消息，不走泛型 WriteTable 反射），
-- 客户端按 EntIndex 反查实体。
-- ═══════════════════════════════════════
local ROLE_ID = { member = 0, leader = 1, specialist = 2 }

function Fireteam.Squad.SyncToAll()
    local list = {}
    for _, squad in pairs(squads) do
        list[#list + 1] = squad
    end
    table.sort(list, function(a, b) return (a.id or 0) < (b.id or 0) end)

    net.Start(Fireteam.NET.SQUAD_UPDATE)
    net.WriteUInt(#list, 5)
    for _, squad in ipairs(list) do
        -- 成员先收集排序，保证写入顺序稳定
        local members = {}
        for ply, info in pairs(squad.members) do
            if IsValid(ply) then members[#members + 1] = { ply = ply, info = info } end
        end
        table.sort(members, function(a, b)
            return a.ply:EntIndex() < b.ply:EntIndex()
        end)

        net.WriteUInt(squad.id or 0, 8)
        net.WriteString(squad.name or "")
        net.WriteString(squad.faction or "")
        net.WriteString(squad.state or "forming")
        net.WriteBool(squad.locked and true or false)
        net.WriteUInt(IsValid(squad.leader) and squad.leader:EntIndex() or 0, 8)
        net.WriteUInt(#members, 5)
        for _, m in ipairs(members) do
            net.WriteUInt(m.ply:EntIndex(), 8)
            net.WriteString(m.ply:Nick())
            net.WriteUInt(ROLE_ID[m.info.role or "member"] or 0, 2)
            net.WriteString(m.info.class or "")
            net.WriteBool(m.info.ready and true or false)
            net.WriteBool(m.ply:Alive())
            net.WriteUInt(math.Clamp(m.ply:Alive() and m.ply:Health() or 0, 0, 1023), 10)
            net.WriteUInt(math.Clamp(math.max(m.ply:GetMaxHealth(), 1), 0, 1023), 10)
        end
    end
    net.Broadcast()
end

-- ═══════════════════════════════════════
-- 玩家断开时清理
-- ═══════════════════════════════════════
hook.Add("PlayerDisconnected", "Fireteam.Squad.Cleanup", function(ply)
    local squad = Fireteam.Squad.GetPlayerSquad(ply)
    if squad then
        Fireteam.Squad.Leave(ply)
    end
end)

-- ═══════════════════════════════════════
-- 网络消息处理（消息名统一注册于 Fireteam.NET）
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.SQUAD_CREATE, function(len, ply)
    -- C→S 输入校验：截断超长字符串（客户端不可信）
    local name = string.sub(net.ReadString(), 1, 32)
    local faction = string.sub(net.ReadString(), 1, 32)
    Fireteam.Squad.Create(ply, name, faction)
end)

net.Receive(Fireteam.NET.SQUAD_JOIN, function(len, ply)
    local squadId = net.ReadInt(8)
    Fireteam.Squad.Join(ply, squadId)
end)

net.Receive(Fireteam.NET.SQUAD_LEAVE, function(len, ply)
    Fireteam.Squad.Leave(ply)
end)

net.Receive(Fireteam.NET.SQUAD_READY, function(len, ply)
    local ready = net.ReadBool()
    Fireteam.Squad.SetReady(ply, ready)
end)

net.Receive(Fireteam.NET.SQUAD_KICK, function(len, ply)
    local target = Entity(net.ReadUInt(8))
    Fireteam.Squad.Kick(ply, target)
end)

net.Receive(Fireteam.NET.SQUAD_LOCK, function(len, ply)
    local locked = net.ReadBool()
    Fireteam.Squad.SetLocked(ply, locked)
end)

print("[FIRETEAM:Squad] ✓ 服务端逻辑已加载")
