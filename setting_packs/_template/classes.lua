-- _template/classes.lua
-- 职业定义：通过 Tag 引用武器，不写死具体类名
return {

    rifleman_alpha = {
        name = "Rifleman",
        name_zh = "步枪手",
        faction = "faction_alpha",
        icon = "fireteam/classes/rifleman.png",

        loadout = {
            primary = {
                tags = { "faction_alpha", "assault_rifle" },
                count = 1
            },
            secondary = {
                tags = { "faction_alpha", "pistol" },
                count = 1,
                optional = true
            },
            grenade = {
                tags = { "faction_alpha", "frag_grenade" },
                count = 2
            }
        },

        stats = {
            speed_mult = 1.0,
            armor = 1,
            stamina = 100,
            radio_access = true
        },

        abilities = { "mark_target", "call_medical" }
    },

    leader_alpha = {
        name = "Squad Leader",
        name_zh = "小队长",
        faction = "faction_alpha",
        icon = "fireteam/classes/leader.png",

        loadout = {
            primary = {
                tags = { "faction_alpha", "assault_rifle" },
                count = 1
            },
            sidearm = {
                tags = { "faction_alpha", "pistol" },
                count = 1
            }
        },

        stats = {
            speed_mult = 0.95,
            armor = 1,
            stamina = 100,
            radio_access = true,
            radio_channels = { "squad", "command" }
        },

        abilities = { "mark_target", "call_medical", "issue_orders" }
    }

    -- ⬇ 在此添加更多职业
}
