-- gamemode/cl_init.lua
-- FIRETEAM Client Entry Point

include("shared.lua")

-- ═══════════════════════════════════════
-- 客户端模块加载器
-- 服务端模块加载器只负责 AddCSLuaFile 下发文件，
-- 客户端必须自行执行 sh_ / cl_ 文件（含 *_ui 命名变体）
-- ═══════════════════════════════════════
local MODULE_BASE_PATH = "gamemodes/fireteam/gamemode/modules/"

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

hook.Add("InitPostEntity", "Fireteam.ClientInit", function()
    local dirs = file.Find(MODULE_BASE_PATH .. "*", "GAME")
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
end)

hook.Add("InitPostEntity", "Fireteam.ClientReady", function()
    Fireteam.Log.Info("核心", "✓ 客户端初始化完成")
end)
