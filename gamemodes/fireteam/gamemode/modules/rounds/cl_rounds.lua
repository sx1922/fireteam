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
    scenario  = nil,
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
    c.scenario  = istable(snap.scenario) and snap.scenario or nil

    hook.Run(Fireteam.HOOKS.ROUNDS_CLIENT_STATE_CHANGED, c.state)
end)

--- 当前剧本显示名（中文客户端用 name_zh）
function Fireteam.Rounds.GetScenarioName()
    local s = Fireteam.Rounds.Client.scenario
    if not s then return nil end
    local lang = GetConVar("gmod_language") and GetConVar("gmod_language"):GetString() or "en"
    return (lang == "zh-CN" and s.name_zh) and s.name_zh or s.name
end

--- 剩余秒数（客户端本地时钟推算）
function Fireteam.Rounds.GetTimeRemaining()
    return math.max(0, Fireteam.Rounds.Client.endTime - CurTime())
end

--- 己方阵营（跟随小队），用于胜利/失败着色
function Fireteam.Rounds.GetMyFaction()
    return Fireteam.Rounds.GetPlayerFaction(LocalPlayer())
end
