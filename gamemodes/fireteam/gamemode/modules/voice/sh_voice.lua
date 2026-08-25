-- modules/voice/sh_voice.lua
-- FIRETEAM Voice/Comms System - Shared

if not Fireteam then Fireteam = {} end
Fireteam.Voice = Fireteam.Voice or {}

-- 电台氛围音总开关（咔嗒声/静噪底声；客户端渲染，服务端可统一关停）
Fireteam.Config.Register("voice.ambience", true, {
    type = "boolean",
    desc = "Radio squelch clicks and static bed"
})

-- 频道状态
Fireteam.Voice.STATE = {
    IDLE        = "idle",
    TRANSMITTING = "transmitting",
    RECEIVING   = "receiving",
    BLOCKED     = "blocked"
}

-- 获取当前通讯模型
function Fireteam.Voice.GetModel()
    return Fireteam.Config.Get("voice.model") or Fireteam.VOICE_MODEL.ANALOG_RADIO
end

-- 获取语音预设（来自设定包）
function Fireteam.Voice.GetPresets()
    return Fireteam.Setting.GetData("voice_presets") or {}
end

-- 获取频道定义
function Fireteam.Voice.GetChannel(channelId)
    local presets = Fireteam.Voice.GetPresets()
    if presets.channels and presets.channels[channelId] then
        return presets.channels[channelId]
    end
    return nil
end

print("[FIRETEAM:Voice] ✓ Shared definitions loaded")
