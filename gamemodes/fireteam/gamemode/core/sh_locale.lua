-- core/sh_locale.lua
-- FIRETEAM Localization System
-- 词条文件位于 gamemode/locale/<lang>.lua，返回 key = value 表。
-- 双端共享：跟随 gmod_language 自动选择，en 为兜底。

if not Fireteam then Fireteam = {} end
Fireteam.Locale = Fireteam.Locale or {}

local LOCALE_BASE = "gamemodes/fireteam/gamemode/locale/"
local FALLBACK_LANG = "en"

local currentLang = FALLBACK_LANG
local strings = {}          -- 当前语言词条
local fallbackStrings = {}  -- en 兜底词条

-- ─────────────────────────────────────
-- 读取语言文件（GAME 路径 + CompileString，
-- 与模块/设定包加载器同一模式，双端可用）
-- ─────────────────────────────────────
local function LoadLanguage(lang)
    local path = LOCALE_BASE .. lang .. ".lua"
    local contents = file.Read(path, "GAME")
    if not contents then return nil end
    local fn = CompileString(contents, path, false)
    if not fn then
        Fireteam.Log.Warn("多语言", "✗ 语言文件语法错误: " .. path)
        return nil
    end
    local tbl = fn()
    if not istable(tbl) then return nil end
    return tbl
end

--- 取词条；带参数时做 string.format 替换
function Fireteam.Locale.Get(key, ...)
    local s = strings[key] or fallbackStrings[key]
    if not s then return tostring(key) end
    if select("#", ...) > 0 then
        local ok, res = pcall(string.format, s, ...)
        if ok then return res end
    end
    return s
end

function Fireteam.Locale.GetLanguage()
    return currentLang
end

--- 切换语言；成功返回 true 并触发 Fireteam.Locale.Changed
function Fireteam.Locale.SetLanguage(lang)
    local tbl = LoadLanguage(lang)
    if not tbl then return false end
    currentLang = lang
    strings = tbl
    hook.Run("Fireteam.Locale.Changed", lang)
    Fireteam.Log.Info("多语言", "✓ 语言已切换: " .. lang)
    return true
end

-- gmod_language → 本框架语言文件名映射
local function ResolveGameLanguage()
    local cvar = GetConVar("gmod_language")
    local gameLang = cvar and cvar:GetString() or FALLBACK_LANG
    -- Steam 语言代码映射（schinese/tchinese → zh-CN）
    if gameLang == "schinese" or gameLang == "tchinese" then
        return "zh-CN"
    end
    return gameLang
end

-- ─────────────────────────────────────
-- 初始化：en 兜底必载，游戏语言可匹配则覆盖
-- ─────────────────────────────────────
fallbackStrings = LoadLanguage(FALLBACK_LANG) or {}
if next(fallbackStrings) == nil then
    Fireteam.Log.Warn("多语言", "⚠ 英文兜底词条为空或缺失")
end

local preferred = ResolveGameLanguage()
if preferred ~= FALLBACK_LANG then
    Fireteam.Locale.SetLanguage(preferred)
else
    strings = fallbackStrings
end

-- 游戏内切换语言时热重载
cvars.AddChangeCallback("gmod_language", function(_, _, newVal)
    local lang = newVal == "schinese" and "zh-CN"
        or newVal == "tchinese" and "zh-CN"
        or newVal
    Fireteam.Locale.SetLanguage(lang)
end)

Fireteam.Log.Info("多语言", "✓ 多语言系统就绪 (" .. currentLang .. ", "
    .. table.Count(strings) .. " 条词条)")
