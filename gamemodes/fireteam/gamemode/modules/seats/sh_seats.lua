-- modules/seats/sh_seats.lua
-- FIRETEAM Vehicle Seats - Shared（模块入口）
-- 座位规范化 + 职业门槛查询。服务端做进入裁决，客户端只画提示。

if not Fireteam then Fireteam = {} end
Fireteam.Seats = Fireteam.Seats or {}

Fireteam.Config.Register("seats.enabled", true, {
    type = "boolean",
    desc = "Class-gated vehicle seats and interaction prompts"
})
Fireteam.Config.Register("seats.prompt_distance", 160, {
    type = "number", min = 64, max = 512,
    desc = "Max distance for the vehicle seat prompt"
})

-- 常见座位角色名（locale 键前缀 seat_role_<name>，未收录则原样显示）
function Fireteam.Seats.RoleLabel(name)
    local key = "seat_role_" .. tostring(name)
    local text = Fireteam.Locale.Get(key)
    if text ~= key then return text end
    return tostring(name)
end

--- 规范化 FTVehicleData.seats → [{index, name, allowed(set)|nil}]
--- 缺省时按 capacity 生成 司机+乘客 的通用布局
function Fireteam.Seats.Normalize(data)
    local out = {}
    if not istable(data) then return out end

    if istable(data.seats) and #data.seats > 0 then
        for i, s in ipairs(data.seats) do
            local entry = {
                index   = i,
                name    = tostring(s.role or s.name or ("seat_" .. i)),
                allowed = nil,
            }
            if istable(s.allowed_classes) then
                local set = {}
                for _, cid in ipairs(s.allowed_classes) do set[cid] = true end
                entry.allowed = set
            end
            out[i] = entry
        end
        return out
    end

    local cap = tonumber(data.capacity) or 0
    for i = 1, math.min(cap, Fireteam.SQUAD_MAX_SIZE) do
        out[i] = {
            index   = i,
            name    = (i == 1) and "driver" or "passenger",
            allowed = nil,
        }
    end
    return out
end

--- 该实体是否为可交互载具（标准车辆或已注册 FTVehicleData 的第三方基座）
function Fireteam.Seats.IsVehicleEntity(ent)
    if not IsValid(ent) then return false end
    if ent:IsVehicle() then return true end
    local cls = ent:GetClass()
    return Fireteam.VehicleInterface.Get(cls) ~= nil
end

--- 实体对应的 FTVehicleData（可能为 nil：未适配的普通车辆）
function Fireteam.Seats.GetData(ent)
    if not IsValid(ent) then return nil end
    return Fireteam.VehicleInterface.Get(ent:GetClass())
end

print("[FIRETEAM:Seats] ✓ Shared definitions loaded")
