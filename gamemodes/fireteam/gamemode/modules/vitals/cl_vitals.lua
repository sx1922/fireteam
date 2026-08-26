-- modules/vitals/cl_vitals.lua
-- FIRETEAM Vitals System - Client Data
-- 接收全员体征快照；倒计时按收到时刻本地外推。

if not Fireteam then Fireteam = {} end
Fireteam.Vitals = Fireteam.Vitals or {}

Fireteam.Vitals.Client = {}          -- { [entIndex] = entry }
Fireteam.Vitals.ReceivedAt = 0

--- 本地玩家条目（无则 nil）
function Fireteam.Vitals.GetSelf()
    local lp = LocalPlayer()
    if not IsValid(lp) then return nil end
    return Fireteam.Vitals.Client[lp:EntIndex()]
end

--- 剩余失血过世秒数（本地外推；非倒地返回 nil）
function Fireteam.Vitals.SelfRemain()
    local self_ = Fireteam.Vitals.GetSelf()
    if not (self_ and self_.state == "downed" and self_.remain) then return nil end
    return math.max(self_.remain - (CurTime() - Fireteam.Vitals.ReceivedAt), 0)
end

-- 手写字段反序列化（与 sv_vitals.BroadcastAll 严格配对）
net.Receive(Fireteam.NET.VITALS_UPDATE, function()
    local STATE_NAME = { [0] = "normal", [1] = "downed", [2] = "dead" }
    local LIMB_ORDER = Fireteam.Vitals.LIMB_ORDER or {}
    local now = CurTime()
    local out = {}

    local count = net.ReadUInt(6)
    for _ = 1, count do
        local idx = net.ReadUInt(8)
        local entry = {
            idx        = idx,
            state      = STATE_NAME[net.ReadUInt(2)] or "normal",
            bleed      = net.ReadUInt(4),
            stabilized = net.ReadBool(),
        }

        local v = net.ReadVector()
        entry.pos = { x = math.floor(v.x), y = math.floor(v.y), z = math.floor(v.z) }

        if net.ReadBool() then
            entry.remain = net.ReadUInt(10)
        end

        if net.ReadBool() then
            local limbs = {}
            for _, part in ipairs(LIMB_ORDER) do
                limbs[part] = net.ReadUInt(7)
            end
            entry.limbs = limbs
            local mask = net.ReadUInt(7)
            local fractures = {}
            for i, part in ipairs(LIMB_ORDER) do
                if bit.band(mask, bit.lshift(1, i - 1)) ~= 0 then fractures[part] = true end
            end
            entry.fractures = fractures
            entry.pain = net.ReadBool()
        end

        if net.ReadBool() then
            entry.stam = net.ReadUInt(10)
            entry.stamMax = net.ReadUInt(10)
        end

        if net.ReadBool() then
            entry.reviving = {
                tgtIdx = net.ReadUInt(8),
                kind   = net.ReadBool() and "revive" or "stabilize",
                ends   = now + net.ReadUInt(10) / 10,
            }
        end

        out[idx] = entry
    end

    Fireteam.Vitals.Client = out
    Fireteam.Vitals.ReceivedAt = now
    hook.Run("Fireteam.Vitals.ClientUpdated")
end)

print("[FIRETEAM:Vitals] ✓ 客户端数据已加载")
