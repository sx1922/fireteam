-- entities/entities/ft_bot_teammate.lua
-- FIRETEAM AI Teammate NextBot
-- 由 modules/ai/sv_ai.lua 部署与指挥；本文件只实现个体行为。
-- 姿态机：follow（跟随主人）/ hold（驻守）/ goto（路点机动，到达后回落）。
-- 索敌交火保持最简：范围内可见敌人 → 站桩点射；深度战术 AI 留待扩展。

AddCSLuaFile()

ENT.Base             = "base_nextbot"
ENT.PrintName        = "FT AI Teammate"
ENT.Author           = "sx1922"
ENT.Spawnable        = false
ENT.AdminOnly        = false

-- ═══════════════════════════════════════
-- 初始化
-- ═══════════════════════════════════════
function ENT:Initialize()
    if not self:GetModel() or self:GetModel() == "models/error.mdl" then
        self:SetModel("models/player/group01/male_02.mdl")
    end

    local hp = Fireteam.Config.Get("ai.health") or 100
    self:SetMaxHealth(hp)
    self:SetHealth(hp)

    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-14, -14, 0), Vector(14, 14, 71))
    self:CapabilitiesAdd(CAP_MOVE_GROUND + CAP_USE_WEAPONS)
    self.loco:SetDeathDropHeight(400)
    self.loco:SetAcceleration(600)
    self.loco:SetDeceleration(600)

    self.FT_Owner        = nil
    self.FT_Stance       = "follow"
    self.FT_PrevStance   = "follow"
    self.FT_HoldPos      = nil
    self.FT_GotoPos      = nil
    self.FT_HoldAtGoto   = false
    self.FT_NextScan     = 0
    self.FT_NextShot     = 0
    self.FT_Target       = nil
    self.FT_LastSeen     = 0

    self:StartActivity(ACT_IDLE)
end

--- 绑定主人（sv_ai 在 Spawn 后调用）
function ENT:Bind(ply)
    self.FT_Owner = ply
end

function ENT:GetStance()
    return self.FT_Stance
end

--- 切姿态；进入 hold 时以当前位置为驻守点
function ENT:SetStance(stance)
    if stance ~= "follow" and stance ~= "hold" and stance ~= "goto" then return end
    if stance == self.FT_Stance then return end
    if stance == "hold" then
        self.FT_HoldPos = self:GetPos()
    end
    if stance ~= "goto" then
        self.FT_GotoPos = nil
    end
    self.FT_Stance = stance
    self:SetNW2String("ftStance", stance)
end

--- 路点指令（MARKER_ADDED → sv_ai 转发）
--- @param holdHere boolean 到达后是否就地驻守（rally）
function ENT:OrderMoveTo(pos, holdHere)
    if not isvector(pos) then return end
    if self.FT_Stance ~= "goto" then
        self.FT_PrevStance = (self.FT_Stance == "hold") and "hold" or "follow"
    end
    -- 先存目标点再切姿态：SetStance 对非 goto 姿态会清空路点
    self.FT_GotoPos    = pos
    self.FT_HoldAtGoto = holdHere and true or false
    self:SetStance("goto")
end

-- ═══════════════════════════════════════
-- 阵营 / 索敌
-- ═══════════════════════════════════════
function ENT:GetFaction()
    return Fireteam.AI.GetPlayerFaction(self.FT_Owner)
end

--- 视线可达（忽略自身；目标恒为玩家）
function ENT:HasLOS(target)
    local tr = util.TraceLine({
        start  = self:EyePos(),
        endpos = target:EyePos(),
        filter = function(e) return e == self end,
        mask   = MASK_BLOCKLOS,
    })
    return not tr.Hit or tr.Entity == target
end

--- 最近的可交战敌方玩家；无阵营定义（无小队/回合）时永不索敌
function ENT:FindEnemy()
    if CurTime() < self.FT_NextScan then
        return IsValid(self.FT_Target) and self.FT_Target or nil
    end
    self.FT_NextScan = CurTime() + 0.5

    local myFaction = self:GetFaction()
    if not myFaction then return nil end

    local range = Fireteam.Config.Get("ai.acquire_range") or 1200
    local best, bestDist = nil, range * range
    for _, p in ipairs(player.GetAll()) do
        if p:IsPlayer() and p:Alive() and p:GetObserverMode() == OBS_MODE_NONE then
            local f = Fireteam.AI.GetPlayerFaction(p)
            if f and f ~= myFaction then
                local d = self:GetPos():DistToSqr(p:GetPos())
                if d < bestDist and self:HasLOS(p) then
                    best, bestDist = p, d
                end
            end
        end
    end
    self.FT_Target = best
    if best then self.FT_LastSeen = CurTime() end
    return best
end

-- ═══════════════════════════════════════
-- 交火
-- ═══════════════════════════════════════
function ENT:ShootAt(enemy)
    local src = self:EyePos()
    local aim = enemy:EyePos() - src
    local dir = aim:GetNormalized()

    self:EmitSound("Weapon_AR2.NPC_Single", 70, math.random(92, 108))
    self:FireBullets({
        Attacker = self,
        Inflictor = self,
        Src       = src,
        Dir       = dir,
        Spread    = Vector(0.04, 0.04, 0),
        Num       = 1,
        Damage    = Fireteam.Config.Get("ai.attack_damage") or 8,
        Tracer    = 1,
        Force     = 4,
    })

    -- 枪口朝向反馈
    self.loco:FaceTowards(enemy:GetPos())
end

--- 交火子循环：目标丢失/死亡/超时后返回主循环
function ENT:Engage(enemy)
    self:StartActivity(ACT_IDLE)

    while true do
        if not IsValid(enemy) or not enemy:Alive() then return end
        if CurTime() - self.FT_LastSeen > 4 then return end

        local range = (Fireteam.Config.Get("ai.acquire_range") or 1200) * 1.25
        local dist = self:GetPos():Distance(enemy:GetPos())
        if dist > range then return end

        if self:HasLOS(enemy) then
            self.FT_LastSeen = CurTime()
            if CurTime() >= self.FT_NextShot then
                self:ShootAt(enemy)
                self.FT_NextShot = CurTime() + 0.3 + math.random() * 0.25
            end
        else
            -- 暂时丢失视线：向最后已知位置逼近一段
            self:StartActivity(ACT_RUN)
            self:MoveToPos(enemy:GetPos(), { lookahead = 128, tolerance = 96, maxage = 1.5 })
            self:StartActivity(ACT_IDLE)
        end

        coroutine.yield()
    end
end

-- ═══════════════════════════════════════
-- 主行为循环
-- ═══════════════════════════════════════
function ENT:RunBehaviour()
    while true do
        local enemy = self:FindEnemy()
        if enemy then
            self:Engage(enemy)
            self.FT_Target = nil
        elseif self.FT_Stance == "goto" and self.FT_GotoPos then
            self:StartActivity(ACT_WALK)
            local reached = self:MoveToPos(self.FT_GotoPos, {
                lookahead = 256,
                tolerance = 48,
                maxage    = 30,
            })
            self:StartActivity(ACT_IDLE)

            if self.FT_Stance == "goto" then  -- 中途未被新指令改写
                if self.FT_HoldAtGoto then
                    self.FT_HoldPos = self.FT_GotoPos
                    self.FT_Stance  = "hold"
                    self:SetNW2String("ftStance", "hold")
                else
                    self:SetStance(self.FT_PrevStance)
                end
            end
        elseif self.FT_Stance == "hold" then
            -- 被物理推离驻守点时归位
            if self.FT_HoldPos
                and self:GetPos():DistToSqr(self.FT_HoldPos) > 100 * 100 then
                self:StartActivity(ACT_WALK)
                self:MoveToPos(self.FT_HoldPos, { tolerance = 40, maxage = 8 })
                self:StartActivity(ACT_IDLE)
            end
        else -- follow
            local owner = self.FT_Owner
            if IsValid(owner) and owner:Alive() then
                local dist = self:GetPos():DistToSqr(owner:GetPos())
                local keep = Fireteam.Config.Get("ai.follow_distance") or 150

                if dist > 4000 * 4000 then
                    -- 主人拉得太远（传送/换图区）：就近补位，防止永久掉队
                    self:SetPos(owner:GetPos() + Vector(math.random(-60, 60), math.random(-60, 60), 8))
                elseif dist > (keep * 1.6) ^ 2 then
                    self:StartActivity(dist > (keep * 4) ^ 2 and ACT_RUN or ACT_WALK)
                    self:MoveToPos(owner:GetPos(), {
                        lookahead = 256,
                        tolerance = keep,
                        maxage    = 6,
                    })
                    self:StartActivity(ACT_IDLE)
                end
            end
        end

        coroutine.yield()
    end
end

-- ═══════════════════════════════════════
-- 受击 / 死亡
-- ═══════════════════════════════════════
function ENT:OnTakeDamage(dmginfo)
    local attacker = dmginfo:GetAttacker()
    -- 友军伤害遵循 squad.friendly_fire 开关
    if attacker:IsPlayer() and attacker ~= self.FT_Owner then
        local myF = self:GetFaction()
        local atkF = Fireteam.AI.GetPlayerFaction(attacker)
        if myF and atkF == myF and not (Fireteam.Config.Get("squad.friendly_fire")) then
            dmginfo:SetDamage(0)
            return
        end
    end
    -- 受击立即转向还击（下个 think 生效）
    if attacker:IsPlayer() and dmginfo:GetDamage() > 0 then
        self.FT_Target   = attacker
        self.FT_LastSeen = CurTime()
        self.FT_NextScan = CurTime() + 0.5
    end
end

function ENT:OnKilled(dmginfo)
    self:BecomeRagdoll(dmginfo)
end

function ENT:OnRemove()
    if Fireteam.AI and Fireteam.AI.Unregister then
        Fireteam.AI.Unregister(self)
    end
end
