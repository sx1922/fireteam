-- setting_packs/coldwar/weapon_overrides.lua
-- BOCW class names are not descriptive in PrintName/Category, so keep
-- the complete Cold War weapon mapping here as an explicit safety net.

local WEST = { "nato", "coldwar_west", "coldwar" }
local EAST = { "warsaw_pact", "coldwar_east", "coldwar" }

return {
    ["cw_xm4"] = { tags = WEST, category = "rifle" },
    ["cw_m16"] = { tags = WEST, category = "rifle" },
    ["cw_krig6"] = { tags = WEST, category = "rifle" },
    ["cw_milano"] = { tags = WEST, category = "smg" },
    ["cw_mp5"] = { tags = WEST, category = "smg" },
    ["cw_mac10"] = { tags = WEST, category = "smg" },
    ["cw_lc10"] = { tags = WEST, category = "smg" },
    ["cw_1911"] = { tags = WEST, category = "pistol" },
    ["cw_gallo"] = { tags = WEST, category = "shotgun" },
    ["cw_hauer77"] = { tags = WEST, category = "shotgun" },
    ["cw_diamatti"] = { tags = WEST, category = "pistol" },
    ["cw_magnum"] = { tags = WEST, category = "revolver" },
    ["cw_dmr14"] = { tags = WEST, category = "dmr" },

    ["cw_ak47"] = { tags = EAST, category = "rifle" },
    ["cw_ak74u"] = { tags = EAST, category = "smg" },
    ["cw_bullfrog"] = { tags = EAST, category = "smg" },
    ["cw_groza"] = { tags = EAST, category = "rifle" },
    ["cw_ffar"] = { tags = EAST, category = "rifle" },

    -- Easter egg: keep it available only to an explicitly opted-in pool.
    ["cw_raygun"] = { tags = { "coldwar", "special", "easter_egg" }, category = "special" },

    -- TFA 武器补充映射（PrintName/Category 不含阵营信息，显式标注）
    -- 西方：M60 通用机枪（lmg）+ SVD 实为华约武器不在此列
    ["tfa_nam_m60_remake"] = { tags = { "nato", "coldwar_west", "coldwar" }, category = "lmg" },

    -- 东方：RPK 班用机枪（lmg）+ SVD 狙击步枪（dmr）
    ["tfa_ins2_wpn_rpkalash"] = { tags = { "warsaw_pact", "coldwar_east", "coldwar" }, category = "lmg" },
    ["tfa_nam_svd"] = { tags = { "warsaw_pact", "coldwar_east", "coldwar" }, category = "dmr" },

    -- 手雷补映射：F1（华约）/ M67（北约）破片手雷，供 grenade 槽匹配
    ["weapon_f1gnade"] = { tags = { "warsaw_pact", "coldwar_east", "frag_grenade", "explosive" }, category = "grenade" },
    ["weapon_m67gnade"] = { tags = { "nato", "coldwar_west", "frag_grenade", "explosive" }, category = "grenade" },
}
