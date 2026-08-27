-- entities/entities/ft_grenade_proj.lua
-- FIRETEAM 投掷物（消耗品栏投出的手雷）
-- 模型/引信/杀伤参数由设定包 items.lua 的 throw 表提供，
-- 本实体只负责物理飞行、引信计时与起爆。

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "FT Grenade Projectile"
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "BlastRadius")
    self:NetworkVar("Float", 1, "BlastDamage")
end

--- 引信剩余秒数（由生成方调用）
function ENT:SetFuse(seconds)
    self.FuseAt = CurTime() + math.max(tonumber(seconds) or 3, 0.5)
end

if SERVER then

    function ENT:Initialize()
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
        self:PhysicsInit(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetBuoyancyRatio(0.3)
            phys:AddAngleVelocity(VectorRand() * 60)   -- 轻微翻滚，视觉自然
        end
    end

    function ENT:Think()
        if not self.Detonated and self.FuseAt and CurTime() >= self.FuseAt then
            self:Detonate()
            return false
        end
        self:NextThink(CurTime())
        return true
    end

    --- 被子弹命中也会起爆
    function ENT:OnTakeDamage()
        self:Detonate()
    end

    function ENT:Detonate()
        if self.Detonated then return end
        self.Detonated = true

        local pos = self:GetPos()
        local attacker = IsValid(self.FT_Attacker) and self.FT_Attacker or self

        local ed = EffectData()
        ed:SetOrigin(pos)
        ed:SetRadius(self:GetBlastRadius())
        util.Effect("Explosion", ed, true, true)
        sound.Play("BaseExplosion", pos, 95, 100, 1.0)

        util.BlastDamage(self, attacker, pos,
            self:GetBlastRadius() > 0 and self:GetBlastRadius() or 350,
            self:GetBlastDamage() > 0 and self:GetBlastDamage() or 90)

        self:Remove()
    end

end

if CLIENT then

    function ENT:Draw()
        self:DrawModel()
    end

end
