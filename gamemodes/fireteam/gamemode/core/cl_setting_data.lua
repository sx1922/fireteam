-- core/cl_setting_data.lua
-- FIRETEAM Setting Data - Client Bridge
-- 服务端的设定包数据表（factions/classes/items/...）只活在服务端；
-- 客户端此前完全没有 Fireteam.Setting.GetData，导致语音预设、F7 阵营
-- 下拉、物品定义等共享路径在客户端全数报错。
--
-- 本桥接层在客户端按已激活包 id 直读同挂载点的设定包文件并缓存：
-- GMA/addon 订阅后客户端本地就有完整副本（lua/fireteam_setting_packs/
-- 或 gamemodes/fireteam/setting_packs），直读比逐文件网络同步更省且零延迟。

if not CLIENT then return end

if not Fireteam then Fireteam = {} end
Fireteam.Setting = Fireteam.Setting or {}

local cache = {}          -- [packId..":"..fileName] = dataTable|false
local activeId = nil      -- 当前激活包 id（SETTING_CHANGED 第三段为包基准路径，前两段可反推）

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
    if not (fileName and activeId) then return nil end

    local key = activeId .. ":" .. fileName
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

--- 激活状态（与 sh_hud.lua 的接收互不影响，各读各的消息段）
net.Receive(Fireteam.NET.SETTING_CHANGED, function()
    Fireteam.Setting.ActiveId = net.ReadString()
    net.ReadString()             -- pack name，跳过
    local basePath = net.ReadString()

    -- 从包路径反推 pack id（取末段目录名），保证缓存键与后续查询一致
    local cleaned = string.gsub(tostring(basePath), "[\\/]+$", "")
    local id = string.match(cleaned, "([^/\\]+)$")
    if id and id ~= "" then activeId = id end

    cache = {}                   -- 换包即清缓存
end)

Fireteam.Log.Info("设定包", "✓ 客户端数据桥接就绪")
