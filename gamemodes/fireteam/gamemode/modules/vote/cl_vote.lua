-- modules/vote/cl_vote.lua
-- FIRETEAM Voting System - Client
-- 接收广播、渲染面板、提交投票

if not Fireteam then Fireteam = {} end
Fireteam.Vote = Fireteam.Vote or {}

Fireteam.Vote.Client = {
    state    = "none",     -- 投票状态
    topic    = nil,
    options  = {},
    votes    = {},        -- [optId] = count
    endsAt   = 0,
}

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
    }

    -- 触发 UI 刷新
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

    Fireteam.Vote.Client.state = "result"
    Fireteam.Vote.Client.winner = winner
    Fireteam.Vote.Client.resultCount = count

    hook.Run("FT_VoteUI_Changed", Fireteam.Vote.Client)
    Fireteam.Log.Info("投票", string.format("投票结果: %s（%d票）", winner, count))
end

-- ═══════════════════════════════════════
-- 投票（提交选项 id）
-- ═══════════════════════════════════════
function Fireteam.Vote.Cast(optionId)
    net.Start(Fireteam.NET.VOTE_CAST)
        net.WriteString(optionId)
    net.SendToServer()
end

-- 注：发起投票由服务端 concommand 负责（管理员执行 ft_vote_scenario / ft_vote_mode）

-- ═══════════════════════════════════════
-- 注册网络接收（util.AddNetworkString 仅服务端，客户端省略）
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.VOTE_START, OnVoteStart)
net.Receive(Fireteam.NET.VOTE_UPDATE, OnVoteUpdate)
net.Receive(Fireteam.NET.VOTE_RESULT, OnVoteResult)

-- ═══════════════════════════════════════
-- 自动结算倒计时（每秒检查）
-- ═══════════════════════════════════════
hook.Add("Think", "Fireteam.Vote.ClientTimeout", function()
    local c = Fireteam.Vote.Client
    if c.state == "active" and CurTime() >= c.endsAt then
        c.state = "timeout"
        hook.Run("FT_VoteUI_Changed", c)
    end
end)

-- ═══════════════════════════════════════
-- 当前状态查询
-- ═══════════════════════════════════════
function Fireteam.Vote.GetStatus()
    local c = Fireteam.Vote.Client
    return c.state, c.topic, c.options, c.votes, c.endsAt - CurTime()
end

Fireteam.Log.Info("投票", "✓ 投票系统客户端已加载")