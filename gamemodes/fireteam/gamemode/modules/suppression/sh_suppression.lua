-- modules/suppression/sh_suppression.lua
-- FIRETEAM Suppression System - Shared

if not Fireteam then Fireteam = {} end
Fireteam.Suppression = Fireteam.Suppression or {}

-- 压制等级
Fireteam.Suppression.LEVEL = {
    NONE    = 0,
    LIGHT   = 1,    -- 轻微：准星微扩
    MEDIUM  = 2,    -- 中等：准星扩散 + 轻微模糊
    HEAVY   = 3,    -- 严重：大幅扩散 + 屏幕震动 + 强模糊
    PINNED  = 4     -- 压制：无法瞄准
}

-- 阈值
Fireteam.Suppression.THRESHOLDS = {
    [0] = 0,
    [1] = 0.2,
    [2] = 0.5,
    [3] = 0.8,
    [4] = 1.0
}

-- 根据压制值获取等级
function Fireteam.Suppression.GetLevel(value)
    local mult = Fireteam.Config.Get("ballistics.suppression_mult") or 1.0
    value = value * mult

    if value >= 1.0 then return 4
    elseif value >= 0.8 then return 3
    elseif value >= 0.5 then return 2
    elseif value >= 0.2 then return 1
    else return 0
    end
end

print("[FIRETEAM:Suppression] ✓ Shared definitions loaded")
