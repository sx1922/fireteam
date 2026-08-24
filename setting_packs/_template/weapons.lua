-- _template/weapons.lua
-- 武器池规则 & 全局过滤
return {

    -- 全局过滤器
    global_filter = {
        allowed_era = { "my_era" },
        banned_tags = {
            "anachronistic_weapon"   -- 不符合时代的武器
        }
    },

    -- 各阵营武器池
    pools = {
        faction_alpha = {
            tags = { "faction_alpha" },
            max_weapons_per_class = 5
        },
        faction_beta = {
            tags = { "faction_beta" },
            max_weapons_per_class = 5
        }
    },

    -- 附件 / 弹药限制
    restrictions = {
        max_mag_count = 6,
        allowed_optics = { "iron", "scope_3x", "red_dot" },
        banned_attachments = { "laser", "thermal" }
    }
}
