-- modules/resupply/sh_resupply.lua
-- FIRETEAM Resupply System - Shared（弹药与补给）
-- 备弹池（loadout 按武器补满备弹）、可放置弹药盒、尸体搜刮。
-- 数值走 config；纯函数供 harness 离线验证。

if not Fireteam then Fireteam = {} end
Fireteam.Resupply = Fireteam.Resupply or {}

Fireteam.Config.Register("resupply.reserve_primary", 240, {
    type = "number", min = 0, max = 999,
    desc = "Primary ammo reserve filled at loadout"
})
Fireteam.Config.Register("resupply.reserve_secondary", 64, {
    type = "number", min = 0, max = 999,
    desc = "Secondary ammo reserve filled at loadout"
})
Fireteam.Config.Register("resupply.crate_uses", 4, {
    type = "number", min = 1, max = 20,
    desc = "Resupply charges per deployed ammo crate"
})
Fireteam.Config.Register("resupply.loot_enabled", true, {
    type = "boolean",
    desc = "Allow looting ammo/items from corpses (E)"
})
Fireteam.Config.Register("resupply.loot_frac", 0.5, {
    type = "number", min = 0.1, max = 1,
    desc = "Fraction of corpse reserves transferred per loot"
})

--- 备弹缺口：当前低于目标时返回需补数量，否则 0
function Fireteam.Resupply.ReserveDelta(current, target)
    return math.max((tonumber(target) or 0) - (tonumber(current) or 0), 0)
end

--- 尸体搜刮份额：按比例向下取整，>0 的至少给 1
function Fireteam.Resupply.ComputeLoot(counts, frac)
    local out = {}
    for k, count in pairs(counts or {}) do
        count = tonumber(count) or 0
        if count > 0 then
            local give = math.floor(count * (tonumber(frac) or 0.5))
            if give < 1 then give = 1 end
            out[k] = math.min(give, count)
        end
    end
    return out
end

--- 弹药盒剩余次数是否还能补给
function Fireteam.Resupply.CrateUsable(usesLeft)
    return (tonumber(usesLeft) or 0) > 0
end
