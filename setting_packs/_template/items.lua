-- _template/items.lua
-- ═════════════════════════════════════════════════════════════
-- 物品定义模板（塔科夫式网格背包 + 消耗品）。
--
-- category 三类与生效方式：
--   consumable  读完条生效——效果由其他模块经
--               Fireteam.Inventory.RegisterUseHandler("consumable", fn) 注册；
--               vitals 模块已内置 bandage（止血）/ splint（修骨折黑腿）/
--               analgesic（止痛）/ medkit（治部位+清出血）四个医疗效果，
--               未注册效果的 consumable 使用时提示"无效果"且不消耗
--   throwable   投掷物：框架内置抛掷（必须带 throw 表：model/fuse/radius/damage/throw_speed）
--   deployable  放置物：效果由模块注册（resupply 已注册弹药盒）
--
-- 字段：
--   slots            可服务的职业装备槽位名（classes.lua loadout 的键）；
--                    武器池无命中时按槽名 + factions 白名单发放
--   amount_per_slot  该槽位发放数量（缺省取 max_carry）
--   max_carry        持有上限
--   use_time         使用读条秒数（throwable 最短受 1 秒投掷间隔约束）
--   size             背包网格占格 {w,h}（10×6 网格；缺省 1×1）
--   icon             预留：物品图标 fireteam/items/<itemId>.png
-- ═════════════════════════════════════════════════════════════

return {

    items = {

        bandage = {
            name = "Bandage",       name_zh = "绷带",
            category = "consumable",
            tags = { "medical", "bandage" },
            slots = { "medical" },
            max_carry = 6,
            amount_per_slot = 4,
            use_time = 2.5
            -- size 缺省 1×1
        },

        splint = {
            name = "Splint",        name_zh = "夹板",
            category = "consumable",
            tags = { "medical", "splint" },
            slots = { "medical" },
            max_carry = 3,
            amount_per_slot = 1,
            use_time = 3.0          -- 固定骨折 / 恢复黑腿部分血量（vitals 注册）
        },

        analgesic = {
            name = "Painkillers",   name_zh = "止痛药",
            category = "consumable",
            tags = { "medical", "painkiller" },
            slots = { "medical" },
            max_carry = 3,
            amount_per_slot = 2,
            use_time = 1.5          -- 限时屏蔽腿伤减速与臂伤晃动（vitals 注册）
        },

        frag_grenade = {
            name = "Frag Grenade",  name_zh = "破片手雷",
            category = "throwable",
            tags = { "frag_grenade", "explosive" },
            slots = { "grenade" },
            max_carry = 3,
            amount_per_slot = 2,
            use_time = 0,
            throw = {
                model = "models/weapons/w_grenade.mdl",   -- 占位模型（HL2 手雷）
                fuse = 3.0,
                radius = 340,
                damage = 90,
                throw_speed = 900
            }
        }

    }

}
