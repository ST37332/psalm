--[[---------------------------------------------------------
    Psalm.Inv — Shared (Full Version with Net Receivers)
---------------------------------------------------------]]

Psalm         = Psalm or {}
Psalm.Inv     = Psalm.Inv or {}
Psalm.Items   = Psalm.Items or {}
Psalm.Containers = Psalm.Containers or {}
Psalm.Gui     = Psalm.Gui or {}

local INV = Psalm.Inv

----------------------------------------------------------------
-- SHARED CONFIG / HELPERS
----------------------------------------------------------------
INV.CONTAINER_DIST  = 150
INV.CONTAINER_DIST_SQR = INV.CONTAINER_DIST * INV.CONTAINER_DIST

function INV.GetItemDef(id)      return Psalm.Items[id]      end
function INV.GetContainerDef(id) return Psalm.Containers[id] end

function INV.GetItemType(item)
    local def = Psalm.Items[item.id]
    if not def then return "consumable" end
    if def.itemType then return def.itemType end
    if item.id and item.id:sub(1, 7) == "weapon_" then return "permanent" end
    return "consumable"
end

function INV.GetInventoryWeight(inv)
    local t = 0
    for _, item in ipairs(inv or {}) do
        local def = Psalm.Items[item.id]
        if def then t = t + (def.weight or 0) end
    end
    return t
end

function INV.RegisterItem(id, data)
    if type(id) ~= "string" or type(data) ~= "table" then return end
    Psalm.Items[id] = data
end

function INV.RegisterContainer(id, data)
    if type(id) ~= "string" or type(data) ~= "table" then return end
    Psalm.Containers[id] = data
end

function INV.BroadcastContainerSync(ent)
    if not IsValid(ent) then return end
    local pos = ent:GetPos()
    local range = (INV.CONTAINER_DIST * 3) ^ 2
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:GetPos():DistToSqr(pos) < range then
            net.Start("container_sync")
                net.WriteEntity(ent)
                net.WriteFloat(ent:GetCurrentWeight())
                net.WriteTable(ent.ContainerItems or {})
            net.Send(p)
        end
    end
end

----------------------------------------------------------------
-- SERVER
----------------------------------------------------------------
if SERVER then
    AddCSLuaFile()

    local NET_STRINGS = {
        "inventory_sync", "inventory_use", "inventory_use_result",
        "inventory_drop", "inventory_drop_result",
        "inventory_move",
        "inventory_spawn_item", "inventory_spawn_container",
        "container_open", "container_sync",
        "container_move_to_inv", "container_move_to_cont",
        "container_admin_setpass"
    }
    for _, n in ipairs(NET_STRINGS) do util.AddNetworkString(n) end

    local function Notify(ply, msg)
        if IsValid(ply) then ply:ChatPrint("[Inventory] " .. tostring(msg)) end
    end

    function INV.InitPlayer(ply)
        if not IsValid(ply) then return end
        ply.Inventory       = ply.Inventory or {}
        ply.ContainerAccess = ply.ContainerAccess or {}
    end

    function INV.SyncInventory(ply)
        if not IsValid(ply) then return end
        net.Start("inventory_sync")
            net.WriteTable(ply.Inventory or {})
        net.Send(ply)
    end

    function INV.AddItem(ply, itemOrID)
        if not IsValid(ply) then return false end
        local itemID = type(itemOrID) == "string" and itemOrID or (IsValid(itemOrID) and itemOrID:GetItemID())
        if not itemID or itemID == "" or not Psalm.Items[itemID] then return false end

        local inv = ply.Inventory
        if not inv then INV.InitPlayer(ply); inv = ply.Inventory end

        table.insert(inv, { id = itemID })
        INV.SyncInventory(ply)
        return true
    end

    function INV.RemoveItem(ply, index)
        if not IsValid(ply) then return nil end
        local inv = ply.Inventory
        if not inv or not inv[index] then return nil end
        local data = table.remove(inv, index)
        INV.SyncInventory(ply)
        return data
    end

    function INV.HasItem(ply, itemID)
        for _, item in ipairs(ply.Inventory or {}) do
            if item.id == itemID then return true end
        end
        return false
    end

    function INV.EquipItem(ply, item)
        if not IsValid(ply) or not item or item.used then return false end
        local def = Psalm.Items[item.id]
        if not def then return false end
        if def.CanUse and not def.CanUse(ply) then
            if def.CanUseSay then Notify(ply, def.CanUseSay) end
            return false
        end
        if def.EquipFunction then
            def.EquipFunction(ply, item)
        elseif def.UseFunction then
            def.UseFunction(ply, item)
        elseif item.id:sub(1, 7) == "weapon_" then
            ply:Give(item.id)
        end
        item.used = true
        INV.SyncInventory(ply)
        return true
    end

    function INV.UnequipItem(ply, item)
        if not IsValid(ply) or not item or not item.used then return end
        local def = Psalm.Items[item.id]
        if def and def.UnequipFunction then
            def.UnequipFunction(ply, item)
        elseif item.id and item.id:sub(1, 7) == "weapon_" then
            if ply:HasWeapon(item.id) then ply:StripWeapon(item.id) end
        end
        item.used = false
        INV.SyncInventory(ply)
    end

    function INV.SpawnItem(pos, itemID)
        if not Psalm.Items[itemID] then return end
        local e = ents.Create("ps_item")
        if not IsValid(e) then return end
        e:SetPos(pos)
        e:SetItemID(itemID)
        e:Spawn()
        e:Activate()
        return e
    end

    function INV.SpawnContainer(pos, contID)
        if not Psalm.Containers[contID] then return end
        local e = ents.Create("ps_container")
        if not IsValid(e) then return end
        e:SetPos(pos)
        e:SetContainerID(contID)
        e:Spawn()
        e:Activate()
        return e
    end

    hook.Add("PlayerInitialSpawn", "Psalm.Inv_Init", function(ply)
        INV.InitPlayer(ply)
        timer.Simple(0, function() if IsValid(ply) then INV.SyncInventory(ply) end end)
    end)

    hook.Add("PlayerSpawn", "Psalm.Inv_ResetEquipped", function(ply)
        for _, item in ipairs(ply.Inventory or {}) do
            if item.used then INV.UnequipItem(ply, item) end
        end
        INV.SyncInventory(ply)
    end)

    concommand.Add("inventory_spawn", function(ply, _, args)
        local pos = IsValid(ply) and (ply:GetEyeTrace().HitPos + ply:GetEyeTrace().HitNormal * 10) or Vector(0,0,0)
        INV.SpawnItem(pos, args[1] or "item_healthkit")
    end)

    -- NETWORK RECEIVERS (SERVER)
    net.Receive("inventory_use", function(_, ply)
        if not IsValid(ply) then return end
        local idx = net.ReadUInt(16)
        local inv = ply.Inventory
        if not inv or not inv[idx] then return end
        local item = inv[idx]
        local def  = Psalm.Items[item.id]
        if not def then return end

        if def.CanUse and not def.CanUse(ply) then
            if def.CanUseSay then Notify(ply, def.CanUseSay) end
            return
        end

        if def.UseFunction then def.UseFunction(ply) end
        if INV.GetItemType(item) ~= "permanent" then
            table.remove(inv, idx)
        end
        INV.SyncInventory(ply)
        net.Start("inventory_use_result"); net.WriteBool(true); net.Send(ply)
    end)

    net.Receive("inventory_drop", function(_, ply)
        if not IsValid(ply) then return end
        local idx = net.ReadUInt(16)
        local inv = ply.Inventory
        if not inv or not inv[idx] then return end

        local item = inv[idx]
        local def = Psalm.Items[item.id]
        if def then
            local tr = ply:GetEyeTrace()
            INV.SpawnItem(tr.HitPos + tr.HitNormal * 10, item.id)
        end

        table.remove(inv, idx)
        INV.SyncInventory(ply)
        net.Start("inventory_drop_result"); net.WriteBool(true); net.Send(ply)
    end)

    net.Receive("container_open", function(_, ply)
        local ent  = net.ReadEntity()
        local pass = net.ReadString()
        if not IsValid(ent) then return end
        if ply:GetPos():DistToSqr(ent:GetPos()) > INV.CONTAINER_DIST_SQR then return end

        local def = Psalm.Containers[ent:GetContainerID()]
        if not def then return end

        if ent:GetPassword() == pass then
            ply.ContainerAccess = ply.ContainerAccess or {}
            ply.ContainerAccess[ent] = true
            net.Start("container_open")
                net.WriteEntity(ent)
                net.WriteBool(false)
                net.WriteString(def.name or "Container")
                net.WriteBool(def.loot or false)
                net.WriteFloat(ent:GetCurrentWeight())
                net.WriteFloat(ent:GetMaxWeight())
                net.WriteTable(ent.ContainerItems or {})
            net.Send(ply)
        else
            net.Start("container_open")
                net.WriteEntity(ent)
                net.WriteBool(true)
                net.WriteString(def.name or "Container")
                net.WriteString("Неверный пароль")
            net.Send(ply)
        end
    end)

    net.Receive("container_move_to_inv", function(_, ply)
        if not IsValid(ply) then return end
        local ent = net.ReadEntity()
        local idx = net.ReadUInt(16)
        if not IsValid(ent) then return end
        if ply:GetPos():DistToSqr(ent:GetPos()) > INV.CONTAINER_DIST_SQR then return end

        local inv = ply.Inventory
        if not inv then INV.InitPlayer(ply); inv = ply.Inventory end

        local itemData = ent:RemoveItem(idx)
        if not itemData then return end
        table.insert(inv, itemData)
        INV.SyncInventory(ply)
        INV.BroadcastContainerSync(ent)
    end)

----------------------------------------------------------------
-- CLIENT
----------------------------------------------------------------
elseif CLIENT then

    --[[ FONTS ]]--
    surface.CreateFont("ix3D2DCMBFontItems", {
        font = "Consolas",
        size = 25,
        extended = true,
        weight = 5,
        blursize = 1,
        scanlines = 2,
        antialias = true,
    })

    --[[ HELPER: Calculate Weight ]]--
    function INV.GetInventoryWeight(inv)
        local t = 0
        for _, item in ipairs(inv or {}) do
            local def = Psalm.Items[item.id]
            if def then t = t + (def.weight or 0) end
        end
        return t
    end

    --[[ TOOLTIP (ixARKTooltip) ]]--
    local PANEL = {}
    function PANEL:Init()
        self:SetSize(448, 232)
        self:MakePopup()
        self:SetMouseInputEnabled(false)
        self:SetKeyboardInputEnabled(false)
        self.populated = false
    end

    function PANEL:SetItem(item)
        self.item = item
        self.populated = false
    end

    function PANEL:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 35, 240))
        surface.SetDrawColor(255, 255, 255)
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    function PANEL:Think()
        if not self.item or self.populated then return end
        self.populated = true

        if not IsValid(self.Name) then
            self.Name = self:Add("DLabel")
            self.Name:SetFont("ix3D2DCMBFont")
            self.Name:SetTextColor(color_white)
            self.Name:SetPos(16, 16)
            self.Name:SetText(self.item:GetName())
            self.Name:SizeToContents()
        end

        if not IsValid(self.Model) then
            self.Model = self:Add("DModelPanel")
            self.Model:SetPos(224, 16)
            self.Model:SetSize(200, 175)
            self.Model:SetModel(self.item:GetModel() or "models/error.mdl")
            self.Model:SetFOV(30)
        end

        if not IsValid(self.Desc) then
            self.Desc = self:Add("DLabel")
            self.Desc:SetFont("ix3D2DCMBFont")
            self.Desc:SetTextColor(Color(200, 200, 200))
            self.Desc:SetPos(16, 40)
            self.Desc:SetSize(416, 150)
            self.Desc:SetWrap(true)
            self.Desc:SetText(self.item:GetDescription() or "")
        end
    end
    vgui.Register("ixARKTooltip", PANEL, "DPanel")

    --[[ ITEM ICON (ixItemIcon) ]]--
    local PANEL = {}
    function PANEL:Init()
        self:Droppable("PsalmItem")
    end

    function PANEL:Paint(w, h)
        surface.SetDrawColor(0, 0, 0, 85)
        surface.DrawRect(2, 2, w - 4, h - 4)
        if self.itemTable and self.itemTable.PaintOver then
            self.itemTable:PaintOver(self, self.itemTable, w, h)
        end
    end

    function PANEL:DoRightClick()
        if not self.itemTable then return end
        local menu = DermaMenu()
        local invID = self.inventoryID or 0

        for k, v in SortedPairs(self.itemTable.functions or {}) do
            if v.OnCanRun and v.OnCanRun(self.itemTable) == false then continue end
            menu:AddOption(v.name or k, function()
                self.itemTable.player = LocalPlayer()
                local send = true
                if v.OnClick then send = v.OnClick(self.itemTable) end
                if v.sound then surface.PlaySound(v.sound) end
                if send ~= false then
                    net.Start("inventory_use")
                        net.WriteUInt(self.itemTable.id, 32)
                        net.WriteUInt(invID, 32)
                    net.SendToServer()
                end
                self.itemTable.player = nil
            end):SetImage(v.icon or "icon16/brick.png")
        end

        local info = self.itemTable.functions and self.itemTable.functions.drop
        if info and not self.itemTable.cantDrop then
            menu:AddOption(info.name or "drop", function()
                net.Start("inventory_drop")
                    net.WriteUInt(self.itemTable.id, 32)
                net.SendToServer()
            end):SetImage(info.icon or "icon16/bin.png")
        end

        menu:Open()
    end

    vgui.Register("ixItemIcon", PANEL, "SpawnIcon")

    --[[ INVENTORY LIST (ixInventoryList) - FIXED LIST VERSION ]]--
    local PANEL = {}
    function PANEL:Init()
        self:SetPadding(4)
        self:Dock(FILL)
        self.iPanels = {}
        self.iGuard = {}
        self.iNames = {}
        self.icons = {}
        self.HoveredItem = nil
        self:BuildList()
    end

    function PANEL:SetInventory(inventory)
        self.inv = inventory
        self:BuildList()
    end

    function PANEL:BuildList()
        if not IsValid(self) then return end

        -- Очистка
        for i, panel in pairs(self.iPanels) do
            if IsValid(panel) then panel:Remove() end
        end
        for i, panel in pairs(self.iGuard) do
            if IsValid(panel) then panel:Remove() end
        end
        self.iPanels, self.iGuard, self.iNames, self.icons = {}, {}, {}, {}
        self.HoveredItem = nil

        if not self.inv then return end

        -- Собираем категории
        local items = self.inv
        local amountofItems, lastItem, lasti = 1, nil, 1
        self.categories = {}

        for key, item in SortedPairsByMemberValue(items, "name") do
            if not item.category then continue end
            if item:GetData("equip") then continue end

            if not self.categories[item.category] then
                self.categories[item.category] = true
            end
        end

        local cats = vgui.Create("DCategoryList", self)
        cats:Dock(FILL)

        -- Создаем категории
        for catName, _ in SortedPairs(self.categories) do
            local cat = cats:Add("")
            cat:SetPaintBackground(false)
            cat:SetHeaderHeight(cat:GetTall() + 20)
            
            cat.Paint = function(p, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 60))
                surface.SetDrawColor(255, 255, 255, 40)
                surface.DrawOutlinedRect(0, 0, w, h)
                draw.SimpleTextOutlined(string.utf8upper(catName), "ix3D2DCMBFontKindofLarge", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))
            end

            -- Контейнер для предметов внутри категории
            local container = vgui.Create("DPanel", cat)
            container:Dock(TOP)
            container:SetPaintBackground(false)
            container:DockPadding(0, 2, 0, 2)

            -- Список предметов
            for key, item in SortedPairsByMemberValue(items, "name") do
                if item.category ~= catName then continue end
                if item:GetData("equip") then continue end

                if item:GetName() == lastItem then
                    amountofItems = amountofItems + 1
                    self.iNames[lasti].aText = item:GetName().." ["..amountofItems.."]"
                    continue
                else
                    amountofItems = 1
                end

                local panel = vgui.Create("DPanel", container)
                panel:Dock(TOP)
                panel:DockMargin(0, 0, 0, 2)
                panel:SetTall(64)
                panel.Paint = function(p, w, h)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.DrawOutlinedRect(0, 0, w, h)
                    if p:IsHovered() then
                        surface.SetDrawColor(60, 60, 70, 100)
                        surface.DrawRect(0, 0, w, h)
                    end
                end

                -- Иконка
                local icon = panel:Add("SpawnIcon")
                icon:SetPos(2, 2)
                icon:SetSize(60, 60)
                icon:SetModel(item:GetModel() or "models/props_junk/popcan01a.mdl")
                icon:SetSkin(item:GetSkin() or 0)
                icon.itemTable = item
                icon.inventoryID = self.invID
                icon.DoClick = function() 
                    surface.PlaySound("gui/menu/ui_button_pressed.ogg")
                    local menu = DermaMenu()
                    local invID = self.invID or 0
                    for k, v in SortedPairs(item.functions or {}) do
                        if v.OnCanRun and v.OnCanRun(item) == false then continue end
                        menu:AddOption(v.name or k, function()
                            item.player = LocalPlayer()
                            local send = true
                            if v.OnClick then send = v.OnClick(item) end
                            if v.sound then surface.PlaySound(v.sound) end
                            if send ~= false then
                                net.Start("inventory_use")
                                    net.WriteUInt(item.id, 32)
                                    net.WriteUInt(invID, 32)
                                net.SendToServer()
                            end
                            item.player = nil
                        end):SetImage(v.icon or "icon16/brick.png")
                    end
                    local info = item.functions and item.functions.drop
                    if info and not item.cantDrop then
                        menu:AddOption(info.name or "drop", function()
                            net.Start("inventory_drop")
                                net.WriteUInt(item.id, 32)
                            net.SendToServer()
                        end):SetImage(info.icon or "icon16/bin.png")
                    end
                    menu:Open()
                end

                -- Тултип
                panel.OnCursorEntered = function()
                    if not self.tooltip then
                        self.tooltip = vgui.Create("ixARKTooltip")
                        self.tooltip:SetItem(item)
                    end
                end
                panel.OnCursorExited = function()
                    if IsValid(self.tooltip) then self.tooltip:Remove(); self.tooltip = nil end
                end

                -- Название
                local nameBtn = panel:Add("DButton")
                nameBtn:SetText("")
                nameBtn:Dock(FILL)
                nameBtn:DockMargin(65, 0, 0, 0)
                nameBtn.aText = item:GetName()
                nameBtn.Paint = function(p, w, h)
                    draw.SimpleTextOutlined(p.aText, "ix3D2DCMBFontItems", 10, h/2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))
                end
                nameBtn.DoClick = icon.DoClick

                table.insert(self.iPanels, panel)
                lastItem = item:GetName()
                lasti = key
            end

            local guard = vgui.Create("DPanel", cat)
            guard:Dock(TOP)
            guard:SetTall(5)
            guard.Paint = function() end
            table.insert(self.iGuard, guard)
        end

        if table.Count(items) > 0 and not self.categories["Разное"] then
            local hasMisc = false
            for _, item in pairs(items) do if not item.category then hasMisc = true; break end end
            if hasMisc then
                local cat = cats:Add("")
                cat:SetPaintBackground(false)
                cat:SetHeaderHeight(cat:GetTall() + 20)
                cat.Paint = function(p, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 60))
                    surface.SetDrawColor(255, 255, 255, 40)
                    surface.DrawOutlinedRect(0, 0, w, h)
                    draw.SimpleTextOutlined("ПРОЧЕЕ", "ix3D2DCMBFontKindofLarge", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))
                end
            end
        end
    end
    vgui.Register("ixInventoryList", PANEL, "DScrollPanel")

    --[[ MAIN MENU ]]--
    INV.Panel = nil
    function INV.OpenMenu()
        if IsValid(INV.Panel) then INV.Panel:Remove(); INV.Panel = nil; return end

        local frame = vgui.Create("DFrame")
        frame:SetSize(900, 600)
        frame:Center()
        frame:SetTitle("")
        frame:MakePopup()
        frame:SetDraggable(true)

        local list = vgui.Create("ixInventoryList", frame)
        list:Dock(LEFT)
        list:SetWide(400)
        list:SetInventory(LocalPlayer().Inventory)

        local right = vgui.Create("DPanel", frame)
        right:Dock(FILL)
        right.Paint = function(s,w,h) draw.RoundedBox(4, 0, 0, w, h, Color(35, 35, 40)) end

        local model = vgui.Create("DModelPanel", right)
        model:Dock(FILL)
        model:SetModel(LocalPlayer():GetModel())

        local weight = vgui.Create("DPanel", right)
        weight:Dock(BOTTOM)
        weight:SetTall(30)
        weight.Paint = function(s, w, h)
            local wgt = INV.GetInventoryWeight(LocalPlayer().Inventory)
            draw.SimpleText("Вес: " .. wgt .. " кг", "DermaDefault", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        INV.Panel = frame
    end

    concommand.Add("inventory_open", INV.OpenMenu)
    hook.Add("ScoreboardShow", "Psalm.Inv.Scoreboard", function() INV.OpenMenu(); return false end)
    hook.Add("ScoreboardHide", "Psalm.Inv.Scoreboard", function() if IsValid(INV.Panel) then INV.Panel:Remove() end; return false end)

    --[[ SPAWNMENU ]]--
    spawnmenu.AddCreationTab("Предметы C44", function()
        local CPanel = vgui.Create("DPanel")
        CPanel.Paint = function() end
        
        local Sheet = vgui.Create("DPropertySheet", CPanel)
        Sheet:Dock(FILL)

        local groups = {}
        for k, itemDef in pairs(Psalm.Items) do
            if isstring(k) and istable(itemDef) and itemDef.category then
                groups[itemDef.category] = groups[itemDef.category] or {}
                table.insert(groups[itemDef.category], k)
            end
        end

        for catName, itemList in SortedPairs(groups) do
            local List = vgui.Create("DScrollPanel")
            local Grid = vgui.Create("DIconLayout", List)
            Grid:Dock(FILL)
            Grid:SetSpaceX(5)
            Grid:SetSpaceY(5)
            Grid:SetBorder(5)

            for _, itemID in ipairs(itemList) do
                local def = Psalm.Items[itemID]
                if def and not def.nospawn then
                    local btn = vgui.Create("DButton", Grid)
                    btn:SetSize(84, 94)
                    btn.DoClick = function()
                        net.Start("inventory_spawn_item")
                        net.WriteString(itemID)
                        net.SendToServer()
                    end
                    btn.Paint = function(s, w, h)
                        draw.RoundedBox(6, 4, 4, w - 8, h - 8, Color(0, 0, 0, 100))
                        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(80, 80, 80, 240) or Color(50, 50, 50, 220))
                        surface.SetDrawColor(255, 255, 255, 30)
                        surface.DrawOutlinedRect(0, 0, w, h)
                        if def.image then
                            surface.SetDrawColor(255, 255, 255, 255)
                            surface.SetMaterial(def.image)
                            local iconSize = math.min(w, h) * 0.6
                            surface.DrawTexturedRect((w - iconSize) / 2, (h - iconSize) / 2 - 10, iconSize, iconSize)
                        end
                        draw.SimpleText(def.name or "Unknown", "ix3D2DCMBFontItems", w / 2, h - 20, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            end
            Sheet:AddSheet(catName, List, "icon16/package.png")
        end
        return CPanel
    end, "icon16/package.png", 200)

end