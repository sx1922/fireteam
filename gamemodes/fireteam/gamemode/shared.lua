-- gamemode/shared.lua
-- FIRETEAM Shared Entry Point

-- 全局表初始化必须在所有 include 之前：
-- 各核心文件自带 `Fireteam.X or {}` 兜底，若初始化放在 include 之后，
-- 某个 include 静默失败时这些冗余行会掩盖真实加载问题。
Fireteam = Fireteam or {}
Fireteam.Config = Fireteam.Config or {}
Fireteam.API = Fireteam.API or {}
Fireteam.Modules = Fireteam.Modules or {}
Fireteam.Setting = Fireteam.Setting or {}
Fireteam.WeaponInterface = Fireteam.WeaponInterface or {}
Fireteam.VehicleInterface = Fireteam.VehicleInterface or {}
Fireteam.Locale = Fireteam.Locale or {}

AddCSLuaFile("core/sh_logger.lua")
AddCSLuaFile("core/sh_constants.lua")
AddCSLuaFile("core/sh_config_registry.lua")
AddCSLuaFile("core/sh_api_registry.lua")
AddCSLuaFile("core/sh_net_protocol.lua")
AddCSLuaFile("core/sh_weapon_interface.lua")
AddCSLuaFile("core/sh_vehicle_interface.lua")
AddCSLuaFile("core/sh_locale.lua")
AddCSLuaFile("core/sh_ui_kit.lua")
AddCSLuaFile("core/sh_keybinds.lua")
AddCSLuaFile("api/sh_fireteam_api.lua")
AddCSLuaFile("api/cl_fireteam_api.lua")
AddCSLuaFile("core/cl_setting_data.lua")

-- 日志系统必须最先加载（后续所有核心文件依赖 Fireteam.Log）
include("core/sh_logger.lua")
include("core/sh_constants.lua")
include("core/sh_locale.lua")
include("core/sh_config_registry.lua")
include("core/sh_api_registry.lua")
include("core/sh_net_protocol.lua")
include("core/sh_weapon_interface.lua")
include("core/sh_vehicle_interface.lua")
include("core/sh_ui_kit.lua")

-- 键位层（引擎 hook + concommand；命令实现惰性解析各模块，故可早于模块加载）
include("core/sh_keybinds.lua")

-- 公开 API 共享表面（依赖 sh_api_registry 的 Register，故置于其后）
include("api/sh_fireteam_api.lua")

-- 客户端设定包数据桥接（仅客户端生效；服务端用 sv_setting_loader 的 GetData）
include("core/cl_setting_data.lua")

Fireteam.Log.Info("核心", "✓ 共享环境已初始化")
