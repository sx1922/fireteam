-- modules/adapters/sv_cw2_adapter.lua
-- FIRETEAM Customizable Weaponry 2.0 Adapter
-- 自动识别 CW2 武器并生成 FIRETEAM 标签。结构与 sv_tfa_adapter.lua 同构：
-- 自守卫（基座缺失即 return）→ 标签生成 → 分类映射 → WEAPON_DISCOVER 注册。

if not CustomizableWeaponry then
    Fireteam.Log.Info("适配器", "未检测到 CW 2.0，跳过适配器")
    return
end

Fireteam.Log.Info("适配器", "检测到 CW 2.0，开始注册适配器...")

-- ═══════════════════════════════════════
-- Tag 生成（名称/分类/类名文本推断，与其他适配器同一套标签词表）
-- ═══════════════════════════════════════
local function GenerateTags(swep)
    local tags = { "cw2" }
    local name = (swep.PrintName or ""):lower()
    local category = (swep.Category or ""):lower()
    local className = (swep.ClassName or ""):lower()
    local combined = name .. " " .. category .. " " .. className

    -- 北约 / 西方
    if combined:find("m16") or combined:find("m4") or combined:find("m14")
        or combined:find("m60") or combined:find("m249") or combined:find("mp5")
        or combined:find("g3") or combined:find("g36") or combined:find("fal")
        or combined:find("famas") or combined:find("aug") or combined:find("galil")
        or combined:find("uzi") or combined:find("1911") or combined:find("beretta")
        or combined:find("m9") or combined:find("remington") or combined:find("spas") then
        table.insert(tags, "nato")
        table.insert(tags, "coldwar_west")
        table.insert(tags, "western")
    end

    -- 华约 / 东方
    if combined:find("ak") or combined:find("rpk") or combined:find("pkm")
        or combined:find("svd") or combined:find("dragunov") or combined:find("mosin")
        or combined:find("ppsh") or combined:find("makarov") or combined:find("tokarev")
        or combined:find("skorpion") or combined:find("vz") or combined:find("saiga") then
        table.insert(tags, "warsaw_pact")
        table.insert(tags, "coldwar_east")
        table.insert(tags, "eastern")
    end

    -- 时代
    if combined:find("cold war") or combined:find("vietnam")
        or combined:find("1960") or combined:find("1970") or combined:find("1980") then
        table.insert(tags, "coldwar")
    end

    -- 武器类型
    if category:find("assault") or combined:find("assault rifle") then
        table.insert(tags, "assault_rifle")
    elseif category:find("smg") or category:find("submachine") then
        table.insert(tags, "smg")
    elseif category:find("lmg") or category:find("machine gun") then
        table.insert(tags, "lmg")
    elseif category:find("sniper") then
        table.insert(tags, "sniper_rifle")
    elseif category:find("marksman") or category:find("dmr") then
        table.insert(tags, "dmr")
    elseif category:find("shotgun") then
        table.insert(tags, "shotgun")
    elseif category:find("pistol") or category:find("handgun") then
        table.insert(tags, "pistol")
    elseif category:find("launcher") or combined:find("rpg") then
        table.insert(tags, "launcher")
    end

    -- CW2 内置消音器挂件（attachments 表里带 silencer 即视为可消音）
    if istable(swep.Attachments) then
        for _, att in pairs(swep.Attachments) do
            local header = istable(att) and tostring(att.header or ""):lower() or ""
            if header:find("muzzle") or header:find("silenc") or header:find("suppress") then
                table.insert(tags, "suppressed")
                break
            end
        end
    end

    return tags
end

-- ═══════════════════════════════════════
-- 分类映射
-- ═══════════════════════════════════════
local function MapCategory(swep)
    local cat = (swep.Category or ""):lower()
    local name = (swep.PrintName or ""):lower()
    if cat:find("assault") then return Fireteam.WEAPON_CATEGORY.RIFLE
    elseif cat:find("smg") or cat:find("submachine") then return Fireteam.WEAPON_CATEGORY.SMG
    elseif cat:find("lmg") or cat:find("machine") then return Fireteam.WEAPON_CATEGORY.LMG
    elseif cat:find("sniper") then return Fireteam.WEAPON_CATEGORY.SNIPER
    elseif cat:find("marksman") or cat:find("dmr") then return Fireteam.WEAPON_CATEGORY.DMR
    elseif cat:find("shotgun") or name:find("shotgun") then return Fireteam.WEAPON_CATEGORY.SHOTGUN
    elseif cat:find("pistol") or name:find("pistol") then return Fireteam.WEAPON_CATEGORY.PISTOL
    elseif cat:find("launcher") then return Fireteam.WEAPON_CATEGORY.LAUNCHER
    else return Fireteam.WEAPON_CATEGORY.RIFLE
    end
end

-- ═══════════════════════════════════════
-- 射击模式（CW2 用 firemodes 数组声明可选模式）
-- ═══════════════════════════════════════
local function GetFireModes(swep)
    local modes = {}
    if istable(swep.FireModes) then
        for _, m in ipairs(swep.FireModes) do
            local key = tostring(m):lower()
            if key:find("auto") and not key:find("semi") then
                table.insert(modes, "auto")
            elseif key:find("burst") then
                table.insert(modes, "burst")
            elseif key:find("semi") then
                table.insert(modes, "semi")
            end
        end
    end
    if #modes == 0 then
        table.insert(modes, swep.Primary and swep.Primary.Automatic and "auto" or "semi")
    end
    return modes
end

-- ═══════════════════════════════════════
-- 注册（设定包 weapon_overrides 可覆盖标签与分类）
-- ═══════════════════════════════════════
local function LoadWeaponOverrides()
    if Fireteam.Setting and Fireteam.Setting.GetData then
        return Fireteam.Setting.GetData("weapon_overrides") or {}
    end
    return {}
end

hook.Add(Fireteam.HOOKS.WEAPON_DISCOVER, "FIRETEAM.CW2Adapter", function()
    local count = 0
    local overrides = LoadWeaponOverrides()

    for _, swep in ipairs(weapons.GetList()) do
        local className = istable(swep) and swep.ClassName or nil
        -- CW2 SWEP 识别：基座派生标记 / 基座类名 / cw_ 类名前缀
        local isCW2 = className and (swep.CW20Weapon
            or swep.Base == "cw_base"
            or className:sub(1, 3) == "cw_")

        if isCW2 then
            -- CW2 表结构不保证有 Primary 子表，全部安全取值
            local primary = istable(swep.Primary) and swep.Primary or {}

            local ftData = {
                base           = className,
                displayName    = swep.PrintName or className,
                tags           = GenerateTags(swep),
                category       = MapCategory(swep),
                suppression    = math.Clamp((tonumber(swep.Recoil) or 1) * 0.25, 0, 1),
                effectiveRange = (tonumber(swep.Range) or 300) * 39.37,   -- 米→世界单位
                fireModes      = GetFireModes(swep),
                opticType      = istable(swep.Attachments) and "scope" or "iron",
                weight         = tonumber(swep.Weight) or 3.5,
                noiseLevel     = 0.7,
                magazineSize   = tonumber(primary.ClipSize) or 30,
                damage         = tonumber(primary.Damage) or 25
            }

            -- 应用设定包覆盖
            local ov = overrides[className]
            if istable(ov) then
                if istable(ov.tags) then
                    local merged, seen = {}, {}
                    for _, tag in ipairs(ftData.tags) do if not seen[tag] then seen[tag] = true table.insert(merged, tag) end end
                    for _, tag in ipairs(ov.tags) do if not seen[tag] then seen[tag] = true table.insert(merged, tag) end end
                    ftData.tags = merged
                end
                if ov.category then ftData.category = ov.category end
            end

            Fireteam.WeaponInterface.Register(ftData)
            count = count + 1
        end
    end

    Fireteam.Log.Info("适配器", "CW 2.0: 已注册 " .. count .. " 件武器")
end)

Fireteam.Log.Info("适配器", "✓ CW 2.0 适配器就绪")
