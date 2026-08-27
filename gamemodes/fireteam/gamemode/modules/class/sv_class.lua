-- modules/class/sv_class.lua
-- FIRETEAM Class System - Server Logic

if not Fireteam then Fireteam = {} end
Fireteam.Class = Fireteam.Class or {}

-- ═══════════════════════════════════════
-- 分配职业
-- ═══════════════════════════════════════
function Fireteam.Class.Assign(ply, classId)
    if not IsValid(ply) then return false end

    local classData = Fireteam.Class.Get(classId)
    if not classData then
        ErrorNoHalt("[FIRETEAM:Class] Unknown class: " .. tostring(classId) .. "\n")
        return false
    end

    -- 检查阵营匹配
    local squad = Fireteam.Squad.GetPlayerSquad(ply)
    if squad and classData.faction ~= squad.faction then
        ply:ChatPrint("[FIRETEAM] Class faction does not match squad faction.")
        return false
    end

    ply.FT_Class = classId
    hook.Run(Fireteam.HOOKS.CLASS_ASSIGNED, ply, classId)

    -- 应用属性
    Fireteam.Class.ApplyStats(ply, classData)

    -- 加载装备
    Fireteam.Class.ApplyLoadout(ply, classData)

    -- 通知客户端
    net.Start(Fireteam.NET.CLASS_ASSIGN)
        net.WriteEntity(ply)
        net.WriteString(classId)
    net.Broadcast()

    ply:ChatPrint("[FIRETEAM] Class assigned: " .. (classData.name or classId))
    return true
end

-- ═══════════════════════════════════════
-- 应用属性修正
-- ═══════════════════════════════════════
function Fireteam.Class.ApplyStats(ply, classData)
    if not classData.stats then return end

    local stats = classData.stats

    -- 速度（统一经 vitals.RecalcSpeed 收口，叠加力竭/腿伤/倒地状态）
    if stats.speed_mult then
        if Fireteam.Vitals and Fireteam.Vitals.RecalcSpeed then
            Fireteam.Vitals.RecalcSpeed(ply)
        else
            ply:SetRunSpeed(400 * stats.speed_mult)
            ply:SetWalkSpeed(200 * stats.speed_mult)
        end
    end

    -- 护甲
    if stats.armor then
        ply:SetArmor(stats.armor * 25)  -- 0=0, 1=25, 2=50, 3=75
    end

    -- 生命值
    ply:SetMaxHealth(100 + (stats.armor or 0) * 10)
    ply:SetHealth(ply:GetMaxHealth())
end

-- ═══════════════════════════════════════
-- 加载装备（槽位统一解析：武器 Tag 匹配优先，
-- 无命中则回落消耗品槽位（grenade/medical/ammo_belt 等，
-- 由设定包 items.lua 声明物品可服务的槽位）
-- ═══════════════════════════════════════
function Fireteam.Class.ApplyLoadout(ply, classData)
    if not classData.loadout then return end

    -- 清空现有武器与上一轮消耗品
    ply:StripWeapons()
    ply:StripAmmo()
    if Fireteam.Inventory and Fireteam.Inventory.Reset then
        Fireteam.Inventory.Reset(ply)
    end

    for slotName, slotDef in pairs(classData.loadout) do
        local candidates = {}
        if slotDef.tags then
            candidates = Fireteam.WeaponInterface.FilterByTags(slotDef.tags, nil)
        end

        if #candidates > 0 then
            -- 随机取一个匹配的（后续可加选择逻辑）
            local chosen = candidates[math.random(#candidates)]
            if chosen and chosen.base then
                ply:Give(chosen.base)
            end
        elseif Fireteam.Inventory and Fireteam.Inventory.GrantForSlot
            and Fireteam.Inventory.GrantForSlot(ply, slotName, classData.faction) then
            -- 消耗品已发放，静默成功
        else
            -- 无匹配时提示（可选槽位静默跳过）
            if not slotDef.optional then
                ply:ChatPrint("[FIRETEAM] ⚠ No weapon found for slot '" .. slotName .. "'")
            end
        end
    end

    -- 备弹池补满（resupply 模块扩展点，缺模块时静默）
    if Fireteam.Resupply and Fireteam.Resupply.OnLoadout then
        Fireteam.Resupply.OnLoadout(ply)
    end
end

-- ═══════════════════════════════════════
-- 玩家重生时重新加载
-- ═══════════════════════════════════════
hook.Add("PlayerSpawn", "Fireteam.Class.Respawn", function(ply)
    local classId = Fireteam.Class.GetPlayerClass(ply)
    if classId then
        local classData = Fireteam.Class.Get(classId)
        if classData then
            timer.Simple(0.5, function()
                if IsValid(ply) then
                    Fireteam.Class.ApplyStats(ply, classData)
                    Fireteam.Class.ApplyLoadout(ply, classData)
                end
            end)
        end
    end
end)

-- ═══════════════════════════════════════
-- 网络：客户端请求分配职业（消息名统一注册于 Fireteam.NET）
-- 门控（防战斗中刷血刷弹药；重生路径走 PlayerSpawn 钩子不受限）：
--   1. 死亡/倒地不可换职业（防止倒地时换职业刷新状态）
--   2. 回合 ACTIVE 期间换职业需 30s 冷却——满血+Strip+重发的收益
--      只允许在非战斗阶段（warmup/briefing/intermission/idle）免费获得
-- ═══════════════════════════════════════
local ASSIGN_COOLDOWN = 30
local lastAssignAt = {}

net.Receive(Fireteam.NET.CLASS_ASSIGN, function(len, ply)
    local classId = string.sub(net.ReadString(), 1, 64)

    if not ply:Alive() then
        ply:ChatPrint("[FIRETEAM] Cannot change class while dead.")
        return
    end
    if Fireteam.Vitals and Fireteam.Vitals.GetState
        and Fireteam.Vitals.GetState(ply) == Fireteam.Vitals.STATE.DOWNED then
        ply:ChatPrint("[FIRETEAM] Cannot change class while downed.")
        return
    end

    -- 同职业重复请求也计入冷却（防连点抖动重发）
    local active = Fireteam.Rounds and Fireteam.Rounds.GetState
        and Fireteam.Rounds.GetState() == "active" or false
    if active then
        local last = lastAssignAt[ply] or 0
        if CurTime() - last < ASSIGN_COOLDOWN then
            ply:ChatPrint(string.format("[FIRETEAM] Class change on cooldown (%ds).",
                math.ceil(ASSIGN_COOLDOWN - (CurTime() - last))))
            return
        end
    end
    lastAssignAt[ply] = CurTime()

    Fireteam.Class.Assign(ply, classId)
end)

hook.Add("PlayerDisconnected", "Fireteam.Class.CleanupCooldown", function(ply)
    lastAssignAt[ply] = nil
end)

Fireteam.Log.Info("Class", "✓ 服务端逻辑已加载")
