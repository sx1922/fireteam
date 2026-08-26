-- modules/squad/sh_squad.lua
-- FIRETEAM Squad System - Shared Definitions

if not Fireteam then Fireteam = {} end
Fireteam.Squad = Fireteam.Squad or {}

-- ═══════════════════════════════════════
-- 数据结构
-- ═══════════════════════════════════════
--- @class FTSquad
--- @field id number          唯一 ID
--- @field name string        显示名
--- @field faction string     所属阵营
--- @field leader Player      队长
--- @field members table      成员列表 [Player] = { role, class, ready }
--- @field createdAt number   创建时间戳

-- 小队状态
Fireteam.Squad.STATE = {
    FORMING     = "forming",       -- 组建中
    READY       = "ready",         -- 就绪
    DEPLOYED    = "deployed",      -- 已部署
    DISBANDED   = "disbanded"      -- 已解散
}

-- 小队角色
Fireteam.Squad.ROLE = {
    LEADER      = "leader",
    MEMBER      = "member",
    SPECIALIST  = "specialist"
}

-- 最大同时存在的小队数
Fireteam.Squad.MAX_SQUADS = 8

-- ═══════════════════════════════════════
-- 共享查询函数
-- ═══════════════════════════════════════

--- 获取玩家所在小队
function Fireteam.Squad.GetPlayerSquad(ply)
    if not IsValid(ply) then return nil end
    return ply.FT_SquadData
end

--- 获取玩家在小队中的角色
function Fireteam.Squad.GetPlayerRole(ply)
    local squad = Fireteam.Squad.GetPlayerSquad(ply)
    if not squad then return nil end
    if squad.leader == ply then return Fireteam.Squad.ROLE.LEADER end
    return Fireteam.Squad.ROLE.MEMBER
end

--- 判断两个玩家是否在同一小队
function Fireteam.Squad.AreInSameSquad(ply1, ply2)
    local s1 = Fireteam.Squad.GetPlayerSquad(ply1)
    local s2 = Fireteam.Squad.GetPlayerSquad(ply2)
    return s1 ~= nil and s1 == s2
end

--- 获取小队成员数
function Fireteam.Squad.GetMemberCount(squad)
    if not squad or not squad.members then return 0 end
    return table.Count(squad.members)
end

--- 获取小队是否满员
function Fireteam.Squad.IsFull(squad)
    local maxSize = Fireteam.Config.Get("squad.max_size") or Fireteam.DEFAULT_SQUAD_SIZE
    return Fireteam.Squad.GetMemberCount(squad) >= maxSize
end

print("[FIRETEAM:Squad] ✓ 共享定义已加载")
