-- _template/factions.lua
-- 阵营定义：每个阵营一个 key
return {

    faction_alpha = {
        name = "Faction Alpha",
        name_zh = "阿尔法阵营",
        icon = "fireteam/factions/alpha_badge.png",
        color = Color(70, 130, 180),

        -- 该阵营可用的装备标签
        allowed_tags = { "faction_alpha", "my_era" },
        banned_tags = { "faction_beta" },

        -- 通讯语音包路径
        voice_pack = "sound/fireteam/my_setting/voice_alpha/",

        -- 小队配置
        default_squad_size = 6,
        command_structure = "squad_leader"  -- flat | squad_leader | commissar | officer
    },

    faction_beta = {
        name = "Faction Beta",
        name_zh = "贝塔阵营",
        icon = "fireteam/factions/beta_badge.png",
        color = Color(180, 60, 50),
        allowed_tags = { "faction_beta", "my_era" },
        banned_tags = { "faction_alpha" },
        voice_pack = "sound/fireteam/my_setting/voice_beta/",
        default_squad_size = 8,
        command_structure = "commissar"
    }
}
