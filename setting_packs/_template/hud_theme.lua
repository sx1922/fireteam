-- setting_packs/_template/hud_theme.lua
-- HUD 主题模板（Lua 版）。GMA 白名单不含 .json，打算发布到 Workshop 的包
-- 必须提供本文件；磁盘部署时 hud_theme.json 亦可（加载器 .lua 优先、.json 回退）。

return {
    theme_id = "my_theme",
    name = "My Custom Theme",

    palette = {
        primary          = "#33ff33",
        secondary        = "#1a8c1a",
        background       = "#0a0a0a",
        surface          = "#121212",
        border           = "#2a2a2a",
        text             = "#e0e0e0",
        text_muted       = "#909090",
        accent           = "#33ff33",
        success          = "#44dd44",
        warning          = "#ffcc00",
        danger           = "#ff3333",
        info             = "#64b4ff",
        squad_ally       = "#66cc66",
        squad_leader     = "#ffd94d",
        marker_waypoint  = "#33ff88",
        marker_enemy     = "#ff3333",
        marker_objective = "#ffcc00",
        marker_danger    = "#ff6600",
        marker_rally     = "#64b4ff",
        marker_medical   = "#ff6699"
    },

    font = {
        primary   = "Roboto",
        fallback  = "Arial",
        size_base = 16
    },

    effects = {
        scanlines = false,
        flicker   = false,
        vignette  = 0.2,
        grain     = 0.0
    },

    elements = {
        compass      = { style = "digital_bar", position = "bottom_center" },
        round_info   = { style = "info_panel", position = "top_left" },
        ammo         = { style = "text_block", position = "bottom_right" },
        health       = { style = "text_block", position = "bottom_left" },
        squad_status = { style = "sidebar_list", position = "bottom_left" },
        consumables  = { style = "chip_row", position = "bottom_center" },
        stamina      = { style = "bar", position = "bottom_center" },
        map          = { style = "digital", open_key = "M" }
    }
}
