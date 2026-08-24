-- modules/marker/sv_marker.lua
-- FIRETEAM Marker System - Server Logic

if not Fireteam then Fireteam = {} end
Fireteam.Marker = Fireteam.Marker or {}

local activeMarkers = {}   -- { [id] = markerData }
local nextMarkerId = 1

-- ═══════════════════════════════════════
-- 放置标记
-- ═══════════════════════════════════════
function Fireteam.Marker.Add(ply, pos, markerType, label)
    if not IsValid(ply) then return nil end

    local squad = Fireteam.Squad.GetPlayerSquad(ply)
    if not squad then
        ply:ChatPrint("[FIRETEAM] Join a squad to place markers.")
        return nil
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
        squadId   = squad.id,
        createdAt = CurTime(),
        expiresAt = CurTime() + Fireteam.Marker.LIFETIME
    }
    nextMarkerId = nextMarkerId + 1

    activeMarkers[marker.id] = marker

    -- 同步给同小队成员
    Fireteam.Marker.SyncToSquad(squad.id)

    return marker
end

-- ═══════════════════════════════════════
-- 移除标记
-- ═══════════════════════════════════════
function Fireteam.Marker.Remove(ply, markerId)
    local marker = activeMarkers[markerId]
    if not marker then return false end

    -- 只有放置者或队长可以移除
    local squad = Fireteam.Squad.GetPlayerSquad(ply)
    if marker.owner ~= ply and (not squad or squad.leader ~= ply) then
        return false
    end

    activeMarkers[markerId] = nil

    if squad then
        Fireteam.Marker.SyncToSquad(marker.squadId)
    end

    return true
end

-- ═══════════════════════════════════════
-- 清除过期标记（只重同步受影响的小队，避免向所有人泄露标记）
-- ═══════════════════════════════════════
timer.Create("Fireteam.Marker.Cleanup", 5, 0, function()
    local now = CurTime()
    local affected = {}
    for id, marker in pairs(activeMarkers) do
        if now > marker.expiresAt then
            affected[marker.squadId] = true
            activeMarkers[id] = nil
        end
    end
    for squadId in pairs(affected) do
        Fireteam.Marker.SyncToSquad(squadId)
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

function Fireteam.Marker.SyncToAll()
    net.Start(Fireteam.NET.MARKER_ADD)
        net.WriteTable(SerializeMarkers(activeMarkers))
    net.Broadcast()
end

-- ═══════════════════════════════════════
-- 网络请求
-- ═══════════════════════════════════════
util.AddNetworkString("FT_MarkerPlace")
net.Receive("FT_MarkerPlace", function(len, ply)
    local pos = net.ReadVector()
    local mType = net.ReadString()
    local label = net.ReadString()
    Fireteam.Marker.Add(ply, pos, mType, label)
end)

util.AddNetworkString("FT_MarkerRemove")
net.Receive("FT_MarkerRemove", function(len, ply)
    local markerId = net.ReadInt(16)
    Fireteam.Marker.Remove(ply, markerId)
end)

print("[FIRETEAM:Marker] ✓ Server logic loaded")
