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
    local className = (swep.ClassName or ""):lower()
    local combined = name .. " " .. category .. " " .. className

    -- NATO
    if combined:find("m16") or combined:find("m4") or combined:find("m60")
        or combined:find("m14") or combined:find("mp5") or combined:find("g3")
        or combined:find("fal") or combined:find("galil") or combined:find("aug")
        or combined:find("famas") or combined:find("sten") or combined:find("bren")
        -- BOCW 枪包北约
        or combined:find("cw_m16") or combined:find("cw_m4") or combined:find("cw_xm4")
        or combined:find("cw_m60") or combined:find("cw_m14") or combined:find("cw_mp5")
        or combined:find("cw_famas") or combined:find("cw_aug") or combined:find("cw_fal")
        or combined:find("cw_g3") or combined:find("cw_krig6") or combined:find("cw_milano")
        or combined:find("cw_mac10") or combined:find("cw_lc10") or combined:find("cw_1911")
        or combined:find("cw_gallo") or combined:find("cw_hauer77") or combined:find("cw_diamatti")
        or combined:find("cw_magnum") or combined:find("cw_dmr14") or combined:find("cw_ffar") then
        table.insert(tags, "nato")
        table.insert(tags, "coldwar_west")
    end

    -- 华约
    if combined:find("ak") or combined:find("rpk") or combined:find("svd")
        or combined:find("mosin") or combined:find("ppsh") or combined:find("makarov")
        or combined:find("tokarev") or combined:find("skorpion")
        -- BOCW 枪包华约
        or combined:find("cw_ak47") or combined:find("cw_akm") or combined:find("cw_ak74")
        or combined:find("cw_rpk") or combined:find("cw_svd") or combined:find("cw_ppsh")
        or combined:find("cw_makarov") or combined:find("cw_tokarev") or combined:find("cw_bullfrog")
        or combined:find("cw_groza") then
        table.insert(tags, "warsaw_pact")
        table.insert(tags, "coldwar_east")
    end

    -- 分类
    if combined:find("assault") or combined:find("rifle")
        -- BOCW 突击步枪
        or combined:find("cw_m16") or combined:find("cw_xm4") or combined:find("cw_ak47")
        or combined:find("cw_ak74") or combined:find("cw_famas") or combined:find("cw_aug")
        or combined:find("cw_fal") or combined:find("cw_g3") or combined:find("cw_krig6")
        or combined:find("cw_groza") or combined:find("cw_ffar") then
        table.insert(tags, "assault_rifle")
    elseif combined:find("smg") or combined:find("sub")
        -- BOCW 冲锋枪
        or combined:find("cw_mp5") or combined:find("cw_ppsh") then
        table.insert(tags, "smg")
    elseif combined:find("lmg") or combined:find("machine")
        -- BOCW 轻机枪
        or combined:find("cw_m60") or combined:find("cw_rpk") then
        table.insert(tags, "lmg")
    elseif combined:find("sniper") or combined:find("bolt")
        -- BOCW 狙击步枪/精确射手步枪
        or combined:find("cw_svd") or combined:find("cw_m14") then
        table.insert(tags, "sniper_rifle")
    elseif combined:find("pistol") or combined:find("handgun")
        -- BOCW 手枪
        or combined:find("cw_makarov") or combined:find("cw_tokarev") then
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
-- 设定包覆盖配置加载
local function LoadWeaponOverrides()
    if Fireteam.Setting and Fireteam.Setting.GetData then
        return Fireteam.Setting.GetData("weapon_overrides") or {}
    end
    return {}
end

hook.Add(Fireteam.HOOKS.WEAPON_DISCOVER, "FIRETEAM.TFAAdapter", function()
    local count = 0
    local overrides = LoadWeaponOverrides()

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

            -- 应用设定包覆盖
            local ov = overrides[className]
            if istable(ov) then
                if istable(ov.tags) then ftData.tags = ov.tags end
                if ov.category then ftData.category = ov.category end
            end

            Fireteam.WeaponInterface.Register(ftData)
            count = count + 1
        end
    end

    Fireteam.Log.Info("适配器", "TFA: 已注册 " .. count .. " 把武器")
end)

Fireteam.Log.Info("适配器", "✓ TFA 适配器就绪")
