-- setting_packs/_template/pack.lua
-- 包元数据模板（Lua 版）。GMA 白名单不含 .json，打算发布到 Workshop 的包
-- 必须提供本文件；磁盘部署时 pack.json 亦可（加载器 .lua 优先、.json 回退）。

return {
    id = "my_setting",
    name = "My Custom Setting",
    version = "1.0.0",
    author = "Your Name",
    description = "Describe your setting here",
    icon = "materials/fireteam/packs/my_setting_icon.png",

    era = { start = 1990, ["end"] = 2020 },

    recommended_addons = {
        {
            workshop_id = "000000000",
            name = "Example Weapon Pack",
            type = "weapon"
        }
    },

    config_overrides = {
        ["voice.model"] = "digital",
        ["voice.distance_max"] = 1000,
        ["hud.theme"] = "modern_digital",
        ["ballistics.bullet_drop"] = true,
        ["ballistics.suppression_mult"] = 1.0,
        ["marker.style"] = "digital"
    }
}
