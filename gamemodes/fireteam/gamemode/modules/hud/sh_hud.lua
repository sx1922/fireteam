-- modules/hud/sh_hud.lua
-- FIRETEAM HUD System - Shared

if not Fireteam then Fireteam = {} end
Fireteam.HUD = Fireteam.HUD or {}

-- 当前主题缓存
Fireteam.HUD.CurrentTheme = nil

-- 颜色缓存（需在下方闭包之前声明）
local colorCache = {}

-- ═══════════════════════════════════════
-- 客户端：跟踪活跃设定包 ID
-- （sv_setting_loader 仅在服务端运行，客户端通过
--   FT_SettingChanged 消息获知当前包）
-- ═══════════════════════════════════════
if CLIENT then
    net.Receive(Fireteam.NET.SETTING_CHANGED, function()
        Fireteam.Setting.ActiveId = net.ReadString()
        net.ReadString() -- pack name，预留
        Fireteam.HUD.ResetThemeCache()
    end)
end

-- ═══════════════════════════════════════
-- 获取当前主题数据
-- ═══════════════════════════════════════
function Fireteam.HUD.GetTheme()
    if Fireteam.HUD.CurrentTheme then
        return Fireteam.HUD.CurrentTheme
    end

    local themeFile = nil

    if SERVER then
        -- 服务端：从设定包注册表读取
        local active = Fireteam.Setting.GetActiveId()
        if active then
            local meta = Fireteam.Setting.Discovered and Fireteam.Setting.Discovered[active]
            if meta then
                themeFile = meta._path .. "hud_theme.json"
                if not file.Exists(themeFile, meta._realm or "GAME") then
                    themeFile = nil
                end
            end
        end
    else
        -- 客户端：按已知部署布局尝试多个候选路径
        local packId = Fireteam.Setting.ActiveId
        if packId then
            local candidates = {
                "gamemodes/fireteam/setting_packs/" .. packId .. "/hud_theme.json",
                "setting_packs/" .. packId .. "/hud_theme.json",
                "lua/fireteam_setting_packs/" .. packId .. "/hud_theme.json"
            }
            for _, path in ipairs(candidates) do
                if file.Exists(path, "GAME") then
                    themeFile = path
                    break
                end
            end
        end
    end

    if themeFile then
        local raw = file.Read(themeFile, "GAME")
        local parsed = raw and util.JSONToTable(raw) or nil
        if parsed then
            Fireteam.HUD.CurrentTheme = parsed
            return Fireteam.HUD.CurrentTheme
        end
    end

    -- 回退默认主题
    Fireteam.HUD.CurrentTheme = {
        theme_id = "fallback",
        palette = {
            primary = "#33ff33",
            secondary = "#1a8c1a",
            background = "#0a0a0a",
            surface = "#101810",
            border = "#1e3a1e",
            text = "#d0ffd0",
            text_muted = "#6fa06f",
            accent = "#39ff6a",
            success = "#33ff33",
            warning = "#ffcc00",
            danger = "#ff3333",
            info = "#64b4ff"
        },
        font = { primary = "DermaDefault", size_base = 16 },
        effects = { scanlines = false, vignette = 0 }
    }
    return Fireteam.HUD.CurrentTheme
end

-- 解析颜色字符串为 Color 对象
function Fireteam.HUD.ParseColor(hex)
    if not hex then return Color(255, 255, 255) end
    hex = hex:gsub("#", "")
    if #hex ~= 6 then return Color(255, 255, 255) end
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return Color(r, g, b)
end

-- 获取主题颜色（委托 UI Kit 统一管理：语义名 → 主题色 → 默认色兜底）
function Fireteam.HUD.GetColor(name)
    return Fireteam.UI.Color(name)
end

-- ─────────────────────────────────────
-- 主题缓存重置（双端入口）
-- 客户端 SETTING_CHANGED / HUD_THEME 消息与服务端
-- Setting.Loaded hook 均走此处；同时广播给 UI Kit 失效取色与字体缓存。
-- ─────────────────────────────────────
function Fireteam.HUD.ResetThemeCache()
    Fireteam.HUD.CurrentTheme = nil
    colorCache = {}
    hook.Run("Fireteam.UI.ThemeInvalidated")
end

-- 主题变更时清缓存（服务端侧：设定包重载）
hook.Add("Fireteam.Setting.Loaded", "HUD.ClearCache", function()
    Fireteam.HUD.ResetThemeCache()
end)

print("[FIRETEAM:HUD] ✓ Shared definitions loaded")
