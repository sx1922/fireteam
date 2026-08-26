-- modules/voice/sh_voice.lua
-- FIRETEAM Voice/Comms System - Shared

if not Fireteam then Fireteam = {} end
Fireteam.Voice = Fireteam.Voice or {}

-- 电台氛围音总开关（咔嗒声/静噪底声；客户端渲染，服务端可统一关停）
Fireteam.Config.Register("voice.ambience", true, {
    type = "boolean",
    desc = "Radio squelch clicks and static bed"
})

-- 三频道切换键（客户端热键；与引擎默认语音键冲突时在此改绑）
Fireteam.Config.Register("voice.key_local", "V", {
    type = "string",
    desc = "Local proximity voice hotkey"
})
Fireteam.Config.Register("voice.key_squad", "B", {
    type = "string",
    desc = "Squad radio hotkey"
})
Fireteam.Config.Register("voice.key_command", "G", {
    type = "string",
    desc = "Command radio hotkey"
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

-- 内置兜底频道（设定包未声明时的地区频道；kind 决定收听分流语义）
Fireteam.Voice.BUILTIN_CHANNELS = {
    ["local"] = {
        name = "Local", name_zh = "地区频道",
        kind = "local", access = "all", interference = false
    }
}

-- 获取频道定义（设定包优先，local 内置兜底）
function Fireteam.Voice.GetChannel(channelId)
    local presets = Fireteam.Voice.GetPresets()
    if presets.channels and presets.channels[channelId] then
        return presets.channels[channelId]
    end
    return Fireteam.Voice.BUILTIN_CHANNELS[channelId]
end

--- 频道收听语义：local 距离人声 / squad 小队网 / command 指挥网 / all 全服
--- （未声明 kind 的旧包按频道 id 推断，向后兼容）
function Fireteam.Voice.GetChannelKind(channelId)
    local ch = Fireteam.Voice.GetChannel(channelId)
    if ch and ch.kind then return ch.kind end
    if channelId == "local" then return "local" end
    if channelId == "command" then return "command" end
    if channelId == "emergency" then return "all" end
    return "squad"
end

print("[FIRETEAM:Voice] ✓ 共享定义已加载")
