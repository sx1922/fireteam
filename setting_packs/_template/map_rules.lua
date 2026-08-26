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

    -- ══ 健康与医疗参数（可选，vitals 模块消费）══
    -- 不声明本块时全部走 config 兜底；声明后按 剧本内 vitals > 此处 > config 解析。
    -- enabled=false 可整体关闭倒地/出血系统（恢复原版即死）。
    vitals = {
        enabled           = true,
        head_mult         = 2.5,    -- 爆头倍率
        chest_mult        = 1.0,
        stomach_mult      = 0.85,
        limb_mult         = 0.6,    -- 四肢减伤
        max_bleed_stacks  = 5,      -- 出血层数上限
        bleed_dps_per_stack = 1.2,  -- 每层每秒掉血
        bleedout_time     = 60,     -- 倒地失血时限（秒）
        stabilize_time    = 3.5,    -- 队友按 E 稳定读条（秒）
        revive_time       = 7,      -- 医疗兵持医疗包复活读条（秒，需背包有 medkit）
        revive_health_frac = 0.4,   -- 复活后回复 HP 比例
        downed_speed      = 40,     -- 倒地匍匐速度
        finish_damage     = 25,     -- 补刀倒地单位所需单次伤害

        -- ── 塔科夫式七部位模型（P6a）──
        -- head 35 / thorax 85 / stomach 70 / 双臂 60 / 双腿 65（基础血量，config 可调）。
        -- 黑部位伤害整笔转移胸腔；头/胸黑=立即死亡（不走倒地）；胃黑=出血拉满；
        -- 腿黑/骨折=减速；臂黑=开火扩散；医疗品（绷带/夹板/止痛药/医疗包）真实生效。
        limbs_enabled     = true,
        fracture_chance   = 0.25,   -- 腿部受击骨折概率（打黑必骨折）
        painkiller_time   = 60,     -- 止痛药持续秒数（屏蔽腿瘸/臂晃）
        leg_speed_mult    = 0.55,   -- 单腿黑/骨折移速倍率（双腿 0.35 另有键）
        medkit_heal_frac  = 0.5     -- 医疗包恢复部位血量比例
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
    --
    -- 运行时扩展（不改本文件）：第三方插件可用 Fireteam.Rounds.RegisterScenario 注册全新剧本，
    -- 或 AddScenarioObjective / RemoveScenarioObjective / AddScenarioSpawn /
    -- SetScenarioTimings / OverrideScenarioVitals / SetScenarioPvE 在扩展层定制任意剧本；
    -- 解析按「基础 ← 扩展层」合成，重载设定包即还原。详见 README「剧本扩展 API」。
    --
    -- PvE 战役（可选）：剧本内（或 rounds 平铺层）声明 pve 表即定义 AI 阵营，
    --   pve = {
    --       player_factions  = { "faction_a" },  -- 玩家方可选阵营；缺省视为全部阵营归玩家方
    --       ai_factions      = { "faction_b" },  -- 简报期生成 AI NextBot 的阵营
    --       bots_per_faction = 4,                -- 每 AI 阵营 bot 数（缺省读 config pve.bots_per_faction）
    --       ai_behavior      = "advance",        -- advance 向当前目标推进 | defend 原地驻防
    --   }
    -- 管理员用 F10 面板或 ft_mode pvp|pve 切换；PvE 下目标按表顺序逐关推进：
    -- 过关进入下一关，失败重试本关，通关后回到第 1 关；切换 mode/剧本会重置进度。
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
