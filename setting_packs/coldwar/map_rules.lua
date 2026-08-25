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
    },

    -- ══ 回合制任务数据（coldwar 示例战役）
    -- 锚点定位保证任意有 navmesh 的地图可玩；
    -- 偏移量为示意值，具体地图可按需微调。
    rounds = {
        enabled = true,
        warmup_time = 30,
        briefing_time = 10,
        round_time = 480,
        ended_time = 10,
        intermission_time = 15,
        kill_points = 1,
        objective_points = 3,
        score_limit = nil,

        objectives = {
            {
                name = "checkpoint_hold",
                type = "hold_zone",
                zone = { anchor = "map_center", offset = { x = 600, y = 0, z = 0 } },
                radius = 220,
                capture_time = 30
            },
            {
                name = "relay_strike",
                type = "destroy_entity",
                target_classes = { "ft_prop_radio_relay" },
                spawn = {
                    pos = { anchor = "map_center", offset = { x = -700, y = 200, z = 0 } },
                    model = "models/props_lab/monitor01b.mdl"
                }
            },
            {
                name = "fallback_extract",
                type = "extract",
                zone = { anchor = "map_center", offset = { x = 0, y = -800, z = 0 } },
                radius = 180,
                hold_time = 45
            },
            {
                name = "last_stand",
                type = "eliminate"
            }
        },

        spawns = {
            western_alliance = {
                { pos = { anchor = "map_center", offset = { x = -1400, y = -400, z = 64 } } },
                { pos = { anchor = "map_center", offset = { x = -1500, y = 0, z = 64 } } },
                { pos = { anchor = "map_center", offset = { x = -1400, y = 400, z = 64 } } },
                { pos = { anchor = "map_center", offset = { x = -1300, y = 0, z = 64 } } }
            },
            eastern_bloc = {
                { pos = { anchor = "map_center", offset = { x = 1400, y = 400, z = 64 } } },
                { pos = { anchor = "map_center", offset = { x = 1500, y = 0, z = 64 } } },
                { pos = { anchor = "map_center", offset = { x = 1400, y = -400, z = 64 } } },
                { pos = { anchor = "map_center", offset = { x = 1300, y = 0, z = 64 } } }
            }
        }
    }
}
