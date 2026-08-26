-- setting_packs/_template/items.lua
-- 消耗品定义模板。
-- 契约：
--   category: "consumable"（读完条生效，效果由其他模块经 RegisterUseHandler 注册）
--             "throwable"（投掷物，框架内置抛掷，需 throw 表）
--             "deployable"（放置物，效果由其他模块注册）
--   slots:    本物品可服务的职业装备槽位名列表（classes.lua loadout 的键）；
--             武器池无命中时按槽名 + 可选 factions 白名单发放
--   amount_per_slot: 该槽位发放数量（缺省取 max_carry）
--   use_time: 使用读条秒数；throwable 最短受 1 秒投掷间隔约束

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
                model = "models/weapons/w_grenade.mdl",
                fuse = 3.0,
                radius = 340,
                damage = 90,
                throw_speed = 900
            }
        }

    }

}
