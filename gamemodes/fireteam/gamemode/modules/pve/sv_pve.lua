-- modules/pve/sv_pve.lua
-- FIRETEAM PvE 战役 - Server
-- 职责：按设定包 pve 配置生成自主阵营 AI 单位；管理 defend（驻守出生带）/
--       advance（周期性向当前目标推进）两种行为；维护战役关卡顺序——
--       PvE 模式下回合目标不轮转，而是逐关推进（过关进入下一关，失败重打）。
-- 生命周期由 sv_rounds 显式驱动：
--   OnEnterBriefing / OnEnterActive / OnRoundEnded / OnPackChanged。
--
-- 设定包契约（map_rules.rounds，剧本级优先于包级）：
--   [scenario].pve = {
--       player_factions = { ... },   -- 玩家方阵营（战役胜负判定用）
--       ai_factions     = { ... },   -- 简报期生成 AI 的阵营
--       bots_per_faction = 3,        -- 每 AI 阵营 bot 数（缺省读 config）
--       ai_behavior     = "defend" | "advance",
--   }

local roster = {}          -- bot entity -> { faction = id }
local stage = 1            -- 战役当前关（1 起）
local campaignCompleteShown = false

local function IsPvEMode()
    return (Fireteam.Config.Get("rounds.mode") or "pvp") == "pve"
end

--- 当前生效的 pve 配置块：剧本级覆盖 > 包级；无则 nil
local function GetPackPvE()
    local scenario = Fireteam.Rounds.ResolveScenario()
    local cfg = Fireteam.Rounds.GetPackConfig() or {}
    return (scenario and scenario.pve) or cfg.pve or nil
end

local function GetObjectiveCount()
    return #Fireteam.Rounds.GetObjectiveTemplates()
end

--- 该阵营是否属于玩家方（未声明 player_factions 时视为全是玩家方）
local function IsPlayerSide(factionId)
    local pve = GetPackPvE()
    if not istable(pve and pve.player_factions) then return true end
    for _, f in ipairs(pve.player_factions) do
        if f == factionId then return true end
    end
    return false
end

--- 从上方找地面（出生锚点是示意值）
local function GroundPos(pos)
    local t = util.TraceLine({
        start  = pos + Vector(0, 0, 256),
        endpos = pos - Vector(0, 0, 4096),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    if t.Hit then return t.HitPos + Vector(0, 0, 8) end
    return pos
end

local function RemoveAllBots()
    local n = 0
    for bot in pairs(roster) do
        if IsValid(bot) then bot:Remove() end
        n = n + 1
    end
    roster = {}
    return n
end

-- ═══════════════════════════════════════
-- 生命周期钩子（sv_rounds 驱动）
-- ═══════════════════════════════════════

--- 简报期：清掉上回合残部，按剧本出生带布设 AI 阵营（禁火待命）
function Fireteam.PvE.OnEnterBriefing()
    RemoveAllBots()

    if not IsPvEMode() then return end
    local pve = GetPackPvE()
    if not istable(pve and pve.ai_factions) or #pve.ai_factions == 0 then return end

    local perFaction = tonumber(pve.bots_per_faction)
        or tonumber(Fireteam.Config.Get("pve.bots_per_faction")) or 4
    local maxBots = tonumber(Fireteam.Config.Get("pve.max_bots")) or 24

    local total = 0
    for _, factionId in ipairs(pve.ai_factions) do
        local spawns = Fireteam.Rounds.GetScenarioSpawns(factionId)
        if #spawns == 0 then
            Fireteam.Log.Warn("PvE", "阵营 " .. tostring(factionId) .. " 在当前剧本无出生点，跳过")
        else
            for i = 1, perFaction do
                if total >= maxBots then break end
                local spec = spawns[(i - 1) % #spawns + 1]
                local base = Fireteam.Rounds.ResolvePos(istable(spec) and (spec.pos or spec) or spec)
                if base then
                    local bot = ents.Create("ft_bot_teammate")
                    if IsValid(bot) then
                        bot:SetPos(GroundPos(base))
                        bot:Spawn()
                        bot:SetCombatFaction(factionId)
                        bot:SetStance("hold")
                        bot.FT_HoldFire = true
                        roster[bot] = { faction = factionId }
                        total = total + 1
                    end
                end
            end
        end
    end

    if total > 0 then
        Fireteam.Log.Info("PvE", string.format("已部署 %d 个 AI 单位（%d 个阵营，简报期禁火）",
            total, #pve.ai_factions))
    end
end

--- ACTIVE 开始：解除禁火；advance 行为立即下发首轮推进指令并挂周期刷新
function Fireteam.PvE.OnEnterActive()
    for bot in pairs(roster) do
        if IsValid(bot) then bot.FT_HoldFire = false end
    end

    local pve = GetPackPvE()
    if pve and pve.ai_behavior == "advance" then
        Fireteam.PvE.IssueAdvanceOrders()
        timer.Create("Fireteam.PvE.Advance", 10, 0, function()
            if Fireteam.Rounds.GetState() ~= Fireteam.Rounds.STATE.ACTIVE then return end
            Fireteam.PvE.IssueAdvanceOrders()
        end)
    end
end

--- 回合结束：清场 + 战役关卡机（目标完成且玩家方获胜 → 推进；否则重试本关）
function Fireteam.PvE.OnRoundEnded(winner, reason)
    timer.Remove("Fireteam.PvE.Advance")

    if IsPvEMode() and GetPackPvE() then
        local total = GetObjectiveCount()
        if total > 0 and reason ~= "idle" then
            if reason == "objective" and winner and IsPlayerSide(winner) then
                if stage >= total then
                    if not campaignCompleteShown then
                        Fireteam.Log.Info("PvE", string.format("★ 战役通关！%d 关全部完成，进度已重置", total))
                        campaignCompleteShown = true
                    end
                    stage = 1
                else
                    stage = stage + 1
                    Fireteam.Log.Info("PvE", string.format("第 %d/%d 关完成 → 进入下一关", stage - 1, total))
                end
            else
                Fireteam.Log.Info("PvE", string.format("第 %d/%d 关未达成——下回合重试本关", stage, total))
            end
        end
    end

    RemoveAllBots()
end

--- 设定包切换：清场并重置战役进度
function Fireteam.PvE.OnPackChanged()
    RemoveAllBots()
    stage = 1
    campaignCompleteShown = false
end

-- ═══════════════════════════════════════
-- 行为指令
-- ═══════════════════════════════════════

--- 向当前目标位置下发推进指令（带散布偏移防扎堆；到达后就地驻守等待下一轮）
function Fireteam.PvE.IssueAdvanceOrders()
    local pve = GetPackPvE()
    if not (pve and pve.ai_behavior == "advance") then return 0 end

    local objPos = Fireteam.Rounds.GetObjectivePos()
    if not objPos then return 0 end

    local n = 0
    for bot in pairs(roster) do
        if IsValid(bot) and not bot.FT_Dying then
            local off = Vector(math.random(-140, 140), math.random(-140, 140), 0)
            bot:OrderMoveTo(objPos + off, true)
            n = n + 1
        end
    end
    return n
end

-- ═══════════════════════════════════════
-- 查询接口（sv_rounds / 管理面板消费）
-- ═══════════════════════════════════════

--- 当前 PvE 配置下的 AI 阵营列表（非 PvE 或无配置返回空表）
function Fireteam.PvE.GetAIFactions()
    if not IsPvEMode() then return {} end
    local pve = GetPackPvE()
    if not istable(pve and pve.ai_factions) then return {} end
    return pve.ai_factions
end

function Fireteam.PvE.GetCurrentStageIndex()
    return stage
end

--- 快照/面板用战役进度；非 PvE 或无目标链返回 nil
function Fireteam.PvE.GetCampaignInfo()
    if not IsPvEMode() then return nil end
    if not GetPackPvE() then return nil end
    local total = GetObjectiveCount()
    if total == 0 then return nil end
    return { stage = stage, total = total }
end

-- ═══════════════════════════════════════
-- 模式 / 剧本变更：战役进度重置（切换语义同回合引擎：下回合生效）
-- ═══════════════════════════════════════
hook.Add(Fireteam.HOOKS.CONFIG_CHANGED, "Fireteam.PvE.ModeOrScenarioChanged", function(key, oldVal, newVal)
    if key ~= "rounds.mode" and key ~= "rounds.scenario" then return end

    if key == "rounds.mode" then
        Fireteam.Log.Info("PvE", string.format("模式切换: %s → %s（下一回合简报生效）",
            tostring(oldVal), tostring(newVal)))
    end

    if stage ~= 1 or campaignCompleteShown then
        stage = 1
        campaignCompleteShown = false
        Fireteam.Log.Info("PvE", "战役进度已重置至第 1 关")
    end
end)

Fireteam.Log.Info("PvE", "✓ PvE 战役服务端已加载")
