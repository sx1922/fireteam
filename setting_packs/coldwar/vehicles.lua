-- setting_packs/coldwar/vehicles.lua
-- 载具池：按现实国家划分。北约各国配置一致；华约各国在北约基础上
-- 增加坦克位（反映两集团装甲兵力结构差异）。

local NATO = { "usa", "uk", "west_germany", "france" }
local WTO  = { "ussr", "east_germany", "poland", "czechoslovakia" }

local pools = {}

for _, id in ipairs(NATO) do
    pools[id] = {
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
    }
end

for _, id in ipairs(WTO) do
    pools[id] = {
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
end

return {

    global_filter = {
        allowed_era = { "coldwar" },
        banned_tags = { "modern_tank", "drone", "digital_apc", "stealth" }
    },

    pools = pools
}
