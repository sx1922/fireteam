-- setting_packs/coldwar/player_models.lua
-- 阵营 → 玩家模型映射。spawn 时由 sv_class 的 PlayerSpawn hook 读取并 SetModel。
-- 模型来自 coldwar_content/03_人物模型 各子包，路径为 GMod 挂载后的相对路径。
-- Poland / Czechoslovakia 无模型包，已从 factions.lua 锁定（locked=true），此处不列。

return {
    -- ═══════════ NATO ═══════════

    usa = {
        -- olegun 通用冷战步兵，按迷彩区分国家
        "models/olegun/coldwarinfantry/coldwar_woodland.mdl",
        "models/olegun/coldwarinfantry/coldwar_green.mdl",
    },

    uk = {
        "models/coom pm/britbong.mdl",
        "models/coom pm/britbong2.mdl",
    },

    west_germany = {
        "models/westgermans/soldier_west.mdl",
        "models/westgermans/soldier_austria_cold.mdl",
    },

    france = {
        -- olegun 用不同迷彩与 US 区分
        "models/olegun/coldwarinfantry/coldwar_dcu.mdl",
        "models/olegun/coldwarinfantry/coldwar_choco.mdl",
    },

    -- ═══════════ Warsaw Pact ═══════════

    ussr = {
        -- alvin/boris/viktor 等角色名 × infantry/crewman/officer/vdvscout 等兵种
        "models/playermodel/soviet/alvin_infantry_01_pm.mdl",
        "models/playermodel/soviet/boris_infantry_01_pm.mdl",
        "models/playermodel/soviet/viktor_infantry_01_pm.mdl",
        "models/playermodel/soviet/alvin_infantry_officer_pm.mdl",
        "models/playermodel/soviet/boris_vdvscout_01_pm.mdl",
        "models/playermodel/soviet/alvin_crewman_01_pm.mdl",
        "models/playermodel/soviet/zurich_infantry_01_pm.mdl",
        "models/playermodel/soviet/tabatabai_infantry_01_pm.mdl",
    },

    east_germany = {
        -- stassi = 军装版（与 civilian 区分）
        "models/playermodel/eastgerman/viktor_stassi_01.mdl",
        "models/playermodel/eastgerman/tabatabai_stassi_01.mdl",
        "models/playermodel/eastgerman/helga_stassi_01.mdl",
        "models/playermodel/eastgerman/monika_stassi_01.mdl",
        "models/playermodel/eastgerman/zurich_stassi_01.mdl",
    },

    -- poland / czechoslovakia：无玩家模型包，factions.lua 已 locked=true
}
