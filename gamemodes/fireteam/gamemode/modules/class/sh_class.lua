-- modules/class/sh_class.lua
-- FIRETEAM Class System - Shared

if not Fireteam then Fireteam = {} end
Fireteam.Class = Fireteam.Class or {}

-- 获取当前设定包的所有职业
function Fireteam.Class.GetAll()
    return Fireteam.Setting.GetData("classes") or {}
end

-- 获取指定职业数据
function Fireteam.Class.Get(classId)
    local classes = Fireteam.Class.GetAll()
    return classes[classId]
end

-- 获取某阵营可用的职业
function Fireteam.Class.GetByFaction(factionId)
    local classes = Fireteam.Class.GetAll()
    local result = {}
    for id, data in pairs(classes) do
        if data.faction == factionId then
            result[id] = data
        end
    end
    return result
end

-- 获取玩家当前职业
function Fireteam.Class.GetPlayerClass(ply)
    if not IsValid(ply) then return nil end
    return ply.FT_Class
end

-- 获取玩家职业数据
function Fireteam.Class.GetPlayerClassData(ply)
    local classId = Fireteam.Class.GetPlayerClass(ply)
    if not classId then return nil end
    return Fireteam.Class.Get(classId)
end

print("[FIRETEAM:Class] ✓ 共享定义已加载")
