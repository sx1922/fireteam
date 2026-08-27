-- gamemode/init.lua
-- FIRETEAM Server Entry Point

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

-- 服务端公开 API 表面（惰性解析，可在模块加载前 include）
include("api/sv_fireteam_api.lua")

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

    -- 1.5 基座适配器（须早于设定包激活：武器/载具发现由 SETTING_LOADED 触发）
    Fireteam.Modules.LoadAdapters()

    -- 2. 发现并激活默认设定包
    Fireteam.Setting.Discover()
    local defaultPack = GetConVar("ft_setting_pack"):GetString()
    if not Fireteam.Setting.Activate(defaultPack) then
        Fireteam.Log.Error("设定包", "✗ 激活默认设定包失败: " .. defaultPack)
    end

    Fireteam.Log.Info("核心", "✓ 引导流程完成")
end)

-- ═══════════════════════════════════════
-- 客户端就绪握手：补齐初始状态
-- ⚠ 引导期（Initialize）激活设定包时全场无人，SETTING_CHANGED / HUD_THEME 的
--   广播发给零接收者；CONFIG_SYNC 因设定包 overrides 全用 silent 写入更是从不产生。
--   加入的玩家全靠本握手拿到既有状态（历史 P0，worklog 041）。
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.CLIENT_READY, function(_, ply)
    if not IsValid(ply) then return end
    if ply.FT_ReadySynced then return end   -- 每次连接只补一次
    ply.FT_ReadySynced = true

    local n = Fireteam.Config.SyncAllTo and Fireteam.Config.SyncAllTo(ply) or 0
    if Fireteam.Setting.SendStateTo then Fireteam.Setting.SendStateTo(ply) end
    if Fireteam.Squad and Fireteam.Squad.SyncToAll then Fireteam.Squad.SyncToAll(ply) end
    if Fireteam.Rounds and Fireteam.Rounds.SendSnapshotTo then
        Fireteam.Rounds.SendSnapshotTo(ply)
    end
    if Fireteam.Commander and Fireteam.Commander.SendStateTo then
        Fireteam.Commander.SendStateTo(ply)
    end
    if Fireteam.Vitals and Fireteam.Vitals.BroadcastAll then
        Fireteam.Vitals.BroadcastAll(ply)
    end
    if Fireteam.Seats and Fireteam.Seats.SendAllTo then Fireteam.Seats.SendAllTo(ply) end

    Fireteam.Log.Info("核心", "✓ 已向 " .. ply:Nick() .. " 下发初始状态（配置 " .. n .. " 项）")
end)

hook.Add("PlayerDisconnected", "Fireteam.ReadyReset", function(ply)
    if IsValid(ply) then ply.FT_ReadySynced = nil end
end)

-- ═══════════════════════════════════════
-- ConVar 注册
-- ═══════════════════════════════════════
CreateConVar("ft_setting_pack", "coldwar", FCVAR_REPLICATED + FCVAR_ARCHIVE,
    "Active FIRETEAM setting pack ID", 0, 0)

CreateConVar("ft_debug", "0", FCVAR_ARCHIVE,
    "Enable FIRETEAM debug logging (0=off, 1=basic, 2=verbose)", 0, 2)

Fireteam.Log.Info("核心", "✓ 服务端入口已加载")
