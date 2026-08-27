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
-- 包元数据双格式：GMA 白名单不含 .json，Workshop 分发必须用 .lua；
-- 磁盘部署与第三方包沿用 .json（.lua 优先，.json 回退）
Fireteam.SETTING_PACK_META_FILE_LUA = "pack.lua"
Fireteam.SETTING_PACK_META_FILE    = "pack.json"

-- 设定包数据文件名（加载顺序即此顺序）
Fireteam.SETTING_DATA_FILES = {
    "factions",
    "classes",
    "weapons",
    "items",
    "vehicles",
    "voice_presets",
    "map_rules",
    "weapon_overrides",
    "vehicle_overrides",
    "player_models"
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

-- 模块加载优先级（数值小者先加载，未列出者默认 100；同级按字母序）
Fireteam.MODULE_LOAD_PRIORITY = {
    squad   = 10,
    class   = 20,
    marker  = 30,
    voice   = 40,
    hud     = 50,
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
-- 全部消息由 sh_net_protocol.lua 在服务端统一 util.AddNetworkString，
-- 模块内不要再重复注册。
-- ═══════════════════════════════════════
Fireteam.NET = {
    -- 服务端 → 客户端
    CONFIG_SYNC          = "FT_ConfigSync",
    SETTING_CHANGED      = "FT_SettingChanged",
    SQUAD_UPDATE         = "FT_SquadUpdate",
    MARKER_ADD           = "FT_MarkerAdd",
    VOICE_CHANNEL        = "FT_VoiceChannel",
    HUD_THEME            = "FT_HUDTheme",
    SUPPRESSION_UPDATE   = "FT_SuppressionUpdate",
    MAP_INFO             = "FT_MapInfo",
    ROUNDS_STATE         = "FT_RoundsState",
    SEAT_UPDATE          = "FT_SeatUpdate",
    COMMANDER_UPDATE     = "FT_CommanderUpdate",   -- 各阵营指挥官席位 + 选举态全量广播
    ADMIN_STATE          = "FT_AdminState",
    PACK_EDITOR_DATA     = "FT_PackEditorData",
    INVENTORY_SYNC       = "FT_InventorySync",
    VITALS_UPDATE        = "FT_VitalsUpdate",

    -- 双向（同一字符串按 realm 各自收发）
    CLASS_ASSIGN         = "FT_ClassAssign",

    -- 客户端 → 服务端（请求）
    CLIENT_READY         = "FT_ClientReady",        -- 客户端模块全量加载完毕，请求初始状态
    MARKER_PLACE         = "FT_MarkerPlace",
    MARKER_REMOVE        = "FT_MarkerRemove",
    SQUAD_CREATE         = "FT_SquadCreate",
    SQUAD_JOIN           = "FT_SquadJoin",
    SQUAD_LEAVE          = "FT_SquadLeave",
    SQUAD_READY          = "FT_SquadReady",
    SQUAD_KICK           = "FT_SquadKick",          -- ply(leader), targetEnt
    SQUAD_LOCK           = "FT_SquadLock",          -- ply(leader), locked(bool)
    COMMANDER_ACTION     = "FT_CommanderAction",    -- action(volunteer/vote/relinquish) [, targetEnt]
    VOICE_SWITCH_CHANNEL = "FT_VoiceSwitchChannel",
    SPECTATE_CONTROL     = "FT_SpecControl",
    ADMIN_ACTION         = "FT_AdminAction",
    PACK_EDITOR_PULL     = "FT_PackEditorPull",
    PACK_EDITOR_EXPORT   = "FT_PackEditorExport",
    ITEM_USE             = "FT_ItemUse",
    ITEM_MOVE            = "FT_ItemMove",
    ITEM_DROP            = "FT_ItemDrop",
    REVIVE_ACTION        = "FT_ReviveAction"
}

-- ═══════════════════════════════════════
-- Hook 命名空间（防止与其他 addon 冲突）
-- ═══════════════════════════════════════
Fireteam.HOOKS = {
    MODULE_LOADED       = "Fireteam.Module.Loaded",
    MODULE_UNLOADED     = "Fireteam.Module.Unloaded",  -- 保留：运行时卸载尚未实现，当前无触发点
    SETTING_LOADED      = "Fireteam.Setting.Loaded",
    SETTING_UNLOAD      = "Fireteam.Setting.Unload",
    WEAPON_DISCOVER     = "Fireteam.Weapon.Discover",
    VEHICLE_DISCOVER    = "Fireteam.Vehicle.Discover",
    PLAYER_JOINED_SQUAD = "Fireteam.Squad.PlayerJoined",
    PLAYER_LEFT_SQUAD   = "Fireteam.Squad.PlayerLeft",
    CONFIG_CHANGED      = "Fireteam.Config.Changed",
    CLASS_ASSIGNED      = "Fireteam.Class.Assigned",
    ROUND_STATE_CHANGED = "Fireteam.Rounds.StateChanged",
    ROUND_ENDED         = "Fireteam.Rounds.Ended",
    PLAYER_ENTER_VEHICLE = "Fireteam.Seats.Entered",
    PLAYER_EXIT_VEHICLE  = "Fireteam.Seats.Left",
    MARKER_ADDED         = "Fireteam.Marker.Added",
    AI_DEPLOYED          = "Fireteam.AI.Deployed",
    BOT_KILLED           = "Fireteam.PvE.BotKilled", -- bot, attacker（PvE/队友通用阵亡归功）
    ITEM_USED            = "Fireteam.Inventory.ItemUsed", -- ply, itemId（消耗品成功使用后触发）
    VITALS_STATE_CHANGED = "Fireteam.Vitals.StateChanged", -- ply, oldState, newState（normal/downed/dead）
    SCENARIO_CHANGED     = "Fireteam.Rounds.ScenarioChanged", -- newScenarioId（剧本切换确认，下一回合生效）

    -- 客户端/跨模块 UI 与状态通知（P10 收编：原先散落各模块的裸字符串）
    LOCALE_CHANGED            = "Fireteam.Locale.Changed",       -- lang（语言切换完成）
    SETTING_ASSET_WARNING     = "Fireteam.Setting.AssetWarning", -- packId, warnings[]
    UI_THEME_INVALIDATED      = "Fireteam.UI.ThemeInvalidated",  -- （HUD 主题缓存失效）
    VOICE_CAN_ACCESS_CHANNEL  = "Fireteam.Voice.CanAccessChannel", -- ply, channelId → false 拒绝
    VOICE_CHANNEL_CHANGED     = "Fireteam.Voice.ChannelChanged",   -- ply, channelId
    INVENTORY_CLIENT_UPDATED  = "Fireteam.Inventory.ClientUpdated",-- （客户端背包快照已更新）
    ROUNDS_CLIENT_STATE_CHANGED = "Fireteam.Rounds.ClientStateChanged", -- state（客户端回合状态同步）
    VITALS_CLIENT_UPDATED     = "Fireteam.Vitals.ClientUpdated",   -- （客户端体征快照已更新）
    COMMANDER_CHANGED         = "Fireteam.Commander.Changed"       -- faction, newCommander|nil（指挥官就任/腾位）
}

Fireteam.Log.Info("常量", "✓ 常量已加载 (v" .. Fireteam.VERSION .. ")")
