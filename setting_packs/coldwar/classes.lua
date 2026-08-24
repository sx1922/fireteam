-- setting_packs/coldwar/classes.lua
return {

    rifleman_west = {
        name = "Rifleman",
        name_zh = "步枪手",
        faction = "western_alliance",
        icon = "fireteam/classes/rifleman.png",
        loadout = {
            primary = { tags = { "nato", "coldwar_west", "assault_rifle" }, count = 1 },
            secondary = { tags = { "nato", "pistol" }, count = 1, optional = true },
            grenade = { tags = { "nato", "frag_grenade" }, count = 2 }
        },
        stats = { speed_mult = 1.0, armor = 1, stamina = 100, radio_access = true },
        abilities = { "mark_target", "call_medical" }
    },

    squad_leader_west = {
        name = "Squad Leader",
        name_zh = "小队长",
        faction = "western_alliance",
        icon = "fireteam/classes/leader.png",
        loadout = {
            primary = { tags = { "nato", "coldwar_west", "assault_rifle" }, count = 1 },
            sidearm = { tags = { "nato", "pistol" }, count = 1 }
        },
        stats = { speed_mult = 0.95, armor = 1, stamina = 100, radio_access = true, radio_channels = { "squad", "command" } },
        abilities = { "mark_target", "call_medical", "issue_orders", "call_artillery" }
    },

    machine_gunner_west = {
        name = "Machine Gunner",
        name_zh = "机枪手",
        faction = "western_alliance",
        icon = "fireteam/classes/mg.png",
        loadout = {
            primary = { tags = { "nato", "coldwar_west", "lmg" }, count = 1 },
            secondary = { tags = { "nato", "pistol" }, count = 1, optional = true },
            ammo_belt = { tags = { "nato", "ammo_box" }, count = 1 }
        },
        stats = { speed_mult = 0.85, armor = 2, stamina = 120, radio_access = true },
        abilities = { "suppress_area", "mark_target" }
    },

    marksman_west = {
        name = "Marksman",
        name_zh = "精确射手",
        faction = "western_alliance",
        icon = "fireteam/classes/marksman.png",
        loadout = {
            primary = { tags = { "nato", "coldwar_west", "dmr" }, count = 1 },
            secondary = { tags = { "nato", "pistol" }, count = 1 }
        },
        stats = { speed_mult = 1.0, armor = 1, stamina = 100, radio_access = true },
        abilities = { "mark_target", "overwatch" }
    },

    medic_west = {
        name = "Combat Medic",
        name_zh = "战斗医疗兵",
        faction = "western_alliance",
        icon = "fireteam/classes/medic.png",
        loadout = {
            primary = { tags = { "nato", "coldwar_west", "carbine" }, count = 1 },
            medical = { tags = { "nato", "medkit" }, count = 2 }
        },
        stats = { speed_mult = 1.05, armor = 0, stamina = 100, radio_access = true },
        abilities = { "heal", "revive", "mark_target" }
    },

    radio_operator_west = {
        name = "Radio Operator",
        name_zh = "通讯员",
        faction = "western_alliance",
        icon = "fireteam/classes/radio.png",
        loadout = {
            primary = { tags = { "nato", "coldwar_west", "assault_rifle" }, count = 1 },
            secondary = { tags = { "nato", "pistol" }, count = 1 }
        },
        stats = { speed_mult = 0.9, armor = 1, stamina = 100, radio_access = true, radio_channels = { "squad", "command" } },
        abilities = { "mark_target", "relay_orders", "call_artillery" }
    },

    -- ═══ 东方集团 ═══

    rifleman_east = {
        name = "Rifleman",
        name_zh = "步枪手",
        faction = "eastern_bloc",
        icon = "fireteam/classes/rifleman_e.png",
        loadout = {
            primary = { tags = { "warsaw_pact", "coldwar_east", "assault_rifle" }, count = 1 },
            secondary = { tags = { "warsaw_pact", "pistol" }, count = 1, optional = true },
            grenade = { tags = { "warsaw_pact", "frag_grenade" }, count = 2 }
        },
        stats = { speed_mult = 1.0, armor = 1, stamina = 100, radio_access = true },
        abilities = { "mark_target", "call_medical" }
    },

    squad_leader_east = {
        name = "Squad Leader",
        name_zh = "小队长",
        faction = "eastern_bloc",
        icon = "fireteam/classes/leader_e.png",
        loadout = {
            primary = { tags = { "warsaw_pact", "coldwar_east", "assault_rifle" }, count = 1 },
            sidearm = { tags = { "warsaw_pact", "pistol" }, count = 1 }
        },
        stats = { speed_mult = 0.95, armor = 1, stamina = 100, radio_access = true, radio_channels = { "squad", "command" } },
        abilities = { "mark_target", "call_medical", "issue_orders" }
    },

    machine_gunner_east = {
        name = "Machine Gunner",
        name_zh = "机枪手",
        faction = "eastern_bloc",
        icon = "fireteam/classes/mg_e.png",
        loadout = {
            primary = { tags = { "warsaw_pact", "coldwar_east", "lmg" }, count = 1 },
            secondary = { tags = { "warsaw_pact", "pistol" }, count = 1, optional = true },
            ammo_belt = { tags = { "warsaw_pact", "ammo_box" }, count = 1 }
        },
        stats = { speed_mult = 0.85, armor = 2, stamina = 120, radio_access = true },
        abilities = { "suppress_area", "mark_target" }
    },

    commissar_east = {
        name = "Commissar",
        name_zh = "政委",
        faction = "eastern_bloc",
        icon = "fireteam/classes/commissar.png",
        loadout = {
            primary = { tags = { "warsaw_pact", "pistol" }, count = 1 },
            secondary = { tags = { "warsaw_pact", "smg" }, count = 1 }
        },
        stats = { speed_mult = 1.0, armor = 1, stamina = 100, radio_access = true, radio_channels = { "squad", "command" } },
        abilities = { "issue_orders", "rally", "mark_target" }
    },

    medic_east = {
        name = "Field Medic",
        name_zh = "野战医疗兵",
        faction = "eastern_bloc",
        icon = "fireteam/classes/medic_e.png",
        loadout = {
            primary = { tags = { "warsaw_pact", "coldwar_east", "carbine" }, count = 1 },
            medical = { tags = { "warsaw_pact", "medkit" }, count = 2 }
        },
        stats = { speed_mult = 1.05, armor = 0, stamina = 100, radio_access = true },
        abilities = { "heal", "revive", "mark_target" }
    }
}
