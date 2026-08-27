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
    hook.Run(Fireteam.HOOKS.VOICE_CHANNEL_CHANGED, ply, channelId)
end)

--- 客户端查询任意玩家的频道（缺省 squad）
function Fireteam.Voice.GetClientChannel(ply)
    if not IsValid(ply) then return "squad" end
    return Fireteam.Voice.ClientChannels[ply:EntIndex()] or "squad"
end

-- ═══════════════════════════════════════
-- 正在说话者（cl_voice_ui 通话事件驱动）
-- Speakers[EntIndex] = 失效时间（说话中远期保活，结束后 +2s 淡出窗）
-- ═══════════════════════════════════════
Fireteam.Voice.Speakers = Fireteam.Voice.Speakers or {}

--- 玩家是否正在说话（含淡出窗）：是则返回其频道 id，否则 nil
function Fireteam.Voice.GetSpeakerChannel(idx)
    local expire = Fireteam.Voice.Speakers[idx]
    if expire and expire > CurTime() then
        return Fireteam.Voice.ClientChannels[idx] or "squad"
    end
    return nil
end

--- 名牌淡出系数 0~1（说话中恒 1，结束后 2 秒线性衰减）
function Fireteam.Voice.GetSpeakerAlpha(idx)
    local expire = Fireteam.Voice.Speakers[idx]
    if not expire or expire <= CurTime() then return 0 end
    return math.Clamp((expire - CurTime()) / 2, 0, 1)
end

-- ═══════════════════════════════════════
-- 三频道切换热键（V=地区 / B=小队 / G=指挥，voice.key_* 可改绑）
-- ═══════════════════════════════════════
local keyBindings = {
    { config = "voice.key_local",   channel = "local" },
    { config = "voice.key_squad",   channel = "squad" },
    { config = "voice.key_command", channel = "command" },
}

local function ResolveKeyCode(configKey)
    local name = Fireteam.Config.Get(configKey)
    if not name or name == "" then return nil end
    return _G["KEY_" .. string.upper(name)]
end

hook.Add("PlayerButtonDown", "Fireteam.Voice.ChannelKeys", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if not Fireteam.UI.CanTogglePanel() then return end
    for _, bind in ipairs(keyBindings) do
        if ResolveKeyCode(bind.config) == button then
            net.Start(Fireteam.NET.VOICE_SWITCH_CHANNEL)
                net.WriteString(bind.channel)
            net.SendToServer()
            return
        end
    end
end)

Fireteam.Log.Info("Voice", "✓ 客户端状态已加载")
