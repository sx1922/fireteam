-- _template/map_rules.lua
return {

    supported_entities = {
        "ft_prop_radio_relay",
        "ft_trigger_interference_zone",
        "ft_entity_intel_object"
    },

    rules = {
        fog_density = 0.01,
        time_of_day = "noon",
        weather = "clear",
        civilian_allowed = false,
        checkpoint_mode = false
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
        }
    }
}
