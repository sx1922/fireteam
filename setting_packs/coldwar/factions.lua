-- setting_packs/coldwar/factions.lua
return {

    western_alliance = {
        name = "Western Alliance",
        name_zh = "西方联盟",
        icon = "fireteam/factions/wa_badge.png",
        color = Color(70, 130, 180),
        allowed_tags = { "nato", "coldwar_west", "western" },
        banned_tags = { "warsaw_pact", "coldwar_east", "eastern" },
        voice_pack = "sound/fireteam/coldwar/voice_en/",
        default_squad_size = 6,
        command_structure = "squad_leader"
    },

    eastern_bloc = {
        name = "Eastern Bloc",
        name_zh = "东方集团",
        icon = "fireteam/factions/eb_badge.png",
        color = Color(180, 60, 50),
        allowed_tags = { "warsaw_pact", "coldwar_east", "eastern" },
        banned_tags = { "nato", "coldwar_west", "western" },
        voice_pack = "sound/fireteam/coldwar/voice_ru/",
        default_squad_size = 8,
        command_structure = "commissar"
    },

    neutral_observers = {
        name = "Neutral Observers",
        name_zh = "中立观察员",
        icon = "fireteam/factions/no_badge.png",
        color = Color(128, 128, 128),
        allowed_tags = { "neutral", "unarmed" },
        banned_tags = { "nato", "warsaw_pact" },
        voice_pack = "sound/fireteam/coldwar/voice_en/",
        default_squad_size = 4,
        command_structure = "flat"
    }
}
