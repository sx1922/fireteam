-- modules/spectate/sh_spectate.lua
-- FIRETEAM Observer Mode - Shared（模块入口）
-- 阵亡后旁观队友：第一/第三/自由视角循环，目标轮换；与回合制联动（阵亡待机到下回合）。

if not Fireteam then Fireteam = {} end
Fireteam.Spectate = Fireteam.Spectate or {}

Fireteam.Config.Register("spectate.enabled", true, {
    type = "boolean",
    desc = "Team spectate after death during rounds"
})

--- 观战候选（优先同小队 → 同阵营 → 全体存活），排除自己
function Fireteam.Spectate.GetCandidates(ply)
    local alive = {}
    for _, p in ipairs(player.GetAll()) do
        if p ~= ply and IsValid(p) and p:Alive() and not p:IsSpec() then
            alive[#alive + 1] = p
        end
    end

    local mySquad = Fireteam.Squad.GetPlayerSquad(ply)
    if mySquad then
        local mates = {}
        for _, p in ipairs(alive) do
            local s = Fireteam.Squad.GetPlayerSquad(p)
            if s and s.id == mySquad.id then mates[#mates + 1] = p end
        end
        if #mates > 0 then return mates end
    end

    local myFaction = Fireteam.Rounds.GetPlayerFaction(ply)
    if myFaction then
        local factionMates = {}
        for _, p in ipairs(alive) do
            if Fireteam.Rounds.GetPlayerFaction(p) == myFaction then
                factionMates[#factionMates + 1] = p
            end
        end
        if #factionMates > 0 then return factionMates end
    end

    return alive
end

Fireteam.Log.Info("Spectate", "✓ 共享定义已加载")
