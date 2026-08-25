-- modules/voice/cl_voice.lua
-- FIRETEAM Voice/Comms System - Client State

if not Fireteam then Fireteam = {} end
Fireteam.Voice = Fireteam.Voice or {}

-- 全体玩家频道缓存（服务端 VOICE_CHANNEL 广播驱动）
-- { [EntIndex] = channelId }
Fireteam.Voice.ClientChannels = Fireteam.Voice.ClientChannels or {}

net.Receive(Fireteam.NET.VOICE_CHANNEL, function()
    local ply = net.ReadEntity()
    local channelId = net.ReadString()
    if not IsValid(ply) then return end
    Fireteam.Voice.ClientChannels[ply:EntIndex()] = channelId
    hook.Run("Fireteam.Voice.ChannelChanged", ply, channelId)
end)

--- 客户端查询任意玩家的频道（缺省 squad）
function Fireteam.Voice.GetClientChannel(ply)
    if not IsValid(ply) then return "squad" end
    return Fireteam.Voice.ClientChannels[ply:EntIndex()] or "squad"
end

print("[FIRETEAM:Voice] ✓ Client state loaded")
