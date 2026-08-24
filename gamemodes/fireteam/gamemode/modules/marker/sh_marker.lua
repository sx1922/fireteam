-- modules/marker/sh_marker.lua
-- FIRETEAM Marker System - Shared

if not Fireteam then Fireteam = {} end
Fireteam.Marker = Fireteam.Marker or {}

-- 标记类型
Fireteam.Marker.TYPE = {
    WAYPOINT    = "waypoint",       -- 路点
    ENEMY       = "enemy",          -- 敌人位置
    OBJECTIVE   = "objective",      -- 目标点
    DANGER      = "danger",         -- 危险区域
    RALLY       = "rally",          -- 集合点
    MEDICAL     = "medical"         -- 医疗点
}

-- 标记颜色映射
Fireteam.Marker.COLORS = {
    waypoint  = Color(100, 200, 255),
    enemy     = Color(255, 60, 60),
    objective = Color(255, 200, 50),
    danger    = Color(255, 120, 0),
    rally     = Color(50, 255, 100),
    medical   = Color(255, 255, 255)
}

-- 标记生命周期（秒）
Fireteam.Marker.LIFETIME = 120

-- 最大标记数（每人）
Fireteam.Marker.MAX_PER_PLAYER = 3

print("[FIRETEAM:Marker] ✓ Shared definitions loaded")
