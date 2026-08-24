-- core/sv_module_loader.lua
-- FIRETEAM Module Discovery & Loading System

if not Fireteam then Fireteam = {} end
Fireteam.Modules = Fireteam.Modules or {}
Fireteam.Modules.Registry = Fireteam.Modules.Registry or {}

local MODULE_BASE_PATH = "gamemodes/fireteam/gamemode/modules/"

-- ─────────────────────────────────────
-- 路径工具
-- file.Find/Exists/Read 使用 GAME 磁盘路径；
-- include/AddCSLuaFile 使用 lua 文件系统路径（去掉 "gamemodes/" 前缀）
-- ─────────────────────────────────────
local function ToLuaPath(gamePath)
    return gamePath:gsub("^gamemodes/", "", 1)
end

local function ExecLuaFile(gamePath, luaPath)
    local ok = pcall(include, luaPath)
    if not ok then
        -- 兜底：直接读盘编译执行，保证服务端逻辑不因路径规则差异而丢失
        local contents = file.Read(gamePath, "GAME")
        if contents then
            CompileString(contents, gamePath)()
        end
    end
end

-- ─────────────────────────────────────
-- 发现所有模块目录
-- ─────────────────────────────────────
function Fireteam.Modules.Discover()
    Fireteam.Modules.Registry = {}

    local dirs = file.Find(MODULE_BASE_PATH .. "*", "GAME")
    for _, dir in ipairs(dirs) do
        -- 跳过 adapters 子目录（适配器由设定包按需加载）
        if dir == "adapters" then continue end

        local modulePath = MODULE_BASE_PATH .. dir .. "/"

        -- 客户端文件支持 cl_<dir>.lua 与 cl_<dir>_ui.lua 两种命名
        local function firstExisting(candidates)
            for _, fname in ipairs(candidates) do
                if file.Exists(modulePath .. fname, "GAME") then
                    return fname
                end
            end
            return nil
        end

        local sharedFile = firstExisting({ "sh_" .. dir .. ".lua" })
        local serverFile = firstExisting({ "sv_" .. dir .. ".lua" })
        local clientFile = firstExisting({ "cl_" .. dir .. ".lua", "cl_" .. dir .. "_ui.lua" })

        if sharedFile or serverFile or clientFile then
            Fireteam.Modules.Registry[dir] = {
                id = dir,
                path = modulePath,
                state = Fireteam.MODULE_STATE.UNLOADED,
                files = {
                    shared = sharedFile,
                    server = serverFile,
                    client = clientFile
                }
            }
        end
    end

    Fireteam.Log.Info("模块", "发现 " .. table.Count(Fireteam.Modules.Registry) .. " 个模块")
end

-- ─────────────────────────────────────
-- 加载单个模块
-- ─────────────────────────────────────
function Fireteam.Modules.Load(moduleId)
    local mod = Fireteam.Modules.Registry[moduleId]
    if not mod then
        Fireteam.Log.Error("模块", "未找到模块: " .. moduleId)
        return false
    end

    if mod.state == Fireteam.MODULE_STATE.ACTIVE then
        Fireteam.Log.Warn("模块", "模块已在运行，跳过重复加载: " .. moduleId)
        return true
    end

    mod.state = Fireteam.MODULE_STATE.LOADING

    local ok, err = pcall(function()
        -- 共享文件：服务端执行 + 发给客户端
        if mod.files.shared then
            local gamePath = mod.path .. mod.files.shared
            local luaPath = ToLuaPath(gamePath)
            pcall(AddCSLuaFile, luaPath)
            ExecLuaFile(gamePath, luaPath)
        end
        -- 服务端文件
        if mod.files.server then
            local gamePath = mod.path .. mod.files.server
            ExecLuaFile(gamePath, ToLuaPath(gamePath))
        end
        -- 客户端文件（仅 AddCSLuaFile，服务端不执行）
        if mod.files.client then
            local gamePath = mod.path .. mod.files.client
            pcall(AddCSLuaFile, ToLuaPath(gamePath))
        end
    end)

    if not ok then
        mod.state = Fireteam.MODULE_STATE.ERROR
        Fireteam.Log.Error("模块", "✗ 模块加载失败 [" .. moduleId .. "]: " .. tostring(err))
        return false
    end

    mod.state = Fireteam.MODULE_STATE.ACTIVE
    hook.Run(Fireteam.HOOKS.MODULE_LOADED, moduleId)
    Fireteam.Log.Info("模块", "✓ 已加载: " .. moduleId)
    return true
end

-- ─────────────────────────────────────
-- 加载所有已发现模块
-- ─────────────────────────────────────
function Fireteam.Modules.LoadAll()
    local loaded, failed = 0, 0
    for id, _ in pairs(Fireteam.Modules.Registry) do
        if Fireteam.Modules.Load(id) then
            loaded = loaded + 1
        else
            failed = failed + 1
        end
    end
    print("[FIRETEAM] Modules: " .. loaded .. " loaded, " .. failed .. " failed")
end

-- ─────────────────────────────────────
-- 查询模块状态
-- ─────────────────────────────────────
function Fireteam.Modules.GetState(moduleId)
    local mod = Fireteam.Modules.Registry[moduleId]
    return mod and mod.state or Fireteam.MODULE_STATE.UNLOADED
end

function Fireteam.Modules.IsActive(moduleId)
    return Fireteam.Modules.GetState(moduleId) == Fireteam.MODULE_STATE.ACTIVE
end

Fireteam.Log.Info("模块", "✓ 模块加载器就绪")
