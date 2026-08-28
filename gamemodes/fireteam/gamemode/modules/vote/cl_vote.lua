-- modules/vote/cl_vote.lua
-- FIRETEAM Voting System - Client
-- 接收广播、渲染面板、提交投票
-- 冷战军事风格：直角面板 + 沙金/橄榄配色 + 角标装饰

if not Fireteam then Fireteam = {} end
Fireteam.Vote = Fireteam.Vote or {}

local kit = Fireteam.UI
local L = Fireteam.Locale.Get

Fireteam.Vote.Client = {
    state     = "none",     -- 投票状态: none / active / result / timeout
    topic     = nil,
    options   = {},
    votes     = {},        -- [optId] = count
    endsAt    = 0,
    proposer  = nil,
    myVote    = nil,       -- 玩家已投的选项 id
    resultAt  = 0,         -- 结果显示时间戳，用于自动隐藏
}

-- 选项行区域缓存（Paint 时写入，GUIMousePressed 时读取）
local optionRects = {}
local panelRect = { x = 0, y = 0, w = 0, h = 0 }

-- ═══════════════════════════════════════
-- 接收 VOTE_START
-- ═══════════════════════════════════════
local function OnVoteStart()
    local topic = net.ReadString()
    local proposer = net.ReadString()
    local endsAt = net.ReadFloat()

    local options = {}
    local n = net.ReadUInt(5)
    for i = 1, n do
        options[i] = {
            id    = net.ReadString(),
            label = net.ReadString(),
        }
    end

    local tally = {}
    for _, opt in ipairs(options) do
        tally[opt.id] = 0
    end

    Fireteam.Vote.Client = {
        state    = "active",
        topic    = topic,
        options  = options,
        votes    = tally,
        endsAt   = endsAt,
        proposer = proposer,
        myVote   = nil,
        resultAt = 0,
    }

    optionRects = {}
    hook.Run("FT_VoteUI_Changed", Fireteam.Vote.Client)
    Fireteam.Log.Info("投票", string.format("收到投票: %s", topic))
end

-- ═══════════════════════════════════════
-- 接收 VOTE_UPDATE
-- ═══════════════════════════════════════
local function OnVoteUpdate()
    local topic = net.ReadString()
    local optId = net.ReadString()
    local count = net.ReadUInt(8)

    if Fireteam.Vote.Client.topic == topic then
        Fireteam.Vote.Client.votes[optId] = count
        hook.Run("FT_VoteUI_Changed", Fireteam.Vote.Client)
    end
end

-- ═══════════════════════════════════════
-- 接收 VOTE_RESULT
-- ═══════════════════════════════════════
local function OnVoteResult()
    local topic = net.ReadString()
    local winner = net.ReadString()
    local count = net.ReadUInt(8)

    local c = Fireteam.Vote.Client
    c.state = "result"
    c.winner = winner
    c.resultCount = count
    c.resultAt = CurTime()

    hook.Run("FT_VoteUI_Changed", c)
    Fireteam.Log.Info("投票", string.format("投票结果: %s（%d票）", winner, count))

    -- 5 秒后自动清除
    timer.Simple(5, function()
        if Fireteam.Vote.Client.state == "result" then
            Fireteam.Vote.Client.state = "none"
            optionRects = {}
        end
    end)
end

-- ═══════════════════════════════════════
-- 投票（提交选项 id）
-- ═══════════════════════════════════════
function Fireteam.Vote.Cast(optionId)
    net.Start(Fireteam.NET.VOTE_CAST)
        net.WriteString(optionId)
    net.SendToServer()
    Fireteam.Vote.Client.myVote = optionId
end

-- ═══════════════════════════════════════
-- 鼠标点击投票
-- ═══════════════════════════════════════
hook.Add("GUIMousePressed", "Fireteam.Vote.OnClick", function(mouseCode)
    if mouseCode ~= MOUSE_LEFT then return end
    local c = Fireteam.Vote.Client
    if c.state ~= "active" then return end
    if c.myVote then return end -- 已投过票

    local mx, my = gui.MousePos()
    for _, rect in ipairs(optionRects) do
        if mx >= rect.x and mx <= rect.x + rect.w
        and my >= rect.y and my <= rect.y + rect.h then
            Fireteam.Vote.Cast(rect.id)
            surface.PlaySound("buttons/button14.wav")
            return
        end
    end
end)

-- ═══════════════════════════════════════
-- HUDPaint：投票面板渲染
-- ═══════════════════════════════════════
hook.Add("HUDPaint", "Fireteam.Vote.Panel", function()
    local c = Fireteam.Vote.Client
    if c.state == "none" then return end

    local theme = Fireteam.HUD and Fireteam.HUD.GetTheme and Fireteam.HUD.GetTheme()
    if not theme then return end

    local scale = math.Clamp(ScrH() / 1080, 0.75, 2)
    local panelW = math.Round(360 * scale)
    local optH = math.Round(32 * scale)
    local headerH = math.Round(56 * scale)
    local footerH = math.Round(20 * scale)

    local totalOpts = #c.options
    local panelH = headerH + totalOpts * optH + footerH + math.Round(16 * scale)

    -- 屏幕顶部居中
    local px = math.Round((ScrW() - panelW) / 2)
    local py = math.Round(40 * scale)

    panelRect = { x = px, y = py, w = panelW, h = panelH }

    -- 入场/退场动画
    local anim = 1
    if c.state == "result" then
        local elapsed = CurTime() - c.resultAt
        if elapsed > 3.5 then
            anim = math.Clamp(1 - (elapsed - 3.5) / 1.5, 0, 1)
        end
    end
    local alpha = anim * 255
    if alpha < 1 then return end

    local colBg     = kit.ColorA("background", math.Round(220 * anim))
    local colSurf   = kit.ColorA("surface", math.Round(200 * anim))
    local colBorder = kit.ColorA("border", math.Round(180 * anim))
    local colText   = kit.ColorA("text", alpha)
    local colMuted  = kit.ColorA("text_muted", alpha)
    local colPrimary = kit.ColorA("primary", alpha)
    local colAccent = kit.ColorA("accent", alpha)
    local colSuccess = kit.ColorA("success", alpha)
    local colDanger = kit.ColorA("danger", alpha)

    -- 面板底色
    surface.SetDrawColor(colBg)
    surface.DrawRect(px, py, panelW, panelH)

    -- 顶部条
    surface.SetDrawColor(kit.ColorA("primary", math.Round(40 * anim)))
    surface.DrawRect(px, py, panelW, headerH)

    -- 边框
    surface.SetDrawColor(colBorder)
    surface.DrawRect(px, py, panelW, 1)                         -- 上
    surface.DrawRect(px, py + panelH - 1, panelW, 1)            -- 下
    surface.DrawRect(px, py, 1, panelH)                         -- 左
    surface.DrawRect(px + panelW - 1, py, 1, panelH)           -- 右

    -- L 形角标（左上 + 右下）
    local bracketSize = math.Round(10 * scale)
    surface.SetDrawColor(colPrimary)
    -- 左上
    surface.DrawRect(px, py, bracketSize, 1)
    surface.DrawRect(px, py, 1, bracketSize)
    -- 右下
    surface.DrawRect(px + panelW - bracketSize, py + panelH - 1, bracketSize, 1)
    surface.DrawRect(px + panelW - 1, py + panelH - bracketSize, 1, bracketSize)

    -- 标题
    local titleText = L("ui_vote_title")
    if c.topic == "scenario" then
        titleText = L("ui_vote_scenario")
    elseif c.topic == "mode" then
        titleText = L("ui_vote_mode")
    end

    draw.SimpleText(titleText, kit.Font("title"), px + math.Round(14 * scale), py + math.Round(10 * scale),
        colPrimary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- 发起人
    local proposerText = string.format(L("ui_vote_proposed_by"), c.proposer or "?")
    draw.SimpleText(proposerText, kit.Font("small"), px + math.Round(14 * scale), py + math.Round(32 * scale),
        colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- 倒计时 / 结果
    local remainSec = math.max(0, math.ceil(c.endsAt - CurTime()))
    if c.state == "active" then
        local timeText = string.format(L("ui_vote_remaining"), remainSec)
        local timeColor = remainSec <= 10 and colDanger or colMuted
        draw.SimpleText(timeText, kit.Font("medium"), px + panelW - math.Round(14 * scale), py + math.Round(10 * scale),
            timeColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        -- 倒计时进度条
        local barY = py + headerH - math.Round(3 * scale)
        local totalDur = c.endsAt > 0 and (c.endsAt - (c.resultAt > 0 and c.resultAt or (c.endsAt - 60))) or 60
        local progress = math.Clamp(remainSec / math.max(1, totalDur), 0, 1)
        surface.SetDrawColor(kit.ColorA("border", math.Round(100 * anim)))
        surface.DrawRect(px + math.Round(14 * scale), barY, panelW - math.Round(28 * scale), math.Round(2 * scale))
        surface.SetDrawColor(timeColor)
        surface.DrawRect(px + math.Round(14 * scale), barY, math.Round((panelW - math.Round(28 * scale)) * progress), math.Round(2 * scale))

    elseif c.state == "result" then
        local resultText
        local resultColor
        if c.winner and c.winner ~= "" then
            resultText = string.format(L("ui_vote_result_pass"), c.winner, c.resultCount or 0)
            resultColor = colSuccess
        else
            resultText = L("ui_vote_result_fail")
            resultColor = colDanger
        end
        draw.SimpleText(resultText, kit.Font("medium"), px + panelW - math.Round(14 * scale), py + math.Round(10 * scale),
            resultColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    elseif c.state == "timeout" then
        draw.SimpleText(L("ui_vote_timeout"), kit.Font("medium"), px + panelW - math.Round(14 * scale), py + math.Round(10 * scale),
            colDanger, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end

    -- 选项行
    optionRects = {}
    local optY = py + headerH + math.Round(8 * scale)

    local mx, my = gui.MousePos()
    local hoverOpt = nil

    for i, opt in ipairs(c.options) do
        local rowX = px + math.Round(10 * scale)
        local rowW = panelW - math.Round(20 * scale)
        local isVoted = (c.myVote == opt.id)
        local isWinner = (c.state == "result" and c.winner == opt.id)
        local isHovered = (c.state == "active" and not c.myVote
            and mx >= rowX and mx <= rowX + rowW
            and my >= optY and my <= optY + optH)

        if isHovered then hoverOpt = opt.id end

        -- 存入点击区域
        optionRects[#optionRects + 1] = {
            id = opt.id,
            x = rowX, y = optY, w = rowW, h = optH,
        }

        -- 行底色
        if isWinner then
            surface.SetDrawColor(kit.ColorA("success", math.Round(40 * anim)))
            surface.DrawRect(rowX, optY, rowW, optH - math.Round(2 * scale))
        elseif isVoted then
            surface.SetDrawColor(kit.ColorA("primary", math.Round(30 * anim)))
            surface.DrawRect(rowX, optY, rowW, optH - math.Round(2 * scale))
        elseif isHovered then
            surface.SetDrawColor(kit.ColorA("accent", math.Round(25 * anim)))
            surface.DrawRect(rowX, optY, rowW, optH - math.Round(2 * scale))
        end

        -- 左侧高亮条
        if isWinner then
            surface.SetDrawColor(colSuccess)
            surface.DrawRect(rowX, optY, 2, optH - math.Round(2 * scale))
        elseif isVoted then
            surface.SetDrawColor(colPrimary)
            surface.DrawRect(rowX, optY, 2, optH - math.Round(2 * scale))
        elseif isHovered then
            surface.SetDrawColor(colAccent)
            surface.DrawRect(rowX, optY, 2, optH - math.Round(2 * scale))
        end

        -- 选项序号（军事编号）
        local numText = string.format("%02d", i)
        draw.SimpleText(numText, kit.Font("small"), rowX + math.Round(8 * scale), optY + math.Round(9 * scale),
            colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- 选项标签
        local labelColor = colText
        if isWinner then labelColor = colSuccess
        elseif isVoted then labelColor = colPrimary
        end
        draw.SimpleText(opt.label, kit.Font("body"), rowX + math.Round(38 * scale), optY + math.Round(8 * scale),
            labelColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- 票数（右侧）
        local voteCount = c.votes[opt.id] or 0
        if c.state == "active" or c.state == "result" then
            local countText = string.format(L("ui_vote_count"), voteCount)
            local countColor = isWinner and colSuccess or colMuted
            draw.SimpleText(countText, kit.Font("small"), rowX + rowW - math.Round(8 * scale), optY + math.Round(9 * scale),
                countColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end

        -- 已投票标记
        if isVoted then
            draw.SimpleText(L("ui_vote_voted"), kit.Font("small"), rowX + rowW - math.Round(50 * scale), optY + math.Round(9 * scale),
                colPrimary, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end

        -- 悬浮提示
        if isHovered then
            draw.SimpleText(L("ui_vote_click_to_vote"), kit.Font("small"), rowX + rowW - math.Round(50 * scale), optY + math.Round(9 * scale),
                colAccent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end

        -- 行间分隔线
        if i < totalOpts then
            surface.SetDrawColor(kit.ColorA("border", math.Round(60 * anim)))
            surface.DrawRect(rowX + math.Round(38 * scale), optY + optH - math.Round(2 * scale), rowW - math.Round(38 * scale), 1)
        end

        optY = optY + optH
    end

    -- 底部提示
    local footerText
    if c.state == "active" then
        if c.myVote then
            footerText = L("ui_vote_voted")
        else
            footerText = L("ui_vote_click_to_vote")
        end
    elseif c.state == "result" then
        footerText = c.winner and c.winner ~= ""
            and string.format(L("ui_vote_result_pass"), c.winner, c.resultCount or 0)
            or L("ui_vote_result_fail")
    elseif c.state == "timeout" then
        footerText = L("ui_vote_timeout")
    end

    if footerText then
        draw.SimpleText(footerText, kit.Font("small"), px + math.Round(14 * scale), py + panelH - math.Round(14 * scale),
            colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    end

    -- 鼠标光标（投票进行中且未投票时显示）
    if c.state == "active" and not c.myVote and hoverOpt then
        -- 改变光标样式（GMod 无 API 直接改光标，用绘制箭头替代）
    end
end)

-- ═══════════════════════════════════════
-- 自动结算倒计时（每秒检查）
-- ═══════════════════════════════════════
hook.Add("Think", "Fireteam.Vote.ClientTimeout", function()
    local c = Fireteam.Vote.Client
    if c.state == "active" and CurTime() >= c.endsAt then
        c.state = "timeout"
        c.resultAt = CurTime()
        hook.Run("FT_VoteUI_Changed", c)

        -- 5 秒后自动清除
        timer.Simple(5, function()
            if Fireteam.Vote.Client.state == "timeout" then
                Fireteam.Vote.Client.state = "none"
                optionRects = {}
            end
        end)
    end
end)

-- ═══════════════════════════════════════
-- 当前状态查询
-- ═══════════════════════════════════════
function Fireteam.Vote.GetStatus()
    local c = Fireteam.Vote.Client
    return c.state, c.topic, c.options, c.votes, c.endsAt - CurTime()
end

-- 注：发起投票由服务端 concommand 负责（管理员执行 ft_vote_scenario / ft_vote_mode）

-- ═══════════════════════════════════════
-- 注册网络接收
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.VOTE_START, OnVoteStart)
net.Receive(Fireteam.NET.VOTE_UPDATE, OnVoteUpdate)
net.Receive(Fireteam.NET.VOTE_RESULT, OnVoteResult)

Fireteam.Log.Info("投票", "✓ 投票系统客户端已加载")
