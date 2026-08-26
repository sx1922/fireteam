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

net.Receive(Fireteam.NET.VITALS_UPDATE, function()
    Fireteam.Vitals.Client = net.ReadTable() or {}
    Fireteam.Vitals.ReceivedAt = CurTime()
    hook.Run("Fireteam.Vitals.ClientUpdated")
end)

print("[FIRETEAM:Vitals] ✓ Client data loaded")
