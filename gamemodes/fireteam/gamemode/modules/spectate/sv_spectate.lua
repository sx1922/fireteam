-- modules/spectate/sv_spectate.lua
-- FIRETEAM Observer Mode - Server
-- 引擎观战（Spectate/SpectateEntity）驱动；目标死亡自动顺延；重生即退出。

local MODE_CYCLE = { OBS_MODE_IN_EYE, OBS_MODE_CHASE, OBS_MODE_ROAM }

--- 回合系统是否正禁止该玩家重生（阵亡待机窗口）
local function RespawnBlocked()
    if not (Fireteam.Rounds and Fireteam.Rounds.IsRespawnBlocked) then return false end
    return Fireteam.Rounds.IsRespawnBlocked() == true
end

--- 应用当前目标（索引越界回绕；候选消失时清空）
local function ApplyTarget(ply)
    if not ply.FT_Spec then return end
    local cands = Fireteam.Spectate.GetCandidates(ply)
    if #cands == 0 then
        ply:SpectateEntity(nil)
        ply.FT_Spec.target = nil
        return
    end
    ply.FT_Spec.idx = ((ply.FT_Spec.idx - 1) % #cands) + 1
    local target = cands[ply.FT_Spec.idx]
    ply.FT_Spec.target = target
    ply:SpectateEntity(target)
end

function Fireteam.Spectate.Start(ply)
    if not Fireteam.Config.Get("spectate.enabled") then return end
    if IsValid(ply) and ply:Alive() then return end
    if #Fireteam.Spectate.GetCandidates(ply) == 0 then return end

    ply.FT_Spec = { idx = 1, modeIdx = 2 }   -- 默认第三人称追尾
    ply:Spectate(MODE_CYCLE[2])
    ApplyTarget(ply)
end

function Fireteam.Spectate.Stop(ply)
    if not ply.FT_Spec then return end
    ply.FT_Spec = nil
    if ply:GetObserverMode() ~= OBS_MODE_NONE then
        ply:UnSpectate()
    end
end

-- ═══════════════════════════════════════
-- 死亡 → 延迟进入观战（给死亡镜头留时间）
-- ═══════════════════════════════════════
hook.Add("PlayerDeath", "Fireteam.Spectate.OnDeath", function(victim)
    timer.Simple(3, function()
        if not IsValid(victim) or victim:Alive() then return end
        if not RespawnBlocked() then return end   -- 可自由重生的服务器不接管
        Fireteam.Spectate.Start(victim)
    end)

    -- 被观看者死亡：所有盯着他的观战者顺延到下一位
    for _, p in ipairs(player.GetAll()) do
        if p.FT_Spec and IsValid(p.FT_Spec.target) and p.FT_Spec.target == victim then
            p.FT_Spec.idx = p.FT_Spec.idx + 1
            ApplyTarget(p)
        end
    end
end)

hook.Add("PlayerSpawn", "Fireteam.Spectate.ExitOnSpawn", function(ply)
    Fireteam.Spectate.Stop(ply)
end)

hook.Add("PlayerDisconnected", "Fireteam.Spectate.Cleanup", function(ply)
    ply.FT_Spec = nil
end)

-- ═══════════════════════════════════════
-- 客户端控制：切换目标 / 循环视角模式
-- ═══════════════════════════════════════
net.Receive(Fireteam.NET.SPECTATE_CONTROL, function(_, ply)
    if not ply.FT_Spec then return end
    local act = net.ReadString()

    if act == "next" then
        ply.FT_Spec.idx = ply.FT_Spec.idx + 1
        ApplyTarget(ply)
    elseif act == "prev" then
        ply.FT_Spec.idx = ply.FT_Spec.idx - 1
        ApplyTarget(ply)
    elseif act == "mode" then
        ply.FT_Spec.modeIdx = (ply.FT_Spec.modeIdx % #MODE_CYCLE) + 1
        ply:Spectate(MODE_CYCLE[ply.FT_Spec.modeIdx])
        ApplyTarget(ply)   -- ROAM 下实体为空也安全
    end
end)

Fireteam.Log.Info("观战", "✓ 观察者模式服务端已加载")
