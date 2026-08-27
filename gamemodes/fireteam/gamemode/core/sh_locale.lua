-- core/sh_locale.lua
-- FIRETEAM Localization System
-- 词条文件位于 gamemode/locale/<lang>.lua，返回 key = value 表。
-- 设定包可通过 <pack>/locale/<lang>.lua 注入专属词条（见 LoadPack）。
-- 双端共享：跟随 gmod_language 自动选择，en 为兜底。

if not Fireteam then Fireteam = {} end
Fireteam.Locale = Fireteam.Locale or {}

local LOCALE_BASE = "gamemodes/fireteam/gamemode/locale/"
local FALLBACK_LANG = "en"

local currentLang = FALLBACK_LANG
local strings = {}          -- 当前语言词条
local fallbackStrings = {}  -- en 兜底词条
local packStrings = {}      -- 设定包词条（当前语言）
local packFallback = {}     -- 设定包词条（en 兜底）
local activePack = nil      -- { path=..., realm=... }，语言热切换时自动重载

-- ─────────────────────────────────────
-- 读取语言文件（GAME 路径 + CompileString，
-- 与模块/设定包加载器同一模式，双端可用）
-- ─────────────────────────────────────
local function ReadLangTable(path, realm)
    local contents = file.Read(path, realm)
    if not contents then return nil end
    local fn = CompileString(contents, path, false)
    if not fn then
        Fireteam.Log.Warn("多语言", "✗ 语言文件语法错误: " .. path)
        return nil
    end
    local tbl = fn()
    return istable(tbl) and tbl or nil
end

local function LoadLanguage(lang)
    return ReadLangTable(LOCALE_BASE .. lang .. ".lua", "GAME")
end

--- 取词条；带参数时做 string.format 替换。
--- 解析顺序：游戏当前语言 → 设定包当前语言 → en 兜底 → 设定包 en。
--- 同 key 下允许设定包覆盖 gamemode 词条（供题材专有用语微调）。
function Fireteam.Locale.Get(key, ...)
    local s = strings[key] or packStrings[key]
        or fallbackStrings[key] or packFallback[key]
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

-- ─────────────────────────────────────
-- 设定包词条注入（双端）
-- 服务端在 Setting.Activate 时调用；客户端经 FT_SettingChanged
-- 携带的包路径调用。pathPrefix 形如 "setting_packs/coldwar/"。
-- 重复调用即整体替换（热切换新包自动顶掉旧包词条）。
-- ─────────────────────────────────────
function Fireteam.Locale.LoadPack(pathPrefix, realm)
    activePack = { path = pathPrefix, realm = realm or "GAME" }

    packStrings = ReadLangTable(pathPrefix .. "locale/" .. currentLang .. ".lua",
        activePack.realm) or {}
    packFallback = ReadLangTable(pathPrefix .. "locale/" .. FALLBACK_LANG .. ".lua",
        activePack.realm) or {}

    local n = table.Count(packStrings) + table.Count(packFallback)
    Fireteam.Log.Info("多语言", "✓ 设定包词条已注入: "
        .. pathPrefix .. " (" .. n .. " 条)")
    hook.Run(Fireteam.HOOKS.LOCALE_CHANGED, currentLang)
    return true
end

function Fireteam.Locale.ClearPack()
    activePack = nil
    packStrings = {}
    packFallback = {}
end

--- 切换语言；成功返回 true 并触发 Fireteam.Locale.Changed。
--- 有激活设定包时，包词条层按新语言一并重载（保留 en 层不重读）。
function Fireteam.Locale.SetLanguage(lang)
    local tbl = LoadLanguage(lang)
    if not tbl then return false end
    currentLang = lang
    strings = tbl
    if activePack then
        packStrings = ReadLangTable(
            activePack.path .. "locale/" .. lang .. ".lua", activePack.realm) or {}
    end
    hook.Run(Fireteam.HOOKS.LOCALE_CHANGED, lang)
    Fireteam.Log.Info("多语言", "✓ 语言已切换: " .. lang)
    return true
end

-- gmod_language → 本框架语言文件名映射
-- GMod 语言代码（schinese/tchinese/russian/…）→ 框架 locale 文件名
local LANGUAGE_MAP = {
    ["schinese"]  = "zh-CN",
    ["tchinese"]  = "zh-TW",
    ["russian"]   = "ru",
    ["spanish"]   = "es",
    ["french"]    = "fr",
    ["german"]    = "de",
    ["japanese"]  = "ja",
    ["korean"]    = "ko",
    ["english"]   = "en",
}
local function ResolveGameLanguage()
    local cvar = GetConVar("gmod_language")
    local gameLang = cvar and cvar:GetString() or FALLBACK_LANG
    return LANGUAGE_MAP[gameLang] or gameLang
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
    local lang = LANGUAGE_MAP[newVal] or newVal
    Fireteam.Locale.SetLanguage(lang)
end)

Fireteam.Log.Info("多语言", "✓ 多语言系统就绪 (" .. currentLang .. ", "
    .. table.Count(strings) .. " 条词条)")
