-- modules/vote/sv_vote.lua
-- FIRETEAM Voting System - Server
-- 发起/计票/执行/冷却

if not Fireteam then Fireteam = {} end
Fireteam.Vote = Fireteam.Vote or {}

local TOPIC = Fireteam.Vote.TOPIC

-- ═══════════════════════════════════════
-- 当前投票状态
-- ═══════════════════════════════════════
local currentVote = {
    state    = Fireteam.Vote.STATE.NONE,
    topic    = nil,
    options  = {},
    votes    = {},        -- [player] = optionId
    proposer = nil,
    endsAt   = 0,
}

local lastVoteTime = 0  -- 防刷冷却

-- ═══════════════════════════════════════
-- 序列化选项到 net
-- ═══════════════════════════════════════
local function NetWriteOptions(options)
    net.WriteUInt(#options, 5)
    for _, opt in ipairs(options) do
        net.WriteString(opt.id)
        net.WriteString(opt.label or opt.id)
    end
end

local function NetReadOptions()
    local n = net.ReadUInt(5)
    local out = {}
    for i = 1, n do
        out[i] = { id = net.ReadString(), label = net.ReadString() }
    end
    return out
end

-- ═══════════════════════════════════════
-- 构造选项列表
-- ═══════════════════════════════════════
local function BuildScenarioOptions()
    local list = Fireteam.Rounds.GetScenarioList()
    if not list then return {} end
    local out = {}
    for id, data in pairs(list) do
        table.insert(out, {
            id    = id,
            label = (data.name_zh or data.name or id) .. " (" .. id .. ")",
        })
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function BuildModeOptions()
    return {
        { id = "pvp", label = "PvP（玩家对抗）" },
        { id = "pve", label = "PvE（玩家 vs AI）" },
    }
end

-- ═══════════════════════════════════════
-- 发起投票
-- ═══════════════════════════════════════
--- @param topic string "scenario"|"mode"
--- @param proposer Player|nil 发起人（nil = 管理员/系统）
--- @return boolean 成功
function Fireteam.Vote.Start(topic, proposer)
    -- 冷却检查
    if CurTime() - lastVoteTime < Fireteam.Config.Get("vote.cooldown") then
        return false, "投票冷却中"
    end

    -- 进行中
    if currentVote.state == Fireteam.Vote.STATE.ACTIVE then
        return false, "已有投票进行中"
    end

    local options = nil
    if topic == TOPIC.SCENARIO then
        options = BuildScenarioOptions()
    elseif topic == TOPIC.MODE then
        options = BuildModeOptions()
    else
        return false, "不支持的投票主题"
    end

    if #options < 2 then
        return false, "选项不足"
    end

    local timeout = Fireteam.Config.Get("vote.timeout")
    currentVote = {
        state    = Fireteam.Vote.STATE.ACTIVE,
        topic    = topic,
        options  = options,
        votes    = {},
        proposer = IsValid(proposer) and proposer:Nick() or "系统",
        endsAt   = CurTime() + timeout,
    }
    lastVoteTime = CurTime()

    -- 广播 VOTE_START
    net.Start(Fireteam.NET.VOTE_START)
        net.WriteString(topic)
        net.WriteString(currentVote.proposer)
        net.WriteFloat(currentVote.endsAt)
        NetWriteOptions(options)
    net.Broadcast()

    hook.Run(Fireteam.HOOKS.VOTE_STARTED, topic, options, currentVote.proposer)
    Fireteam.Log.Info("投票", string.format("发起投票: %s（发起者: %s）", topic, currentVote.proposer))
    return true
end

-- ═══════════════════════════════════════
-- 投票（计票）
-- ═══════════════════════════════════════
function Fireteam.Vote.Cast(ply, optionId)
    if not IsValid(ply) then return false end
    if currentVote.state ~= Fireteam.Vote.STATE.ACTIVE then
        return false, "无投票进行中"
    end
    if CurTime() > currentVote.endsAt then
        return false, "投票已结束"
    end
    if currentVote.votes[ply] then
        return false, "你已投过票"
    end

    -- 验证选项 id
    local found = false
    for _, opt in ipairs(currentVote.options) do
        if opt.id == optionId then
            found = true
            break
        end
    end
    if not found then
        return false, "无效选项"
    end

    currentVote.votes[ply] = optionId
    Fireteam.Log.Info("投票", string.format("%s 投票: %s", ply:Nick(), optionId))

    -- 广播 VOTE_UPDATE（实时票数）
    net.Start(Fireteam.NET.VOTE_UPDATE)
        net.WriteString(currentVote.topic)
        net.WriteString(optionId)
        net.WriteUInt(table.Count(currentVote.votes), 8)
    net.Broadcast()

    return true
end

-- ═══════════════════════════════════════
-- 结算
-- ═══════════════════════════════════════
local function TallyVotes()
    local tally = {}
    for _, opt in ipairs(currentVote.options) do
        tally[opt.id] = 0
    end
    for _, optId in pairs(currentVote.votes) do
        tally[optId] = (tally[optId] or 0) + 1
    end
    return tally
end

local function ResolveWinner(tally)
    local threshold = Fireteam.Config.Get("vote.threshold")
    local totalVoters = #player.GetAll()
    if totalVoters == 0 then return nil, 0 end
    local required = math.ceil(totalVoters * threshold)

    local best, bestCount = nil, 0
    for optId, count in pairs(tally) do
        if count > bestCount then
            best, bestCount = optId, count
        end
    end

    if bestCount >= required then
        return best, bestCount
    end
    return nil, bestCount
end

function Fireteam.Vote.Resolve()
    if currentVote.state ~= Fireteam.Vote.STATE.ACTIVE then return end

    local tally = TallyVotes()
    local winner, count = ResolveWinner(tally)

    currentVote.state = Fireteam.Vote.STATE.NONE

    -- 广播结果
    net.Start(Fireteam.NET.VOTE_RESULT)
        net.WriteString(currentVote.topic)
        net.WriteString(winner or "")
        net.WriteUInt(count, 8)
    net.Broadcast()

    if winner then
        Fireteam.Log.Info("投票", string.format("投票通过: %s (%d票)", winner, count))

        -- 执行结果
        if currentVote.topic == TOPIC.SCENARIO then
            Fireteam.Config.Set("rounds.scenario", winner)
        elseif currentVote.topic == TOPIC.MODE then
            Fireteam.Config.Set("rounds.mode", winner)
        end

        hook.Run(Fireteam.HOOKS.VOTE_PASSED, currentVote.topic, winner)
    else
        Fireteam.Log.Info("投票", "投票未达阈值，未通过")
        hook.Run(Fireteam.HOOKS.VOTE_FAILED, currentVote.topic)
    end

    currentVote = { state = Fireteam.Vote.STATE.NONE, options = {}, votes = {}, topic = nil, proposer = nil, endsAt = 0 }
end

-- ═══════════════════════════════════════
-- Think：超时自动结算
-- ═══════════════════════════════════════
hook.Add("Think", "Fireteam.Vote.Timeout", function()
    if currentVote.state ~= Fireteam.Vote.STATE.ACTIVE then return end
    if CurTime() >= currentVote.endsAt then
        Fireteam.Vote.Resolve()
    end
end)

-- ═══════════════════════════════════════
-- 清理：玩家断线时移除其投票
-- ═══════════════════════════════════════
hook.Add("PlayerDisconnected", "Fireteam.Vote.Cleanup", function(ply)
    currentVote.votes[ply] = nil
end)

-- ═══════════════════════════════════════
-- 网络接收
-- ═══════════════════════════════════════
util.AddNetworkString(Fireteam.NET.VOTE_START)
util.AddNetworkString(Fireteam.NET.VOTE_CAST)
util.AddNetworkString(Fireteam.NET.VOTE_UPDATE)
util.AddNetworkString(Fireteam.NET.VOTE_RESULT)

net.Receive(Fireteam.NET.VOTE_CAST, function(len, ply)
    local optionId = net.ReadString()
    Fireteam.Vote.Cast(ply, optionId)
end)

-- ═══════════════════════════════════════
-- 管理员命令（简化投票入口）
-- ═══════════════════════════════════════
concommand.Add("ft_vote_scenario", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    Fireteam.Vote.Start("scenario", ply)
end)

concommand.Add("ft_vote_mode", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    Fireteam.Vote.Start("mode", ply)
end)

-- ═══════════════════════════════════════
-- 公共 API（供其他模块调用）
-- ═══════════════════════════════════════
function Fireteam.Vote.GetStatus()
    return currentVote.state, currentVote.topic, currentVote.options,
           table.Count(currentVote.votes), currentVote.endsAt - CurTime()
end

function Fireteam.Vote.SetThreshold(threshold)
    Fireteam.Config.Set("vote.threshold", math.Clamp(threshold, 0.1, 1.0))
end

function Fireteam.Vote.Cancel()
    if currentVote.state ~= Fireteam.Vote.STATE.ACTIVE then return end
    currentVote.state = Fireteam.Vote.STATE.NONE
    net.Start(Fireteam.NET.VOTE_RESULT)
        net.WriteString(currentVote.topic)
        net.WriteString("")
        net.WriteUInt(0, 8)
    net.Broadcast()
    currentVote = { state = Fireteam.Vote.STATE.NONE, options = {}, votes = {}, topic = nil, proposer = nil, endsAt = 0 }
end

Fireteam.Log.Info("投票", "✓ 投票系统服务端已加载")
