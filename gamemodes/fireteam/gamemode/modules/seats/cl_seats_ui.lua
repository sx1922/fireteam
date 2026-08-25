-- modules/seats/cl_seats_ui.lua
-- FIRETEAM Vehicle Seats - Client HUD
-- 准星载具识别 → 座位布局提示条；乘员状态下车内布局常显。

local kit = Fireteam.UI
local L = function(key, ...)
    return Fireteam.Locale and Fireteam.Locale.Get(key, ...) or key
end

-- 服务端占用快照 { [vehIdx] = { driver=nick, seats={names} } }
local occupancy = {}

net.Receive(Fireteam.NET.SEAT_UPDATE, function()
    -- 服务端经 Fireteam.Net.SendToAll 写入（数字走 WriteDouble）
    local idx = math.Round(net.ReadDouble())
    local snap = net.ReadTable()
    if not istable(snap) then return end
    occupancy[idx] = snap
end)

--- 准星射线找载具（含第三方基座实体）
local function TraceVehicle()
    local me = LocalPlayer()
    if not IsValid(me) then return nil end

    local maxDist = Fireteam.Config.Get("seats.prompt_distance") or 160
    local tr = util.TraceLine({
        start  = me:GetShootPos(),
        endpos = me:GetShootPos() + me:GetAimVector() * maxDist,
        filter = me,
    })
    local ent = tr.Entity
    if IsValid(ent) and Fireteam.Seats.IsVehicleEntity(ent) then
        return ent
    end

    -- 射线没打中时做一次近距离球形兜底（载具体积大、准星易扫空）
    for _, v in ipairs(ents.GetAll()) do
        if Fireteam.Seats.IsVehicleEntity(v)
            and v:GetPos():DistToSqr(me:GetPos()) < (maxDist * 1.2) ^ 2 then
            -- 只取视线方向 ±45° 内的最近者
            local dir = (v:GetPos() - me:GetShootPos()):GetNormalized()
            if dir:Dot(me:GetAimVector()) > 0.7 then return v end
            break
        end
    end
    return nil
end

--- 布局行：把规范化座位与占用快照拼成 chips 数据
--- （GetDriver 为服务端专用，客户端一律以快照为准）
local function BuildChips(veh, data)
    local layout = data and Fireteam.Seats.Normalize(data) or {}
    local snap = occupancy[veh:EntIndex()] or {}

    local myClassId = Fireteam.Class.GetPlayerClass(LocalPlayer())

    local chips = {}
    local total = math.max(#layout,
        snap.seats and #snap.seats or 0,
        (snap.driver and snap.driver ~= "") and 1 or 0)

    for i = 1, total do
        local def = layout[i]
        local name = def and def.name or ((i == 1) and "driver" or "passenger")
        local occupant
        if i == 1 then
            occupant = (snap.driver and snap.driver ~= "") and snap.driver or nil
        else
            local p = snap.seats and snap.seats[i - 1]
            occupant = (p and p ~= "") and p or nil
        end

        local locked = def and def.allowed ~= nil
        local lockedOk = false
        if locked and myClassId then
            lockedOk = def.allowed[myClassId] == true
        end

        chips[#chips + 1] = {
            name     = Fireteam.Seats.RoleLabel(name),
            occupant = occupant,
            locked   = locked,
            lockedOk = lockedOk,
        }
    end
    return chips
end

local function DrawSeatStrip(x, y, w, chips, scale)
    local rowH = math.Round(20 * scale)
    local cx = x + 12 * scale

    kit.DrawPanel(x, y, w, rowH * #chips + 10 * scale, { fillAlpha = 190 })

    for i, chip in ipairs(chips) do
        local cy = y + 5 * scale + (i - 1) * rowH + rowH / 2

        local dotColor = "text_muted"
        if isstring(chip.occupant) then
            dotColor = "success"
        elseif chip.locked then
            dotColor = chip.lockedOk and "warning" or "danger"
        end

        surface.SetDrawColor(kit.Color(dotColor))
        -- 状态圆点（方形近似）
        surface.DrawRect(cx, cy - 3 * scale, 6 * scale, 6 * scale)

        local label = chip.name
        local labelColor = isstring(chip.occupant) and "text" or "text_muted"
        draw.SimpleText(label, kit.Font("small"), cx + 12 * scale, cy,
            kit.Color(labelColor), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if isstring(chip.occupant) then
            draw.SimpleText(chip.occupant, kit.Font("small"),
                x + w - 12 * scale, cy,
                kit.Color("primary"), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        elseif chip.locked then
            draw.SimpleText(chip.lockedOk and "✓" or "🔒", kit.Font("small"),
                x + w - 12 * scale, cy,
                kit.Color(chip.lockedOk and "warning" or "danger"),
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
end

hook.Add("HUDPaint", "Fireteam.Seats.Prompt", function()
    if not Fireteam.Config.Get("seats.enabled") then return end
    local me = LocalPlayer()
    if not IsValid(me) then return end

    local scale = ScrH() / 1080

    -- ══ 乘员视角：常显本车布局 ══
    if me.InVehicle() and me:GetVehicle() then
        local veh = me:GetVehicle()
        -- 乘员坐在子座上时定位主载具
        local parent = veh
        if IsValid(veh:GetParent()) and Fireteam.Seats.IsVehicleEntity(veh:GetParent()) then
            parent = veh:GetParent()
        end

        local data = Fireteam.Seats.GetData(parent)
        local chips = BuildChips(parent, data)

        local w = math.Round(240 * scale)
        local h = math.Round(20 * scale) * #chips + math.Round(46 * scale)
        local x, y = kit.ResolveAnchor(
            kit.GetElement("vehicle_seats").position or "right", w, h)

        kit.DrawPanel(x, y, w, h, { fillAlpha = 190 })
        draw.SimpleText(data and data.displayName or L("seat_generic_name"),
            kit.Font("small"), x + w / 2, y + 14 * scale,
            kit.Color("text"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        DrawSeatStrip(x, y + 26 * scale, w, chips, scale)
        draw.SimpleText(L("seat_exit_hint"), kit.Font("small"),
            x + w / 2, y + h - 11 * scale,
            kit.Color("warning"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    -- ══ 步兵视角：准星指向载具时的上车提示 ══
    local veh = TraceVehicle()
    if not IsValid(veh) then return end

    local data = Fireteam.Seats.GetData(veh)
    local occ = occupancy[veh:EntIndex()]
    local filled = 0
    if occ then
        if occ.driver and occ.driver ~= "" then filled = filled + 1 end
        for _, n in ipairs(occ.seats or {}) do
            if n and n ~= "" then filled = filled + 1 end
        end
    else
        -- 无快照（刚进服未同步）时按 0 占用显示
    end
    local cap = data and math.max(#Fireteam.Seats.Normalize(data), 1) or 2

    local title = data and data.displayName or L("seat_generic_name")
    local hint = L("seat_enter_hint", title, filled, cap)

    surface.SetFont(kit.Font("body"))
    local tw = surface.GetTextSize(hint)
    local w = math.max(math.Round(320 * scale), tw + 48 * scale)
    local h = math.Round(34 * scale)
    local x, y = ScrW() / 2 - w / 2, ScrH() * 0.62

    kit.DrawPanel(x, y, w, h, { fillAlpha = 200 })
    draw.SimpleText("[E] ", kit.Font("body"), x + 12 * scale, y + h / 2,
        kit.Color("primary"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(hint, kit.Font("body"), x + 40 * scale, y + h / 2,
        kit.Color("text"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- 有布局数据时附带座位一览
    if data and #Fireteam.Seats.Normalize(data) > 0 then
        local chips = BuildChips(veh, data)
        DrawSeatStrip(x, y - math.Round(20 * scale) * #chips - 16 * scale, w, chips, scale)
    end
end)
