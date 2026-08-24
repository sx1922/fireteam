-- setting_packs/coldwar/weapons.lua
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

    pools = {
        western_alliance = {
            tags = { "nato", "coldwar_west" },
            max_weapons_per_class = 5
        },
        eastern_bloc = {
            tags = { "warsaw_pact", "coldwar_east" },
            max_weapons_per_class = 5
        },
        neutral_observers = {
            tags = { "neutral" },
            max_weapons_per_class = 3
        }
    },

    restrictions = {
        max_mag_count = 6,
        allowed_optics = { "iron", "scope_3x", "scope_6x" },
        banned_attachments = { "grip", "laser", "flashlight", "red_dot", "holographic" }
    }
}
