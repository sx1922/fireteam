-- setting_packs/coldwar/factions.lua
-- 冷战阵营：现实国家（1968–1985）
-- 北约四国 vs 华约四国。装备标签沿用集团级标签（nato/warsaw_pact），
-- 叠加国别标签便于细分；lore 字段记录各军在本包两个剧本中的历史角色。

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
        command_structure = "squad_leader",
        lore = "V Corps' 3rd Armored Division and 11th ACR held the Fulda corridor; Berlin Brigade garrisoned West Berlin.",
        lore_zh = "第5军麾下第3装甲师与第11装甲骑兵团扼守富尔达走廊；柏林旅驻防西柏林。"
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
        command_structure = "squad_leader",
        lore = "British Army of the Rhine screened the North German Plain; Berlin Infantry Brigade held the western sectors of the divided city.",
        lore_zh = "驻莱茵英国陆军（BAOR）警戒北德平原；柏林步兵旅据守分裂城市西半的英占区。"
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
        command_structure = "squad_leader",
        lore = "Bundeswehr III Corps manned the inner-German border; territorial forces muster far west as the relief force for Berlin.",
        lore_zh = "联邦国防军第3军沿德国内部边界设防；本土防卫部队在西面远郊集结，充当柏林解围援军。"
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
        command_structure = "squad_leader",
        lore = "Forces Françaises en Allemagne covered the southern flank; the French garrison answered only to Paris, not NATO.",
        lore_zh = "驻德法国军队（FFA）掩护南翼；西柏林法军分遣队只听命于巴黎，不受北约指挥链节制。"
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
        command_structure = "commissar",
        lore = "Group of Soviet Forces in Germany — the 8th Guards Army was slated to spearhead the Fulda thrust; its garrison held East Berlin.",
        lore_zh = "驻德苏军集群——近卫第8集团军是富尔达方向主攻矛头；其卫戍部队控制东柏林。"
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
        command_structure = "commissar",
        lore = "NVA motor rifle divisions of Military District III would follow the Soviet shock armies; the Berlin District guarded the city's east.",
        lore_zh = "国家人民军第3军区摩托化步兵师将随苏军突击集团跟进；柏林军区卫戍东半城。"
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
        command_structure = "commissar",
        lore = "Formed the Pact's second echelon, following behind the front-line shock axis to exploit the breakthrough.",
        lore_zh = "编为华约第二梯队，在一线突击轴身后跟进，负责扩张突破口。"
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
        command_structure = "commissar",
        lore = "Covered the southern approach as the second-echelon reserve of the front.",
        lore_zh = "掩护南向通道，担任方面军第二梯队预备队。"
    }
}
