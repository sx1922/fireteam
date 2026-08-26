-- _template/vehicles.lua
-- ═════════════════════════════════════════════════════════════
-- 载具规则：结构与 weapons.lua 同构（global_filter + pools）。
-- 载具基座经适配器桥接（LVS / Simfphys 等），标签同样来自工坊 addon。
-- 座位交互（E 键提示 / 职业门槛座位 / 车载电台）由 seats 模块消费。
-- ═════════════════════════════════════════════════════════════
return {

    global_filter = {
        allowed_era = { "my_era" },
        banned_tags = { "anachronistic_vehicle" }
    },

    pools = {
        faction_alpha = {
            transport = {                      -- 分类名任意（展示/配额用）
                tags = { "faction_alpha", "transport" },
                min_capacity = 6,              -- 最少座位数
                max_armor = 1                  -- 装甲等级上限
            },
            recon = {
                tags = { "faction_alpha", "recon" },
                max_armor = 0
            }
        },
        faction_beta = {
            transport = {
                tags = { "faction_beta", "transport" },
                min_capacity = 8,
                max_armor = 1
            },
            armor = {
                tags = { "faction_beta", "tank" },
                max_count = 1                  -- 全场同分类数量上限
            }
        }
    }
}
