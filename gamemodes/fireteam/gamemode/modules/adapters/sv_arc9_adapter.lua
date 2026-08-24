-- modules/adapters/sv_arc9_adapter.lua
-- FIRETEAM ARC9 Weapon Base Adapter
-- 自动识别 ARC9 武器并生成 FIRETEAM 标签

if not ARC9 then
    Fireteam.Log.Info("适配器", "未检测到 ARC9，跳过适配器")
    return
end

Fireteam.Log.Info("适配器", "检测到 ARC9，开始注册适配器...")

-- ═══════════════════════════════════════
-- Tag 生成规则
-- ═══════════════════════════════════════
local function GenerateTags(swep)
    local tags = { "arc9" }

    -- 阵营 / 国家
    local name = (swep.PrintName or ""):lower()
    local category = (swep.Category or ""):lower()
    local desc = (swep.Description or ""):lower()
    local combined = name .. " " .. category .. " " .. desc

    -- NATO / 西方
    if combined:find("m16") or combined:find("m4") or combined:find("m60")
        or combined:find("m14") or combined:find("m249") or combined:find("m240")
        or combined:find("mp5") or combined:find("g3") or combined:find("fal")
        or combined:find("l1a1") or combined:find("sten") or combined:find("bren")
        or combined:find("galil") or combined:find("uzi") or combined:find("aug")
        or combined:find("famas") or combined:find("hk33") or combined:find("g36") then
        table.insert(tags, "nato")
        table.insert(tags, "coldwar_west")
        table.insert(tags, "western")
    end

    -- 华约 / 东方
    if combined:find("ak") or combined:find("rpk") or combined:find("pkp")
        or combined:find("svd") or combined:find("mosin") or combined:find("ppsh")
        or combined:find("pps") or combined:find("dragunov") or combined:find("makarov")
        or combined:find("tokarev") or combined:find("skorpion") or combined:find("vz")
        or combined:find("wz") or combined:find("pm63") then
        table.insert(tags, "warsaw_pact")
        table.insert(tags, "coldwar_east")
        table.insert(tags, "eastern")
    end

    -- 冷战时代判定
    if combined:find("cold war") or combined:find("vietnam")
        or combined:find("1960") or combined:find("1970") or combined:find("1980") then
        table.insert(tags, "coldwar")
    end

    -- 武器分类（基于 Category 文本）
    if category:find("assault") or category:find("rifle") then
        table.insert(tags, "assault_rifle")
    elseif category:find("smg") or category:find("submachine") then
        table.insert(tags, "smg")
    elseif category:find("lmg") or category:find("machine gun") or category:find("belt") then
        table.insert(tags, "lmg")
    elseif category:find("sniper") or category:find("bolt") then
        table.insert(tags, "sniper_rifle")
    elseif category:find("dmr") or category:find("marksman") then
        table.insert(tags, "dmr")
    elseif category:find("shotgun") then
        table.insert(tags, "shotgun")
    elseif category:find("pistol") or category:find("handgun") then
        table.insert(tags, "pistol")
    elseif category:find("launcher") or category:find("rocket") or category:find("rpg") then
        table.insert(tags, "launcher")
    end

    -- 特殊属性
    if swep.Silenced or combined:find("suppressor") or combined:find("silencer") then
        table.insert(tags, "suppressed")
    end

    return tags
end

-- ═══════════════════════════════════════
-- 分类映射
-- ═══════════════════════════════════════
local function MapCategory(swep)
    local cat = (swep.Category or ""):lower()
    if cat:find("assault") then return Fireteam.WEAPON_CATEGORY.RIFLE
    elseif cat:find("smg") then return Fireteam.WEAPON_CATEGORY.SMG
    elseif cat:find("lmg") or cat:find("machine") then return Fireteam.WEAPON_CATEGORY.LMG
    elseif cat:find("sniper") then return Fireteam.WEAPON_CATEGORY.SNIPER
    elseif cat:find("dmr") or cat:find("marksman") then return Fireteam.WEAPON_CATEGORY.DMR
    elseif cat:find("shotgun") then return Fireteam.WEAPON_CATEGORY.SHOTGUN
    elseif cat:find("pistol") then return Fireteam.WEAPON_CATEGORY.PISTOL
    elseif cat:find("launcher") then return Fireteam.WEAPON_CATEGORY.LAUNCHER
    else return Fireteam.WEAPON_CATEGORY.RIFLE
    end
end

-- ═══════════════════════════════════════
-- 射击模式推断
-- ═══════════════════════════════════════
local function GetFireModes(swep)
    local modes = {}
    if swep.SelectiveFire or swep.ARC9_SelectiveFire then
        table.insert(modes, "semi")
        table.insert(modes, "auto")
        local burst = tonumber(swep.BurstSize) or 1
        if burst > 1 then
            table.insert(modes, "burst")
        end
    else
        table.insert(modes, "semi")
    end
    return modes
end

-- ═══════════════════════════════════════
-- 注册到发现钩子
-- （weapons.GetList() 返回数组，类名在 swep.ClassName）
-- ═══════════════════════════════════════
hook.Add(Fireteam.HOOKS.WEAPON_DISCOVER, "FIRETEAM.ARC9Adapter", function(weaponList)
    local count = 0

    for _, swep in ipairs(weapons.GetList()) do
        if swep and swep.ARC9 then
            local className = swep.ClassName or ("arc9_unknown_" .. count)

            -- ARC9 表结构不一定有 Primary 子表，全部做安全取值
            local primary = istable(swep.Primary) and swep.Primary or {}

            local ftData = {
                base           = className,
                displayName    = swep.PrintName or className,
                tags           = GenerateTags(swep),
                category       = MapCategory(swep),
                suppression    = math.Clamp((tonumber(swep.Recoil) or 1) * 0.3, 0, 1),
                effectiveRange = (tonumber(swep.Range) or 300) * 39.37, -- 米→单位
                fireModes      = GetFireModes(swep),
                opticType      = "iron",
                weight         = tonumber(swep.Weight) or 3.5,
                noiseLevel     = math.Clamp((tonumber(swep.ShootVolume) or 140) / 160, 0, 1),
                magazineSize   = tonumber(primary.ClipSize) or 30,
                damage         = tonumber(primary.Damage) or 25
            }

            Fireteam.WeaponInterface.Register(ftData)
            count = count + 1
        end
    end

    print("[FIRETEAM:Adapter] ARC9: registered " .. count .. " weapon(s)")
end)

print("[FIRETEAM:Adapter] ✓ ARC9 adapter ready")
