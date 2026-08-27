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
-- 按住说话（Squad 式）
-- 命令 +ft_voice_local / +ft_voice_squad / +ft_voice_command 由
-- core/sh_keybinds.lua 注册；键位玩家自绑，不碰 vanilla 的 +voicerecord 键。
--
-- 语义：按下 → 切到该频道并代发 +voicerecord；松开 → 停止录音并回退原频道。
-- ⚠ 取舍：切频道请求与首个语音包可能同 tick 到达服务端，极端情况下首 tick
--   按旧频道分发（<1 tick 的可闻差异），换取零输入延迟。
-- ═══════════════════════════════════════
local talking = nil          -- 正在按住的 kind
local prevChannel = nil      -- 按住前的频道，松开后回退

--- 切频道请求（也供面板等其他入口复用）
function Fireteam.Voice.RequestChannel(channelId)
    if not isstring(channelId) or channelId == "" then return false end
    net.Start(Fireteam.NET.VOICE_SWITCH_CHANNEL)
        net.WriteString(channelId)
    net.SendToServer()
    return true
end

function Fireteam.Voice.BeginTalk(kind)
    if talking then return end            -- 已在说话，忽略其他频道键
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    talking = kind
    prevChannel = Fireteam.Voice.GetClientChannel(lp)
    if kind ~= prevChannel then
        Fireteam.Voice.RequestChannel(kind)
    end
    RunConsoleCommand("+voicerecord")
end

function Fireteam.Voice.EndTalk(kind)
    if talking ~= kind then return end
    RunConsoleCommand("-voicerecord")
    talking = nil

    -- 回退到按住前的频道（避免"按一次就永久改频道"）
    if prevChannel and prevChannel ~= kind then
        Fireteam.Voice.RequestChannel(prevChannel)
    end
    prevChannel = nil
end

--- 当前是否正按住某频道说话（HUD 指示器可用）
function Fireteam.Voice.GetTalkingKind()
    return talking
end

Fireteam.Log.Info("Voice", "✓ 客户端状态已加载")
