-- modules/admin/sv_admin.lua
-- FIRETEAM Admin Panel - Server
-- 管理员校验 → 执行动作（复用各模块公开 API）→ 回发全量状态快照。

local function IsAdmin(ply)
    return IsValid(ply) and ply:IsAdmin()
end

--- 全量状态快照（配置元数据 + 设定包 + 回合 + 玩家总览）
local function BuildState()
    local packs = {}
    for id, meta in pairs(Fireteam.Setting.Discovered or {}) do
        packs[#packs + 1] = {
            id     = id,
            name   = meta.name or id,
            source = meta._source or "?",
        }
    end
    table.sort(packs, function(a, b) return a.id < b.id end)

    local players = {}
    for _, p in ipairs(player.GetAll()) do
        local squad = Fireteam.Squad.GetPlayerSquad(p)
        players[#players + 1] = {
            name    = p:Nick(),
            squad   = squad and squad.name or "-",
            faction = squad and squad.faction or "-",
            classId = Fireteam.Class.GetPlayerClass(p),
            alive   = p:Alive(),
            ping    = p:Ping(),
        }
    end

    local roundState, roundNum = nil, 0
    if Fireteam.Rounds and Fireteam.Rounds.GetState then
        roundState = Fireteam.Rounds.GetState()
    end

    local modeInfo = {}
    if Fireteam.Rounds and Fireteam.Rounds.GetModeInfo then
        modeInfo = Fireteam.Rounds.GetModeInfo()
    end

    return {
        configs    = Fireteam.Config.DescribeAll(),
        packs      = packs,
        activePack = Fireteam.Setting.GetActiveId(),
        rounds     = {
            state    = roundState,
            mode     = modeInfo.mode or "pvp",
            campaign = modeInfo.campaign,
        },
        players    = players,
    }
end

local function SendState(ply)
    Fireteam.Net.SendToPlayer(ply, Fireteam.NET.ADMIN_STATE,
        BuildState())
end

-- ═══════════════════════════════════════
-- 动作执行（全部走模块公开 API，不触碰内部状态）
-- ═══════════════════════════════════════
local function ExecuteAction(ply, act)
    if act.type == "set_config" then
        -- Config.Set 内置类型/范围/枚举校验，失败返回 false 不落地
        local ok = Fireteam.Config.Set(tostring(act.key), act.value)
        if ok then
            Fireteam.Log.Info("管理", ply:Nick() .. " 修改配置 " .. tostring(act.key)
                .. " = " .. tostring(act.value))
        end
        return ok

    elseif act.type == "reset_config" then
        return Fireteam.Config.Reset(tostring(act.key))

    elseif act.type == "switch_pack" then
        local id = tostring(act.id)
        if not Fireteam.Setting.Discovered[id] then return false end
        Fireteam.Log.Info("管理", ply:Nick() .. " 切换设定包 → " .. id)
        local ok, err = pcall(Fireteam.Setting.Activate, id)
        if not ok then
            Fireteam.Log.Error("管理", "切换设定包失败: " .. tostring(err))
        end
        return ok

    elseif act.type == "round_next" then
        if Fireteam.Rounds and Fireteam.Rounds.AdminAdvance then
            Fireteam.Rounds.AdminAdvance()
            return true
        end
        return false

    elseif act.type == "round_end" then
        if Fireteam.Rounds and Fireteam.Rounds.AdminEnd then
            return Fireteam.Rounds.AdminEnd(act.arg)
        end
        return false
    end

    return false
end

net.Receive(Fireteam.NET.ADMIN_ACTION, function(_, ply)
    if not IsAdmin(ply) then
        ply:ChatPrint("[FIRETEAM] " .. Fireteam.Locale.Get("admin_denied"))
        return
    end

    local act = net.ReadTable()
    if not istable(act) then return end
    if not Fireteam.Admin.ACTIONS[act.type] then return end

    ExecuteAction(ply, act)
    SendState(ply)   -- 无论成败都回快照，客户端界面即刷新为真实值
end)

Fireteam.Log.Info("管理", "✓ 管理面板服务端已加载")
