-- setting_packs/coldwar/vehicles.lua
return {

    global_filter = {
        allowed_era = { "coldwar" },
        banned_tags = { "modern_tank", "drone", "digital_apc", "stealth" }
    },

    pools = {
        western_alliance = {
            transport = {
                tags = { "nato", "coldwar", "transport" },
                min_capacity = 6,
                max_armor = 1
            },
            recon = {
                tags = { "nato", "coldwar", "recon" },
                max_armor = 0
            },
            air = {
                tags = { "nato", "coldwar", "helicopter" },
                max_count = 2
            }
        },
        eastern_bloc = {
            transport = {
                tags = { "warsaw_pact", "coldwar", "transport" },
                min_capacity = 8,
                max_armor = 1
            },
            recon = {
                tags = { "warsaw_pact", "coldwar", "recon" },
                max_armor = 1
            },
            armor = {
                tags = { "warsaw_pact", "coldwar", "tank" },
                max_count = 1
            }
        }
    }
}
