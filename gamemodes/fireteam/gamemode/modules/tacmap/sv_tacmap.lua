-- modules/tacmap/sv_tacmap.lua
-- FIRETEAM Tactical Map - Server Logic
-- 职责：向客户端推送地图边界信息；新加入小队的成员补收全量标记快照。

if not Fireteam then Fireteam = {} end
Fireteam.TacMap = Fireteam.TacMap or {}

local function BroadcastMapInfo(plys)
    local vmin, vmax = Fireteam.TacMap.GetPackBounds()

    net.Start(Fireteam.NET.MAP_INFO)
        net.WriteBool(vmin ~= nil)
        if vmin then
            net.WriteVector(vmin)
            net.WriteVector(vmax)
        end
    if plys then
        net.Send(plys)
    else
        net.Broadcast()
    end
end

--- 设定包切换时重新广播（含 hud 主题等一并刷新的场景）
hook.Add(Fireteam.HOOKS.SETTING_LOADED, "Fireteam.TacMap.PushBounds", function()
    BroadcastMapInfo()
end)

--- 玩家进服时补发边界与（稍后入队时的）标记快照
hook.Add("PlayerInitialSpawn", "Fireteam.TacMap.PlayerJoin", function(ply)
    -- 延迟一拍，等客户端 InitPostEntity 完成
    timer.Simple(3, function()
        if IsValid(ply) then
            BroadcastMapInfo(ply)
        end
    end)
end)

--- 加入小队后立即同步该小队全部标记（解决 late-join 看不到旧标记）
hook.Add(Fireteam.HOOKS.PLAYER_JOINED_SQUAD, "Fireteam.TacMap.SyncMarkersOnJoin", function(ply, squad)
    if squad and squad.id then
        Fireteam.Marker.SyncToSquad(squad.id)
    end
end)

Fireteam.Log.Info("TacMap", "✓ 服务端逻辑已加载")
