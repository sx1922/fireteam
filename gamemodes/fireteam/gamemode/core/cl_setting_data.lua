-- core/cl_setting_data.lua
-- FIRETEAM Setting Data - Client Bridge
-- 服务端的设定包数据表（factions/classes/items/...）只活在服务端；
-- 客户端此前完全没有 Fireteam.Setting.GetData，导致语音预设、F7 阵营
-- 下拉、物品定义等共享路径在客户端全数报错。
--
-- 本桥接层在客户端按已激活包 id 直读同挂载点的设定包文件并缓存：
-- GMA/addon 订阅后客户端本地就有完整副本（lua/fireteam_setting_packs/
-- 或 gamemodes/fireteam/setting_packs），直读比逐文件网络同步更省且零延迟。
--
-- ⚠ 不在此注册 net.Receive(SETTING_CHANGED)：GMod 的 net 接收表是「一消息名一
-- 回调、后注册覆盖」，modules/hud/sh_hud.lua 加载更晚会把本文件的回调顶掉
-- （历史 P0：桥接层实际零生效）。改为惰性读 sh_hud 统一维护的
-- Fireteam.Setting.ActiveId，并在 id 变化时自动失效缓存。

if not CLIENT then return end

if not Fireteam then Fireteam = {} end
Fireteam.Setting = Fireteam.Setting or {}

local cache = {}          -- [fileName] = dataTable|false（cacheId 变化即整体丢弃）
local cacheId = nil       -- 上次构建缓存时的包 id

local SEARCH = {
    { path = "setting_packs/",                     realm = "GAME" },
    { path = "gamemodes/fireteam/setting_packs/",  realm = "GAME" },
    { path = "lua/fireteam_setting_packs/",        realm = "LUA" },
}

local function RunDataLua(path, realm)
    local contents = file.Read(path, realm)
    if not contents then return nil end
    local fn = CompileString(contents, path, false)
    if not fn then return nil end
    local tbl = fn()
    return istable(tbl) and tbl or nil
end

--- 校验文件名防路径穿越：只允许字母数字下划线
local function SafeName(fileName)
    if not isstring(fileName) then return nil end
    if not fileName:match("^[%w_]+$") then return nil end
    return fileName
end

--- 客户端设定包数据访问；未激活或无数据时返回 nil
function Fireteam.Setting.GetData(fileName)
    fileName = SafeName(fileName)
    if not fileName then return nil end

    local activeId = Fireteam.Setting.ActiveId
    if not activeId or activeId == "" then return nil end

    -- 换包（或首次拿到 id）即丢弃旧缓存
    if cacheId ~= activeId then
        cache = {}
        cacheId = activeId
    end

    local key = fileName
    local hit = cache[key]
    if hit ~= nil then return hit or nil end

    for _, sp in ipairs(SEARCH) do
        local base = sp.path .. activeId .. "/"
        if file.Exists(base .. fileName .. ".lua", sp.realm) then
            local data = RunDataLua(base .. fileName .. ".lua", sp.realm)
            -- 归一两种写法：纯表 / { items = {...} } 风格的顶层单键包装不在此处理，
            -- 与服务端 GetData 保持一致：返回整表，消费方自行取子键
            cache[key] = data or false
            return data or nil
        end
        -- .json 回退（磁盘部署场景；GMA 白名单本不含 json）
        if file.Exists(base .. fileName .. ".json", sp.realm) then
            local raw = file.Read(base .. fileName .. ".json", sp.realm)
            local data = raw and util.JSONToTable(raw) or nil
            cache[key] = data or false
            return data or nil
        end
    end

    cache[key] = false   -- 未找到也缓存，避免 Think 类调用反复扫盘
    return nil
end

Fireteam.Log.Info("设定包", "✓ 客户端数据桥接就绪")
