-- modules/tacmap/sh_tacmap.lua
-- FIRETEAM Tactical Map - Shared
-- M 键战术地图：程序化"纸质图纸"画布，不依赖地图俯视图素材。

if not Fireteam then Fireteam = {} end
Fireteam.TacMap = Fireteam.TacMap or {}

-- 配置项
Fireteam.Config.Register("tacmap.enabled", true, {
    type = "boolean",
    desc = "Enable the tactical map (M key)"
})
Fireteam.Config.Register("tacmap.grid_step", 1024, {
    type = "number", min = 256, max = 8192,
    desc = "Map grid step in world units"
})
Fireteam.Config.Register("tacmap.allow_click_place", true, {
    type = "boolean",
    desc = "Allow placing waypoints by clicking the map"
})

-- 客户端自动推算边界失败时的兜底半宽（世界单位）
Fireteam.TacMap.FALLBACK_HALF_EXTENT = 6144

--- 读取设定包 map_rules.map.bounds
--- 期望结构：bounds_min/bounds_max 各为 Vector 或 {x,y} 表；z 忽略
function Fireteam.TacMap.GetPackBounds()
    local rules = Fireteam.Setting.GetData("map_rules")
    if not (rules and rules.map and rules.map.bounds) then return nil end

    local b = rules.map.bounds
    local function toVec(v)
        if isvector(v) then return v end
        if istable(v) and v.x and v.y then return Vector(v.x, v.y, 0) end
        return nil
    end

    local vmin, vmax = toVec(b.bounds_min), toVec(b.bounds_max)
    if vmin and vmax then return vmin, vmax end
    return nil
end

print("[FIRETEAM:TacMap] ✓ 共享定义已加载")
