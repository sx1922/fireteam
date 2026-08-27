-- setting_packs/coldwar/locale/en.lua
-- Cold War pack-specific strings, injected on pack activation via
-- Fireteam.Locale.LoadPack (server: Setting.Activate; client: FT_SettingChanged).
-- Only "cw_"/"ui_cwt_"-prefixed keys live here to avoid clobbering gamemode strings.

return {
    -- F10 Cold War scenario preset tool
    ui_cwt_title           = "Cold War Scenario Tool",
    ui_cwt_scenario        = "Scenario:",
    ui_cwt_faction         = "Faction:",
    ui_cwt_role            = "Vehicle Role:",
    ui_cwt_spawn           = "Spawn Point:",
    ui_cwt_apply           = "Apply Selection",
    ui_cwt_err_scenario    = "Please select a scenario.",
    ui_cwt_err_faction     = "Please select a faction.",
    ui_cwt_err_role        = "Please select a vehicle role.",
    ui_cwt_err_spawn       = "Please select a spawn point.",
    ui_cwt_applied         = "Selection applied.",
}
