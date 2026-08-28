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
    "admin", "ai", "ballistics", "class", "commander", "hud", "inventory", "mainmenu",
    "marker", "packeditor", "pve", "resupply", "rounds", "seats", "spectate",
    "squad", "stamina", "suppression", "tacmap", "vitals", "voice"
}

local function ExecModuleFile(gamePath, moduleId)
    -- 首选 lua 文件系统路径（去掉 "gamemodes/" 前缀）
    local luaPath = gamePath:gsub("^gamemodes/", "", 1)
    local ok, err = pcall(include, luaPath)
    if ok then return true end

    Fireteam.Log.Error("模块",
        "include 失败 [" .. moduleId .. "]: " .. luaPath .. " — " .. tostring(err))

    -- 兜底：直接读 GAME 磁盘路径编译执行；诊断名带模块便于定位
    local contents = file.Read(gamePath, "GAME")
    if not contents then
        error("[" .. moduleId .. "] include 与文件读取均失败: " .. gamePath, 0)
    end
    local chunk, compileErr = CompileString(contents, moduleId .. ":" .. luaPath)
    if not chunk then
        error("[" .. moduleId .. "] 兜底编译失败: " .. tostring(compileErr), 0)
    end
    local ranOk, runErr = pcall(chunk)
    if not ranOk then
        error("[" .. moduleId .. "] 兜底执行失败: " .. tostring(runErr), 0)
    end
    return true
end

-- 立即加载，不等 InitPostEntity：客户端文件在进服时已由 AddCSLuaFile
-- 全量下发，此处延迟只会让 net.Receive 注册晚于服务器首帧广播（丢消息）。
-- file.Find 返回 (files, directories)：只取第二个返回值（目录列表）
local _, dirs = file.Find(MODULE_BASE_PATH .. "*", "GAME")
if #dirs == 0 then
    dirs = FALLBACK_MODULES
    Fireteam.Log.Warn("模块", "file.Find 未发现模块目录，回退内置清单（GMA 分发场景）")
end

local failed = {}
local priorities = Fireteam.MODULE_LOAD_PRIORITY or {}
table.sort(dirs, function(a, b)
    local pa, pb = priorities[a] or 100, priorities[b] or 100
    return pa == pb and a < b or pa < pb
end)
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
                -- 单文件粒度隔离：一个模块报错不应拖垮后续全部模块
                local ok, err = pcall(ExecModuleFile, basePath .. fname, dir)
                if not ok then
                    Fireteam.Log.Error("模块", "✗ 客户端模块失败: " .. dir .. "/" .. fname
                        .. " — " .. tostring(err))
                    failed[#failed + 1] = dir .. "/" .. fname
                end
            end
        end
    end
end

if #failed > 0 then
    Fireteam.Log.Error("模块", "✗ 客户端模块加载失败清单: " .. table.concat(failed, ", "))
    Fireteam.Log.Info("模块", "客户端模块已加载（部分失败）")
else
    Fireteam.Log.Info("模块", "✓ 客户端模块已全部加载")
end

-- 客户端公开 API 表面（读各模块客户端缓存，故置于模块加载之后）
do
    local ok, err = pcall(ExecModuleFile,
        "gamemodes/fireteam/gamemode/api/cl_fireteam_api.lua", "api")
    if not ok then
        Fireteam.Log.Error("API", "✗ 客户端 API 表面加载失败: " .. tostring(err))
    end
end

Fireteam.Log.Info("核心", "✓ 客户端初始化完成")

-- ═══════════════════════════════════════
-- 就绪握手：请求服务端补发初始状态
-- 所有 net.Receive 此刻已注册完毕；InitPostEntity 后再发，保证连接已可收发。
-- ═══════════════════════════════════════
hook.Add("InitPostEntity", "Fireteam.ClientReady", function()
    timer.Simple(1, function()
        net.Start(Fireteam.NET.CLIENT_READY)
        net.SendToServer()
        Fireteam.Log.Debug("核心", "已发送就绪握手，等待初始状态")
    end)
end)
