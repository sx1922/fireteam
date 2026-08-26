-- _template/classes.lua
-- ═════════════════════════════════════════════════════════════
-- 职业定义。核心原则：通过 Tag 引用武器，绝不写死武器类名。
--
-- loadout 解析顺序（sv_class.ApplyLoadout）：
--   1. WeaponInterface.FilterByTags(slot.tags) 在已发现的工坊武器中筛选 → 随机 Give 一把
--   2. 无武器命中 → Inventory.GrantForSlot 按 items.lua 的 slots 字段发放消耗品
--      （例：grenade 槽没有手雷武器时，发 items.lua 里 slots 含 "grenade" 的物品）
--
-- stats 字段：
--   speed_mult    移速倍率（走 200 / 跑 400 基准；与力竭/腿伤在 vitals.RecalcSpeed 统一收口）
--   armor         0~3：引擎护甲 = ×25；最大生命 = 100 + armor×10
--   stamina       体力上限（冲刺耗 9/s、回复 12/s、滞回力竭禁冲刺）
--   radio_access  电台准入（预留）
--   radio_channels 可收听的频道列表（预留；实际权限走 voice_presets 的 access）
--
-- abilities：能力展示标签（F8 职业卡片显示；call_medical 等为约定俗成名）
--
-- 职业 id 建议「角色_阵营」格式（如 squad_leader_usa）——
-- 语音指挥频道的 access 权限按职业 id 列表校验（见 voice_presets.lua）。
-- ═════════════════════════════════════════════════════════════
return {

    rifleman_alpha = {
        name = "Rifleman",
        name_zh = "步枪手",
        faction = "faction_alpha",          -- 必须是 factions.lua 里的 key
        icon = "fireteam/classes/rifleman.png",

        loadout = {
            primary = {
                tags = { "faction_alpha", "assault_rifle" },
                count = 1
            },
            secondary = {
                tags = { "faction_alpha", "pistol" },
                count = 1,
                optional = true              -- 池里没有匹配武器时跳过，不报错
            },
            grenade = {
                tags = { "faction_alpha", "frag_grenade" },
                count = 2
            }
        },

        stats = {
            speed_mult = 1.0,
            armor = 1,
            stamina = 100,
            radio_access = true
        },

        abilities = { "mark_target", "call_medical" }
    },

    leader_alpha = {
        name = "Squad Leader",
        name_zh = "小队长",
        faction = "faction_alpha",
        icon = "fireteam/classes/leader.png",

        loadout = {
            primary = {
                tags = { "faction_alpha", "assault_rifle" },
                count = 1
            },
            sidearm = {                      -- 槽名任意；与 items.lua 的 slots 对应即可发物品
                tags = { "faction_alpha", "pistol" },
                count = 1
            }
        },

        stats = {
            speed_mult = 0.95,
            armor = 1,
            stamina = 100,
            radio_access = true,
            radio_channels = { "squad", "command" }
        },

        abilities = { "mark_target", "call_medical", "issue_orders" }
    }

    -- ⬇ 在此添加更多职业。PvE 模式下 AI 阵营的玩家方职业照常由真人选择，
    --   AI 敌军使用 ft_bot_teammate（NextBot），不走职业系统。
}
