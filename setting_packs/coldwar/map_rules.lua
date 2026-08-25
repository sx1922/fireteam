-- setting_packs/coldwar/map_rules.lua
-- 地图规则与回合任务数据（coldwar 示例战役）
-- 出生点按国家划分：北约四国沿西侧展开，华约四国沿东侧展开，
-- 各占一条纵向带（4 点/国）；锚点定位保证任意有 navmesh 的地图可玩。

local NATO = { { id = "usa", y = -1050 }, { id = "uk", y = -350 },
               { id = "west_germany", y = 350 }, { id = "france", y = 1050 } }
local WTO  = { { id = "ussr", y = -1050 }, { id = "east_germany", y = -350 },
               { id = "poland", y = 350 }, { id = "czechoslovakia", y = 1050 } }

--- 一条国家出生带：4 个点位，x 固定侧翼，y 以国家基准上下铺开
local function spawnBand(sideSign, baseY)
    local points = {}
    for i, dy in ipairs({ -150, -50, 50, 150 }) do
        points[#points + 1] = {
            pos = {
                anchor = "map_center",
                offset = { x = sideSign * 1400, y = baseY + dy, z = 64 }
            }
        }
    end
    return points
end

local spawns = {}
for _, n in ipairs(NATO) do spawns[n.id] = spawnBand(-1, n.y) end
for _, n in ipairs(WTO)  do spawns[n.id] = spawnBand(1, n.y) end

-- 中立观察员：中央偏南的小型缓冲区
spawns.un_observers = {
    { pos = { anchor = "map_center", offset = { x = -150, y = 1250, z = 64 } } },
    { pos = { anchor = "map_center", offset = { x =   -50, y = 1300, z = 64 } } },
    { pos = { anchor = "map_center", offset = { x =    50, y = 1300, z = 64 } } },
    { pos = { anchor = "map_center", offset = { x =  150, y = 1250, z = 64 } } },
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

        spawns = spawns
    }
}
