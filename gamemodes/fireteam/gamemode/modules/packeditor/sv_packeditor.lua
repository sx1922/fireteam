-- modules/packeditor/sv_packeditor.lua
-- FIRETEAM Setting Pack Editor - Server Logic
-- PULL：把设定包全部数据文件解析成表发回客户端
-- EXPORT：接收编辑结果，写入 data/fireteam_packs/<id>/（JSON 格式）

if not Fireteam then Fireteam = {} end
Fireteam.PackEditor = Fireteam.PackEditor or {}

local L = function(key, ...)
    return Fireteam.Locale.Get(key, ...)
end

-- ─────────────────────────────────────
-- 读取单个设定包的全部数据（供 PULL）
-- ─────────────────────────────────────
local function ReadDataLua(path, realm)
    local contents = file.Read(path, realm)
    if not contents then return nil end
    local fn = CompileString(contents, path, false)
    if not fn then return nil end
    return fn()
end

local function CollectPack(meta)
    local out = {
        _source   = meta._source,
        _path     = nil,          -- 不外泄服务端路径细节
    }

    -- pack.json 元数据
    local rawMeta = file.Read(meta._path .. Fireteam.SETTING_PACK_META_FILE, meta._realm)
    out["pack"] = util.JSONToTable(rawMeta or "") or {}

    -- 数据文件（lua 优先，json 兜底；与加载器同序）
    for _, fname in ipairs(Fireteam.SETTING_DATA_FILES) do
        local luaFile  = meta._path .. fname .. ".lua"
        local jsonFile = meta._path .. fname .. ".json"
        if file.Exists(luaFile, meta._realm) then
            out[fname] = ReadDataLua(luaFile, meta._realm)
        elseif file.Exists(jsonFile, meta._realm) then
            out[fname] = util.JSONToTable(file.Read(jsonFile, meta._realm) or "")
        end
    end

    -- HUD 主题
    local themeFile = meta._path .. "hud_theme.json"
    if file.Exists(themeFile, meta._realm) then
        out["hud_theme"] = util.JSONToTable(file.Read(themeFile, meta._realm) or "")
    end

    return out
end

--- 设定包列表摘要 { [id] = displayName }
function Fireteam.PackEditor.GetPackList()
    local list = {}
    for id, meta in pairs(Fireteam.Setting.Discovered) do
        list[id] = meta.name or id
    end
    return list
end

-- ─────────────────────────────────────
-- 导出
-- ─────────────────────────────────────
local function WriteExport(packId, files)
    local root = Fireteam.PackEditor.EXPORT_ROOT .. packId .. "/"
    file.CreateDir(root)

    local written = {}
    for fname, tbl in pairs(files) do
        if istable(tbl) then
            local diskName
            if fname == "pack" then
                diskName = Fireteam.SETTING_PACK_META_FILE
            else
                diskName = fname .. ".json"
            end
            local json = util.TableToJSON(tbl, true)
            if json and file.Write(root .. diskName, json) then
                written[#written + 1] = diskName
            end
        end
    end
    return written
end

net.Receive(Fireteam.NET.PACK_EDITOR_PULL, function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    if not Fireteam.Config.Get("packeditor.enabled") then return end

    local wantId = net.ReadString()
    if wantId == "" then
        -- 空请求 → 只回列表
        Fireteam.Net.SendToPlayer(ply, Fireteam.NET.PACK_EDITOR_DATA,
            { packs = Fireteam.PackEditor.GetPackList() })
        return
    end

    local meta = Fireteam.Setting.Discovered[wantId]
    if not meta then
        Fireteam.Net.SendToPlayer(ply, Fireteam.NET.PACK_EDITOR_DATA,
            { packs = Fireteam.PackEditor.GetPackList(), error = "not_found" })
        return
    end

    Fireteam.Net.SendToPlayer(ply, Fireteam.NET.PACK_EDITOR_DATA, {
        packs = Fireteam.PackEditor.GetPackList(),
        id    = wantId,
        files = CollectPack(meta),
    })
end)

net.Receive(Fireteam.NET.PACK_EDITOR_EXPORT, function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then
        ply:ChatPrint("[FIRETEAM] " .. L("pe_need_admin"))
        return
    end
    if not Fireteam.Config.Get("packeditor.enabled") then return end

    local payload = net.ReadTable()
    if not istable(payload) or not isstring(payload.id) then return end

    local packId = string.match(payload.id, "[%w_%-]+")
    if not packId or packId == "" then
        ply:ChatPrint("[FIRETEAM] " .. L("pe_export_fail"))
        return
    end

    local ok, err = pcall(WriteExport, packId, payload.files or {})
    if ok and #err > 0 then
        ply:ChatPrint("[FIRETEAM] " .. L("pe_export_ok", packId, #err))
        Fireteam.Log.Info("设定包编辑器", ply:Nick() .. " 导出设定包 '" .. packId .. "'（" .. table.concat(err, ", ") .. "）")
    else
        ply:ChatPrint("[FIRETEAM] " .. L("pe_export_fail"))
    end
end)

Fireteam.Log.Info("设定包编辑器", "✓ 服务端已加载")
