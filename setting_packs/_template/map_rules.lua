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
    },

    -- ══ 回合制任务数据（rounds 模块消费）══
    -- 位置写法两种：{ x=,y=,z= } 绝对坐标，或
    -- { anchor="map_center"|"nav_random", offset={x=,y=,z=} } 地图相对锚点。
    --
    -- 剧本（多套任务/出生点切换）写法：把 objectives/spawns 包进 scenarios 表，
    --   default_scenario = "scenario_a",
    --   scenarios = {
    --       scenario_a = { name="...", name_zh="...", objectives={...}, spawns={...}, timings={ briefing=8, round_time=420 } },
    --       scenario_b = { ... },
    --   }
    -- 每个剧本可带 timings 短键覆盖（warmup/briefing/round_time/ended/intermission）。
    -- 切换用控制台 ft_scenario <id> 或 F10 管理面板，下一回合简报生效。
    -- 不声明 scenarios 时，下方平铺的 objectives/spawns 作为隐式单剧本照常工作（向后兼容）。
    rounds = {
        enabled = false,             -- 模板包默认关闭；启用请改 true 并配置 objectives
        warmup_time = 30,            -- 热身秒数
        briefing_time = 10,          -- 简报（冻结）秒数
        round_time = 600,            -- 回合时长秒数
        ended_time = 10,             -- 结算屏展示秒数
        intermission_time = 15,      -- 幕间休整秒数
        kill_points = 1,             -- 击杀得分（跨阵营）
        objective_points = 3,        -- 目标完成得分
        score_limit = nil,           -- 数字：达到该分提前结束回合；nil 不启用

        -- 目标轮转表，type ∈ hold_zone | eliminate | destroy_entity | extract
        objectives = {
            {
                name = "example_hold",
                type = "hold_zone",
                zone = { anchor = "map_center", offset = { x = 600, y = 0, z = 0 } },
                radius = 220,        -- 区域半径（世界单位）
                capture_time = 30    -- 占领所需秒数
            },
            {
                name = "example_destroy",
                type = "destroy_entity",
                target_classes = { "ft_prop_radio_relay" },
                spawn = {            -- 场上无实例时的降级生成（可选）
                    pos = { anchor = "map_center", offset = { x = -700, y = 200, z = 0 } },
                    model = "models/props_lab/monitor01b.mdl"
                }
            },
            {
                name = "example_extract",
                type = "extract",
                zone = { anchor = "map_center", offset = { x = 0, y = -800, z = 0 } },
                radius = 180,
                hold_time = 45       -- 累计在场秒数（按人数加速）
            },
            {
                name = "example_eliminate",
                type = "eliminate"
            }
        },

        -- 阵营出生点（round-robin）；缺省则不传送
        spawns = {
            your_faction_id = {
                { pos = { anchor = "map_center", offset = { x = -1400, y = 0, z = 0 } } },
                { pos = { anchor = "map_center", offset = { x = -1500, y = 300, z = 0 } } }
            },
            enemy_faction_id = {
                { pos = { anchor = "map_center", offset = { x = 1400, y = 0, z = 0 } } },
                { pos = { anchor = "map_center", offset = { x = 1500, y = -300, z = 0 } } }
            }
        }
    }
}
