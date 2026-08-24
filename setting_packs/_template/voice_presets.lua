-- _template/voice_presets.lua
return {

    model = "digital",   -- analog_radio | digital | direct | field_phone

    channels = {
        squad = {
            name = "Squad Net",
            range = 600,
            interference = true,
            encryption = false
        },
        command = {
            name = "Command Net",
            range = 2000,
            interference = true,
            encryption = true,
            access = { "leader_alpha" }
        },
        emergency = {
            name = "Emergency",
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
