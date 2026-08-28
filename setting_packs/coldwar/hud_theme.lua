-- setting_packs/coldwar/hud_theme.lua
-- HUD 主题（Lua 版）。GMA 白名单不含 .json，Workshop 分发必须用本文件；
-- 磁盘部署时 hud_theme.json 仍可用（加载器 .lua 优先、.json 回退）。
-- 两份内容需保持同步。

return {
    theme_id = "coldwar_military",
    name = "Cold War Military",

    palette = {
        primary          = "#c4a35a",   -- 沙金/军牌色
        secondary        = "#8a8560",   -- 卡其暗调
        background       = "#2a2e1e",   -- 橄榄军绿
        surface          = "#1e2218",   -- 深橄榄
        border           = "#3a3520",   -- 暗卡其边框
        text             = "#d4c9a0",   -- 卡其文字
        text_muted       = "#8a8560",   -- 暗卡其
        accent           = "#b87333",   -- 铁锈橙（模板喷漆感）
        success          = "#5a7a3a",   -- 军绿
        warning          = "#c4a35a",   -- 沙金
        danger           = "#8b3a2a",   -- 铁锈红
        info             = "#6a8a9a",   -- 灰蓝
        squad_ally       = "#6a9a4a",   -- 友军绿
        squad_leader     = "#c4a35a",   -- 队长金
        marker_waypoint  = "#b87333",   -- 路点铁锈
        marker_enemy     = "#8b3a2a",   -- 敌方锈红
        marker_objective = "#c4a35a",   -- 目标金
        marker_danger    = "#b87333",   -- 危险橙
        marker_rally    = "#6a8a9a",   -- 集结灰蓝
        marker_medical   = "#7a5a6a"    -- 医疗暗紫
    },

    font = {
        primary   = "Courier Prime",
        fallback  = "Courier New",
        size_base = 16
    },

    effects = {
        scanlines = false,
        flicker   = false,
        vignette  = 0.25,
        grain     = 0.08
    },

    elements = {
        compass         = { style = "analog_tape", position = "bottom_center" },
        round_info      = { style = "info_panel", position = "top_left" },
        ammo            = { style = "text_block", position = "bottom_right" },
        health          = { style = "text_block", position = "bottom_left" },
        squad_status    = { style = "sidebar_list", position = "bottom_left" },
        consumables     = { style = "chip_row", position = "bottom_center" },
        stamina         = { style = "bar", position = "bottom_center" },
        map             = { style = "paper_fold", open_key = "M" },
        radio_indicator = { style = "frequency_dial", position = "bottom_left" }
    }
}
