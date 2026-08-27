-- modules/commander/cl_commander.lua
-- FIRETEAM Commander System - Client
-- 接收 FT_CommanderUpdate 全量快照写入缓存；
-- 面板/HUD 经 GetClientState / GetCachedFactionCommander 消费。
-- 快照携带的是"剩余秒数"，落地换算为绝对到期时间便于本地倒计时。

if not Fireteam then Fireteam = {} end
Fireteam.Commander = Fireteam.Commander or {}

local clientState = {}   -- [faction] = { cmdIdx, voting, expiresAt, candidates = {idx,...} }
local lastRecvAt = 0

net.Receive(Fireteam.NET.COMMANDER_UPDATE, function()
    local out = {}
    local factionCount = net.ReadUInt(5)
    for _ = 1, factionCount do
        local faction = net.ReadString()
        local cmdIdx = net.ReadUInt(8)
        local voting = net.ReadBool()

        local entry = { cmdIdx = cmdIdx, voting = false, candidates = {} }
        if voting then
            local remainSecs = net.ReadFloat()
            local candCount = net.ReadUInt(5)
            for i = 1, candCount do
                entry.candidates[i] = net.ReadUInt(8)
            end
            entry.voting = true
            entry.expiresAt = CurTime() + remainSecs
        end
        out[faction] = entry
    end

    clientState = out
    lastRecvAt = CurTime()

    -- 小队管理面板开着则重建（内部自带节流）
    if Fireteam.Squad and Fireteam.Squad.RebuildPanelSoon then
        Fireteam.Squad.RebuildPanelSoon()
    end
end)

--- 全量缓存 { [faction] = { cmdIdx, voting, expiresAt, candidates } }
function Fireteam.Commander.GetClientState()
    return clientState
end

--- 本阵营指挥官 EntIndex；空位返回 nil
function Fireteam.Commander.GetCachedFactionCommander(faction)
    local s = faction and clientState[faction] or nil
    if s and s.cmdIdx and s.cmdIdx ~= 0 then return s.cmdIdx end
    return nil
end

--- 本地倒计时剩余秒（含网络快照间插值）；无选举返回 0
function Fireteam.Commander.GetElectionSecondsLeft(faction)
    local s = faction and clientState[faction] or nil
    if not (s and s.voting) then return 0 end
    return math.max(0, (s.expiresAt or 0) - CurTime())
end

Fireteam.Log.Info("Commander", "✓ 客户端已加载")
