-- modules/commander/sv_commander.lua
-- FIRETEAM Commander System - Server Logic
-- 席位表 commanders[faction] = Player；选举表 elections[faction]。
-- 失效原则：任指挥官必须持续满足「本阵营某小队的现任队长」，
-- 离队/解散/断线即腾位（hook 即时判定，无状态残留）。

if not Fireteam then Fireteam = {} end
Fireteam.Commander = Fireteam.Commander or {}

local ELECTION_TIME = Fireteam.Commander.ELECTION_TIME
local EXTEND_TIME   = Fireteam.Commander.EXTEND_TIME

local commanders = {}   -- [factionId] = Player | nil
local elections  = {}   -- [factionId] = { endsAt, extendedOnce,
                        --                 candidates = { [entIdx] = Player },
                        --                 votes      = { [voterEntIdx] = candidateEntIdx } }

-- ═══════════════════════════════════════
-- 查询
-- ═══════════════════════════════════════
function Fireteam.Commander.GetFactionCommander(faction)
    local cmd = commanders[faction]
    return IsValid(cmd) and cmd or nil
end

function Fireteam.Commander.IsFactionCommander(ply)
    if not IsValid(ply) then return false end
    local f = ply.FT_CommanderOf
    return f ~= nil and commanders[f] == ply
end

--- 本阵营全部现任小队长 { [entIdx] = Player }
local function GetLeadersOfFaction(faction)
    local out = {}
    if not (Fireteam.Squad and Fireteam.Squad.GetAll) then return out end
    for _, sq in pairs(Fireteam.Squad.GetAll()) do
        if sq.faction == faction and IsValid(sq.leader) then
            out[sq.leader:EntIndex()] = sq.leader
        end
    end
    return out
end

--- 调用者是否本阵营某小队队长（志愿/投票资格）
local function IsSquadLeaderOf(ply, faction)
    local sq = Fireteam.Squad.GetPlayerSquad(ply)
    return sq ~= nil
        and sq.faction == faction
        and sq.leader == ply
end

-- ═══════════════════════════════════════
-- 同步（手写定序，客户端 cl_commander.lua 严格配对）
-- ═══════════════════════════════════════
--- @param target Player|nil  指定则单发（CLIENT_READY 补齐用），缺省全场广播
local function SyncToAll(target)
    -- 需广播的阵营集合：席位 ∪ 选举 ∪ 有小队的阵营
    local set = {}
    for f in pairs(commanders) do set[f] = true end
    for f in pairs(elections)  do set[f] = true end
    if Fireteam.Squad and Fireteam.Squad.GetAll then
        for _, sq in pairs(Fireteam.Squad.GetAll()) do set[sq.faction or ""] = true end
    end
    set[""] = nil

    local list = {}
    for f in pairs(set) do list[#list + 1] = f end
    table.sort(list)

    net.Start(Fireteam.NET.COMMANDER_UPDATE)
    net.WriteUInt(#list, 5)
    for _, faction in ipairs(list) do
        net.WriteString(faction)
        local cmd = commanders[faction]
        net.WriteUInt(IsValid(cmd) and cmd:EntIndex() or 0, 8)

        local el = elections[faction]
        net.WriteBool(el ~= nil)
        if el then
            net.WriteFloat(math.max(0, el.endsAt - CurTime()))
            local cands = {}
            for idx in pairs(el.candidates) do cands[#cands + 1] = idx end
            table.sort(cands)
            net.WriteUInt(#cands, 5)
            for _, idx in ipairs(cands) do net.WriteUInt(idx, 8) end
        end
    end
    if IsValid(target) then net.Send(target) else net.Broadcast() end
end

--- 单发指挥席位与选举态（供 CLIENT_READY 握手补齐）
function Fireteam.Commander.SendStateTo(ply)
    if IsValid(ply) then SyncToAll(ply) end
end

-- ═══════════════════════════════════════
-- 就任 / 结算
-- ═══════════════════════════════════════
local function Elect(faction, ply, reasonKey)
    commanders[faction] = ply
    elections[faction] = nil
    ply.FT_CommanderOf = faction

    hook.Run(Fireteam.HOOKS.COMMANDER_CHANGED, faction, ply)
    for _, p in ipairs(player.GetAll()) do
        p:ChatPrint("[FIRETEAM] ★ " .. ply:Nick() .. " takes command of [" .. faction .. "]")
    end
    Fireteam.Log.Info("Commander", "" .. faction .. " → " .. ply:Nick())
    SyncToAll()
end

--- 结算选举：最高票当选；平票延长一次，再平随机取
local function SettleElection(faction)
    local el = elections[faction]
    if not el then return end

    local tally = {}
    for voterIdx, candIdx in pairs(el.votes) do
        -- 计票时跳过已失效的候选（中途离队/断线被移除）
        if el.candidates[candIdx] then
            tally[candIdx] = (tally[candIdx] or 0) + 1
        end
    end

    local bestIdx, bestN, tie = nil, 0, false
    for idx, n in pairs(tally) do
        if n > bestN then bestIdx, bestN, tie = idx, n, false
        elseif n == bestN then tie = true end
    end

    -- 无票/平票且未延长过 → 延长再战
    if (bestIdx == nil or tie) and not el.extendedOnce then
        el.extendedOnce = true
        el.endsAt = CurTime() + EXTEND_TIME
        for _, p in ipairs(player.GetAll()) do
            p:ChatPrint("[FIRETEAM] Commander vote tied on [" .. faction .. "] - extended " .. EXTEND_TIME .. "s")
        end
        SyncToAll()
        return
    end

    elections[faction] = nil

    local winner = nil
    if bestIdx ~= nil and not tie then
        winner = el.candidates[bestIdx]
    else
        -- 再平：候选中随机取（按排序保证可复现）
        local pool = {}
        for idx in pairs(el.candidates) do pool[#pool + 1] = idx end
        if #pool > 0 then
            table.sort(pool)
            winner = el.candidates[pool[math.random(#pool)]]
        end
    end

    if IsValid(winner) then
        Elect(faction, winner)
    else
        SyncToAll()
    end
end

--- 开启竞选（含重选挑战）：现任可选进入候选池
local function StartElection(faction, seededCandidates)
    local candidates = {}
    for _, p in pairs(seededCandidates or {}) do
        if IsValid(p) then candidates[p:EntIndex()] = p end
    end
    elections[faction] = {
        endsAt       = CurTime() + ELECTION_TIME,
        extendedOnce = false,
        candidates   = candidates,
        votes        = {},
    }
    for _, p in ipairs(player.GetAll()) do
        p:ChatPrint("[FIRETEAM] ★ Commander election started on [" .. faction .. "] - "
            .. ELECTION_TIME .. "s")
    end
end

-- ═══════════════════════════════════════
-- 三态入口
-- ═══════════════════════════════════════
function Fireteam.Commander.Volunteer(ply)
    if not IsValid(ply) then return false end
    local sq = Fireteam.Squad.GetPlayerSquad(ply)
    if not sq then
        ply:ChatPrint("[FIRETEAM] Join a squad as its leader first.")
        return false
    end
    if sq.leader ~= ply then
        ply:ChatPrint("[FIRETEAM] Only the squad leader can run for commander.")
        return false
    end

    local faction = sq.faction
    local cur = commanders[faction]

    if cur == ply then
        ply:ChatPrint("[FIRETEAM] You already command this faction.")
        return false
    end

    local el = elections[faction]
    if el then
        -- 选举进行中：仅补报候选池
        el.candidates[ply:EntIndex()] = ply
        SyncToAll()
        return true
    end

    if not IsValid(cur) then
        -- 态 1：席位空缺 + 单志愿者 → 立即就任
        -- （若与他人几乎同时点击，后者到时席位已占 → 自然转入态 3 挑战）
        Elect(faction, ply)
        return true
    end

    -- 态 3：已有现任 → 重选挑战，现任自动入池
    StartElection(faction, { cur, ply })
    SyncToAll()
    return true
end

function Fireteam.Commander.Vote(ply, targetIdx)
    if not IsValid(ply) then return false end
    local sq = Fireteam.Squad.GetPlayerSquad(ply)
    if not sq or sq.leader ~= ply then
        ply:ChatPrint("[FIRETEAM] Only squad leaders may vote.")
        return false
    end

    local el = elections[sq.faction]
    if not el then
        ply:ChatPrint("[FIRETEAM] No election is running.")
        return false
    end
    if not el.candidates[targetIdx] then
        ply:ChatPrint("[FIRETEAM] Not a candidate.")
        return false
    end

    el.votes[ply:EntIndex()] = targetIdx   -- 一人一票，可改票
    SyncToAll()
    return true
end

function Fireteam.Commander.Relinquish(ply)
    local faction = IsValid(ply) and ply.FT_CommanderOf or nil
    if not faction or commanders[faction] ~= ply then return false end

    commanders[faction] = nil
    ply.FT_CommanderOf = nil
    hook.Run(Fireteam.HOOKS.COMMANDER_CHANGED, faction, nil)
    for _, p in ipairs(player.GetAll()) do
        p:ChatPrint("[FIRETEAM] ★ " .. ply:Nick() .. " relinquished command of [" .. faction .. "]")
    end
    SyncToAll()
    return true
end

-- ═══════════════════════════════════════
-- 失效清理：失去「本阵营现任队长」身份即腾位/移出候选池
-- PLAYER_LEFT_SQUAD 触发时 members 已删、leader 尚未转移，
-- 因此资格校验必须同时要求 members 里仍有本人。
-- ═══════════════════════════════════════
local function ValidatePlayer(ply)
    -- 1) 现任席位
    for faction, cmd in pairs(commanders) do
        if cmd == ply then
            local stillValid = false
            if IsValid(ply) then
                local sq = Fireteam.Squad.GetPlayerSquad(ply)
                stillValid = sq ~= nil
                    and sq.faction == faction
                    and sq.leader == ply
                    and sq.members[ply] ~= nil
            end
            if not stillValid then
                commanders[faction] = nil
                ply.FT_CommanderOf = nil
                hook.Run(Fireteam.HOOKS.COMMANDER_CHANGED, faction, nil)
                for _, p in ipairs(player.GetAll()) do
                    p:ChatPrint("[FIRETEAM] ★ Command of [" .. faction .. "] is vacant")
                end
            end
        end
    end

    -- 2) 候选池：失格者移出；只剩单人时立即结算（无对手无需再投）
    for faction, el in pairs(elections) do
        local idx = IsValid(ply) and ply:EntIndex() or nil
        if idx and el.candidates[idx] then
            local sq = Fireteam.Squad.GetPlayerSquad(ply)
            if not (sq and sq.faction == faction and sq.leader == ply and sq.members[ply]) then
                -- 清除失格候选人的全部选票，防止陈旧票数影响结算
                for voterIdx, votedForIdx in pairs(el.votes) do
                    if votedForIdx == idx then
                        el.votes[voterIdx] = nil
                    end
                end
                el.candidates[idx] = nil
            end
        end
        if table.Count(el.candidates) <= 1 then
            -- 仅剩一名候选时给其清空选票直接当选；零候选则结算为空位
            SettleElection(faction)
        end
    end

    SyncToAll()
end

hook.Add(Fireteam.HOOKS.PLAYER_LEFT_SQUAD, "Fireteam.Commander.ValidateOnLeave", function(ply)
    ValidatePlayer(ply)
end)

hook.Add("PlayerDisconnected", "Fireteam.Commander.Cleanup", function(ply)
    ValidatePlayer(ply)
end)

-- 选举倒计时（1s tick，到期结算）
timer.Create("Fireteam.Commander.ElectionTick", 1, 0, function()
    for faction, el in pairs(elections) do
        if CurTime() >= el.endsAt then
            SettleElection(faction)
        end
    end
end)

-- ═══════════════════════════════════════
-- 指挥频道动态授权：
-- 频道 access 白名单之外的玩家，凡本阵营指挥官一律放行 kind=="command"。
-- 返回 true=授权；nil=不干预（交给其他判定路径）。
-- 听觉层同阵营过滤由 voice 模块既有逻辑完成，此处无需处理。
-- ═══════════════════════════════════════
hook.Add(Fireteam.HOOKS.VOICE_CAN_ACCESS_CHANNEL, "Fireteam.Commander.ChannelAccess",
function(ply, channelId)
    local presets = Fireteam.Setting.GetData and Fireteam.Setting.GetData("voice_presets") or nil
    local chDef = presets and presets.channels and presets.channels[channelId] or nil
    if not chDef or chDef.kind ~= "command" then return nil end
    if Fireteam.Commander.IsFactionCommander(ply) then return true end
end)

-- ═══════════════════════════════════════
-- 网络消息
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.COMMANDER_ACTION, function(len, ply)
    local action = string.sub(net.ReadString(), 1, 16)
    if action == "volunteer" then
        Fireteam.Commander.Volunteer(ply)
    elseif action == "relinquish" then
        Fireteam.Commander.Relinquish(ply)
    elseif action == "vote" then
        local targetIdx = net.ReadUInt(8)
        Fireteam.Commander.Vote(ply, targetIdx)
    end
end)

Fireteam.Log.Info("Commander", "✓ 服务端逻辑已加载")
