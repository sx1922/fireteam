-- gamemode/cl_init.lua
-- FIRETEAM Client Entry Point

include("shared.lua")

-- ═══════════════════════════════════════
-- 客户端模块加载器
-- 服务端模块加载器只负责 AddCSLuaFile 下发文件，
-- 客户端必须自行执行 sh_ / cl_ 文件（含 *_ui 命名变体）
-- ═══════════════════════════════════════
local MODULE_BASE_PATH = "gamemodes/fireteam/gamemode/modules/"

-- GMA 分发兜底清单：直接部署时 file.Find 自动发现全部模块；
-- 打包为 GMA 后个别挂载环境下发现可能返回空，此时回退本清单。
-- ⚠ 新增/删除模块目录时必须同步维护此表。
local FALLBACK_MODULES = {
    "admin", "ai", "ballistics", "class", "hud", "inventory", "mainmenu",
    "marker", "packeditor", "pve", "resupply", "rounds", "seats", "spectate",
    "squad", "stamina", "suppression", "tacmap", "vitals", "voice"
}

local function ExecModuleFile(gamePath)
    -- 首选 lua 文件系统路径（去掉 "gamemodes/" 前缀）
    local luaPath = gamePath:gsub("^gamemodes/", "", 1)
    local ok = pcall(include, luaPath)
    if not ok then
        -- 兜底：直接读 GAME 磁盘路径编译执行
        local contents = file.Read(gamePath, "GAME")
        if contents then
            CompileString(contents, gamePath)()
        end
    end
end

-- 立即加载，不等 InitPostEntity：客户端文件在进服时已由 AddCSLuaFile
-- 全量下发，此处延迟只会让 net.Receive 注册晚于服务器首帧广播（丢消息）。
local dirs = file.Find(MODULE_BASE_PATH .. "*", "GAME")
if #dirs == 0 then
    dirs = FALLBACK_MODULES
    Fireteam.Log.Warn("模块", "file.Find 未发现模块目录，回退内置清单（GMA 分发场景）")
end

for _, dir in ipairs(dirs) do
    if dir ~= "adapters" then
        local basePath = MODULE_BASE_PATH .. dir .. "/"
        local candidates = {
            "sh_" .. dir .. ".lua",
            "cl_" .. dir .. ".lua",
            "cl_" .. dir .. "_ui.lua"
        }
        for _, fname in ipairs(candidates) do
            if file.Exists(basePath .. fname, "GAME") then
                ExecModuleFile(basePath .. fname)
            end
        end
    end
end

Fireteam.Log.Info("模块", "✓ 客户端模块已全部加载")
Fireteam.Log.Info("核心", "✓ 客户端初始化完成")
