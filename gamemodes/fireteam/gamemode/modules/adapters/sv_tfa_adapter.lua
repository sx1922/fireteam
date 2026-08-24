-- modules/adapters/sv_tfa_adapter.lua
-- FIRETEAM TFA Weapon Base Adapter

if not TFA then
    Fireteam.Log.Info("适配器", "未检测到 TFA，跳过适配器")
    return
end

Fireteam.Log.Info("适配器", "检测到 TFA，开始注册适配器...")

-- ═══════════════════════════════════════
-- Tag 生成
-- ═══════════════════════════════════════
local function GenerateTags(swep)
    local tags = { "tfa" }
    local name = (swep.PrintName or ""):lower()
    local category = (swep.Category or ""):lower()
    local combined = name .. " " .. category

    -- NATO
    if combined:find("m16") or combined:find("m4") or combined:find("m60")
        or combined:find("m14") or combined:find("mp5") or combined:find("g3")
        or combined:find("fal") or combined:find("galil") or combined:find("aug")
        or combined:find("famas") or combined:find("sten") or combined:find("bren") then
        table.insert(tags, "nato")
        table.insert(tags, "coldwar_west")
    end

    -- 华约
    if combined:find("ak") or combined:find("rpk") or combined:find("svd")
        or combined:find("mosin") or combined:find("ppsh") or combined:find("makarov")
        or combined:find("tokarev") or combined:find("skorpion") then
        table.insert(tags, "warsaw_pact")
        table.insert(tags, "coldwar_east")
    end

    -- 分类
    if combined:find("assault") or combined:find("rifle") then
        table.insert(tags, "assault_rifle")
    elseif combined:find("smg") or combined:find("sub") then
        table.insert(tags, "smg")
    elseif combined:find("lmg") or combined:find("machine") then
        table.insert(tags, "lmg")
    elseif combined:find("sniper") or combined:find("bolt") then
        table.insert(tags, "sniper_rifle")
    elseif combined:find("pistol") or combined:find("handgun") then
        table.insert(tags, "pistol")
    elseif combined:find("shotgun") then
        table.insert(tags, "shotgun")
    end

    return tags
end

-- ═══════════════════════════════════════
-- 分类映射
-- ═══════════════════════════════════════
local function MapCategory(swep)
    local name = (swep.PrintName or ""):lower()
    if name:find("smg") or name:find("sub") then return Fireteam.WEAPON_CATEGORY.SMG
    elseif name:find("lmg") or name:find("machine") then return Fireteam.WEAPON_CATEGORY.LMG
    elseif name:find("sniper") or name:find("bolt") then return Fireteam.WEAPON_CATEGORY.SNIPER
    elseif name:find("pistol") then return Fireteam.WEAPON_CATEGORY.PISTOL
    elseif name:find("shotgun") then return Fireteam.WEAPON_CATEGORY.SHOTGUN
    else return Fireteam.WEAPON_CATEGORY.RIFLE
    end
end

-- ═══════════════════════════════════════
-- 注册
-- （weapons.GetList() 返回数组，类名在 swep.ClassName）
-- ═══════════════════════════════════════
hook.Add(Fireteam.HOOKS.WEAPON_DISCOVER, "FIRETEAM.TFAAdapter", function()
    local count = 0

    for _, swep in ipairs(weapons.GetList()) do
        local className = istable(swep) and swep.ClassName or nil
        if className and (swep.TFA or swep.Base == "tfa_gun_base" or className:find("tfa_")) then
            -- TFA 表不一定有 Primary 子表，全部安全取值
            local primary = istable(swep.Primary) and swep.Primary or {}

            local ftData = {
                base           = className,
                displayName    = swep.PrintName or className,
                tags           = GenerateTags(swep),
                category       = MapCategory(swep),
                suppression    = math.Clamp((tonumber(primary.KickUp) or 1) * 0.2, 0, 1),
                effectiveRange = (tonumber(primary.Range) or 300) * 39.37,
                fireModes      = { "semi", "auto" },
                opticType      = swep.IronSights and "iron" or "scope",
                weight         = tonumber(swep.Weight) or 3.5,
                noiseLevel     = 0.7,
                magazineSize   = tonumber(primary.ClipSize) or 30,
                damage         = tonumber(primary.Damage) or 25
            }

            Fireteam.WeaponInterface.Register(ftData)
            count = count + 1
        end
    end

    Fireteam.Log.Info("适配器", "TFA: 已注册 " .. count .. " 把武器")
end)

Fireteam.Log.Info("适配器", "✓ TFA 适配器就绪")
