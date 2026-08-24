-- core/sh_constants.lua
-- FIRETEAM Global Constants & Enums

if not Fireteam then Fireteam = {} end

-- ═══════════════════════════════════════
-- 版本信息
-- ═══════════════════════════════════════
Fireteam.VERSION = "0.1.0-alpha"
Fireteam.MIN_GMOD_VERSION = 250814

-- ═══════════════════════════════════════
-- 设定包相关常量
-- ═══════════════════════════════════════
Fireteam.SETTING_PACK_PATH_BUILTIN = "setting_packs/"
Fireteam.SETTING_PACK_PATH_GAMEMODE = "gamemodes/fireteam/setting_packs/"
Fireteam.SETTING_PACK_PATH_ADDON   = "lua/fireteam_setting_packs/"
Fireteam.SETTING_PACK_META_FILE    = "pack.json"

-- 设定包数据文件名（加载顺序即此顺序）
Fireteam.SETTING_DATA_FILES = {
    "factions",
    "classes",
    "weapons",
    "vehicles",
    "voice_presets",
    "map_rules"
}

-- ═══════════════════════════════════════
-- 模块生命周期状态
-- ═══════════════════════════════════════
Fireteam.MODULE_STATE = {
    UNLOADED  = 0,
    LOADING   = 1,
    ACTIVE    = 2,
    ERROR     = 3,
    DISABLED  = 4
}

-- ═══════════════════════════════════════
-- 武器 / 载具抽象分类
-- ═══════════════════════════════════════
Fireteam.WEAPON_CATEGORY = {
    RIFLE       = "rifle",
    CARBINE     = "carbine",
    SMG         = "smg",
    LMG         = "lmg",
    HMG         = "hmg",
    SHOTGUN     = "shotgun",
    PISTOL      = "pistol",
    REVOLVER    = "revolver",
    SNIPER      = "sniper_rifle",
    DMR         = "dmr",
    GRENADE     = "grenade",
    MELEE       = "melee",
    LAUNCHER    = "launcher",
    SPECIAL     = "special"
}

Fireteam.VEHICLE_ROLE = {
    TRANSPORT   = "transport",
    RECON       = "recon",
    APC         = "apc",
    TANK        = "tank",
    AIR         = "air",
    NAVAL       = "naval",
    UTILITY     = "utility"
}

-- ═══════════════════════════════════════
-- 小队 / 角色常量
-- ═══════════════════════════════════════
Fireteam.SQUAD_MAX_SIZE     = 12
Fireteam.SQUAD_MIN_SIZE     = 2
Fireteam.DEFAULT_SQUAD_SIZE = 6

Fireteam.COMMAND_STRUCTURE = {
    FLAT          = "flat",           -- 无层级
    SQUAD_LEADER  = "squad_leader",   -- 小队长制
    COMMISSAR     = "commissar",      -- 政委制
    OFFICER       = "officer"         -- 军官制
}

-- ═══════════════════════════════════════
-- 通讯模型
-- ═══════════════════════════════════════
Fireteam.VOICE_MODEL = {
    ANALOG_RADIO  = "analog_radio",
    DIGITAL       = "digital",
    DIRECT        = "direct",
    FIELD_PHONE   = "field_phone"
}

-- ═══════════════════════════════════════
-- HUD 主题标识
-- ═══════════════════════════════════════
Fireteam.HUD_THEME = {
    CRT_GREEN       = "crt_green",
    MONO_AMBER      = "monochrome_amber",
    PAPER_MAP       = "paper_map",
    MODERN_DIGITAL  = "modern_digital",
    MINIMAL         = "minimal"
}

-- ═══════════════════════════════════════
-- 网络消息 ID（集中管理避免冲突）
-- ═══════════════════════════════════════
Fireteam.NET = {
    CONFIG_SYNC       = "FT_ConfigSync",
    SETTING_CHANGED   = "FT_SettingChanged",
    SQUAD_UPDATE      = "FT_SquadUpdate",
    MARKER_ADD        = "FT_MarkerAdd",
    MARKER_REMOVE     = "FT_MarkerRemove",
    CLASS_ASSIGN      = "FT_ClassAssign",
    VOICE_CHANNEL     = "FT_VoiceChannel",
    HUD_THEME         = "FT_HUDTheme",
    ASSET_WARNING     = "FT_AssetWarning"
}

-- ═══════════════════════════════════════
-- Hook 命名空间（防止与其他 addon 冲突）
-- ═══════════════════════════════════════
Fireteam.HOOKS = {
    MODULE_LOADED       = "Fireteam.Module.Loaded",
    MODULE_UNLOADED     = "Fireteam.Module.Unloaded",
    SETTING_LOADED      = "Fireteam.Setting.Loaded",
    SETTING_UNLOAD      = "Fireteam.Setting.Unload",
    WEAPON_DISCOVER     = "Fireteam.Weapon.Discover",
    VEHICLE_DISCOVER    = "Fireteam.Vehicle.Discover",
    PLAYER_JOINED_SQUAD = "Fireteam.Squad.PlayerJoined",
    PLAYER_LEFT_SQUAD   = "Fireteam.Squad.PlayerLeft",
    CONFIG_CHANGED      = "Fireteam.Config.Changed",
    CLASS_ASSIGNED      = "Fireteam.Class.Assigned"
}

Fireteam.Log.Info("常量", "✓ 常量已加载 (v" .. Fireteam.VERSION .. ")")
