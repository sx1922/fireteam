-- _template/voice_presets.lua
return {

    model = "digital",   -- analog_radio | digital | direct | field_phone

    channels = {
        ["local"] = {
            name = "Local",
            name_zh = "地区频道",
            kind = "local",
            range = 800,
            interference = false,
            access = "all"
        },
        squad = {
            name = "Squad Net",
            name_zh = "小队频道",
            kind = "squad",
            range = 600,
            interference = true,
            encryption = false
        },
        command = {
            name = "Command Net",
            name_zh = "指挥频道",
            kind = "command",
            range = 2000,
            interference = true,
            encryption = true,
            access = { "leader_alpha" }
        },
        emergency = {
            name = "Emergency",
            name_zh = "应急频道",
            kind = "all",
            range = 1200,
            interference = false,
            access = "all"
        }
    },

    effects = {
        radio_static = true,
        distance_falloff = true,
        terrain_occlusion = true,
        vehicle_noise_reduction = 0.4
    },

    voice_packs = {
        faction_alpha = "sound/fireteam/my_setting/voice_alpha/",
        faction_beta  = "sound/fireteam/my_setting/voice_beta/"
    }
}
