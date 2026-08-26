-- modules/resupply/sv_resupply.lua
-- FIRETEAM Resupply System - Server
-- ① loadout 后按武器补满备弹池；② 弹药盒 item 放置 ft_ammo_crate（N 次补给后消失）；
-- ③ 对尸体（服务端布娃娃）按 E 搜刮部分备弹/消耗品。回合简报时清理本模块实体。

if not Fireteam then Fireteam = {} end
Fireteam.Resupply = Fireteam.Resupply or {}

local LOOT_SCAN   = 0.25
local LOOT_RANGE  = 90

local function IsEnabled()
    return Fireteam.Config.Get("resupply.reserve_primary") ~= nil   -- 模块级开关即 config 存在性
end

-- ─────────────────────────────────────
-- ① 备弹池：loadout 后按武器类型补到目标量
-- ─────────────────────────────────────

--- 把玩家所有武器的备弹补到 config 目标。返回实际补充总数（harness 可测）
function Fireteam.Resupply.FillReserves(ply)
    local targetPrim = tonumber(Fireteam.Config.Get("resupply.reserve_primary")) or 0
    local targetSec  = tonumber(Fireteam.Config.Get("resupply.reserve_secondary")) or 0
    local filled = 0

    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) then
            for typeId, target in pairs({
                [wep:GetPrimaryAmmoType()]   = targetPrim,
                [wep:GetSecondaryAmmoType()] = targetSec,
            }) do
                if type(typeId) == "number" and typeId > 0 and target > 0 then
                    local delta = Fireteam.Resupply.ReserveDelta(ply:GetAmmoCount(typeId), target)
                    if delta > 0 then
                        ply:GiveAmmo(delta, typeId, true)
                        filled = filled + delta
                    end
                end
            end
        end
    end
    return filled
end

function Fireteam.Resupply.OnLoadout(ply)
    if not IsValid(ply) then return end
    -- 延迟一拍：等武器 Give 的默认弹药到位后再补差额
    timer.Simple(0.1, function()
        if IsValid(ply) and ply:Alive() then
            Fireteam.Resupply.FillReserves(ply)
        end
    end)
end

-- ─────────────────────────────────────
-- ② 弹药盒放置（deployable 大类处理器）
-- ─────────────────────────────────-----

local function PlaceInFront(ply, def)
    local ent = ents.Create("ft_ammo_crate")
    if not IsValid(ent) then return false end

    local pos = ply:GetShootPos() + ply:GetAimVector() * 40
    ent:SetPos(pos)
    ent:SetAngles(Angle(0, ply:GetAngles().y, 0))
    ent:SetUses(tonumber(Fireteam.Config.Get("resupply.crate_uses")) or 4)
    ent.FT_Owner = ply
    ent:Spawn()
    ent:Activate()
    return true
end

-- ─────────────────────────────────-----
-- ③ 尸体搜刮：死亡时快照进服务端布娃娃，按 E 提取份额
-- ─────────────────────────────────-----

local lootBodies = {}   -- { [ragdoll] = { ammo={typeId=count}, items={id=count} } }

--- 死亡布娃娃的战利品快照（harness 可测）
function Fireteam.Resupply.BuildLoot(victim)
    local ammo, items = {}, {}
    for _, wep in ipairs(victim:GetWeapons()) do
        if IsValid(wep) then
            for _, typeId in ipairs({ wep:GetPrimaryAmmoType(), wep:GetSecondaryAmmoType() }) do
                if type(typeId) == "number" and typeId > 0 then
                    ammo[typeId] = (ammo[typeId] or 0) + victim:GetAmmoCount(typeId)
                end
            end
        end
    end
    if Fireteam.Inventory and Fireteam.Inventory.GetAll then
        items = Fireteam.Inventory.GetAll(victim)
    end
    return { ammo = ammo, items = items }
end

--- 把战利品份额转移给搜刮者；返回是否拿到了任何东西
function Fireteam.Resupply.TransferLoot(looter, loot)
    local frac = tonumber(Fireteam.Config.Get("resupply.loot_frac")) or 0.5
    local gotAnything = false

    local ammoShare = Fireteam.Resupply.ComputeLoot(loot.ammo, frac)
    for typeId, give in pairs(ammoShare) do
        looter:GiveAmmo(give, typeId, true)
        loot.ammo[typeId] = math.max((loot.ammo[typeId] or 0) - give, 0)
        looter:ChatPrint("[FIRETEAM] " .. string.format(Fireteam.Locale.Get("resupply_loot_ammo"), give))
        gotAnything = true
    end

    local itemShare = Fireteam.Resupply.ComputeLoot(loot.items, frac)
    for itemId, give in pairs(itemShare) do
        local applied = Fireteam.Inventory.Add and Fireteam.Inventory.Add(looter, itemId, give) or 0
        if applied > 0 then
            loot.items[itemId] = math.max((loot.items[itemId] or 0) - applied, 0)
            looter:ChatPrint("[FIRETEAM] "
                .. string.format(Fireteam.Locale.Get("resupply_loot_item"), applied,
                    (Fireteam.Inventory.GetItemDef(itemId) or {}).name or itemId))
            gotAnything = true
        end
    end

    return gotAnything
end

hook.Add("PlayerDeath", "Fireteam.Resupply.CorpseLoot", function(victim)
    if not IsEnabled() then return end
    if Fireteam.Config.Get("resupply.loot_enabled") == false then return end

    timer.Simple(0.2, function()
        if not IsValid(victim) then return end
        local ok, rag = pcall(victim.CreateServerRagdoll, victim)
        if not ok or not IsValid(rag) then return end
        lootBodies[rag] = Fireteam.Resupply.BuildLoot(victim)
        rag.FT_ResupplyLoot = true
        SafeRemoveEntityDelayed(rag, 180)   -- 兜底回收，避免尸体常驻
    end)
end)

timer.Create("Fireteam.Resupply.LootScan", LOOT_SCAN, 0, function()
    if not IsEnabled() then return end
    if Fireteam.Config.Get("resupply.loot_enabled") == false then return end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and ply:KeyDown(IN_USE)
            and not (Fireteam.Vitals and Fireteam.Vitals.IsDowned and Fireteam.Vitals.IsDowned(ply)) then
            local tr = ply:GetEyeTrace()
            local rag = tr.Entity
            if IsValid(rag) and rag.FT_ResupplyLoot and lootBodies[rag]
                and ply:GetPos():Distance(rag:GetPos()) <= LOOT_RANGE then
                if Fireteam.Resupply.TransferLoot(ply, lootBodies[rag]) then
                    -- 清空后移除登记
                    local empty = true
                    for _, counts in pairs({ lootBodies[rag].ammo, lootBodies[rag].items }) do
                        for _, n in pairs(counts) do
                            if (tonumber(n) or 0) > 0 then empty = false break end
                        end
                    end
                    if empty then lootBodies[rag] = nil end
                end
            end
        end
    end
end)

-- ─────────────────────────────────────
-- 回合清场：移除本模块实体与尸体登记
-- ─────────────────────────────────────

hook.Add(Fireteam.HOOKS.ROUND_STATE_CHANGED, "Fireteam.Resupply.RoundReset", function(newState)
    if newState == Fireteam.Rounds.STATE.BRIEFING
        or newState == Fireteam.Rounds.STATE.WARMUP then
        for _, ent in ipairs(ents.FindByClass("ft_ammo_crate")) do
            if IsValid(ent) then ent:Remove() end
        end
        for rag in pairs(lootBodies) do
            if IsValid(rag) then rag:Remove() end
            lootBodies[rag] = nil
        end
    end
end)

hook.Add("PlayerDisconnected", "Fireteam.Resupply.Cleanup", function()
    -- lootBodies 以实体为键，布娃娃被引擎回收后留下死键：
    -- 周期清扫一次防累积
    for rag in pairs(lootBodies) do
        if not IsValid(rag) then lootBodies[rag] = nil end
    end
end)

-- ─────────────────────────────────────
-- 装配：deployable 处理器 + loadout 扩展点
-- ─────────────────────────────────────

if Fireteam.Inventory and Fireteam.Inventory.RegisterUseHandler then
    Fireteam.Inventory.RegisterUseHandler("deployable", PlaceInFront)
end

Fireteam.Log.Info("补给", "✓ 弹药/补给系统服务端已加载")
