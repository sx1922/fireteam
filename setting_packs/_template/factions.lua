-- _template/factions.lua
-- ═════════════════════════════════════════════════════════════
-- 阵营定义：每个阵营一个 key（小写下划线，如 faction_alpha / usa）。
-- key 会被引用于：classes.lua 的 faction 字段、map_rules.lua 的
-- spawns/pve.player_factions/pve.ai_factions、weapons.lua 的 pools。
--
-- 字段说明：
--   color            阵营色（Color(r,g,b)）：左上战局块比分色点、结算屏己方高亮
--   allowed_tags     该阵营可用的装备标签（与 banned_tags 必须互斥）
--   banned_tags      禁用标签（敌对阵营标签写这里）
--   voice_pack       语音目录（预留字段）
--   default_squad_size 小队人数上限（受 config squad.max_size 二次约束）
--   command_structure 指挥链风格：flat（无）| squad_leader（队长制）|
--                     commissar（政委制）| officer（军官制）——展示与语音权限约定
--   lore / lore_zh   可选：阵营背景设定（coldwar 包有完整示例）
-- ═════════════════════════════════════════════════════════════
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
