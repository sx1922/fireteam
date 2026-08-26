-- _template/weapons.lua
-- ═════════════════════════════════════════════════════════════
-- 武器池规则 & 全局过滤。
-- 工作流：工坊武器（ARC9/TFA 等）自带标签 → 本文件按标签准入 →
--         职业 loadout 的 tags 再从「已准入」的武器里随机挑选。
-- 查某把武器有什么标签：装上后游戏内查看，或查该武器 addon 说明。
-- ═════════════════════════════════════════════════════════════
return {

    -- 全局过滤器：任何阵营任何槽位都过这一关
    global_filter = {
        allowed_era = { "my_era" },       -- 武器须带其中至少一个时代标签
        banned_tags = {
            "anachronistic_weapon"        -- 不符合时代的武器（硬禁）
        }
    },

    -- 各阵营武器池：pools.<faction key 与 factions.lua 对应>
    pools = {
        faction_alpha = {
            tags = { "faction_alpha" },   -- 该阵营能用的武器标签
            max_weapons_per_class = 5     -- 单职业池上限（随机抽取范围）
        },
        faction_beta = {
            tags = { "faction_beta" },
            max_weapons_per_class = 5
        }
    },

    -- 附件 / 弹药限制（展示性约定，供适配器消费）
    restrictions = {
        max_mag_count = 6,
        allowed_optics = { "iron", "scope_3x", "red_dot" },
        banned_attachments = { "laser", "thermal" }
    }
}
