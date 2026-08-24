-- gamemode/init.lua
-- FIRETEAM Server Entry Point

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

-- ═══════════════════════════════════════
-- Core 服务端模块
-- ═══════════════════════════════════════
include("core/sv_module_loader.lua")
include("core/sv_setting_loader.lua")

-- ═══════════════════════════════════════
-- 模块自动加载
-- ═══════════════════════════════════════
hook.Add("Initialize", "Fireteam.Bootstrap", function()
    Fireteam.Log.Info("核心", "═══════════════════════════════════")
    Fireteam.Log.Info("核心", "FIRETEAM v" .. Fireteam.VERSION .. " 战术框架启动中...")
    Fireteam.Log.Info("核心", "═══════════════════════════════════")

    -- 1. 发现并加载所有模块
    Fireteam.Modules.Discover()
    Fireteam.Modules.LoadAll()

    -- 2. 发现并激活默认设定包
    Fireteam.Setting.Discover()
    local defaultPack = GetConVar("ft_setting_pack"):GetString()
    if not Fireteam.Setting.Activate(defaultPack) then
        Fireteam.Log.Error("设定包", "✗ 激活默认设定包失败: " .. defaultPack)
    end

    Fireteam.Log.Info("核心", "✓ 引导流程完成")
end)

-- ═══════════════════════════════════════
-- ConVar 注册
-- ═══════════════════════════════════════
CreateConVar("ft_setting_pack", "coldwar", FCVAR_REPLICATED + FCVAR_ARCHIVE,
    "Active FIRETEAM setting pack ID", 0, 0)

CreateConVar("ft_debug", "0", FCVAR_ARCHIVE,
    "Enable FIRETEAM debug logging (0=off, 1=basic, 2=verbose)", 0, 2)

Fireteam.Log.Info("核心", "✓ 服务端入口已加载")
