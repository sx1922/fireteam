-- modules/packeditor/sh_pack_editor.lua
-- FIRETEAM Setting Pack Editor - Shared Definitions
-- 接口级可视化设定包编辑器：schema 驱动表单，导出为 JSON 设定包。
-- GMod 沙箱限制服务端只能写 data/，导出目录为 data/fireteam_packs/<id>/，
-- 复制到 setting_packs/（或打包 Workshop）后即可被发现与激活。

if not Fireteam then Fireteam = {} end
Fireteam.PackEditor = Fireteam.PackEditor or {}

Fireteam.Config.Register("packeditor.enabled", true, {
    type = "boolean", desc = "F9 设定包编辑器总开关"
})

-- 导出根目录（相对 garrysmod/data/）
Fireteam.PackEditor.EXPORT_ROOT = "fireteam_packs/"

-- ═══════════════════════════════════════
-- Schema：可编辑字段的声明式描述
-- file = 数据文件名（导出时 pack→pack.json，其余→<file>.json）
-- path 支持点分路径；@ 前缀表示整表特化编辑器（调色板/元素布局）
-- ═══════════════════════════════════════
Fireteam.PackEditor.SCHEMA = {
    {
        file      = "pack",
        title_key = "pe_sec_meta",
        fields    = {
            { path = "id",          type = "string" },
            { path = "name",        type = "string" },
            { path = "version",     type = "string" },
            { path = "author",      type = "string" },
            { path = "description", type = "text" },
        }
    },
    {
        file      = "hud_theme",
        title_key = "pe_sec_theme",
        fields    = {
            { path = "theme_id", type = "string" },
            { path = "@palette", type = "colormap" },
            { path = "@elements", type = "elementmap" },
            { path = "font.primary",   type = "string" },
            { path = "font.fallback",  type = "string" },
            { path = "font.size_base", type = "number", min = 8, max = 32 },
            { path = "effects.scanlines", type = "boolean" },
            { path = "effects.flicker",   type = "boolean" },
            { path = "effects.vignette",  type = "number", min = 0, max = 1 },
            { path = "effects.grain",     type = "number", min = 0, max = 1 },
        }
    },
    {
        file      = "map_rules",
        title_key = "pe_sec_maprules",
        fields    = {
            { path = "rules.fog_density",     type = "number", min = 0, max = 1 },
            { path = "rules.time_of_day",     type = "enum",
              options = { "dawn", "morning", "noon", "afternoon", "dusk", "night" } },
            { path = "rules.weather",         type = "enum",
              options = { "clear", "overcast", "rain", "storm", "fog" } },
            { path = "rules.civilian_allowed", type = "boolean" },
            { path = "rules.checkpoint_mode",  type = "boolean" },
            { path = "rounds.enabled",           type = "boolean" },
            { path = "rounds.warmup_time",       type = "number", min = 0, max = 600 },
            { path = "rounds.briefing_time",     type = "number", min = 0, max = 120 },
            { path = "rounds.round_time",        type = "number", min = 60, max = 3600 },
            { path = "rounds.ended_time",        type = "number", min = 0, max = 120 },
            { path = "rounds.intermission_time", type = "number", min = 0, max = 300 },
            { path = "rounds.kill_points",       type = "number", min = 0, max = 10 },
            { path = "rounds.objective_points",  type = "number", min = 0, max = 10 },
        }
    },
}

-- ═══════════════════════════════════════
-- 路径读写工具
-- ═══════════════════════════════════════
function Fireteam.PackEditor.PathGet(tbl, path)
    local cur = tbl
    for seg in string.gmatch(path, "[^.]+") do
        if not istable(cur) then return nil end
        cur = cur[seg]
    end
    return cur
end

function Fireteam.PackEditor.PathSet(tbl, path, value)
    local segs = {}
    for seg in string.gmatch(path, "[^.]+") do
        segs[#segs + 1] = seg
    end
    local cur = tbl
    for i = 1, #segs - 1 do
        if not istable(cur[segs[i]]) then cur[segs[i]] = {} end
        cur = cur[segs[i]]
    end
    cur[segs[#segs]] = value
end

-- ═══════════════════════════════════════
-- 颜色序列化（hud_theme palette 用 "#rrggbb" 字符串）
-- ═══════════════════════════════════════
function Fireteam.PackEditor.HexToColor(hex)
    if not isstring(hex) then return Color(255, 255, 255) end
    local r, g, b = string.match(hex, "^#(%x%x)(%x%x)(%x%x)")
    if not r then return Color(255, 255, 255) end
    return Color(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

function Fireteam.PackEditor.ColorToHex(c)
    return string.format("#%02x%02x%02x", c.r, c.g, c.b)
end

print("[FIRETEAM:PackEditor] ✓ Shared definitions loaded")
