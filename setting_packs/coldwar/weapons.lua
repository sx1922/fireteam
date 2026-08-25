-- setting_packs/coldwar/weapons.lua
-- 武器池：按现实国家划分，标签解析仍以集团级为主（nato/warsaw_pact），
-- 国别标签供安装的武器包做细分（如 ARC9 各国武器打上对应 tag）。

local NATO = { "usa", "uk", "west_germany", "france" }
local WTO  = { "ussr", "east_germany", "poland", "czechoslovakia" }

local pools = {}

for _, id in ipairs(NATO) do
    pools[id] = {
        tags = { "nato", "coldwar_west", id },
        max_weapons_per_class = 5
    }
end

for _, id in ipairs(WTO) do
    pools[id] = {
        tags = { "warsaw_pact", "coldwar_east", id },
        max_weapons_per_class = 5
    }
end

pools.un_observers = {
    tags = { "neutral" },
    max_weapons_per_class = 3
}

return {

    global_filter = {
        allowed_era = { "coldwar", "pre_coldwar" },
        banned_tags = {
            "modern_optic",
            "digital_cammo",
            "smart_weapon",
            "laser_sight",
            "red_dot",
            "thermal_scope",
            "picatinny_rail",
            "polymer_frame"
        }
    },

    pools = pools,

    restrictions = {
        max_mag_count = 6,
        allowed_optics = { "iron", "scope_3x", "scope_6x" },
        banned_attachments = { "grip", "laser", "flashlight", "red_dot", "holographic" }
    }
}
