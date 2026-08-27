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

Fireteam.Log.Info("核心", "✓ 共享环境已初始化")
