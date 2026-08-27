-- setting_packs/coldwar/pack.lua
-- 包元数据（Lua 版）。GMA 白名单不含 .json，Workshop 分发必须用本文件；
-- 磁盘部署时 pack.json 仍可用（加载器 .lua 优先、.json 回退）。
-- 两份内容需保持同步。

return {
    id = "coldwar",
    name = "Iron Curtain Germany",
    version = "1.2.0",
    author = "FIRETEAM Team",
    description = "Cold War tactical setting, 1968-1985. Eight playable factions — US, UK, West Germany, France vs USSR, East Germany, Poland, Czechoslovakia — across two scenarios: the Fulda Gap corridor battle (default) and the Battle of West Berlin.",
    icon = "materials/fireteam/packs/coldwar_icon.png",

    era = { start = 1968, ["end"] = 1985 },

    factions = {
        "usa", "uk", "west_germany", "france",
        "ussr", "east_germany", "poland", "czechoslovakia"
    },

    scenarios = {
        { id = "fulda_gap", name = "Fulda Gap", name_zh = "富尔达缺口" },
        { id = "berlin", name = "Battle of West Berlin", name_zh = "西柏林之战" }
    },

    recommended_addons = {
        { workshop_id = "000000001", name = "ARC9 Cold War Weapons", type = "weapon" },
        { workshop_id = "000000002", name = "LVS Wheeled Vehicles", type = "vehicle" },
        { workshop_id = "000000003", name = "Cold War Sound Pack", type = "sound" }
    },

    config_overrides = {
        ["voice.model"] = "analog_radio",
        ["voice.distance_max"] = 800,
        ["voice.interference"] = true,
        ["hud.theme"] = "crt_green",
        ["ballistics.bullet_drop"] = true,
        ["ballistics.suppression_mult"] = 1.2,
        ["marker.style"] = "chalk",
        ["squad.max_size"] = 6,
        ["squad.friendly_fire"] = false
    }
}
