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
                if not hook.Run(Fireteam.HOOKS.VOICE_CAN_ACCESS_CHANNEL, ply, channelId) then
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
-- 语音拦截（按说话者频道 kind 分流）
-- ═══════════════════════════════════════
hook.Add("PlayerCanHearPlayersVoice", "Fireteam.Voice.DistanceCheck", function(listener, talker)
    if listener == talker then return end

    local channelId = Fireteam.Voice.GetPlayerChannel(talker)
    local channelDef = Fireteam.Voice.GetChannel(channelId)
    local kind = Fireteam.Voice.GetChannelKind(channelId)
    local dist = listener:GetPos():Distance(talker:GetPos())

    -- 地区频道：距离内全员可听，3D 人声
    if kind == "local" then
        local maxRange = channelDef and tonumber(channelDef.range)
            or Fireteam.Config.Get("voice.distance_max") or 800
        if dist > maxRange then return false, false end
        return true, true
    end

    -- 无线电类频道：先按语义筛收听者
    if kind == "squad" then
        -- 小队网：仅本小队成员
        if not Fireteam.Squad.AreInSameSquad(listener, talker) then return false, false end
    elseif kind == "command" then
        -- 指挥网：同阵营（发言权限已由 SetChannel 把关）
        local lf = Fireteam.Rounds.GetPlayerFaction(listener)
        local tf = Fireteam.Rounds.GetPlayerFaction(talker)
        if not lf or lf ~= tf then return false, false end
    end
    -- kind == "all"（emergency）：全服可收

    local maxRange = channelDef and tonumber(channelDef.range) or 500
    if maxRange <= 0 then maxRange = math.huge end
    if dist > maxRange then return false, false end

    return true, false  -- 电台声不做 3D
end)

-- ═══════════════════════════════════════
-- 网络请求（消息名统一注册于 Fireteam.NET）
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.VOICE_SWITCH_CHANNEL, function(len, ply)
    -- C→S 输入校验：截断超长频道 id
    local channelId = string.sub(net.ReadString(), 1, 32)
    Fireteam.Voice.SetChannel(ply, channelId)
end)

-- 玩家离开清理
hook.Add("PlayerDisconnected", "Fireteam.Voice.Cleanup", function(ply)
    playerChannels[ply] = nil
end)

print("[FIRETEAM:Voice] ✓ 服务端逻辑已加载")
