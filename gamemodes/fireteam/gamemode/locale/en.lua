-- gamemode/locale/en.lua
-- FIRETEAM English Localization

return {
    -- 小队
    squad_created          = "Squad created",
    squad_disbanded        = "Squad disbanded",
    squad_joined           = "You joined the squad",
    squad_left             = "You left the squad",
    squad_full             = "Squad is full",
    squad_not_found        = "Squad not found",
    already_in_squad       = "You are already in a squad",
    not_in_squad           = "You are not in a squad",
    leader_promoted        = "%s is now the squad leader",
    member_kicked          = "%s was kicked from the squad",
    not_leader             = "Only the squad leader can do that",

    -- 职业
    class_selected         = "Class selected: %s",
    class_locked           = "This class is locked",
    class_limit_reached    = "Class limit reached",
    loadout_given          = "Loadout issued",

    -- 标记
    marker_placed          = "Marker placed",
    marker_removed         = "Marker removed",
    marker_limit_reached   = "Marker limit reached",
    too_far_from_marker    = "Too far from marker",

    -- 载具
    vehicle_locked         = "Vehicle locked - wrong crew",
    vehicle_no_seat        = "No free seats",
    vehicle_destroyed      = "Vehicle destroyed",

    -- 压制
    suppressed_light       = "SUPPRESSED",
    suppressed_heavy       = "HEAVY FIRE",
    suppressed_pinned      = "PINNED DOWN",

    -- 系统
    setting_pack_loaded    = "Setting pack loaded: %s",
    setting_pack_failed    = "Failed to load setting pack: %s",
    hud_theme_updated      = "HUD theme updated",

    -- UI 面板
    ui_squad_title         = "FIRETEAM — Squad Management",
    ui_class_title         = "FIRETEAM — Select Class",
    ui_current_squad       = "Current Squad: %s [%s]",
    ui_member_count        = "%d member(s)",
    ui_leave_squad         = "Leave Squad",
    ui_squad_name          = "Squad Name:",
    ui_squad_name_placeholder = "Enter squad name...",
    ui_select_faction      = "Faction:",
    ui_create_squad        = "Create Squad",
    ui_available_squads    = "Available Squads",
    ui_join_squad_first    = "Join a squad first to select a class.",
    ui_abilities           = "Abilities: %s",
    ui_current             = "CURRENT",
    ui_hint_esc_close      = "ESC to close"
}
