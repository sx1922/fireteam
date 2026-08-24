-- setting_packs/coldwar/map_rules.lua
return {

    supported_entities = {
        "ft_prop_radio_relay",
        "ft_trigger_interference_zone",
        "ft_entity_intel_object",
        "ft_decoy_tank",
        "ft_checkpoint",
        "ft_bunker_entrance"
    },

    rules = {
        fog_density = 0.02,
        time_of_day = "dawn",
        weather = "overcast",
        civilian_allowed = false,
        checkpoint_mode = true
    },

    trigger_overrides = {
        interference_zone = {
            radius = 300,
            strength = 0.8,
            affects = { "squad_radio", "command_radio" }
        },
        radio_relay = {
            boost_range = 1.5,
            can_be_destroyed = true
        },
        checkpoint = {
            detection_radius = 200,
            alarm_triggers_reinforcement = true
        }
    }
}
