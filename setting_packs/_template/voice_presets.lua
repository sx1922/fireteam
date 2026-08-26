-- _template/voice_presets.lua
-- ═════════════════════════════════════════════════════════════
-- 语音频道结构（战术小队式三频道：地区/小队/指挥 + 应急）。
--
-- kind 决定收听分流（PlayerCanHearPlayersVoice）：
--   local   地区频道：range 内所有人可听，3D 人声（range 缺省读 voice.distance_max）
--   squad   小队网：仅同小队成员，range 内
--   command 指挥网：同阵营全部成员，range 内；发言需 access 权限（职业 id 列表）
--   all     全服广播（应急），range 内
--
-- 切换热键默认 V=地区 / B=小队 / G=指挥（config voice.key_local/squad/command 可改绑）。
-- range ≤ 0 视为不限距。不声明 ["local"] 时框架内置兜底。
-- 旧包不写 kind 时按频道 id 推断（squad→squad / command→command / emergency→all），
-- 完全向后兼容。
--
-- access 写法："all" 或职业 id 列表（职业 id 见 classes.lua，建议 角色_阵营 格式）。
-- ═════════════════════════════════════════════════════════════
return {

    model = "digital",   -- analog_radio | digital | direct | field_phone（氛围音风格，预留）

    channels = {
        ["local"] = {
            name = "Local",            -- 频道名（电台面板显示）
            name_zh = "地区频道",       -- 中文客户端显示
            kind = "local",
            range = 800,               -- 收听半径（世界单位）
            interference = false,      -- 是否受地形干扰（氛围音量衰减）
            access = "all"
        },
        squad = {
            name = "Squad Net",
            name_zh = "小队频道",
            kind = "squad",
            range = 600,
            interference = true,
            encryption = false         -- 预留字段
        },
        command = {
            name = "Command Net",
            name_zh = "指挥频道",
            kind = "command",
            range = 2000,              -- 0 = 不限距
            interference = true,
            encryption = true,
            access = { "leader_alpha" }  -- 谁能切到指挥网发言（职业 id 列表）
        },
        emergency = {
            name = "Emergency",
            name_zh = "应急频道",
            kind = "all",
            range = 1200,
            interference = false,
            access = "all"
        }
    },

    effects = {                        -- 氛围音开关（radio_static=false 关停底声，其余预留）
        radio_static = true,
        distance_falloff = true,
        terrain_occlusion = true,
        vehicle_noise_reduction = 0.4
    },

    voice_packs = {                    -- 阵营 → 语音目录映射（预留）
        faction_alpha = "sound/fireteam/my_setting/voice_alpha/",
        faction_beta  = "sound/fireteam/my_setting/voice_beta/"
    }
}
