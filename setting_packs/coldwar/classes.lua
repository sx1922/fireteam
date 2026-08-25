-- setting_packs/coldwar/classes.lua
-- 职业定义：角色模板 × 现实国家 程序化生成。
-- 每国 6 个基础职业；华约各国额外拥有政委（政治军官传统）。
-- 装备槽按集团标签解析（nato/coldwar_west 或 warsaw_pact/coldwar_east），
-- 武器池见 weapons.lua。

local NATO = { "usa", "uk", "west_germany", "france" }
local WTO  = { "ussr", "east_germany", "poland", "czechoslovakia" }

-- 角色模板。name_w/name_e：两大集团下的显示名；
-- slots 里 extra 会拼进集团标签组构成完整 tags。
local ROLES = {
    rifleman = {
        name_w = "Rifleman",          name_zh_w = "步枪手",
        name_e = "Rifleman",          name_zh_e = "步枪手",
        icon_suffix = "",
        slots = {
            primary   = { extra = "assault_rifle" },
            secondary = { extra = "pistol", optional = true },
            grenade   = { extra = "frag_grenade" },
        },
        stats    = { speed_mult = 1.0, armor = 1, stamina = 100, radio_access = true },
        abilities_w = { "mark_target", "call_medical" },
        abilities_e = { "mark_target", "call_medical" },
    },

    squad_leader = {
        name_w = "Squad Leader",      name_zh_w = "小队长",
        name_e = "Squad Leader",      name_zh_e = "小队长",
        icon_suffix = "",
        slots = {
            primary = { extra = "assault_rifle" },
            sidearm = { extra = "pistol" },
        },
        stats       = { speed_mult = 0.95, armor = 1, stamina = 100,
                        radio_access = true, radio_channels = { "squad", "command" } },
        abilities_w = { "mark_target", "call_medical", "issue_orders", "call_artillery" },
        abilities_e = { "mark_target", "call_medical", "issue_orders" },
    },

    machine_gunner = {
        name_w = "Machine Gunner",    name_zh_w = "机枪手",
        name_e = "Machine Gunner",    name_zh_e = "机枪手",
        icon_suffix = "",
        slots = {
            primary   = { extra = "lmg" },
            secondary = { extra = "pistol", optional = true },
            ammo_belt = { extra = "ammo_box" },
        },
        stats       = { speed_mult = 0.85, armor = 2, stamina = 120, radio_access = true },
        abilities_w = { "suppress_area", "mark_target" },
        abilities_e = { "suppress_area", "mark_target" },
    },

    marksman = {
        name_w = "Marksman",          name_zh_w = "精确射手",
        name_e = "Marksman",          name_zh_e = "精确射手",
        icon_suffix = "",
        slots = {
            primary   = { extra = "dmr" },
            secondary = { extra = "pistol" },
        },
        stats       = { speed_mult = 1.0, armor = 1, stamina = 100, radio_access = true },
        abilities_w = { "mark_target", "overwatch" },
        abilities_e = { "mark_target", "overwatch" },
    },

    medic = {
        name_w = "Combat Medic",      name_zh_w = "战斗医疗兵",
        name_e = "Field Medic",       name_zh_e = "野战医疗兵",
        icon_suffix = "",
        slots = {
            primary = { extra = "carbine" },
            medical = { extra = "medkit" },
        },
        stats       = { speed_mult = 1.05, armor = 0, stamina = 100, radio_access = true },
        abilities_w = { "heal", "revive", "mark_target" },
        abilities_e = { "heal", "revive", "mark_target" },
    },

    radio_operator = {
        name_w = "Radio Operator",    name_zh_w = "通讯员",
        name_e = "Radio Operator",    name_zh_e = "通讯员",
        icon_suffix = "",
        slots = {
            primary   = { extra = "assault_rifle" },
            secondary = { extra = "pistol" },
        },
        stats       = { speed_mult = 0.9, armor = 1, stamina = 100,
                        radio_access = true, radio_channels = { "squad", "command" } },
        abilities_w = { "mark_target", "relay_orders", "call_artillery" },
        abilities_e = { "mark_target", "relay_orders" },
    },
}

-- 华约特有：政委（政治军官）
local COMMISSAR = {
    name = "Commissar", name_zh = "政委",
    slots = {
        primary   = { extra = "pistol" },
        secondary = { extra = "smg" },
    },
    stats    = { speed_mult = 1.0, armor = 1, stamina = 100,
                 radio_access = true, radio_channels = { "squad", "command" } },
    abilities = { "issue_orders", "rally", "mark_target" },
}

local out = {}

local function buildNation(nationId, bloc)
    local isWest     = bloc == "west"
    local blocTags   = isWest and { "nato", "coldwar_west" } or { "warsaw_pact", "coldwar_east" }
    local iconSuffix = isWest and "" or "_e"

    for roleKey, role in pairs(ROLES) do
        local loadout = {}
        for slotName, slot in pairs(role.slots) do
            local entry = { tags = { blocTags[1], blocTags[2], slot.extra } }
            if slot.optional then entry.optional = true end
            loadout[slotName] = entry
        end

        out[roleKey .. "_" .. nationId] = {
            name     = isWest and role.name_w or role.name_e,
            name_zh  = isWest and role.name_zh_w or role.name_zh_e,
            faction  = nationId,
            icon     = "fireteam/classes/" .. roleKey .. iconSuffix .. ".png",
            loadout  = loadout,
            stats    = table.Copy(role.stats),
            abilities = table.Copy(isWest and role.abilities_w or role.abilities_e),
        }
    end
end

for _, id in ipairs(NATO) do buildNation(id, "west") end
for _, id in ipairs(WTO)  do buildNation(id, "east") end

-- 政委：仅华约各国
for _, id in ipairs(WTO) do
    out["commissar_" .. id] = {
        name      = COMMISSAR.name,
        name_zh   = COMMISSAR.name_zh,
        faction   = id,
        icon      = "fireteam/classes/commissar.png",
        loadout   = {
            primary   = { tags = { "warsaw_pact", COMMISSAR.slots.primary.extra } },
            secondary = { tags = { "warsaw_pact", COMMISSAR.slots.secondary.extra } },
        },
        stats     = table.Copy(COMMISSAR.stats),
        abilities = table.Copy(COMMISSAR.abilities),
    }
end

return out
