-- entities/ft_ammo_crate.lua
-- 可放置弹药盒：E 键补满备弹，N 次补给后消失。由 resupply 模块的
-- deployable 物品放置；回合简报时由该模块清场移除。

AddCSLuaFile()

ENT.Type            = "anim"
ENT.Base            = "base_anim"
ENT.PrintName       = "Ammo Crate"
ENT.Author          = "FIRETEAM"
ENT.Spawnable       = false
ENT.UseType         = SIMPLE_USE

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "UsesLeft")
end

function ENT:SetUses(n)
    self:SetUsesLeft(math.max(tonumber(n) or 0, 0))
end

if SERVER then

    local RESUPPLY_COOLDOWN = 1.0

    function ENT:Initialize()
        self:SetModel("models/items/ammocrate01.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end

        self.FT_NextUse = 0
    end

    -- 补满一名玩家的备弹池；返回实际补充数
    local function FillPlayer(ply)
        local targetPrim = tonumber(Fireteam.Config.Get("resupply.reserve_primary")) or 0
        local targetSec  = tonumber(Fireteam.Config.Get("resupply.reserve_secondary")) or 0
        local filled = 0
        for _, wep in ipairs(ply:GetWeapons()) do
            if IsValid(wep) then
                for typeId, target in pairs({
                    [wep:GetPrimaryAmmoType()]   = targetPrim,
                    [wep:GetSecondaryAmmoType()] = targetSec,
                }) do
                    if type(typeId) == "number" and typeId > 0 and target > 0 then
                        local delta =
                            Fireteam.Resupply.ReserveDelta(ply:GetAmmoCount(typeId), target)
                        if delta > 0 then
                            ply:GiveAmmo(delta, typeId, true)
                            filled = filled + delta
                        end
                    end
                end
            end
        end
        return filled
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        if not activator:Alive() then return end
        if CurTime() < (self.FT_NextUse or 0) then return end
        self.FT_NextUse = CurTime() + RESUPPLY_COOLDOWN

        local usesLeft = self:GetUsesLeft()
        if not Fireteam.Resupply.CrateUsable(usesLeft) then return end

        local filled = FillPlayer(activator)
        if filled <= 0 then
            activator:ChatPrint("[FIRETEAM] "
                .. Fireteam.Locale.Get("resupply_reserve_full"))
            return
        end

        self:SetUses(usesLeft - 1)
        activator:EmitSound("Ambient.Level.HeadshellCaseBounce3")

        local left = self:GetUsesLeft()
        activator:ChatPrint("[FIRETEAM] "
            .. string.format(Fireteam.Locale.Get("resupply_crate_take"), left))
        if left <= 0 then
            activator:ChatPrint("[FIRETEAM] "
                .. Fireteam.Locale.Get("resupply_crate_spent"))
            SafeRemoveEntityDelayed(self, 3)
        end
    end

else

    function ENT:Draw()
        self:DrawModel()
    end

end
