-- core/sv_setting_loader.lua
-- FIRETEAM Setting Pack Discovery, Loading & Hot-Switch

if not Fireteam then Fireteam = {} end
Fireteam.Setting = Fireteam.Setting or {}
Fireteam.Setting.Discovered = Fireteam.Setting.Discovered or {}
Fireteam.Setting.Active = nil
Fireteam.Setting.Data = {}

-- 网络消息注册（必须在 net.Start 之前完成）
util.AddNetworkString(Fireteam.NET.SETTING_CHANGED)

-- ─────────────────────────────────────
-- 扫描所有设定包
-- ─────────────────────────────────────
function Fireteam.Setting.Discover()
    Fireteam.Setting.Discovered = {}

    local searchPaths = {
        { path = Fireteam.SETTING_PACK_PATH_BUILTIN,  source = "builtin",  realm = "GAME" },
        { path = Fireteam.SETTING_PACK_PATH_GAMEMODE, source = "gamemode", realm = "GAME" },
        { path = Fireteam.SETTING_PACK_PATH_ADDON,    source = "addon",    realm = "LUA" }
    }

    for _, sp in ipairs(searchPaths) do
        local dirs = file.Find(sp.path .. "*", sp.realm)
        for _, dir in ipairs(dirs) do
            local metaFile = sp.path .. dir .. "/" .. Fireteam.SETTING_PACK_META_FILE
            if file.Exists(metaFile, sp.realm) then
                local raw = file.Read(metaFile, sp.realm)
                local meta = util.JSONToTable(raw)
                if meta and meta.id then
                    meta._path = sp.path .. dir .. "/"
                    meta._source = sp.source
                    meta._realm = sp.realm
                    Fireteam.Setting.Discovered[meta.id] = meta
                    Fireteam.Log.Info("设定包", "  发现设定包: " .. meta.id .. " (来源: " .. sp.source .. ")")
                else
                    Fireteam.Log.Error("设定包", "✗ pack.json 无效: " .. metaFile)
                end
            end
        end
    end

    Fireteam.Log.Info("设定包", "共发现 " .. table.Count(Fireteam.Setting.Discovered) .. " 个设定包")
end

-- ─────────────────────────────────────
-- 安全执行设定包 Lua 文件（不依赖 include 的搜索路径）
-- ─────────────────────────────────────
local function RunDataLua(path, realm)
    local contents = file.Read(path, realm)
    if not contents then return nil end
    local fn = CompileString(contents, path, false)
    if not fn then
        Fireteam.Log.Error("设定包", "✗ 数据文件语法错误: " .. path)
        return nil
    end
    return fn()
end

-- ─────────────────────────────────────
-- 加载设定包数据文件
-- ─────────────────────────────────────
local function LoadDataFiles(meta)
    local data = {}
    for _, fname in ipairs(Fireteam.SETTING_DATA_FILES) do
        local luaFile = meta._path .. fname .. ".lua"
        local jsonFile = meta._path .. fname .. ".json"

        if file.Exists(luaFile, meta._realm) then
            data[fname] = RunDataLua(luaFile, meta._realm)
        elseif file.Exists(jsonFile, meta._realm) then
            data[fname] = util.JSONToTable(file.Read(jsonFile, meta._realm))
        end
        -- 文件不存在则静默跳过（可选文件）
    end
    return data
end

-- ─────────────────────────────────────
-- 应用配置覆盖
-- ─────────────────────────────────────
local function ApplyConfigOverrides(meta)
    if not meta.config_overrides then return end
    for k, v in pairs(meta.config_overrides) do
        if Fireteam.Config and Fireteam.Config.Set then
            Fireteam.Config.Set(k, v, { silent = true })
        end
    end
end

-- ─────────────────────────────────────
-- 验证资产可用性
-- ─────────────────────────────────────
local function ValidateAssets(meta, data)
    local warnings = {}

    -- 检查武器 Tag 是否有匹配
    if data.weapons and data.classes then
        local allWeapons = Fireteam.WeaponInterface.GetAll and Fireteam.WeaponInterface.GetAll() or {}
        for classId, classDef in pairs(data.classes) do
            if classDef.loadout then
                for slotName, slotDef in pairs(classDef.loadout) do
                    if slotDef.tags and not slotDef.optional then
                        local matchCount = 0
                        for _, w in ipairs(allWeapons) do
                            local hasAll = true
                            for _, tag in ipairs(slotDef.tags) do
                                if not table.HasValue(w.tags or {}, tag) then
                                    hasAll = false; break
                                end
                            end
                            if hasAll then matchCount = matchCount + 1 end
                        end
                        if matchCount == 0 then
                            table.insert(warnings,
                                string.format("Class '%s' slot '%s': no weapons match tags [%s]",
                                    classId, slotName, table.concat(slotDef.tags, ", ")))
                        end
                    end
                end
            end
        end
    end

    if #warnings > 0 then
        Fireteam.Log.Warn("设定包", "⚠ 资源校验警告 ('" .. meta.id .. "'):")
        for _, w in ipairs(warnings) do
            Fireteam.Log.Warn("设定包", "  - " .. w)
        end
        hook.Run("Fireteam.Setting.AssetWarning", meta.id, warnings)
    end

    return warnings
end

-- ─────────────────────────────────────
-- 激活设定包（支持热切换）
-- ─────────────────────────────────────
function Fireteam.Setting.Activate(packId)
    local meta = Fireteam.Setting.Discovered[packId]
    if not meta then
        Fireteam.Log.Error("设定包", "✗ 未找到设定包: " .. packId)
        return false
    end

    -- 卸载旧包
    if Fireteam.Setting.Active then
        hook.Run(Fireteam.HOOKS.SETTING_UNLOAD, Fireteam.Setting.Active.id)
        Fireteam.Setting.Data = {}
    end

    -- 加载数据
    local ok, data = pcall(LoadDataFiles, meta)
    if not ok then
        Fireteam.Log.Error("设定包", "✗ 数据加载失败 '" .. packId .. "': " .. tostring(data))
        return false
    end

    -- 应用配置
    ApplyConfigOverrides(meta)

    -- 存储
    Fireteam.Setting.Data = data
    Fireteam.Setting.Active = meta

    -- 触发生命周期钩子
    hook.Run(Fireteam.HOOKS.SETTING_LOADED, packId, meta, data)

    -- 验证资产
    ValidateAssets(meta, data)

    -- 通知客户端
    net.Start(Fireteam.NET.SETTING_CHANGED)
        net.WriteString(packId)
        net.WriteString(meta.name)
    net.Broadcast()

    Fireteam.Log.Info("设定包", "✓ 已激活: " .. meta.name .. " (v" .. (meta.version or "?") .. ")")
    return true
end

-- ─────────────────────────────────────
-- 获取当前活跃设定包数据
-- ─────────────────────────────────────
function Fireteam.Setting.GetData(fileName)
    return Fireteam.Setting.Data[fileName]
end

function Fireteam.Setting.GetActiveId()
    return Fireteam.Setting.Active and Fireteam.Setting.Active.id or nil
end

-- ─────────────────────────────────────
-- ConVar 监听热切换
-- ─────────────────────────────────────
cvars.AddChangeCallback("ft_setting_pack", function(_, oldVal, newVal)
    if oldVal == newVal then return end
    Fireteam.Log.Info("设定包", "收到切换请求: " .. oldVal .. " → " .. newVal)
    Fireteam.Setting.Activate(newVal)
end)

Fireteam.Log.Info("设定包", "✓ 设定包加载器就绪")
