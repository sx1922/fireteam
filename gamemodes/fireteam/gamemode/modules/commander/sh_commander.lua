-- modules/commander/sh_commander.lua
-- FIRETEAM Commander System - Shared
-- 多小队联合作战的指挥链层（P11）：每个阵营一个指挥官席位，
-- 由各小队队长（SL）志愿就任或竞选产生。
--
-- 制度（单管线三态，仿 OWI Squad）：
--   1) 席位空缺 + 单一志愿者          → 立即就任
--   2) 席位空缺 + 第二名志愿者出现     → 开启竞选投票（全体本阵营 SL 投票）
--   3) 席位已有主 + 其他 SL 志愿       → 触发重选挑战，现任自动进入候选池
-- 任指挥官脱离本阵营小队队长身份（离队/解散/断线）即自动腾位。
--
-- 权限三件套（本期边界）：
--   a) kind=="command" 语音频道准入（经 VOICE_CAN_ACCESS_CHANNEL 动态授权）
--   b) 阵营级地图标记（对全阵营广播，区别于小队级标记；marker 模块消费）
--   c) 指挥视图全阵营态势（tacmap 模块消费）

if not Fireteam then Fireteam = {} end
Fireteam.Commander = Fireteam.Commander or {}

--- 竞选投票时长（秒）；平票延长一次
Fireteam.Commander.ELECTION_TIME  = 45
Fireteam.Commander.EXTEND_TIME   = 30

--- 席位状态
Fireteam.Commander.STATE = {
    IDLE   = "idle",    -- 无进行中选举
    VOTING = "voting",  -- 竞选/重选投票进行中
}

-- ─────────────────────────────────────
-- 双端查询接口（各自 realm 实现同名语义）
--   SERVER  sv_commander.lua：
--     Fireteam.Commander.GetFactionCommander(faction) → Player | nil
--     Fireteam.Commander.IsFactionCommander(ply)      → boolean
--   CLIENT  cl_commander.lua：
--     Fireteam.Commander.GetClientState()                       → 缓存表
--     Fireteam.Commander.GetCachedFactionCommander(faction)     → entIndex | nil
-- ─────────────────────────────────────

Fireteam.Log.Info("Commander", "✓ 共享定义已加载")
