-- gamemode/shared.lua
-- FIRETEAM Shared Entry Point

AddCSLuaFile("core/sh_logger.lua")
AddCSLuaFile("core/sh_constants.lua")
AddCSLuaFile("core/sh_config_registry.lua")
AddCSLuaFile("core/sh_api_registry.lua")
AddCSLuaFile("core/sh_net_protocol.lua")
AddCSLuaFile("core/sh_weapon_interface.lua")
AddCSLuaFile("core/sh_vehicle_interface.lua")

-- 日志系统必须最先加载（后续所有核心文件依赖 Fireteam.Log）
include("core/sh_logger.lua")
include("core/sh_constants.lua")
include("core/sh_config_registry.lua")
include("core/sh_api_registry.lua")
include("core/sh_net_protocol.lua")
include("core/sh_weapon_interface.lua")
include("core/sh_vehicle_interface.lua")

-- 全局表初始化（仅声明，不赋值）
Fireteam = Fireteam or {}
Fireteam.Config = Fireteam.Config or {}
Fireteam.API = Fireteam.API or {}
Fireteam.Modules = Fireteam.Modules or {}
Fireteam.Setting = Fireteam.Setting or {}
Fireteam.WeaponInterface = Fireteam.WeaponInterface or {}
Fireteam.VehicleInterface = Fireteam.VehicleInterface or {}
Fireteam.Locale = Fireteam.Locale or {}

Fireteam.Log.Info("核心", "✓ 共享环境已初始化")
