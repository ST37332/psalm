AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Psalm Item"
ENT.Category  = "Psalm"
ENT.Spawnable = false
ENT.AdminOnly = true

function ENT:GetItemID()    return self:GetNWString("ItemID", "") end
function ENT:GetItemDef()
    local id = self:GetItemID()
    if id == "" then return nil end
    return Psalm.Items[id]
end
function ENT:GetName()
    local def = self:GetItemDef()
    return def and def.name or self.PrintName
end
function ENT:GetRarity()
    local def = self:GetItemDef()
    return def and def.rarity or 0
end
function ENT:GetDescription()
    local def = self:GetItemDef()
    return def and def.description or (def and def.desc) or ""
end

if SERVER then

    function ENT:Initialize()
        self:SetModel("models/props_junk/garbage_coffeemug001a.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end

        self.SpawnedOnce = true
        local id = self:GetItemID()
        if id ~= "" then self:SetItemID(id) end
    end

    function ENT:SetItemID(id)
        if not id or id == "" then return end
        self:SetNWString("ItemID", id)

        local def = Psalm.Items[id]
        if def and def.model and self:GetModel() ~= def.model then
            self:SetModel(def.model)
            if self.SpawnedOnce then
                self:PhysicsInit(SOLID_VPHYSICS)
                local phys = self:GetPhysicsObject()
                if IsValid(phys) then phys:Wake() end
            end
        end
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        if self.NextPickup and self.NextPickup > CurTime() then return end
        self.NextPickup = CurTime() + 0.5

        if Psalm.Inv.AddItem(activator, self) then
            activator:ChatPrint("[Inventory] Взято: " .. self:GetName())
            self:Remove()
        else
            activator:ChatPrint("[Inventory] Нет места в инвентаре.")
        end
    end

end

if CLIENT then
    function ENT:Draw() self:DrawModel() end
end