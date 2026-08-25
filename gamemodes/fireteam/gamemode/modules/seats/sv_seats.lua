-- modules/seats/sv_seats.lua
-- FIRETEAM Vehicle Seats - Server
-- 进入裁决（职业门槛座位）、占用快照广播、车载电台授权。

local L = function(key, ...)
    return Fireteam.Locale.Get(key, ...)
end

-- ═══════════════════════════════════════
-- 占用枚举（不维护状态表，实时读引擎数据避免漂移）
-- ═══════════════════════════════════════
local function CollectSeatEntities(ent)
    local list = {}
    if ent.GetPassengerSeats then
        for _, s in ipairs(ent:GetPassengerSeats() or {}) do
            if IsValid(s) then list[#list + 1] = s end
        end
    end
    if #list == 0 then
        for _, child in ipairs(ent:GetChildren()) do
            if IsValid(child) and child:IsVehicle() and child ~= ent then
                list[#list + 1] = child
            end
        end
    end
    return list
end

--- { driver=Player|nil, seats={ [i]=Player|nil } }
function Fireteam.Seats.ServerOccupancy(ent)
    local occ = { driver = nil, seats = {} }
    local d = ent.GetDriver and ent:GetDriver()
    if IsValid(d) and d:IsPlayer() then occ.driver = d end

    for i, seatEnt in ipairs(CollectSeatEntities(ent)) do
        local sd = seatEnt.GetDriver and seatEnt:GetDriver()
        occ.seats[i] = (IsValid(sd) and sd:IsPlayer()) and sd or nil
    end
    return occ
end

--- 占用快照 → 客户端（显示名列表，轻量）
local function SnapshotPayload(ent)
    local occ = Fireteam.Seats.ServerOccupancy(ent)
    local names = {}
    for i, p in ipairs(occ.seats) do
        names[i] = IsValid(p) and p:Nick() or ""
    end
    return {
        driver   = IsValid(occ.driver) and occ.driver:Nick() or "",
        seats    = names,
    }
end

local lastSync = {}   -- vehIdx -> CurTime
local function SyncVehicle(ent)
    if not IsValid(ent) then return end
    local idx = ent:EntIndex()
    if lastSync[idx] and CurTime() - lastSync[idx] < 0.2 then return end
    lastSync[idx] = CurTime()

    Fireteam.Net.SendToAll(Fireteam.NET.SEAT_UPDATE, idx, SnapshotPayload(ent))
end

-- ═══════════════════════════════════════
-- 进入裁决：目标座位有 allowed_classes 时校验玩家职业
-- ═══════════════════════════════════════
hook.Add("CanPlayerEnterVehicle", "Fireteam.Seats.Gate", function(ply, veh, role)
    if not Fireteam.Config.Get("seats.enabled") then return end
    if ply:InVehicle() then return end

    local data = Fireteam.Seats.GetData(veh)
    if not data then return end   -- 未适配载具：不做门槛

    local layout = Fireteam.Seats.Normalize(data)
    if #layout == 0 then return end

    -- 引擎将选择的座位：role==0 司机，否则取第一个空乘客位（近似）
    local targetIdx = 1
    if role ~= 0 then
        local occ = Fireteam.Seats.ServerOccupancy(veh)
        for i = 1, math.max(#layout, #occ.seats) do
            if not occ.seats[i] then targetIdx = i + 1 break end
        end
    end

    local seatDef = layout[targetIdx] or layout[#layout]
    if not seatDef or not seatDef.allowed then return end   -- 该座位无限制

    local classId = Fireteam.Class.GetPlayerClass(ply)
    if classId and seatDef.allowed[classId] then return end -- 职业匹配放行

    -- 列出可用的职业名
    local okClasses = {}
    for cid in pairs(seatDef.allowed) do
        local cd = Fireteam.Class.Get(cid)
        okClasses[#okClasses + 1] = (cd and cd.name) or cid
    end
    ply:ChatPrint("[FIRETEAM] " .. L("seat_locked_class", table.concat(okClasses, ", ")))
    return false
end)

-- ═══════════════════════════════════════
-- 进出事件：占用同步 + 车载电台提示/授权
-- ═══════════════════════════════════════
hook.Add("PlayerEnteredVehicle", "Fireteam.Seats.Entered", function(ply, veh, role)
    if not Fireteam.Seats.IsVehicleEntity(veh) then return end

    hook.Run(Fireteam.HOOKS.PLAYER_ENTER_VEHICLE, ply, veh, role)
    SyncVehicle(veh)

    -- 车载电台：乘员自动获得 vehicle.radioChannels 的使用权，并提示
    local data = Fireteam.Seats.GetData(veh)
    if data and istable(data.radioChannels) and #data.radioChannels > 0 then
        ply:ChatPrint("[FIRETEAM] "
            .. L("seat_radio_hint", table.concat(data.radioChannels, ", ")))
    end
end)

hook.Add("PlayerLeftVehicle", "Fireteam.Seats.Left", function(ply, veh)
    if not IsValid(veh) then return end
    if not Fireteam.Seats.IsVehicleEntity(veh) then return end

    hook.Run(Fireteam.HOOKS.PLAYER_EXIT_VEHICLE, ply, veh)
    timer.Simple(0.05, function() SyncVehicle(veh) end)
end)

--- 载具乘员豁免频道的职业 access 限制（仅限载具声明的 radioChannels）
hook.Add("Fireteam.Voice.CanAccessChannel", "Fireteam.Seats.VehicleRadio", function(ply, channelId)
    local veh = ply.InVehicle and ply:GetVehicle()
    if not IsValid(veh) then return false end

    local data = Fireteam.Seats.GetData(veh)
    if data and istable(data.radioChannels)
        and table.HasValue(data.radioChannels, channelId) then
        return true
    end
    return false
end)

Fireteam.Log.Info("座位", "✓ 座位交互服务端已加载")
