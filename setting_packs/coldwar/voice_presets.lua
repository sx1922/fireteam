-- setting_packs/coldwar/voice_presets.lua
return {

    model = "analog_radio",

    channels = {
        squad = {
            name = "Squad Net",
            range = 500,
            interference = true,
            encryption = false
        },
        command = {
            name = "Command Net",
            range = 2000,
            interference = true,
            encryption = true,
            access = { "squad_leader_west", "squad_leader_east", "commissar_east", "radio_operator_west" }
        },
        emergency = {
            name = "Emergency",
            range = 1000,
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
        western_alliance = "sound/fireteam/coldwar/voice_en/",
        eastern_bloc = "sound/fireteam/coldwar/voice_ru/"
    }
}
