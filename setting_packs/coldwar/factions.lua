-- setting_packs/coldwar/factions.lua
-- 冷战阵营：现实国家（1968–1985）
-- 北约四国 vs 华约四国 + 联合国军事观察员。
-- 装备标签沿用集团级标签（nato/warsaw_pact），叠加国别标签便于细分。

return {

    -- ═══════════ 北约 NATO ═══════════

    usa = {
        name = "United States Army",
        name_zh = "美国陆军",
        icon = "fireteam/factions/usa_badge.png",
        color = Color(60, 120, 210),
        allowed_tags = { "nato", "coldwar_west", "western", "usa", "us_army" },
        banned_tags = { "warsaw_pact", "coldwar_east", "eastern" },
        voice_pack = "sound/fireteam/coldwar/voice_en/",
        default_squad_size = 6,
        command_structure = "squad_leader"
    },

    uk = {
        name = "British Army",
        name_zh = "英国陆军",
        icon = "fireteam/factions/uk_badge.png",
        color = Color(45, 145, 145),
        allowed_tags = { "nato", "coldwar_west", "western", "uk", "british_army" },
        banned_tags = { "warsaw_pact", "coldwar_east", "eastern" },
        voice_pack = "sound/fireteam/coldwar/voice_en/",
        default_squad_size = 6,
        command_structure = "squad_leader"
    },

    west_germany = {
        name = "Bundeswehr (West Germany)",
        name_zh = "西德联邦国防军",
        icon = "fireteam/factions/brd_badge.png",
        color = Color(185, 140, 55),
        allowed_tags = { "nato", "coldwar_west", "western", "west_germany", "bundeswehr" },
        banned_tags = { "warsaw_pact", "coldwar_east", "eastern" },
        voice_pack = "sound/fireteam/coldwar/voice_de/",
        default_squad_size = 6,
        command_structure = "squad_leader"
    },

    france = {
        name = "French Army",
        name_zh = "法国陆军",
        icon = "fireteam/factions/fr_badge.png",
        color = Color(95, 165, 85),
        allowed_tags = { "nato", "coldwar_west", "western", "france", "french_army" },
        banned_tags = { "warsaw_pact", "coldwar_east", "eastern" },
        voice_pack = "sound/fireteam/coldwar/voice_fr/",
        default_squad_size = 6,
        command_structure = "squad_leader"
    },

    -- ═══════════ 华约 Warsaw Pact ═══════════

    ussr = {
        name = "Soviet Army",
        name_zh = "苏联陆军",
        icon = "fireteam/factions/ussr_badge.png",
        color = Color(205, 50, 50),
        allowed_tags = { "warsaw_pact", "coldwar_east", "eastern", "ussr", "soviet_army" },
        banned_tags = { "nato", "coldwar_west", "western" },
        voice_pack = "sound/fireteam/coldwar/voice_ru/",
        default_squad_size = 8,
        command_structure = "commissar"
    },

    east_germany = {
        name = "National People's Army (East Germany)",
        name_zh = "东德国家人民军",
        icon = "fireteam/factions/ddr_badge.png",
        color = Color(225, 135, 45),
        allowed_tags = { "warsaw_pact", "coldwar_east", "eastern", "east_germany", "nva" },
        banned_tags = { "nato", "coldwar_west", "western" },
        voice_pack = "sound/fireteam/coldwar/voice_de/",
        default_squad_size = 8,
        command_structure = "commissar"
    },

    poland = {
        name = "Polish People's Army",
        name_zh = "波兰人民军",
        icon = "fireteam/factions/pol_badge.png",
        color = Color(205, 105, 150),
        allowed_tags = { "warsaw_pact", "coldwar_east", "eastern", "poland", "polish_army" },
        banned_tags = { "nato", "coldwar_west", "western" },
        voice_pack = "sound/fireteam/coldwar/voice_pl/",
        default_squad_size = 8,
        command_structure = "commissar"
    },

    czechoslovakia = {
        name = "Czechoslovak People's Army",
        name_zh = "捷克斯洛伐克人民军",
        icon = "fireteam/factions/tch_badge.png",
        color = Color(140, 70, 160),
        allowed_tags = { "warsaw_pact", "coldwar_east", "eastern", "czechoslovakia", "csla" },
        banned_tags = { "nato", "coldwar_west", "western" },
        voice_pack = "sound/fireteam/coldwar/voice_cs/",
        default_squad_size = 8,
        command_structure = "commissar"
    },

    -- ═══════════ 中立 ═══════════

    un_observers = {
        name = "UN Military Observers",
        name_zh = "联合国军事观察员",
        icon = "fireteam/factions/un_badge.png",
        color = Color(150, 150, 150),
        allowed_tags = { "neutral", "unarmed" },
        banned_tags = { "nato", "warsaw_pact" },
        voice_pack = "sound/fireteam/coldwar/voice_en/",
        default_squad_size = 4,
        command_structure = "flat"
    }
}
