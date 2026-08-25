-- modules/rounds/cl_rounds.lua
-- FIRETEAM Rounds Framework - Client State
-- 接收 ROUNDS_STATE 快照；UI 层（cl_rounds_ui）负责渲染。

Fireteam.Rounds.Client = Fireteam.Rounds.Client or {
    state     = "idle",
    endTime   = 0,
    round     = 0,
    scores    = {},
    winner    = nil,
    reason    = "",
    objective = nil,
}

net.Receive(Fireteam.NET.ROUNDS_STATE, function()
    local snap = net.ReadTable()
    if not istable(snap) then return end

    local c = Fireteam.Rounds.Client
    c.state     = snap.state or "idle"
    c.endTime   = tonumber(snap.endTime) or 0
    c.round     = tonumber(snap.round) or 0
    c.scores    = istable(snap.scores) and snap.scores or {}
    c.winner    = snap.winner  -- string | nil
    c.reason    = snap.reason or ""
    c.objective = istable(snap.objective) and snap.objective or nil

    hook.Run("Fireteam.Rounds.ClientStateChanged", c.state)
end)

--- 剩余秒数（客户端本地时钟推算）
function Fireteam.Rounds.GetTimeRemaining()
    return math.max(0, Fireteam.Rounds.Client.endTime - CurTime())
end

--- 己方阵营（跟随小队），用于胜利/失败着色
function Fireteam.Rounds.GetMyFaction()
    return Fireteam.Rounds.GetPlayerFaction(LocalPlayer())
end
