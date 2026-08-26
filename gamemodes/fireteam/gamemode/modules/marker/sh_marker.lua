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

-- 标记颜色映射（内置兜底；运行时优先取主题 palette 的 marker_<type> 键）
Fireteam.Marker.COLORS = {
    waypoint  = Color(100, 200, 255),
    enemy     = Color(255, 60, 60),
    objective = Color(255, 200, 50),
    danger    = Color(255, 120, 0),
    rally     = Color(50, 255, 100),
    medical   = Color(255, 255, 255)
}

--- 取标记类型颜色：主题 palette.marker_<type> 优先，缺省回退内置色
function Fireteam.Marker.GetTypeColor(markerType)
    if Fireteam.UI and Fireteam.UI.Color then
        local themed = Fireteam.UI.Color("marker_" .. tostring(markerType))
        -- UI.Color 对未知键返回白色兜底，此时改用内置色
        if themed and not (themed.r == 255 and themed.g == 255 and themed.b == 255 and markerType ~= "medical") then
            return themed
        end
    end
    return Fireteam.Marker.COLORS[markerType] or Color(255, 255, 255)
end

-- 标记生命周期（秒）
Fireteam.Marker.LIFETIME = 120

-- 最大标记数（每人）
Fireteam.Marker.MAX_PER_PLAYER = 3

print("[FIRETEAM:Marker] ✓ 共享定义已加载")
