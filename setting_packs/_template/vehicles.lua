-- _template/vehicles.lua
return {

    global_filter = {
        allowed_era = { "my_era" },
        banned_tags = { "anachronistic_vehicle" }
    },

    pools = {
        faction_alpha = {
            transport = {
                tags = { "faction_alpha", "transport" },
                min_capacity = 6,
                max_armor = 1
            },
            recon = {
                tags = { "faction_alpha", "recon" },
                max_armor = 0
            }
        },
        faction_beta = {
            transport = {
                tags = { "faction_beta", "transport" },
                min_capacity = 8,
                max_armor = 1
            },
            armor = {
                tags = { "faction_beta", "tank" },
                max_count = 1
            }
        }
    }
}
