-- modules/rounds/cl_rounds_ui.lua
-- FIRETEAM Rounds Framework - Client HUD
-- 顶部状态横幅（状态名 + 倒计时 + 目标进度）与 ENDED 结算屏，全部走 UI Kit。

local L = function(key, ...)
    return Fireteam.Locale and Fireteam.Locale.Get(key, ...) or key
end

local STATE_LABEL = {
    warmup       = "round_warmup",
    briefing     = "round_briefing",
    active       = "round_active",
    ended        = "round_ended",
    intermission = "round_intermission",
}

--- 阵营显示名（跟随语言偏好）
local function FactionDisplayName(factionId)
    local facs = Fireteam.Setting and Fireteam.Setting.GetData("factions") or {}
    local f = facs[factionId]
    if not istable(f) then return factionId end
    local cv = GetConVar("gmod_language")
    local lang = cv and cv:GetString() or "en"
    if lang:sub(1, 2) == "zh" and f.name_zh then return f.name_zh end
    return f.name or factionId
end

local function FormatTime(secs)
    secs = math.max(0, math.floor(secs))
    return string.format("%02d:%02d", math.floor(secs / 60), secs % 60)
end

-- ═══════════════════════════════════════
-- 绘制：顶部横幅
-- ═══════════════════════════════════════
local function DrawBanner(c)
    local scale = ScrH() / 1080
    local w = math.Round(420 * scale)
    local x = math.Round(ScrW() / 2 - w / 2)
    local y = math.Round(8 * scale)

    local stateKey = STATE_LABEL[c.state]
    if not stateKey then return end

    -- 底板高度按内容动态：状态行 + 计时行 (+ 目标两行)
    local h = math.Round(58 * scale)
    local obj = c.objective
    if c.state == "active" and obj then h = math.Round(92 * scale) end

    Fireteam.UI.DrawPanel(x, y, w, h, { fillAlpha = 180 })

    local cx = x + w / 2
    local cy = y + math.Round(16 * scale)

    -- 状态名 + 剧本名 + 回合号
    local title = L(stateKey)
    local scn = Fireteam.Rounds.GetScenarioName()
    if scn then title = scn .. " · " .. title end
    if c.round > 0 then
        title = string.format("%s · #%d", title, c.round)
    end
    draw.SimpleText(title, Fireteam.UI.Font("medium"), cx, cy,
        Fireteam.UI.Color("text"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cy = cy + math.Round(24 * scale)

    -- 倒计时（等宽字体）
    local remain = FormatTime(math.max(0, c.endTime - CurTime()))
    local timeColor = "text"
    if c.state == "active" then
        timeColor = (c.endTime - CurTime() < 30) and "danger" or "primary"
    end
    draw.SimpleText(remain, Fireteam.UI.Font("num"), cx, cy,
        Fireteam.UI.Color(timeColor), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- 目标行 + 进度条（仅 ACTIVE）
    if c.state == "active" and obj then
        local label = L(obj.label ~= "" and obj.label or "objective_unknown")
        local objName = obj.name
        local cv = GetConVar("gmod_language")
        if cv and cv:GetString():sub(1, 2) == "zh" and obj.name_zh and obj.name_zh ~= "" then
            objName = obj.name_zh
        end
        if objName and objName ~= "" then label = label .. " — " .. objName end
        draw.SimpleText(label, Fireteam.UI.Font("small"), cx, y + h - math.Round(30 * scale),
            Fireteam.UI.Color("warning"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        Fireteam.UI.DrawProgressBar(
            x + math.Round(20 * scale), y + h - math.Round(16 * scale),
            w - math.Round(40 * scale), math.Round(7 * scale),
            tonumber(obj.progress) or 0, "marker_objective")
    end
end

-- ═══════════════════════════════════════
-- 绘制：结算屏
-- ═══════════════════════════════════════
local function DrawSummary(c)
    local scale = ScrH() / 1080
    local w = math.Round(460 * scale)
    local rowH = math.Round(26 * scale)
    local h = math.Round(150 * scale) + rowH * table.Count(c.scores or {})
    local x = math.Round(ScrW() / 2 - w / 2)
    local y = math.Round(ScrH() * 0.28)

    Fireteam.UI.DrawPanel(x, y, w, h, { fillAlpha = 220 })

    local cx = x + w / 2
    local cy = y + math.Round(34 * scale)

    -- 胜负标题（相对己方阵营着色）
    local myFaction = Fireteam.Rounds.GetMyFaction()
    local headline, colorName
    if c.winner == nil then
        headline, colorName = L("round_draw"), "text_muted"
    elseif c.winner == myFaction then
        headline, colorName = L("round_victory"), "success"
    else
        headline, colorName = L("round_defeat"), "danger"
    end
    if c.winner then
        headline = headline .. " — " .. FactionDisplayName(c.winner)
    end
    draw.SimpleText(headline, Fireteam.UI.Font("large"), cx, cy,
        Fireteam.UI.Color(colorName), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cy = cy + math.Round(36 * scale)

    -- 阵营比分
    local sorted = {}
    for fid, sc in pairs(c.scores or {}) do sorted[#sorted + 1] = { id = fid, score = sc } end
    table.sort(sorted, function(a, b) return a.score > b.score end)

    for _, entry in ipairs(sorted) do
        local isMine = entry.id == myFaction
        draw.SimpleText(FactionDisplayName(entry.id), Fireteam.UI.Font("body"),
            cx - math.Round(12 * scale), cy,
            Fireteam.UI.Color(isMine and "primary" or "text"),
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(entry.score), Fireteam.UI.Font("num"),
            cx + math.Round(12 * scale), cy,
            Fireteam.UI.Color(isMine and "primary" or "text"),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        cy = cy + rowH
    end

    -- 下一回合倒计时
    cy = cy + math.Round(6 * scale)
    draw.SimpleText(L("round_next_in", math.ceil(math.max(0, c.endTime - CurTime()))),
        Fireteam.UI.Font("small"), cx, cy,
        Fireteam.UI.Color("text_muted"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- ═══════════════════════════════════════
-- HUD 挂载
-- ═══════════════════════════════════════
hook.Add("HUDPaint", "Fireteam.Rounds.HUD", function()
    if not Fireteam.Rounds.IsEnabled() then return end
    local c = Fireteam.Rounds.Client
    if c.state == "idle" then return end

    DrawBanner(c)
    if c.state == "ended" then DrawSummary(c) end
end)
