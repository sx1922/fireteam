-- modules/voice/sv_voice.lua
-- FIRETEAM Voice/Comms System - Server Logic

if not Fireteam then Fireteam = {} end
Fireteam.Voice = Fireteam.Voice or {}

-- 玩家当前频道
local playerChannels = {}  -- [Player] = channelId

-- ═══════════════════════════════════════
-- 切换频道
-- ═══════════════════════════════════════
function Fireteam.Voice.SetChannel(ply, channelId)
    if not IsValid(ply) then return false end

    local channel = Fireteam.Voice.GetChannel(channelId)
    if not channel then
        ply:ChatPrint("[FIRETEAM] Unknown channel: " .. tostring(channelId))
        return false
    end

    -- 检查访问权限（access 为职业 ID 列表或 "all"）
    if channel.access and channel.access ~= "all" then
        local classId = Fireteam.Class.GetPlayerClass(ply)
        if type(channel.access) == "table" then
            if not classId or not table.HasValue(channel.access, classId) then
                -- 扩展点：其他模块可授权（座位模块用它放行车载电台）
                if not hook.Run("Fireteam.Voice.CanAccessChannel", ply, channelId) then
                    ply:ChatPrint("[FIRETEAM] You don't have access to channel: " .. (channel.name or channelId))
                    return false
                end
            end
        end
    end

    playerChannels[ply] = channelId

    net.Start(Fireteam.NET.VOICE_CHANNEL)
        net.WriteEntity(ply)
        net.WriteString(channelId)
    net.Broadcast()

    ply:ChatPrint("[FIRETEAM] Switched to channel: " .. (channel.name or channelId))
    return true
end

-- ═══════════════════════════════════════
-- 获取玩家频道
-- ═══════════════════════════════════════
function Fireteam.Voice.GetPlayerChannel(ply)
    return playerChannels[ply] or "squad"
end

-- ═══════════════════════════════════════
-- 语音拦截（距离/干扰）
-- ═══════════════════════════════════════
hook.Add("PlayerCanHearPlayersVoice", "Fireteam.Voice.DistanceCheck", function(listener, talker)
    if listener == talker then return true end

    -- 同小队不受距离限制（无线电，受频道范围约束）
    if Fireteam.Squad.AreInSameSquad(listener, talker) then
        local channel = Fireteam.Voice.GetPlayerChannel(talker)
        local channelDef = Fireteam.Voice.GetChannel(channel)
        local maxRange = channelDef and channelDef.range or 500

        local dist = listener:GetPos():Distance(talker:GetPos())
        if dist > maxRange then
            return false, false
        end
        return true, false  -- 听到但不 3D
    end

    -- 非同小队：仅近距离直接通话
    local directRange = 300
    local dist = listener:GetPos():Distance(talker:GetPos())
    if dist > directRange then
        return false, false
    end

    return true, true  -- 3D 语音
end)

-- ═══════════════════════════════════════
-- 网络请求（消息名统一注册于 Fireteam.NET）
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.VOICE_SWITCH_CHANNEL, function(len, ply)
    local channelId = net.ReadString()
    Fireteam.Voice.SetChannel(ply, channelId)
end)

-- 玩家离开清理
hook.Add("PlayerDisconnected", "Fireteam.Voice.Cleanup", function(ply)
    playerChannels[ply] = nil
end)

print("[FIRETEAM:Voice] ✓ Server logic loaded")
