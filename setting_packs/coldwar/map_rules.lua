-- setting_packs/coldwar/map_rules.lua
-- 地图规则与回合任务数据（coldwar 示例战役）
-- 双剧本（scenarios）：
--   fulda_gap 富尔达缺口（默认）——北约西翼防御带 vs 华约东翼突击轴，8 国全线展开
--   berlin    西柏林之战 —— 三国守军紧凑中央防区，华约三线压上；城市攻坚节奏更快
-- 出生点按国家划分，各占一条纵向带（4 点/国）；锚点定位保证任意有 navmesh 的地图可玩。

--- 一条国家出生带：4 个点位沿 y 铺开（x 固定侧翼，y 以基准上下铺开）
--- 缺省 xDist=1400 / spread=100 时与旧版几何完全一致（dy = -150/-50/+50/+150）
local function spawnBand(sideSign, baseY, xDist, spread)
    xDist  = xDist or 1400
    spread = spread or 100
    local points = {}
    for _, k in ipairs({ -1.5, -0.5, 0.5, 1.5 }) do
        points[#points + 1] = {
            pos = {
                anchor = "map_center",
                offset = { x = sideSign * xDist, y = baseY + k * spread, z = 64 }
            }
        }
    end
    return points
end

-- ── 剧本 1 出生：富尔达缺口，东西两条对峙面 ──
local spawns_fulda = {
    usa            = spawnBand(-1, -1050),
    uk             = spawnBand(-1,  -350),
    west_germany   = spawnBand(-1,   350),
    france         = spawnBand(-1,  1050),
    ussr           = spawnBand( 1, -1050),
    east_germany   = spawnBand( 1,  -350),
    poland         = spawnBand( 1,   350),
    czechoslovakia = spawnBand( 1,  1050)
}

-- ── 剧本 2 出生：西柏林之战 ──
-- 守军 = 美英法三国驻军（历史上西柏林仅此三国驻军），中央紧凑防区；
-- 西德按四国协定的游戏化处理摆在远西外围充当解围援军；
-- 苏军 + 东德柏林军区构成东弧主攻，波/捷作为第二梯队从东北、东南后方跟进。
local spawns_berlin = {
    usa            = spawnBand(-1, -260,  420, 70),   -- 美占区（中央北段）
    uk             = spawnBand(-1,    0,  360, 70),   -- 英占区（正中）
    france         = spawnBand(-1,  260,  420, 70),   -- 法占区（中央南段）
    west_germany   = spawnBand(-1,  900, 1600),       -- 远西外围解围部队
    ussr           = spawnBand( 1, -400, 1500, 130),  -- 东弧主攻·北半轴
    east_germany   = spawnBand( 1,  100, 1450, 130),  -- 东弧主攻·中南轴
    poland         = spawnBand( 1,  950, 1900),       -- 第二梯队·东北后方
    czechoslovakia = spawnBand( 1, -950, 1900)        -- 第二梯队·东南后方
}

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

    -- ══ 回合制任务数据 ══
    -- 目标锚点基于地图中心，与具体国家无关；
    -- 多国会战时按各阵营分别计分与判定。
    -- 剧本切换：控制台 ft_scenario <id> 或 F10 管理面板，下一回合简报生效。
    rounds = {
        enabled = true,
        default_scenario = "fulda_gap",
        warmup_time = 30,
        briefing_time = 10,
        round_time = 480,
        ended_time = 10,
        intermission_time = 15,
        kill_points = 1,
        objective_points = 3,
        score_limit = nil,

        scenarios = {

            -- ══ 剧本 1：富尔达缺口 ══
            -- 想定：华约装甲洪流穿越走廊直扑莱茵河，北约且战且退、守待增援。
            fulda_gap = {
                name = "Fulda Gap",
                name_zh = "富尔达缺口",

                objectives = {
                    {   -- 占区：边境哨所「阿尔法点」（真实地标 Point Alpha）
                        name = "Point Alpha",
                        name_zh = "阿尔法点哨所",
                        type = "hold_zone",
                        zone = { anchor = "map_center", offset = { x = 600, y = 0, z = 0 } },
                        radius = 220,
                        capture_time = 30
                    },
                    {   -- 摧毁：巴特黑斯费尔德通信中继，切断北约指挥链
                        name = "Bad Hersfeld Relay",
                        name_zh = "巴特黑斯费尔德中继站",
                        type = "destroy_entity",
                        target_classes = { "ft_prop_radio_relay" },
                        spawn = {
                            pos = { anchor = "map_center", offset = { x = -700, y = 200, z = 0 } },
                            model = "models/props_lab/monitor01b.mdl"
                        }
                    },
                    {   -- 撤离：经金齐希河谷走廊向莱茵方向退却
                        name = "Kinzig Extraction",
                        name_zh = "金齐希河谷撤离",
                        type = "extract",
                        zone = { anchor = "map_center", offset = { x = 0, y = -800, z = 0 } },
                        radius = 180,
                        hold_time = 45
                    },
                    {   -- 歼灭：福格尔斯贝格山前背水一战
                        name = "Vogelsberg Stand",
                        name_zh = "福格尔斯贝格背水一战",
                        type = "eliminate"
                    }
                },

                -- PvE 战役：玩家执北约守方，华约四国由 AI 沿走廊推进（管理员 ft_mode pve 启用）
                pve = {
                    player_factions = { "usa", "uk", "west_germany", "france" },
                    ai_factions     = { "ussr", "east_germany", "poland", "czechoslovakia" },
                    ai_behavior     = "advance"
                },

                spawns = spawns_fulda
            },

            -- ══ 剧本 2：西柏林之战 ══
            -- 想定：华约不越境封锁而是直取全城，三国守军背水固守等待空桥承诺。
            berlin = {
                name = "Battle of West Berlin",
                name_zh = "西柏林之战",

                -- 城市攻坚节奏更快：简报缩短、单回合压缩到 7 分钟
                timings = { briefing = 8, round_time = 420 },

                objectives = {
                    {   -- 占区：查理检查站突破（Friedrichstraße 通道口）
                        name = "Charlie Breach",
                        name_zh = "查理检查站突破",
                        type = "hold_zone",
                        zone = { anchor = "map_center", offset = { x = -300, y = 0, z = 0 } },
                        radius = 200,
                        capture_time = 25
                    },
                    {   -- 摧毁：瘫痪守军通讯中继，孤立各占区守备队
                        name = "Garrison Relay",
                        name_zh = "瘫痪守军通讯",
                        type = "destroy_entity",
                        target_classes = { "ft_prop_radio_relay" },
                        spawn = {
                            pos = { anchor = "map_center", offset = { x = 250, y = 180, z = 0 } },
                            model = "models/props_lab/monitor01b.mdl"
                        }
                    },
                    {   -- 撤离：滕珀尔霍夫机场空运撤出（1948 空运的历史回响）
                        name = "Tempelhof Airlift",
                        name_zh = "滕珀尔霍夫空运撤出",
                        type = "extract",
                        zone = { anchor = "map_center", offset = { x = -150, y = -650, z = 0 } },
                        radius = 200,
                        hold_time = 40
                    },
                    {   -- 歼灭：驻军最后抵抗
                        name = "Garrison Last Stand",
                        name_zh = "驻军最后抵抗",
                        type = "eliminate"
                    }
                },

                -- PvE 战役：玩家执华约攻方，三国守军由 AI 固守中央防区
                pve = {
                    player_factions = { "ussr", "east_germany" },
                    ai_factions     = { "usa", "uk", "france" },
                    ai_behavior     = "defend"
                },

                spawns = spawns_berlin
            }
        }
    }
}
