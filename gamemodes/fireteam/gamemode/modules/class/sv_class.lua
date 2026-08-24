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

    -- 速度
    if stats.speed_mult then
        ply:SetRunSpeed(400 * stats.speed_mult)
        ply:SetWalkSpeed(200 * stats.speed_mult)
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
-- 加载装备（通过 Tag 匹配武器）
-- ═══════════════════════════════════════
function Fireteam.Class.ApplyLoadout(ply, classData)
    if not classData.loadout then return end

    -- 清空现有武器
    ply:StripWeapons()
    ply:StripAmmo()

    for slotName, slotDef in pairs(classData.loadout) do
        if not slotDef.tags then continue end

        -- 从武器接口中按 Tag 查找
        local candidates = Fireteam.WeaponInterface.FilterByTags(slotDef.tags, nil)

        if #candidates > 0 then
            -- 随机取一个匹配的（后续可加选择逻辑）
            local chosen = candidates[math.random(#candidates)]
            if chosen and chosen.base then
                ply:Give(chosen.base)
            end
        else
            -- 无匹配时提示（可选槽位静默跳过）
            if not slotDef.optional then
                ply:ChatPrint("[FIRETEAM] ⚠ No weapon found for slot '" .. slotName .. "'")
            end
        end
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
-- 网络：客户端请求分配职业
-- ═══════════════════════════════════════
util.AddNetworkString("FT_ClassAssign")
net.Receive("FT_ClassAssign", function(len, ply)
    local classId = net.ReadString()
    Fireteam.Class.Assign(ply, classId)
end)

print("[FIRETEAM:Class] ✓ Server logic loaded")
