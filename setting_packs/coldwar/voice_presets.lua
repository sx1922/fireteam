-- setting_packs/coldwar/voice_presets.lua
-- 电台预设：频道结构与国别语音包映射。
-- 指挥频道的 access 列表按新职业 id（<角色>_<国家>）程序化生成：
-- 北约 = 小队长 + 通讯员；华约 = 小队长 + 政委 + 通讯员。

local NATO = { "usa", "uk", "west_germany", "france" }
local WTO  = { "ussr", "east_germany", "poland", "czechoslovakia" }

local commandAccess = {}
for _, id in ipairs(NATO) do
    table.insert(commandAccess, "squad_leader_" .. id)
    table.insert(commandAccess, "radio_operator_" .. id)
end
for _, id in ipairs(WTO) do
    table.insert(commandAccess, "squad_leader_" .. id)
    table.insert(commandAccess, "commissar_" .. id)
    table.insert(commandAccess, "radio_operator_" .. id)
end

return {

    model = "analog_radio",

    channels = {
        ["local"] = {
            name = "Local",
            name_zh = "地区频道",
            kind = "local",
            range = 800,
            interference = false,
            access = "all"
        },
        squad = {
            name = "Squad Net",
            name_zh = "小队频道",
            kind = "squad",
            range = 500,
            interference = true,
            encryption = false
        },
        command = {
            name = "Command Net",
            name_zh = "指挥频道",
            kind = "command",
            range = 2000,
            interference = true,
            encryption = true,
            access = commandAccess
        },
        emergency = {
            name = "Emergency",
            name_zh = "应急频道",
            kind = "all",
            range = 1000,
            interference = false,
            access = "all"
        }
    },

    effects = {
        radio_static = true,
        distance_falloff = true,
        terrain_occlusion = true,
        vehicle_noise_reduction = 0.4
    },

    voice_packs = {
        usa            = "sound/fireteam/coldwar/voice_en/",
        uk             = "sound/fireteam/coldwar/voice_en/",
        france         = "sound/fireteam/coldwar/voice_fr/",
        west_germany   = "sound/fireteam/coldwar/voice_de/",
        east_germany   = "sound/fireteam/coldwar/voice_de/",
        ussr           = "sound/fireteam/coldwar/voice_ru/",
        poland         = "sound/fireteam/coldwar/voice_pl/",
        czechoslovakia = "sound/fireteam/coldwar/voice_cs/"
    }
}
