-- modules/marker/sv_marker.lua
-- FIRETEAM Marker System - Server Logic

if not Fireteam then Fireteam = {} end
Fireteam.Marker = Fireteam.Marker or {}

local activeMarkers = {}   -- { [id] = markerData }
local nextMarkerId = 1

-- ═══════════════════════════════════════
-- 放置标记
-- opts.factionWide=true：阵营级标记（P11），仅本阵营指挥官可放，
-- 广播范围为本阵营全部小队；不带此开关则为普通小队级标记。
-- ═══════════════════════════════════════
function Fireteam.Marker.Add(ply, pos, markerType, label, opts)
    if not IsValid(ply) then return nil end

    local squad = Fireteam.Squad.GetPlayerSquad(ply)
    if not squad then
        ply:ChatPrint("[FIRETEAM] Join a squad to place markers.")
        return nil
    end

    local factionWide = opts and opts.factionWide or false
    if factionWide then
        local isCmdr = Fireteam.Commander
            and Fireteam.Commander.IsFactionCommander
            and Fireteam.Commander.IsFactionCommander(ply)
        if not isCmdr then
            ply:ChatPrint("[FIRETEAM] Only your faction commander may place faction-wide markers.")
            return nil
        end
    end

    -- 检查数量限制
    local myCount = 0
    for _, m in pairs(activeMarkers) do
        if m.owner == ply then myCount = myCount + 1 end
    end
    local maxMarkers = Fireteam.Config.Get("marker.max_per_player") or Fireteam.Marker.MAX_PER_PLAYER
    if myCount >= maxMarkers then
        ply:ChatPrint("[FIRETEAM] Maximum markers reached. Remove one first.")
        return nil
    end

    local marker = {
        id        = nextMarkerId,
        type      = markerType or Fireteam.Marker.TYPE.WAYPOINT,
        pos       = pos,
        label     = label or "",
        owner     = ply,
        -- 阵营级标记不带 squadId（避免被客户端小队过滤器放行到别队语义混淆），
        -- 以 faction 字段标识广播域
        squadId   = not factionWide and squad.id or nil,
        faction   = factionWide and squad.faction or nil,
        createdAt = CurTime(),
        expiresAt = CurTime() + Fireteam.Marker.LIFETIME
    }
    nextMarkerId = nextMarkerId + 1

    activeMarkers[marker.id] = marker

    if factionWide then
        Fireteam.Marker.SyncToFaction(squad.faction)
    else
        Fireteam.Marker.SyncToSquad(squad.id)
    end

    -- 扩展点：AI 队友等消费方据此响应路点指令
    hook.Run(Fireteam.HOOKS.MARKER_ADDED, ply, marker)

    return marker
end

-- ═══════════════════════════════════════
-- 移除标记
-- ═══════════════════════════════════════
function Fireteam.Marker.Remove(ply, markerId)
    local marker = activeMarkers[markerId]
    if not marker then return false end

    -- 权限：放置者、本队队长（小队级标记）、或该阵营指挥官（阵营级标记）
    local allowed = marker.owner == ply
    if not allowed and marker.faction then
        local isCmdr = Fireteam.Commander
            and Fireteam.Commander.IsFactionCommander
            and Fireteam.Commander.IsFactionCommander(ply)
        local mySquad = Fireteam.Squad.GetPlayerSquad(ply)
        allowed = isCmdr and mySquad and mySquad.faction == marker.faction
    elseif not allowed then
        local squad = Fireteam.Squad.GetPlayerSquad(ply)
        allowed = squad ~= nil and squad.leader == ply
    end
    if not allowed then return false end

    activeMarkers[markerId] = nil

    if marker.faction then
        Fireteam.Marker.SyncToFaction(marker.faction)
    elseif marker.squadId then
        Fireteam.Marker.SyncToSquad(marker.squadId)
    end

    return true
end

-- ═══════════════════════════════════════
-- 清除过期标记（只重同步受影响的广播域，避免向无关玩家泄露标记）
-- ═══════════════════════════════════════
timer.Create("Fireteam.Marker.Cleanup", 5, 0, function()
    local now = CurTime()
    local affectedSquads = {}
    local affectedFactions = {}
    for id, marker in pairs(activeMarkers) do
        if now > marker.expiresAt then
            if marker.faction then
                affectedFactions[marker.faction] = true
            else
                affectedSquads[marker.squadId] = true
            end
            activeMarkers[id] = nil
        end
    end
    for squadId in pairs(affectedSquads) do
        Fireteam.Marker.SyncToSquad(squadId)
    end
    for faction in pairs(affectedFactions) do
        Fireteam.Marker.SyncToFaction(faction)
    end
end)

-- ═══════════════════════════════════════
-- 查询
-- ═══════════════════════════════════════
function Fireteam.Marker.GetAll()
    return activeMarkers
end

function Fireteam.Marker.GetBySquad(squadId)
    local result = {}
    for _, m in pairs(activeMarkers) do
        if m.squadId == squadId then
            table.insert(result, m)
        end
    end
    return result
end

function Fireteam.Marker.GetByFaction(factionId)
    local result = {}
    for _, m in pairs(activeMarkers) do
        if m.faction == factionId then
            table.insert(result, m)
        end
    end
    return result
end

-- ═══════════════════════════════════════
-- 同步
-- （owner 以 EntIndex+昵称快照发送，不直接发 Player 引用）
-- ═══════════════════════════════════════
local function SerializeMarkers(markers)
    local out = {}
    for _, m in pairs(markers) do
        table.insert(out, {
            id        = m.id,
            type      = m.type,
            pos       = m.pos,
            label     = m.label,
            squadId   = m.squadId,
            faction   = m.faction,
            ownerIdx  = IsValid(m.owner) and m.owner:EntIndex() or 0,
            ownerName = IsValid(m.owner) and m.owner:Nick() or "?",
            expiresAt = m.expiresAt
        })
    end
    return out
end

function Fireteam.Marker.SyncToSquad(squadId)
    local markers = Fireteam.Marker.GetBySquad(squadId)
    local squad = Fireteam.Squad.GetById(squadId)
    if not squad then return end

    local targets = {}
    for ply, _ in pairs(squad.members) do
        if IsValid(ply) then
            table.insert(targets, ply)
        end
    end
    if #targets == 0 then return end

    net.Start(Fireteam.NET.MARKER_ADD)
        net.WriteTable(SerializeMarkers(markers))
    net.Send(targets)
end

--- 阵营级广播（P11）：本阵营全部小队成员可见指挥官标记
function Fireteam.Marker.SyncToFaction(factionId)
    if not (Fireteam.Squad and Fireteam.Squad.GetByFaction) then return end
    local markers = Fireteam.Marker.GetByFaction(factionId)

    local targets = {}
    for _, squad in ipairs(Fireteam.Squad.GetByFaction(factionId)) do
        for ply, _ in pairs(squad.members) do
            if IsValid(ply) and not table.HasValue(targets, ply) then
                table.insert(targets, ply)
            end
        end
    end
    if #targets == 0 then return end

    net.Start(Fireteam.NET.MARKER_ADD)
        net.WriteTable(SerializeMarkers(markers))
    net.Send(targets)
end

function Fireteam.Marker.SyncToAll()
    net.Start(Fireteam.NET.MARKER_ADD)
        net.WriteTable(SerializeMarkers(activeMarkers))
    net.Broadcast()
end

-- ═══════════════════════════════════════
-- 网络请求（消息名统一注册于 Fireteam.NET）
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.MARKER_PLACE, function(len, ply)
    local pos = net.ReadVector()
    -- C→S 输入校验：截断超长字符串（客户端不可信）
    local mType = string.sub(net.ReadString(), 1, 24)
    local label = string.sub(net.ReadString(), 1, 32)
    -- 第四段：阵营级标记声明——服务端仍以 Commander 校验为准，客户端声明不可信
    local factionWide = net.ReadBool()
    Fireteam.Marker.Add(ply, pos, mType, label, { factionWide = factionWide })
end)

net.Receive(Fireteam.NET.MARKER_REMOVE, function(len, ply)
    local markerId = net.ReadInt(16)
    Fireteam.Marker.Remove(ply, markerId)
end)

print("[FIRETEAM:Marker] ✓ 服务端逻辑已加载")
