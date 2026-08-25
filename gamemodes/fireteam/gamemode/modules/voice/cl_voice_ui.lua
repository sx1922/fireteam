-- modules/voice/cl_voice_ui.lua
-- FIRETEAM Voice Ambience + Radio Indicator - Client
-- 能力边界（决策 D4）：引擎不向 Lua 暴露原始语音流，本文件只做氛围呈现——
-- 通话起止的电台咔嗒声、频道内有人讲话时的静噪底声、按距离/遮挡调制的干扰音量。

local kit = Fireteam.UI

-- ═══════════════════════════════════════
-- 音效注册（素材由 gamemode content/ 提供，零外部依赖）
-- ═══════════════════════════════════════
sound.Add({
    name = "Fireteam.Voice.SquelchOn", channel = CHAN_STATIC,
    volume = 0.55, level = 60, pitch = 100, sound = "fireteam/voice/squelch_on.wav"
})
sound.Add({
    name = "Fireteam.Voice.SquelchOff", channel = CHAN_STATIC,
    volume = 0.45, level = 60, pitch = 100, sound = "fireteam/voice/squelch_off.wav"
})

local staticChannel = nil     -- IGModAudioChannel 静噪底声
local staticVolume  = 0       -- 当前平滑音量
local bedFailed     = false   -- 资源缺失时静默降级
local transmitters  = {}      -- [EntIndex] = Player（正在收听的人）
local selfTalking   = false

local function AmbienceOn()
    return Fireteam.Config.Get("voice.ambience") ~= false
end

-- ═══════════════════════════════════════
-- 可听性近似（镜像服务端 PlayerCanHear 规则）
-- ═══════════════════════════════════════
local function IsAudible(talker)
    local me = LocalPlayer()
    if not IsValid(me) or not IsValid(talker) or talker == me then return false end

    local dist = me:GetPos():Distance(talker:GetPos())

    if Fireteam.Squad.AreInSameSquad(me, talker) then
        local chDef = Fireteam.Voice.GetChannel(Fireteam.Voice.GetClientChannel(talker))
        local maxRange = chDef and chDef.range or 500
        return dist <= maxRange
    end

    return dist <= 300
end

-- ═══════════════════════════════════════
-- 干扰系数 0~1：距离占比 + 地形遮挡惩罚
-- ═══════════════════════════════════════
local function InterferenceFactor(talker)
    local me = LocalPlayer()
    if not IsValid(me) then return 0 end

    local refMax = Fireteam.Config.Get("voice.distance_max") or 800
    local dist = me:GetPos():Distance(talker:GetPos())
    local factor = math.Clamp(dist / math.max(refMax, 1), 0, 1) * 0.6

    local chDef = Fireteam.Voice.GetChannel(Fireteam.Voice.GetClientChannel(talker))
    if Fireteam.Config.Get("voice.interference")
        and chDef and chDef.interference ~= false then
        local tr = util.TraceLine({
            start  = me:EyePos(),
            endpos = talker:EyePos(),
            filter = { me, talker },
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if tr.Hit then factor = factor + 0.35 end
    end

    return math.Clamp(factor, 0, 1)
end

--- 静噪床目标音量：取所有在听者的最大干扰；有人但很近也保留最低底噪
local function BedTargetVolume()
    if not AmbienceOn() then return 0 end

    -- 设定包 effects.radio_static == false 时整段关停
    local presets = Fireteam.Voice.GetPresets()
    if presets.effects and presets.effects.radio_static == false then return 0 end

    local worst = 0
    for _, ply in pairs(transmitters) do
        if IsValid(ply) then
            worst = math.max(worst, InterferenceFactor(ply))
        else
            worst = math.max(worst, 0.15)
        end
    end
    if next(transmitters) and worst < 0.15 then worst = 0.15 end
    return worst
end

local function EnsureBed()
    if staticChannel and staticChannel:IsValid() then return true end
    if bedFailed then return false end

    sound.PlayFile("sound/fireteam/voice/static_loop.wav", "noplay noblock", function(ch, err)
        if not IsValid(ch) or err then
            bedFailed = true
            Fireteam.Log.Warn("语音", "静噪音频加载失败，氛围音降级：" .. tostring(err))
            return
        end
        ch:SetLooping(true)
        ch:SetVolume(0)
        staticChannel = ch
    end)
    return false
end

-- ═══════════════════════════════════════
-- 主循环：底声平滑启停
-- ═══════════════════════════════════════
hook.Add("Think", "Fireteam.Voice.StaticBed", function()
    local target = BedTargetVolume()

    if target > 0 and EnsureBed() then
        staticVolume = Lerp(FrameTime() * 6, staticVolume, target * 0.5)
        if not staticChannel:IsPlaying() then staticChannel:Play() end
        staticChannel:SetVolume(staticVolume)
    elseif staticChannel and staticChannel:IsValid() and staticVolume > 0.005 then
        -- 收尾淡出后挂起
        staticVolume = Lerp(FrameTime() * 6, staticVolume, 0)
        staticChannel:SetVolume(staticVolume)
        if staticVolume <= 0.005 then staticChannel:Pause() end
    elseif staticChannel and staticChannel:IsValid() and staticVolume <= 0.005 then
        staticChannel:Pause()
    end
end)

-- ═══════════════════════════════════════
-- 通话事件 → 咔嗒声 + 收听名单
-- ═══════════════════════════════════════
hook.Add("PlayerStartedVoice", "Fireteam.Voice.TxStart", function(ply)
    if not AmbienceOn() then return end
    if not IsValid(ply) then return end

    if ply == LocalPlayer() then
        selfTalking = true
        LocalPlayer():EmitSound("Fireteam.Voice.SquelchOn")
        return
    end

    if IsAudible(ply) then
        transmitters[ply:EntIndex()] = ply
        LocalPlayer():EmitSound("Fireteam.Voice.SquelchOn")
    end
end)

hook.Add("PlayerEndedVoice", "Fireteam.Voice.TxEnd", function(ply)
    if not IsValid(ply) then return end

    if ply == LocalPlayer() then
        selfTalking = false
        if AmbienceOn() then LocalPlayer():EmitSound("Fireteam.Voice.SquelchOff") end
        return
    end

    if transmitters[ply:EntIndex()] then
        transmitters[ply:EntIndex()] = nil
        if AmbienceOn() then LocalPlayer():EmitSound("Fireteam.Voice.SquelchOff") end
    end
end)

hook.Add("PlayerDisconnected", "Fireteam.Voice.RxCleanup", function(ply)
    transmitters[ply:EntIndex()] = nil
end)

-- ═══════════════════════════════════════
-- 电台指示器（elements.radio_indicator，主题驱动显隐）
-- ═══════════════════════════════════════
--- 由频道 ID 推导稳定的伪频率显示（纯装饰）
local function FakeFrequency(channelId)
    local h = 0
    for i = 1, #channelId do h = (h * 31 + channelId:byte(i)) % 400 end
    return string.format("%.1f MHz", 30 + h / 10)
end

hook.Add("HUDPaint", "Fireteam.Voice.RadioIndicator", function()
    -- 主题未定义该元素则不渲染（换包即换皮的可见性语义）
    local elem = kit.GetElement("radio_indicator")
    if not elem or elem.visible == false or next(elem) == nil then return end

    local me = LocalPlayer()
    if not IsValid(me) then return end

    local scale = ScrH() / 1080
    local w = math.Round(230 * scale)
    local h = math.Round(56 * scale)
    local x, y = kit.ResolveAnchor(elem.position or "bottom_left", w, h)

    kit.DrawPanel(x, y, w, h, { fillAlpha = 190 })

    local channelId = Fireteam.Voice.GetClientChannel(me)
    local chDef = Fireteam.Voice.GetChannel(channelId)
    local label = chDef and chDef.name or channelId

    -- 行 1：频道名 + 伪频率
    draw.SimpleText(label, kit.Font("small"), x + 10 * scale, y + 14 * scale,
        kit.Color("text"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(FakeFrequency(channelId), kit.Font("small"),
        x + w - 10 * scale, y + 14 * scale,
        kit.Color("text_muted"), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- 刻度装饰线（frequency_dial 风格）
    surface.SetDrawColor(kit.ColorA("border", 200))
    for i = 0, 8 do
        local tx = x + 12 * scale + i * (w - 24 * scale) / 8
        surface.DrawRect(tx, y + 28 * scale, 1, (i % 4 == 0) and 8 * scale or 4 * scale)
    end

    -- 行 2：TX / RX 状态
    local rxCount = 0
    for _ in pairs(transmitters) do rxCount = rxCount + 1 end

    local statusColor = kit.Color("text_muted")
    local statusText = L("voice_status_idle")
    local blink = math.sin(CurTime() * 6) > 0

    if selfTalking then
        statusColor = blink and kit.Color("danger") or kit.ColorA("danger", 120)
        statusText = L("voice_status_tx")
    elseif rxCount > 0 then
        statusColor = kit.Color("primary")
        statusText = L("voice_status_rx", rxCount)
    end

    draw.SimpleText(statusText, kit.Font("small"), x + w / 2, y + h - 11 * scale,
        statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
