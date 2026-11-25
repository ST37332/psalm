AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Psalm Container"
ENT.Category  = "Psalm"
ENT.Spawnable = false
ENT.AdminOnly = true

-- SHARED
function ENT:GetContainerID()  return self:GetNWString("ContainerID", "") end
function ENT:GetContainerDef()
    local id = self:GetContainerID()
    if id == "" then return nil end
    return Psalm.Containers[id]
end
function ENT:GetLootMode()     return self:GetNWBool("LootMode", false)   end
function ENT:GetMaxWeight()    return self:GetNWFloat("MaxWeight", 100)   end
function ENT:GetHasPassword()  return self:GetNWBool("HasPassword", false) end

function ENT:GetGridSize()
    local def = self:GetContainerDef()
    if def then return def.gridW or 5, def.gridH or 4 end
    return 5, 4
end

if SERVER then

    function ENT:Initialize()
        self:SetModel("models/props_c17/FurnitureDrawer001a.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        self.ContainerItems = self.ContainerItems or {}
        self.Password       = self.Password or ""

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end

        self.SpawnedOnce = true
        local id = self:GetContainerID()
        if id ~= "" then self:SetContainerID(id) end
    end

    function ENT:SetContainerID(id)
        if not id or id == "" then return end
        self:SetNWString("ContainerID", id)

        local def = Psalm.Containers[id]
        if not def then return end

        self:SetNWBool("LootMode",  def.loot or false)
        self:SetNWFloat("MaxWeight", def.weight or def.maxWeight or 100)

        if def.model and self:GetModel() ~= def.model then
            self:SetModel(def.model)
            if self.SpawnedOnce then
                self:PhysicsInit(SOLID_VPHYSICS)
                local phys = self:GetPhysicsObject()
                if IsValid(phys) then phys:Wake() end
            end
        end

        -- Первичное наполнение лутом
        if def.loot and def.loot_list and not self.LootPopulated then
            self.LootPopulated = true
            for _, itemID in ipairs(def.loot_list) do
                self:TryAddItem(itemID)
            end
            timer.Simple(0, function()
                if IsValid(self) then Psalm.Inv.BroadcastContainerSync(self) end
            end)
        end
    end

    function ENT:SetPassword(pass)
        self.Password = pass or ""
        self:SetNWBool("HasPassword", self.Password ~= "")
    end
    function ENT:GetPassword() return self.Password or "" end

    ------------------------------------------------------------
    -- Items
    ------------------------------------------------------------

    function ENT:GetCurrentWeight()
        local t = 0
        for _, item in ipairs(self.ContainerItems or {}) do
            local def = Psalm.Items[item.id]
            if def then t = t + (def.weight or 0) end
        end
        return t
    end

    function ENT:CanHoldItem(def)
        if not def then return false end
        return (self:GetCurrentWeight() + (def.weight or 0)) <= self:GetMaxWeight()
    end

    function ENT:AddItem(itemData)
        if not itemData or not itemData.id then return false end
        self.ContainerItems = self.ContainerItems or {}
        table.insert(self.ContainerItems, itemData)
        return true
    end

    function ENT:RemoveItem(index)
        if not self.ContainerItems or not self.ContainerItems[index] then return nil end
        return table.remove(self.ContainerItems, index)
    end

    -- Попытаться добавить предмет в первое свободное место
    function ENT:TryAddItem(itemID)
        local itemDef = Psalm.Items[itemID]
        if not itemDef then return false end

        self.ContainerItems = self.ContainerItems or {}
        local gw, gh = self:GetGridSize()
        local w, h   = itemDef.gridW or 1, itemDef.gridH or 1
        local fx, fy = Psalm.Inv.FindFreeSlot(self.ContainerItems, w, h, gw, gh)
        if not fx then return false end

        table.insert(self.ContainerItems, { id = itemID, x = fx, y = fy })
        return true
    end

    ------------------------------------------------------------
    -- Interaction
    ------------------------------------------------------------

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        Psalm.Inv.OpenContainer(activator, self)
    end

    function ENT:OnRemove()
        for _, p in ipairs(player.GetAll()) do
            if p.ContainerAccess and p.ContainerAccess[self] then
                p.ContainerAccess[self] = nil
            end
        end
    end

end

if CLIENT then
    function ENT:Draw() self:DrawModel() end
end