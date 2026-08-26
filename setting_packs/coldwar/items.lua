-- setting_packs/coldwar/items.lua
-- 消耗品定义：冷战题材。物品按 slots 声明可服务的职业装备槽位
-- （grenade/medical/ammo_belt 等），武器池无命中时由背包系统按槽名发放。
-- factions 字段可选：声明后仅该阵营可获得。

return {

    items = {

        bandage = {
            name = "Bandage",          name_zh = "绷带",
            category = "consumable",
            tags = { "medical", "bandage" },
            slots = { "medical" },
            max_carry = 6,
            amount_per_slot = 4,
            use_time = 2.5,            -- 使用读条（秒）
        },

        medkit = {
            name = "Field Med Kit",    name_zh = "野战医疗包",
            category = "consumable",
            tags = { "medical", "medkit" },
            slots = { "medical" },
            max_carry = 2,
            amount_per_slot = 1,
            use_time = 4.0,
        },

        splint = {
            name = "Splint",           name_zh = "夹板",
            category = "consumable",
            tags = { "medical", "splint" },
            slots = { "medical" },
            max_carry = 3,
            amount_per_slot = 1,
            use_time = 3.0,            -- 固定骨折 / 恢复黑腿部分血量
        },

        analgesic = {
            name = "Painkillers",      name_zh = "止痛药",
            category = "consumable",
            tags = { "medical", "painkiller" },
            slots = { "medical" },
            max_carry = 3,
            amount_per_slot = 2,
            use_time = 1.5,            -- 限时屏蔽腿伤减速与臂伤晃动
        },

        frag_grenade = {
            name = "Frag Grenade",     name_zh = "破片手雷",
            category = "throwable",
            tags = { "frag_grenade", "explosive" },
            slots = { "grenade" },
            max_carry = 3,
            amount_per_slot = 2,
            use_time = 0,
            throw = {
                -- 占位模型（HL2 手雷）；工坊内容就位后可换 cw 时期模型
                model = "models/weapons/w_grenade.mdl",
                fuse = 3.0,
                radius = 340,
                damage = 90,
                throw_speed = 900
            }
        },

        ammo_box = {
            name = "Ammo Box",         name_zh = "弹药盒",
            category = "deployable",
            tags = { "ammo", "deployable" },
            slots = { "ammo_belt" },
            max_carry = 2,
            amount_per_slot = 1,
            use_time = 1.0,
        }

    }

}
