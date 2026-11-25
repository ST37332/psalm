
local INVENTORY_UI = {}

local BACKPACK_ENUM = 10
local SLOTS_ON_ROW = 5

local activeSection

local textHasFocus = false

local logo = GM.Logo
local dg = surface.GetTextureID( "vgui/gradient-l" )
local dg2 = surface.GetTextureID( "vgui/gradient-r" )
local dg3 = surface.GetTextureID( "vgui/gradient-u" )
local dg4 = surface.GetTextureID( "vgui/gradient-d" )

local ANIM_TIME = 0.5
local INVENTORY_FADE_TIME = ANIM_TIME

MAX_VEHICLE_SPEED_INVENTORY = 10000

local eItemDeployEnt
local function AttemptDeploy( tItemTable, slot )
	eItemDeployEnt = ClientsideModel( tItemTable.Model )
	eItemDeployEnt.slot = slot
	eItemDeployEnt.spawnOffset = tItemTable.DeployOffset
    eItemDeployEnt.blockIndoors = tItemTable.BlockIndoors

	AddNotification( L"inventory.deploy_instructions", 5, 3 )

	Monolith.Inventory:CloseMenu()
end

hook.Add( "PostDrawTranslucentRenderables", "Monolith.Inventory.eItemDeployEnt", function()
    if not IsValid( eItemDeployEnt ) then return end
    eItemDeployEnt:DrawWireFrame( function( eEnt, bHasCancelled )
        if bHasCancelled then
            Monolith.Inventory:ShowMenu()
            return
        end

        net.Start( "Monolith.Inventory.DeployItem" )
            net.WriteUInt( eEnt.slot, 8 )
            net.WriteVector( eEnt:GetPos() )
            net.WriteAngle( eEnt:GetAngles() )
        net.SendToServer()
    end, eItemDeployEnt.blockIndoors )
end )


local INSPECT = {}

function INSPECT:Init()
    self:Dock( FILL )
end

function INSPECT:AddAction( sText, fCallback, bNoRemove )
    local bButton = self.actionsLayout:Add( "psButton" )
    bButton:Dock( TOP )
    bButton:SetText( sText )
    bButton:SetTall( 30 )

    -- Set tool tip
    bButton:SetTooltip( sText )

    bButton.DoClick = function( this )
        Monolith.Inventory:ClearStatPreview()

        if fCallback then fCallback( this, self ) end

        if not bNoRemove then
            self:Remove()
        end
    end

    return bButton
end

function INSPECT:SetItem( iSlot, tItemData, tSlotData )
    self.slot = iSlot
    self.itemData = tItemData
    self.slotData = tSlotData

    self.titleContainer = self:Add( "EditablePanel" )
    self.titleContainer:Dock( TOP )
    self.titleContainer:DockMargin( 0, 61, 0, 0 )
    self.titleContainer:SetTall( 110 )
    self.titleContainer:InvalidateParent( true )

    self.icon = self.titleContainer:Add( "Panel" )
    self.icon:Dock( RIGHT )
    self.icon:DockMargin( 8, 8, 8, 8 )
    self.icon:SetModel( tItemData.Model )
    self.icon:SetWide( 100 - 8  )
    self.icon:InvalidateParent( true )

    self.icon.LayoutEntity = function( )
        if tItemData.Preview then
            tItemData:Preview( self.icon:GetEntity( ) )
        end
    end

    Monolith.Inventory:SetItemIcon( self.icon, {
        enum = 10,
        slot = iSlot,
        itemData = tItemData,
        slotData = tSlotData,
        doClick = nil
    })

    local bIsRepairable = Monolith.Durability and Monolith.Durability.IsRepairableItem and Monolith.Durability:IsRepairableItem( tItemData ) or ( tSlotData.extra and tSlotData.extra.durability )
    local nDurability = bIsRepairable and ( tSlotData.extra and tSlotData.extra.durability or Monolith.Durability and Monolith.Durability.MAX_DURABILITY or 100 ) or nil
    local sName = nDurability and ( tItemData:GetName() .. " (" .. nDurability .. "%)" ) or tItemData:GetName()

    self.header = self.titleContainer:Add( "EditablePanel" )
    self.header:Dock( TOP )
    self.header:SetTall( 60 )
    self.header:DockMargin( 0, 0, 0, 0 )

    if nDurability and nDurability <= 0 then
        self.durability = self.header:Add( "DImage" )
        self.durability:Dock( RIGHT )
        self.durability:DockMargin( 0, 8, 0, 0 )
        self.durability:SetWide( 32 )
        self.durability:SetImage( "mrp/radar/blip_fire.png" )
        self.durability:SetAlpha( 150 )
        self.durability:SetImageColor( Monolith.UI.Color( "Red" ):SetAlpha( 150 ) )
    end

    self.title = self.header:Add( "psHeader" )
    self.title:SetText( sName:utf8upper() )
    self.title:SetFont( Monolith.Fonts.DIN_Pro_40_BOLD )
    self.title:Dock( FILL )
    self.title:SetContentAlignment( 4 )
    self.title:SizeToContents()
    self.title:DockMargin( 0, -12, 0, 0 )
    self.title:InvalidateParent( true )
    self.title:SetColor( tItemData.Variant and tItemData.Variant.Color or Color( 255, 255, 255, 150 ) )

    self.desc = self.titleContainer:Add( "DLabel" )
    self.desc:Dock( FILL )
    self.desc:SetContentAlignment( 7 )
    self.desc:SetFont( Monolith.Fonts.DIN_Pro_23 )
    self.desc:SetText( tItemData:GetDescription() )
    self.desc:DockMargin( 0, -16, 0, 0 )
    self.desc:InvalidateParent( true )
    self.desc:SetColor( Color( 255, 255, 255, 150 ) )
    self.desc:SetWrap( true )

    local COLOR_WHITE_25 = Monolith.Color.white:SetAlpha( 25 )

    self.divider = self:Add( "DPanel" )
    self.divider:Dock( TOP )
    self.divider:SetTall( 2 )
    self.divider:DockMargin( 0, 35, 0, 0 )
    self.divider.Paint = function( this, w, h )
        surface.SetDrawColor( COLOR_WHITE_25 )
		surface.DrawRect( 0, 0, w, h )
    end

    self.actionStatsContainer = self:Add( "EditablePanel" )
    self.actionStatsContainer:Dock( FILL )
    self.actionStatsContainer:DockPadding( 0, 4, 0, 0 )

    if not tItemData.noActions then
        self.actions = self.actionStatsContainer:Add( "EditablePanel" )
        self.actions:Dock( RIGHT )
        self.actions:SetWide( 200 )

        self.actionsHeader = self.actions:Add( "psHeader" )
        self.actionsHeader:SetText( L"inventory.actions" )
        self.actionsHeader:SetFont( Monolith.Fonts.DIN_Pro_36_BOLD )
        self.actionsHeader:SetTall( 36 )
        self.actionsHeader:DockMargin( 0, 20, 0, 0 )
        self.actionsHeader:SetContentAlignment( 6 )
        self.actionsHeader:SizeToContents()
        self.actionsHeader:InvalidateParent( true )
        self.actionsHeader:SetColor( Color( 255, 255, 255, 150 ) )

        self.actionsLayout = self.actions:Add( "DIconLayout" )
        self.actionsLayout:Dock( FILL )
        self.actionsLayout:DockMargin( 0, 10, 0, 0 )
        self.actionsLayout:SetContentAlignment( 6 )
    end

    self.stats = self.actionStatsContainer:Add( "EditablePanel" )
    self.stats:Dock( FILL )

    self.statsHeader = self.stats:Add( "psHeader" )
    self.statsHeader:SetText( L"inventory.stats" )
    self.statsHeader:SetFont( Monolith.Fonts.DIN_Pro_36_BOLD )
    self.statsHeader:SetTall( 36 )
    self.statsHeader:DockMargin( 0, 20, 0, 0 )
    self.statsHeader:SetContentAlignment( 4 )
    self.statsHeader:SizeToContents()
    self.statsHeader:InvalidateParent( true )
    self.statsHeader:SetColor( Color( 255, 255, 255, 150 ) )

    self.statsLayout = self.stats:Add( "DIconLayout" )
    self.statsLayout:Dock( FILL )

    local bCanConfiscate = Monolith.Confiscation.CanConfiscate( tItemData )
    if bCanConfiscate then
        local label = self.statsLayout:Add( "DLabel" )
        label:Dock( TOP )
        label:SetText( L"inventory.confiscatable" )
        label:SetColor( Monolith.UI.Color( "Red" ) )
        label:SetFont( Monolith.Fonts.DIN_Pro_24 )
        label:SetContentAlignment( 4 )
        label:SetTall( 26 )
        label:DockMargin( 0, 10, 0, 0 )
    end

    local bDropOnDeath = tItemData.DropOnDeath or bCanConfiscate
    if bDropOnDeath then
        local label = self.statsLayout:Add( "DLabel" )
        label:Dock( TOP )
        label:SetText( L"inventory.drop_on_death" )
        label:SetColor( Monolith.UI.Color( "White" ):SetAlpha( 150 ) )
        label:SetFont( Monolith.Fonts.DIN_Pro_24 )
        label:SetContentAlignment( 4 )
        label:SetTall( 26 )
        label:DockMargin( 0, 10, 0, 0 )
    end

    Monolith.Inventory:BuildStats( tItemData, tSlotData, self.statsLayout )
end

vgui.Register( "psInventoryInspect", INSPECT, "EditablePanel" )

DEFINE_BASECLASS( "psFrame" )

local cvSafetySize = CreateClientConVar( "mrp_inventory_safety_size", "16", true, false, "" )

local cvInventoryWidthOverride = CreateClientConVar( "mrp_inventory_scrw", "0", true, false, "" )
local cvInventoryHeightOverride = CreateClientConVar( "mrp_inventory_scrh", "0", true, false, "" )

function INVENTORY_UI:Init()
    self:MakePopup()
    self:InvalidateParent( true )

    if cvInventoryWidthOverride:GetInt() ~= 0 then
        self:SetSize( cvInventoryWidthOverride:GetInt(), cvInventoryHeightOverride:GetInt() )
        self:Center()
        self:ShowQuit()
    end

    self:ShowCloseButton( false )
    self:SetDraggable( false )
    self:SetTitle( "" )

    -- I use this so I can dock the panel properly without having a nice DFrame top border.
    self.outerPanel = self:Add( "Panel" )
    self.outerPanel:SetSize( self:GetSize() )

    self.panel = self.outerPanel:Add( "Panel" )
    self.panel:Dock( FILL )

    local SAFETY_SIZE = cvSafetySize:GetInt()
    if SAFETY_SIZE < 0 or SAFETY_SIZE > 100 then
        SAFETY_SIZE = 16
    end

    self.SAFETY_SIZE = SAFETY_SIZE

    self.panel:DockMargin( SAFETY_SIZE, SAFETY_SIZE, SAFETY_SIZE, SAFETY_SIZE )
    self.panel:InvalidateParent( true )

    -- Draw notification first, as we're undocking it after
    self.notificationBox = self:Add( "psButton" )
    self.notificationBox:SetSize( self:GetWide() / 2.5, 36 )
    self.notificationBox:SetPos( self:GetWide() / 2 - ( self.notificationBox:GetWide() / 2 ), - self:GetTall() )
    self.notificationBox:SetText( "" )

    self.notificationBox:SetTextColor( color_white )
    self.notificationBox:SetExpensiveShadow( 2, Color( 0, 0, 0, 150 ) )

    self.notificationBox.Paint = function( this, w, h )
        draw.RoundedBoxEx( 16, 0, 0, w, h, this:GetColor(), false, false, true, true )
    end

	hook.Run( "Monolith.Inventory.OnInventoryOpened", self )

    local nOffset = self:GetWide() - self.QuitButton:GetWide()

    if Monolith.Config.GetAssert( "general.affiliate.enabled", false ) then
		self.Referrals = self:Add( "psButton" )
		self.Referrals:SetSize( 96, 32 )
		self.Referrals:SetText( L"referrals.gui.modificationsTitle":utf8upper() )
		self.Referrals:SizeToContentsX( 8 )

        nOffset = nOffset - self.Referrals:GetWide()
		self.Referrals:SetPos( nOffset, 0 )

		self.Referrals.DoClick = function()
            self.sections:OpenSection( self.sections.sections[ L"referrals.gui.modificationsTitle" ] )
		end
    end
end

function INVENTORY_UI:AddNotification( sText, iTime, iType, cColor )
    cColor = cColor or Monolith.UI.Color( "Grey" )

    self.notificationBox:SetText( sText )

    self.notificationBox:SetColor( cColor:SetAlpha( 75 ) )
    self.notificationBox:SetHoveredColor( cColor:SetAlpha( 125 ) )

    local xPos, _ = self.notificationBox:GetPos()

	self.notificationBox.currentY = -64
	self.notificationBox:CreateAnimation( 0.2, {
		index = 1,
		easing = "inSine",
		target = { currentY = 0 },
		Think = function(animation, panel)
			panel:SetPos( xPos, panel.currentY )
		end,
		OnComplete = function(animation, panel)
			timer.Simple( iTime or 5, function()
				if not IsValid( panel ) then return end

				panel.currentY = 0
				panel:CreateAnimation( 1, {
					index = 1,
					easing = "outSine",
					target = { currentY = 64 },
					Think = function(animation, _panel)
						_panel:SetPos( xPos, -_panel.currentY )
					end
				})
			end )
		end
	})
end

function INVENTORY_UI:Fade(bool, callback)
    -- Fade effect
    self:SetAlpha(bool and 0 or 255)
    self:AlphaTo(bool and 255 or 0, INVENTORY_FADE_TIME, 0, callback)

    self.TargetAlpha = bool and 100 or 50

    self.IsFading = true
end

function INVENTORY_UI:AddSection( name, icon, callback, canDo, extraData )
    return self.sections:AddSection( name, icon,
        -- callback
        function( panel )
            activeSection = name
			self:StretchSectionPanel( false )

            callback( panel )


        end,
        -- canDo
        canDo,
        extraData
    )
end

function INVENTORY_UI:CreateStatusEffect( sStatus, cColor, fCallback )
    local container = self.PlayerStatusList:Add( "Panel" )
    container:Dock( BOTTOM )
    container:DockMargin(0, 4, 0, 0)
    container:SetTall( 36 )    

    container.Paint = function(this, w, h)
        local iFraction = math.Clamp( ( fCallback() / 100 ), 0, 1 )
        local sStatusText = Monolith.Stats:GetStatusText( sStatus, fCallback() )

        draw.SimpleText( sStatusText, Monolith.Fonts.DIN_Pro_17, 1, 1, Monolith.Color.black:SetAlpha(125), TEXT_ALIGN_LEFT )
        draw.SimpleText( sStatusText, Monolith.Fonts.DIN_Pro_17, 0, 0, Monolith.Color.white:SetAlpha(125), TEXT_ALIGN_LEFT )

        surface.SetDrawColor(28, 28, 28, 255)
        surface.DrawOutlinedRect(0, 20, w, 8)

        draw.RoundedBox( 3, 0, 20, w, 8, Color(65, 65, 65, 255) )

        local tStatPreview = Monolith.Inventory._StatPreview
        if tStatPreview and tStatPreview[ sStatus ] then

            local iStatAmount = tStatPreview[ sStatus ]
            local nChangeAmount = math.Clamp( ( math.abs( iStatAmount ) / 100), 0, 1) 

            local strobeAlpha = math.abs( math.cos( RealTime() ) * 255 )
            local bIsLoss = iStatAmount < 0 and fCallback() > ( fCallback() + iStatAmount )

            -- Make a more distinct color so people understand.
            local cBrighterColor = Color( math.min( cColor.r + 30, 255 ), math.min( cColor.g + 30, 255), math.min( cColor.b + 30, 255), strobeAlpha )
            local cLossColor = Color( math.min( cColor.r - 30, 255 ), math.min( cColor.g - 30, 255), math.min( cColor.b - 30, 255), strobeAlpha )

            if bIsLoss then
                draw.RoundedBox( 3, 0, 20, w * iFraction, 8, cColor )
                draw.RoundedBox( 3, w * iFraction - w * nChangeAmount, 20, w * nChangeAmount, 8, cLossColor )
            else
                draw.RoundedBox( 3, w * iFraction - 2, 20, w * nChangeAmount, 8, cBrighterColor )
                draw.RoundedBox( 3, 0, 20, w * iFraction, 8, cColor )
            end
        else
            draw.RoundedBox( 3, 0, 20, w * iFraction, 8, cColor )
        end
    end

    return container
end

function INVENTORY_UI:SetInventory( tInventory )
    self.CurrentInventory = tInventory
end

function INVENTORY_UI:GetInventory()
    return self.CurrentInventory or self:getPlayer().Inventory or Monolith.Inventory:New( nil )
end

function INVENTORY_UI:UpdateEquipment()
    if IsValid( self.primaryWeapon ) then self.primaryWeapon:Remove() end
    if IsValid( self.secondaryWeapon ) then self.secondaryWeapon:Remove() end
    if IsValid( self.tertiaryWeapon ) then self.tertiaryWeapon:Remove() end
    if IsValid( self.armor ) then self.armor:Remove() end
    if IsValid( self.equipmentItems ) then self.equipmentItems:Clear() end

    local tPlayerInventory = self:GetInventory()
    local nEquipmentSlotSize = ( self.equipmentItems:GetWide() - ( 4 * ( tPlayerInventory.EQUIPMENT_MISC_SLOTS  ) ) ) / ( tPlayerInventory.EQUIPMENT_MISC_SLOTS  )

    local primarySlotData, primaryItemData = tPlayerInventory:GetPrimaryWep()
    self.primaryWeapon = self:CreateItem( self.characterPanel, Monolith.Inventory.EQUIPMENT_PRIMARY, Monolith.Inventory.EQUIPMENT_PRIMARY, primaryItemData, primarySlotData, function( this )
        self:CreateEquipmentActions( Monolith.Inventory.EQUIPMENT_PRIMARY, primarySlotData, primaryItemData )
    end )

    local iSlotSize = self:GetSlotSize()
    self.SlotSize = iSlotSize
    local iWeaponSlotSize = nEquipmentSlotSize

    local nX, nY = self.equipmentItems:GetPos()

    local nEquipmentPos = nX + iWeaponSlotSize + 6
    local nEquipmentYPos = self:GetTall() - iWeaponSlotSize * 2 - 38

    MONOLITH_SLOT_SIZE = iSlotSize

    self.primaryWeapon:Dock( NODOCK )
    self.primaryWeapon:SetSize( iWeaponSlotSize, iWeaponSlotSize )
    self.primaryWeapon:SetPos( nEquipmentPos, nEquipmentYPos )

    local alphaBg = Color( 0, 0, 0, 125 )

    local rifleMat = Material( "mrp/icons/rifle.png", "smooth" )
    self.primaryWeapon.PostPaint = function( this, w, h )
        if not primaryItemData then
            surface.SetMaterial( rifleMat )
            surface.SetDrawColor( alphaBg )
            surface.DrawTexturedRectRotated( w / 2, h / 2, w * 0.5, h * 0.5, 0 )
        end
    end

    local secondarySlotData, secondaryItemData = tPlayerInventory:GetSecondaryWep()
    self.secondaryWeapon = self:CreateItem( self.characterPanel, Monolith.Inventory.EQUIPMENT_SECONDARY, Monolith.Inventory.EQUIPMENT_SECONDARY, secondaryItemData, secondarySlotData, function( this )
        self:CreateEquipmentActions( Monolith.Inventory.EQUIPMENT_SECONDARY, secondarySlotData, secondaryItemData )
    end )

    self.secondaryWeapon:Dock( NODOCK )
    self.secondaryWeapon:SetSize( iWeaponSlotSize, iWeaponSlotSize )

    local pistolMat = Material( "mrp/icons/pistol.png", "smooth" )
    self.secondaryWeapon.PostPaint = function( this, w, h )
        if not secondaryItemData then
            surface.SetMaterial( pistolMat )
            surface.SetDrawColor( alphaBg )
            surface.DrawTexturedRectRotated( w / 2, h / 2, w * 0.5, h * 0.5, 0 )
        end
    end

    local SPACER = 2

    nEquipmentYPos = nEquipmentYPos - iWeaponSlotSize - SPACER

    self.secondaryWeapon:SetPos( nEquipmentPos, nEquipmentYPos )

    local tertiarySlotData, tertiaryItemData = tPlayerInventory:GetTertiaryWep()
    self.tertiaryWeapon = self:CreateItem( self.characterPanel, Monolith.Inventory.EQUIPMENT_TERTIARY, Monolith.Inventory.EQUIPMENT_TERTIARY, tertiaryItemData, tertiarySlotData, function( this )
        self:CreateEquipmentActions( Monolith.Inventory.EQUIPMENT_TERTIARY, tertiarySlotData, tertiaryItemData )
    end )

    self.tertiaryWeapon:Dock( NODOCK )
    self.tertiaryWeapon:SetSize( iWeaponSlotSize, iWeaponSlotSize )

    nEquipmentYPos = nEquipmentYPos - iWeaponSlotSize - SPACER

    self.tertiaryWeapon:SetPos( nEquipmentPos, nEquipmentYPos )


    local knifeMat = Material( "mrp/icons/knife.png", "smooth" )
    self.tertiaryWeapon.PostPaint = function( this, w, h )
        if not tertiaryItemData then
            surface.SetMaterial( knifeMat )
            surface.SetDrawColor( alphaBg )
            surface.DrawTexturedRectRotated( w / 2, h / 2, w * 0.5, h * 0.5, 0 )
        end
    end

    local armorSlotData, armorItemData = tPlayerInventory:GetArmor()
    self.armor = self:CreateItem( self.characterPanel, Monolith.Inventory.EQUIPMENT_ARMOR, Monolith.Inventory.EQUIPMENT_ARMOR, armorItemData, armorSlotData, function( this )
        self:CreateEquipmentActions( Monolith.Inventory.EQUIPMENT_ARMOR, armorSlotData, armorItemData )
    end )

    self.armor:Dock( NODOCK )
    self.armor:SetSize( iWeaponSlotSize, iWeaponSlotSize )

    nEquipmentYPos = nEquipmentYPos - iWeaponSlotSize - SPACER

    self.armor:SetPos( nEquipmentPos, nEquipmentYPos )

    local armorMat = Material( "mrp/icons/shield.png", "smooth" )
    self.armor.PostPaint = function( this, w, h )
        if not armorItemData then
            surface.SetMaterial( armorMat )
            surface.SetDrawColor( alphaBg )
            surface.DrawTexturedRectRotated( w / 2, h / 2, w * 0.5, h * 0.5, 0 )
        end
    end

	for equipmentId = 1, tPlayerInventory.EQUIPMENT_MISC_SLOTS do
        local equipmentSlotData, equipmentItemData = tPlayerInventory:GetEquipmentItem( equipmentId )
        self:CreateItem( self.equipmentItems, Monolith.Inventory.EQUIPMENT_MISC, equipmentId, equipmentItemData, equipmentSlotData, function( this )
            self:CreateEquipmentActions( equipmentId, equipmentSlotData, equipmentItemData )
        end, nEquipmentSlotSize ) -- 2 means 2 rows
    end
end

-- @TODO: Review this. It's messy. ( Also needs icons at some point )
function INVENTORY_UI:UpdateApparel()
    if IsValid( self.feetApparel ) then self.feetApparel:Remove() end
    if IsValid( self.legsApparel ) then self.legsApparel:Remove() end
    if IsValid( self.handsApparel ) then self.handsApparel:Remove() end
    if IsValid( self.torsoApparel ) then self.torsoApparel:Remove() end
    if IsValid( self.faceApparel ) then self.faceApparel:Remove() end
    if IsValid( self.headApparel ) then self.headApparel:Remove() end

    local tPlayerInventory = self:GetInventory()

    local nApparelSlotSize = ( self.equipmentItems:GetWide() - ( 4 * ( tPlayerInventory.EQUIPMENT_MISC_SLOTS  ) ) ) / ( tPlayerInventory.EQUIPMENT_MISC_SLOTS  )
    local alphaBg = Color( 0, 0, 0, 125 )

    -- Make the feet icon
    local tFeetSlotData, tFeetItemData = tPlayerInventory:GetFootApparel()
    self.feetApparel = self:CreateItem( self.characterPanel, Monolith.Inventory.APPAREL_FEET, Monolith.Inventory.APPAREL_FEET, tFeetItemData, tFeetSlotData, function( this )
        self:CreateApparelActions( Monolith.Inventory.APPAREL_HEAD, tFeetSlotData, tFeetItemData )
    end )

    local iSlotSize = self:GetSlotSize()
    self.SlotSize = iSlotSize

    local iApparelSlotSize = nApparelSlotSize
    local nEquipmentPos = 0
    local nEquipmentYPos = self:GetTall() - ( iApparelSlotSize * 2 ) - 40 - iApparelSlotSize

    self.feetApparel:Dock( NODOCK )
    self.feetApparel:SetSize( iApparelSlotSize, iApparelSlotSize )
    self.feetApparel:SetPos( nEquipmentPos, nEquipmentYPos + iApparelSlotSize )

    local feetMat = Material( "icons/icon_feet.png", "smooth" )
    self.feetApparel.PostPaint = function( this, w, h )
        if not tFeetItemData then
            surface.SetMaterial( feetMat )
            surface.SetDrawColor( alphaBg )
            surface.DrawTexturedRectRotated( w / 2, h / 2, w * 0.5, h * 0.5, 0 )
        end
    end

    -- Make the legs icon
    local tLegsSlotData, tLegsItemData = tPlayerInventory:GetLegApparel()
    self.legsApparel = self:CreateItem( self.characterPanel, Monolith.Inventory.APPAREL_LEGS, Monolith.Inventory.APPAREL_LEGS, tLegsItemData, tLegsSlotData, function( this )
        self:CreateApparelActions( Monolith.Inventory.APPAREL_LEGS, tLegsSlotData, tLegsItemData )
    end )

    self.legsApparel:Dock( NODOCK )
    self.legsApparel:SetSize( iApparelSlotSize, iApparelSlotSize )

    local SPACER = 2
    nEquipmentYPos = nEquipmentYPos - SPACER

    self.legsApparel:SetPos( nEquipmentPos, nEquipmentYPos )

    local legsMat = Material( "icons/icon_leggings.png", "smooth" )
    self.legsApparel.PostPaint = function( this, w, h )
        if not tLegsItemData then
            surface.SetMaterial( legsMat )
            surface.SetDrawColor( alphaBg )
            surface.DrawTexturedRectRotated( w / 2, h / 2, w * 0.5, h * 0.5, 0 )
        end
    end

    -- Make the hands icon
    local tHandsSlotData, tHandsItemData = tPlayerInventory:GetHandApparel()
    self.handsApparel = self:CreateItem( self.characterPanel, Monolith.Inventory.APPAREL_HANDS, Monolith.Inventory.APPAREL_HANDS, tHandsItemData, tHandsSlotData, function( this )
        self:CreateApparelActions( Monolith.Inventory.APPAREL_HANDS, tHandsSlotData, tHandsItemData )
    end )

    self.handsApparel:Dock( NODOCK )
    self.handsApparel:SetSize( iApparelSlotSize, iApparelSlotSize )

    nEquipmentYPos = nEquipmentYPos - iApparelSlotSize - SPACER

    self.handsApparel:SetPos( nEquipmentPos, nEquipmentYPos )

    local handsMat = Material( "icons/icon_hands.png", "smooth" )
    self.handsApparel.PostPaint = function( this, w, h )
        if not tHandsItemData then
            surface.SetMaterial( handsMat )
            surface.SetDrawColor( alphaBg )
            surface.DrawTexturedRectRotated( w / 2, h / 2, w * 0.5, h * 0.5, 0 )
        end
    end

    -- Make the chest icon
    local tTorsoSlotData, tTorsoItemData = tPlayerInventory:GetChestApparel()
    self.torsoApparel = self:CreateItem( self.characterPanel, Monolith.Inventory.APPAREL_TORSO, Monolith.Inventory.APPAREL_TORSO, tTorsoItemData, tTorsoSlotData, function( this )
        self:CreateApparelActions( Monolith.Inventory.APPAREL_TORSO, tTorsoSlotData, tTorsoItemData )
    end )

    self.torsoApparel:Dock( NODOCK )
    self.torsoApparel:SetSize( iApparelSlotSize, iApparelSlotSize )

    nEquipmentYPos = nEquipmentYPos - iApparelSlotSize - SPACER

    self.torsoApparel:SetPos( nEquipmentPos, nEquipmentYPos )

    local torsoMat = Material( "icons/icon_torso.png", "smooth" )
    self.torsoApparel.PostPaint = function( this, w, h )
        if not tTorsoItemData then
            surface.SetMaterial( torsoMat )
            surface.SetDrawColor( alphaBg )
            surface.DrawTexturedRectRotated( w / 2, h / 2, w * 0.5, h * 0.5, 0 )
        end
    end

    -- Make the face icon
    local tFaceSlotData, tFaceItemData = tPlayerInventory:GetFaceApparel()
    self.faceApparel = self:CreateItem( self.characterPanel, Monolith.Inventory.APPAREL_FACE, Monolith.Inventory.APPAREL_FACE, tFaceItemData, tFaceSlotData, function( this )
        self:CreateApparelActions( Monolith.Inventory.APPAREL_FACE, tFaceSlotData, tFaceItemData )
    end )

    self.faceApparel:Dock( NODOCK )
    self.faceApparel:SetSize( iApparelSlotSize, iApparelSlotSize )

    nEquipmentYPos = nEquipmentYPos - iApparelSlotSize - SPACER

    self.faceApparel:SetPos( nEquipmentPos, nEquipmentYPos )

    local faceMat = Material( "icons/icon_head.png", "smooth" )
    self.faceApparel.PostPaint = function( this, w, h )
        if not tFaceItemData then
            surface.SetMaterial( faceMat )
            surface.SetDrawColor( alphaBg )
            surface.DrawTexturedRectRotated( w / 2, h / 2, w * 0.5, h * 0.5, 0 )
        end
    end

    -- Make the head icon
    local tHeadSlotData, tHeadItemData = tPlayerInventory:GetHeadApparel()
    self.headApparel = self:CreateItem( self.characterPanel, Monolith.Inventory.APPAREL_HEAD, Monolith.Inventory.APPAREL_HEAD, tHeadItemData, tHeadSlotData, function( this )
        self:CreateApparelActions( Monolith.Inventory.APPAREL_HEAD, tHeadSlotData, tHeadItemData )
    end )

    self.headApparel:Dock( NODOCK )
    self.headApparel:SetSize( iApparelSlotSize, iApparelSlotSize )

    nEquipmentYPos = nEquipmentYPos - iApparelSlotSize - SPACER

    self.headApparel:SetPos( nEquipmentPos, nEquipmentYPos )

    local headMat = Material( "icons/icon_headgear.png", "smooth" )
    self.headApparel.PostPaint = function( this, w, h )
        if not tHeadItemData then
            surface.SetMaterial( headMat )
            surface.SetDrawColor( alphaBg )
            surface.DrawTexturedRectRotated( w / 2, h / 2, w * 0.5, h * 0.5, 0 )
        end
    end
end

function INVENTORY_UI:SetUtilityContents( panel )
    self.utilitySection.child = nil
    self.utilitySection:Clear()

    if not panel then return end

    panel:SetParent( self.utilitySection )
    self.utilitySection.child = panel

    return panel
end

function INVENTORY_UI:SetupSections()
    if IsValid( self.sections ) then
        self.sections:Remove()
    end

    local tPlayerInventory = self:GetInventory()

	self.sectionsOuter = self.panel:Add( "psPanel" )
	self.sectionsOuter:SetBackground( false )
    self.sectionsOuter:DockMargin( 0, 16, 0, 0 )
    self.sectionsOuter:Dock( RIGHT )
    self.sectionsOuter:SetWide( self:GetWide() / 3 )
    self.sectionsOuter:InvalidateParent( true )

    self.sections = self.sectionsOuter:Add( "psSectionsPanel" )
    self.sections:SetSize( self.sectionsOuter:GetSize() )

    self.sections:Setup()

	local xPos = self:GetWide()
	self.sections.origin = select( 1, self.sections:GetPos() )
    self.sections:SetPos( xPos, 0 )

	self.sections:NoClipping( true )

	self.sections:SetAlpha( 0 )

    self.sections.currentX = xPos
	self.sections.alpha = 0

	self.sections:CreateAnimation( ANIM_TIME, {
		index = 1,
		easing = "inSine",
		target = { alpha = 255 },
		Think = function(animation, panel)
			panel:SetAlpha( panel.alpha )
		end
	})

	self.sections:CreateAnimation( ANIM_TIME, {
		index = 2,
		easing = "inOutSine",
		target = { currentX = self.sections.origin },
		Think = function(animation, panel)
			panel:SetPos( panel.currentX, select( 2, panel:GetPos() ) )
		end,
		OnComplete = function(animation, panel)

		end
	})

    self.inventorySection = self:AddSection( L"inventory.inventory", "icons/inventory/backpack_icon.png",
        -- callback
        function( panel )
            self.items = panel:Add( "psPanel" )
            self.items:SetBackground( false )
            self.items:Dock( FILL )
            self.items:InvalidateParent( true )

            -- Create items for player
            self:ItemSetup()

            -- Load equipment
            self:UpdateEquipment()

            -- Load apparel
            self:UpdateApparel()
        end,
        -- canDo
        function()
            return true
        end,
        {
            subHeader = Monolith.GetPhrase( "inventory.inventory_description", tPlayerInventory and tPlayerInventory.BACKPACK_SLOTS or 0 )
        }
    )

    self.inventorySection:Receiver( "inventory" , function( receiver, tbl, dropped )
        self:SlotReceiver( receiver, tbl, dropped )
    end )

    self.sections:OpenSection( self.sections.sections[ L"inventory.inventory" ] )

    self.notificationBox:MoveToFront()
end

function INVENTORY_UI:DrawPlayerCard()
    local bStreamer = Monolith.ClientSettings:GetValue( "bStreamerMode", false )

    self.playerCard = self.characterPanel:Add( "psPanel" )
    self.playerCard:SetPos( 0, 0 )
    self.playerCard:SetSize( 512, 64 )
    self.playerCard:InvalidateParent( true )

    self.playerCard.Paint = function( this, w, h )
        surface.SetDrawColor( 25, 25, 25, 100 )
        surface.SetTexture( dg )
        surface.DrawTexturedRect( 0, 0, w, h )
    end

    local tFaction = Monolith.Jobs:GetJobCategory( self:getPlayer():GetJobCategory() )

    self.playerAvatar = self.playerCard:Add( "AvatarMask" )
    self.playerAvatar:Dock( LEFT )
    self.playerAvatar:DockMargin( 4, 4, 4, 4 )
    self.playerAvatar:InvalidateParent( true )
    self.playerAvatar:SetWide( 64 )
    self.playerAvatar:SetTall( 64 )

    self.playerAvatar.Paint = function( this, w, h )
        local mAvatar = tFaction.avatar or Material( "icons/unknown_person.png" )

        surface.SetDrawColor( color_white )
        surface.SetMaterial( mAvatar )
        surface.DrawTexturedRect( 0, 0, w, h )
    end

    local sName = self:getPlayer():GetRecognizedName() or self:getPlayer():GetFullName()

    self.playerName = self.playerCard:Add( "psHeader" )
    self.playerName:SetFont( Monolith.Fonts.DIN_Pro_38_BOLD )
    self.playerName:DockMargin( 4, 4, 0, 0 )
    self.playerName:SetText( sName )
    self.playerName:SetColor( GAMEMODE.ThemeColor )
    self.playerName:InvalidateParent( true )
    self.playerName:SetContentAlignment( 4 )
    self.playerName:SetTall( 42 )

	if self:getPlayer() ~= LocalPlayer() then
		self.playerName:SetText( L("inventory.viewer.someonesInventory", self:getPlayer():GetRecogName() ) )
		self.playerName:SizeToContentsX()
	end

    local tJob = self:getPlayer():GetJob()

    local sRank = tJob and tJob.name
    if sRank then
        self.playerRank = self.playerCard:Add( "psHeader" )
        self.playerRank:SetFont( Monolith.Fonts.DIN_Pro_24 )
        self.playerRank:DockMargin( 4, -4, 0, 0 )
        self.playerRank:SetText( sRank )
        self.playerRank:SetColor( tJob.color )
        self.playerRank:InvalidateParent( true )
        self.playerRank:SetContentAlignment( 4 )
        self.playerRank:SetTall( 20 )
    end
end

local CIRCLE_GRADIENT = Material( "mrp/spherical_gradient.png" )
local CHAT_MATERIAL_STRING = "mrp/icons/chat.png"
function INVENTORY_UI:Setup()
    self.IsFading = true
    self:Fade(true, function()
        self.IsFading = false
    end)

    self.startTime = CurTime()

    self:InvalidateParent( true )

	self.characterPanelOuter = self.panel:Add( "psPanel" )
    self.characterPanelOuter:SetBackground( false )
    self.characterPanelOuter:Dock( LEFT )
    self.characterPanelOuter:SetWide( self:GetWide() / 3 )
    self.characterPanelOuter:InvalidateParent( true )

    self.characterPanel = self.characterPanelOuter:Add( "psPanel" )
    self.characterPanel:SetBackground( false )
    self.characterPanel:SetSize( self.characterPanelOuter:GetSize() )

	local xPos = - self.characterPanel:GetWide()
	self.characterPanel.origin = select( 1, self.characterPanel:GetPos() )
    self.characterPanel:SetPos( xPos, 0 )

	self.characterPanel:NoClipping( false )

	self.characterPanel:SetAlpha( 0 )

	self.characterPanel.alpha = 0
	self.characterPanel.currentX = xPos

	self.characterPanel:CreateAnimation( ANIM_TIME, {
		index = 1,
		easing = "inSine",
		target = { alpha = 255 },
		Think = function(animation, panel)
			panel:SetAlpha( panel.alpha )
		end
	})

	self.characterPanel:CreateAnimation( ANIM_TIME, {
		index = 2,
		easing = "inOutSine",
		target = { currentX = self.characterPanel.origin },
		Think = function(animation, panel)
			panel:SetPos( panel.currentX, select( 2, panel:GetPos() ) )
		end,
		OnComplete = function(animation, panel)

		end
	})

    self.equipmentItems = self.characterPanel:Add( "DIconLayout" )
    self.equipmentItems:Dock( BOTTOM )
    self.equipmentItems:DockMargin( 0, 0, 0, 0 )
    self.equipmentItems:SetTall( 80 )
    self.equipmentItems:InvalidateParent( true )
    self.equipmentItems:SetSpaceX( 2 )

    local pPlayer = self:getPlayer()

    local sCharacterName = pPlayer:GetFullName()
    local cWhite = Monolith.UI.Color( "White" ):SetAlpha( 150 )

    self.character = self.characterPanel:Add( "psCharacterModel" )
    self.character:Dock( FILL )
    self.character:DockMargin( 0, 0, 64 + 4, 0 )
    --self.character:SetSize( pPanel:GetWide() * 0.3, self:GetTall() * 1 )
    self.character:SetPlayer( self:getPlayer() )
    self.character:SetFollower( true )

    -- TODO: Define the pos in the job table instead.
    -- Will make it easier in the future and less messy.
    if self.character.Entity:GetModel() == "models/combine_scanner.mdl" or self.character.Entity:GetModel() == "models/shield_scanner.mdl" then
        -- Fix the scanner appearing at the bottom of the Camera.
        self.character.Entity:SetPos( Vector( -20, 0, 57 ) )
    elseif self.character.Entity:GetModel() == "models/player/combine_heavy.mdl" then
        -- Fix the charger being too tall.
        self.character.Entity:SetPos( Vector( -20, 0, -5 ) )
    end

	local nGenderOffset = pPlayer:IsMale() and 56 or 54

    self.character:SetCamPos( Vector( 70, 5, nGenderOffset ) )
    self.character:SetLookAt( Vector( 0, 0, nGenderOffset ) )

    -- Ultrawide
    if self:GetWide() / self:GetTall() > 1.8 then
        self.character:SetFOV( 25 )
    else
        self.character:SetFOV( 18 )
    end

    local col = Monolith.UI.Color( "CombineBlue" )

    self.character:SetAmbientLight( col )
    self.character:SetDirectionalLight( BOX_FRONT, Color( 255, 150, 100 ) )
    self.character:SetAnimated( true )

    self.character:SetDirectionalLight( BOX_TOP, Color( 255, 255, 255) )
    self.character:SetDirectionalLight( BOX_FRONT, Color( 255, 255, 255) )
    self.character:SetDirectionalLight( BOX_RIGHT, Monolith.UI.Color( "White" ) )
    self.character:SetDirectionalLight( BOX_LEFT, Monolith.UI.Color( "CombineBlue" ) )
    self.character:SetDirectionalLight( BOX_BOTTOM, Color( 100, 100, 100 ) )

    self.character.IsCharacterModel = true

    self.character:InvalidateParent( true )

    self.character:Receiver( "inventory", function( receiver, tbl, dropped )
        self:SlotReceiver( receiver, tbl, dropped )
    end )

    local whereToLook = {
        function( ent ) return ent:GetPos() + ent:GetForward() * 100 + ent:GetUp() * 50 + ent:GetRight() * -125 end,
        function( ent ) return ent:GetPos() + ent:GetForward() * 100 + ent:GetUp() * 50 + ent:GetRight() * 125 end,
        function( ent ) return ent:GetPos() + ent:GetForward() * 100 + ent:GetUp() * 50 + ent:GetRight() * 25 end,
    }

    timer.Create("MRP.Intro.LookAtAPlace", 5, 0, function()
        if not IsValid( self.character ) then timer.Remove( "MRP.Intro.LookAtAPlace" ) return end

        self.character.CurrentLookAt = whereToLook[ math.random( 1, #whereToLook ) ]( self.character.Entity )
    end )

    self.character.CurrentLookAt = whereToLook[ 1 ]( self.character.Entity )

    self.character.LayoutEntity = function( this, ent )
        ent:SetSequence( pPlayer:GetJobPreviewAnim() )
    end

    local oldThink = self.character.Think
    self.character.Think = function( this )
        oldThink( this )

        local curEyeTarget = LerpVector( FrameTime() * 10, this.CurEyeTarget or this.CurrentLookAt, this.CurrentLookAt )
        this.Entity:SetEyeTarget( curEyeTarget )
        this.CurEyeTarget = curEyeTarget
    end

    -- Set up inventory section
    self:SetupSections()

    self.utilitySection = self.panel:Add( "psPanel" )
    self.utilitySection:Dock( FILL )
    self.utilitySection:DockMargin( 0, 12, 12, 64 )
    self.utilitySection:SetBackground( false )
    self.utilitySection:Droppable( "inventory" )
    self.utilitySection:InvalidateParent( true )

    self.utilitySection.IsUtilityMenu = true

    self.utilitySection:Receiver( "inventory", function( receiver, tbl, dropped )
        self:SlotReceiver( receiver, tbl, dropped )
    end )

    local nWidth = self.utilitySection:GetWide()
    self.utilitySection:Dock( LEFT )
    self.utilitySection:SetWide( nWidth )

    self.utilityWidth = nWidth

    -- Draw player card
    self:DrawPlayerCard()

    if self:getPlayer() == LocalPlayer() then
        hook.Run( "Monolith.Inventory.AddSection", self )

        local nX, nY = self.equipmentItems:GetPos()

		self:DrawStatus( nX, nY )
    end

    self.QuitButton:MoveToFront()
end

function INVENTORY_UI:StretchSectionPanel( bool )
	self.sectionsOuter:SetWide( bool and self:GetWide() * 0.62 or self:GetWide() / 3 )
    self.sections:Dock( FILL )

    if IsValid( self.utilitySection ) then
        self.utilitySection:SetWide( bool and 1 or self.utilityWidth )
        self.utilitySection:InvalidateParent( true )
        self.utilitySection:InvalidateLayout( true )
    end

    self.sections:InvalidateParent( true )
    self.sections:InvalidateLayout( true )
end

function INVENTORY_UI:DrawStatus(nX, nY)
    local tPlayerInventory = self:GetInventory()
    local nEquipmentSlotSize = ( self.equipmentItems:GetWide() - ( 4 * ( tPlayerInventory.EQUIPMENT_MISC_SLOTS  ) ) ) / ( tPlayerInventory.EQUIPMENT_MISC_SLOTS  )

    self.PlayerStatusList = self.characterPanel:Add( "Panel" )
    self.PlayerStatusList:SetSize( self.equipmentItems:GetWide() * 0.66, 224 )
    self.PlayerStatusList:SetPos( nEquipmentSlotSize * 2.25, nY - self.PlayerStatusList:GetTall() - 12 )

    self:CreateStatusEffect("Energy", Color( 73, 80, 116 ), function()
        return GetStat( "Energy" )
    end )

    self:CreateStatusEffect("Thirst", Color( 81, 106, 125 ), function()
        return GetStat( "Thirst" )
    end )

    self:CreateStatusEffect("Hunger", Color( 128, 113, 84 ), function()
        return GetStat( "Hunger" )
    end)

    self:CreateStatusEffect("Health", Color( 116, 69, 69 ), function()
        return LocalPlayer():Health()
    end )
end

function INVENTORY_UI:CreateActions(slot, itemData, slotData)
    local InteractionMenu = DermaMenu()

    local tPlayerInventory = self:GetInventory()
    local emptySlot = tPlayerInventory:FindFirstEmptySlot()

    if itemData.Category and itemData.Category == Monolith.InventoryItem.ITEM_EQUIPMENT then
        local unEquip = InteractionMenu:AddOption( L("inventory.equip"), function()
            net.Start( "InventoryToEquipment" )
                net.WriteInt( slot, 16 )
                net.WriteInt( emptySlot, 16 )
            net.SendToServer()
        end ):SetIcon( "icon16/bomb.png" )
    end

    if itemData.Category == itemData.ITEM_CONSUMABLE then
        local use = InteractionMenu:AddOption( itemData.UseAlias or L("inventory.use") )
        use:SetIcon( "icon16/briefcase.png" )

        use.DoClick = function()
            if slot ~= nil then
                net.Start( "RequestUseItem" )
                net.WriteInt( slot, 16 )
                net.SendToServer()
            end
        end
    end

    if itemData.Category == itemData.ITEM_DEPLOYABLE then
        local use = InteractionMenu:AddOption( L("inventory.deploy") )
        use:SetIcon( "icon16/lightning.png" )

        use.DoClick = function()
            if slot ~= nil then
                AttemptDeploy( itemData, slot )
            end
        end
    end

    if itemData.Category == itemData.ITEM_FOOD then
        local use = InteractionMenu:AddOption( L("inventory.consume") )
        use:SetIcon( "icon16/drink.png" )

        use.DoClick = function()
            if slot ~= nil then
                net.Start( "RequestUseItem" )
                net.WriteInt( slot, 16 )
                net.SendToServer()
            end
        end
    end

    if itemData.Category == itemData.ITEM_APPAREL then
        local unEquip = InteractionMenu:AddOption( L"inventory.equip", function()
            net.Start( "Monolith.Inventory.InventoryToApparel" )
                net.WriteInt( slot, 16 )
                net.WriteInt( emptySlot, 16 )
            net.SendToServer()
        end ):SetIcon( "icon16/bomb.png" )
    end

    InteractionMenu:Open()
end

function INVENTORY_UI:GetSlotSize()
    ITEM_SLOT_SIZE = self.SlotSize or IsValid( self.sections ) and ( ( self.sections.contentScroll:GetWide() / SLOTS_ON_ROW ) - 5 ) or 64

    return ITEM_SLOT_SIZE
end

function INVENTORY_UI:SlotReceiver( receiver, tbl, dropped, button )
	if istable( tbl ) then
		tbl = tbl[ 1 ]
	end

    if not dropped then
		self.WasRightClickDragAction = input.IsMouseDown( MOUSE_RIGHT ) or input.IsKeyDown( KEY_LSHIFT )
		self.WasMiddleClickDragAction = input.IsMouseDown( MOUSE_MIDDLE ) or input.IsKeyDown( KEY_LCONTROL )

        if IsValid( button ) and IsValid( button.modelPanel ) then
            local x, y = input.GetCursorPos()
            button:Dock( NODOCK )
            button:SetPos( x, y )
        end
        return
	end

    local tPlayerInventory = self:GetInventory()

	local bWasRightMouse = self.WasRightClickDragAction or false
	local bWasMiddleMouse = self.WasMiddleClickDragAction or false
	self.WasRightClickDragAction = nil
	self.WasMiddleClickDragAction = nil

    -- Drop equipment *directly onto the floor* by dragging it into the utility section
    if receiver.IsUtilityMenu and tbl.Slot and tbl.InvEnum ~= BACKPACK_ENUM then
        if not tPlayerInventory:IsValidEquipmentSlot( tbl.Slot ) and not tPlayerInventory:IsValidApparelSlot( tbl.Slot ) then return end
        local bApparelItem = tbl.itemData and tbl.itemData.Category == tbl.itemData.ITEM_APPAREL or false

        local sNetmessage = bApparelItem and "Monolith.Inventory.DropApparel" or "Monolith.Inventory.DropEquipment"
        net.Start( sNetmessage )
            net.WriteInt( tbl.Slot, 16 )
        net.SendToServer()

        return
    end

    -- Drag equipment/apparel into your inventory by dragging it into the backpack section
    if receiver.IsSection and tbl.itemData and tbl.itemData.Category then
        local emptySlot = tPlayerInventory:FindFirstEmptySlot()
        if not emptySlot then return end

        local sNetmessage = tbl.itemData.Category == Monolith.InventoryItem.ITEM_APPAREL and "Monolith.Inventory.ApparelToInventory" or "EquipmentToInventory"
        net.Start( sNetmessage )
            net.WriteInt( emptySlot, 16 )
            net.WriteInt( tbl.Slot , 16 )
        net.SendToServer( )

        return
    end


    if receiver.IsCharacterModel and tbl.itemData and tbl.itemData.Category then
        if tbl.itemData.Category == Monolith.InventoryItem.ITEM_EQUIPMENT then
            local foundSlot = tPlayerInventory:FindSlotForEquipment( tbl.itemData )
            if not foundSlot then return end
    
            net.Start( "InventoryToEquipment" )
                net.WriteInt( tbl.Slot, 16 )
                net.WriteInt( foundSlot, 16 )
            net.SendToServer( )
    
            return
        end

        if tbl.itemData.Category == Monolith.InventoryItem.ITEM_APPAREL then
            local foundSlot = tPlayerInventory:FindSlotForApparel( tbl.itemData )
            if not foundSlot then return end
    
            net.Start( "Monolith.Inventory.InventoryToApparel" )
                net.WriteInt( tbl.Slot, 16 )
                net.WriteInt( foundSlot, 16 )
            net.SendToServer( )

            return
        end
    end

    -- Check if the player is dragging into the utility menu (i.e dragging into thin air to drop an item)
    if receiver.IsUtilityMenu and tbl.Slot and tbl.Identifier == "inventory" then
		if bWasRightMouse then
        	net.Start( "RequestDropSingleItem" )
		elseif bWasMiddleMouse and tbl.slotData.count ~= 1 then
			net.Start( "RequestDropCustomAmountItem" )
		else
			net.Start( "RequestDropItem" )
			net.WriteVector( gui.ScreenToVector( gui.MousePos() ) )

		end
            net.WriteInt( tbl.Slot, 16 )
			if bWasMiddleMouse then net.WriteInt( tbl.slotData.count / 2, 16 ) end
        net.SendToServer()

        return
    end

    -- Added a hook for any module or plugin to override the slot receiver i.e banking
    local doContinue = hook.Run( "Monolith.Inventory.SlotReceiver", self, receiver, tbl, dropped, bWasRightMouse, bWasMiddleMouse )
    if doContinue == true then return end

    -- Cant drag an item onto itself and cant drag a nil item onto another
	if tbl == receiver or not tbl.itemData then return end

    if tbl.itemData.IsAttachment and receiver.InvEnum ~= BACKPACK_ENUM and
        ( receiver.itemData.EquipSlot == Monolith.Inventory.EQUIPMENT_PRIMARY
        or receiver.itemData.EquipSlot == Monolith.Inventory.EQUIPMENT_SECONDARY
        or receiver.itemData.EquipSlot == Monolith.Inventory.EQUIPMENT_TERTIARY
        or receiver.itemData.EquipSlot == Monolith.Inventory.EQUIPMENT_MISC or Monolith.Inventory.ApparelSlot[ receiver.itemData.EquipSlot ] ) then

        if receiver.itemData.Attachments and receiver.itemData.Attachments[ tbl.itemData.Class ] or receiver.itemData.Attachments[ tbl.itemData.ID ] then
            local sNetmessage = receiver.itemData.Category == Monolith.Inventory.ITEM_APPAREL and "Monolith.Inventory.DropAttachment" or "Monolith.Inventory.DropAttachment"
                  
            net.Start( "AttachItemOntoWeaponItemEquipped" )
                net.WriteInt( receiver.Slot, 16 )
                net.WriteInt( tbl.Slot, 16 )
            net.SendToServer()
        else
            AddNotification( Monolith.GetPhrase( "inventory.cant_put_x_on_y", tbl.itemData.Name, receiver.itemData.Name ) )
        end

        return
    end

    -- Attachment checking
	if tbl.itemData.IsAttachment and receiver.itemData and
    ( receiver.itemData.EquipSlot == Monolith.Inventory.EQUIPMENT_PRIMARY
    or receiver.itemData.EquipSlot == Monolith.Inventory.EQUIPMENT_SECONDARY
    or receiver.itemData.EquipSlot == Monolith.Inventory.EQUIPMENT_TERTIARY
    or receiver.itemData.EquipSlot == Monolith.Inventory.EQUIPMENT_MISC or Monolith.Inventory.ApparelSlot[ receiver.itemData.EquipSlot ] ) then

		if receiver.itemData.Attachments and ( receiver.itemData.Attachments[ tbl.itemData.Class ] or receiver.itemData.Attachments[ tbl.itemData.ID ] ) then
            net.Start( "AttachItemOntoWeaponItem" )
            net.WriteInt( receiver.Slot , 16 )
            net.WriteInt( tbl.Slot , 16 )
            net.SendToServer( )
		else
            AddNotification( Monolith.GetPhrase( "inventory.cant_put_x_on_y", tbl.itemData.Name, receiver.itemData.Name ) )
		end

    -- Swap the receiver with the tbl item, (drag and drop)
	elseif receiver.InvEnum == BACKPACK_ENUM then
        if not tbl.Slot then return end

		if tbl.InvEnum == BACKPACK_ENUM then
			if bWasRightMouse and tbl.slotData.count ~= 1 then
				net.Start("RequestSplitItem")
					net.WriteInt( tbl.Slot, 16 )
					net.WriteInt( receiver.Slot, 16 )
					net.WriteInt( 1, 16 )
				net.SendToServer()

				return
			elseif bWasMiddleMouse and tbl.slotData.count ~= 1 then
				net.Start("RequestSplitItem")
					net.WriteInt( tbl.Slot, 16 )
					net.WriteInt( receiver.Slot, 16 )
					net.WriteInt( tbl.slotData.count / 2, 16 )
				net.SendToServer()

				return
			end

			net.Start( "SwapInventorySlots" )
			net.WriteInt( tbl.Slot , 16 )
			net.WriteInt( receiver.Slot , 16 )
			net.SendToServer( )

            surface.PlaySound( "foley/inventory/inv_move".. math.random( 1, 3 ) .. ".wav" )
		else
            if receiver.itemData and not ( receiver.itemData.Category and receiver.itemData.Category == Monolith.InventoryItem.ITEM_EQUIPMENT or receiver.itemData.Category == Monolith.InventoryItem.ITEM_APPAREL ) then
                return
            end

            local sNetmessage = tbl.itemData.Category == Monolith.InventoryItem.ITEM_APPAREL and "Monolith.Inventory.ApparelToInventory" or "EquipmentToInventory"

			net.Start( sNetmessage )
			net.WriteInt( receiver.Slot , 16 )
			net.WriteInt( tbl.Slot , 16 )
			net.SendToServer( )
		end

    -- Check if inventory is going to equipment/apparel
	elseif tbl.InvEnum == BACKPACK_ENUM then
		if not tbl.itemData.Category or tbl.itemData.Category ~= Monolith.InventoryItem.ITEM_EQUIPMENT and tbl.itemData.Category ~= Monolith.InventoryItem.ITEM_APPAREL then return end
        if not tbl.Slot or not receiver.Slot then return end

        local sNetmessage = tbl.itemData.Category == Monolith.InventoryItem.ITEM_APPAREL and "Monolith.Inventory.InventoryToApparel" or "InventoryToEquipment"

		net.Start( sNetmessage )
		net.WriteInt( tbl.Slot, 16 )
		net.WriteInt( receiver.Slot , 16 )
		net.SendToServer( )
	end
end

local gradient = Material("vgui/gradient-r")
local stripes = Material( "mrp/icon_stripes.png", "smooth" )
local glowMat = Material( "mrp/spherical_gradient.png", "smooth" )
local blipFire = Material( "mrp/radar/blip_fire.png", "smooth mips" )

local GRADIENT_DOWN = Material( "vgui/gradient-d" )
local MAT_GRADIENT = Material( "gui/gradient" )

local ELEMENT_DOWN_COLOR = Color( 45, 45, 45, 225 )
local ELEMENT_HOVER_COLOR = Color( 40, 40, 40, 225 )
local PURPLE = Monolith.Color.purple
local ORANGE = Monolith.Color.orange
local BLUE = Monolith.Color.blue
local RED = Monolith.Color.red
local CYAN = Monolith.Color.cyan
local LIGHT_GREEN = Monolith.Color.lightgreen
local ACTION_COLOR = Monolith.Color.grey
local TEXT_BACKGROUND_COLOR = Color( 0, 0, 0, 100 )
local TEXT_FOREGROUND_COLOR = Color( 255, 255, 255, 200 )
local STAR = Material( "mrp/icons/star.png", "smooth" )
local EMPTY_COLOR = Color( 50, 50, 50 )

local DEBUG = false
local roundedSquare = Material( "mrp/square_rounded.png" )

local CMB_ITEM = Material( "icons/inventory/cmb_poly.png", "smooth" )
local CMB_ITEM_COLOR = Color( 0, 0, 0)
local CMB_POLY = Material( "icons/inventory/cmb_poly.png", "smooth" )

function Monolith.Inventory:GetItemColor( tItemData, tSlotData, nInvEnum )
    local cColor = Monolith.UI.Color( "DarkGrey" )
    local sPlayerTeam = LocalPlayer():Team()
    local tJob = Monolith.Jobs:GetJob( sPlayerTeam )

    -- if not tItemData then
    --     cColor = nInvEnum == Monolith.Inventory.EQUIPMENT_PRIMARY and ORANGE
    --         or nInvEnum == Monolith.Inventory.EQUIPMENT_SECONDARY and BLUE
    --             or nInvEnum == Monolith.Inventory.EQUIPMENT_TERTIARY and RED
    --                 or nInvEnum == Monolith.Inventory.EQUIPMENT_MISC and LIGHT_GREEN
    --                     or nInvEnum == Monolith.Inventory.EQUIPMENT_ARMOR and CYAN
    --                         or Color( 50, 50, 50 )
    -- end

    if not tItemData then
        -- Empty
        cColor = EMPTY_COLOR
    end

    if tItemData and tItemData.PremiumOnly then
        --cColor = HSVToColor( CurTime() * 10 % 360, 1, 1 )
    end

    if tItemData and tItemData.Variant then
        cColor = tItemData.Variant.Color
    end

    if tItemData and tItemData.DeleteOnJobChange then
        cColor = tJob.color
    end

    if tItemData and tItemData.Category == ITEM_DEPRECATED then
        cColor = Monolith.UI.Color( "Red" )
    end

    return cColor
end

function Monolith.Inventory:SetStatPreview( sStat, iAmountToAdd )
    if not self._StatPreview then
        self._StatPreview = {}
    end

    self._StatPreview[ sStat ] = iAmountToAdd
end

function Monolith.Inventory:ClearStatPreview()
    self._StatPreview = {}
end

local ICON_LOCK_MAT = Material( "mrp/icons/lock.png" )
function Monolith.Inventory:SetItemIcon( button, data, player )
    if not IsValid( button ) then return end

	if not IsValid( player ) then player = LocalPlayer() end

    -- Fuck off if you don't complete me!
    if not data then return end

    local enum = data.enum
    local slot = data.slot
    local itemData = data.itemData
    local slotData = data.slotData
    local doClick = data.doClick
    local doDoubleClick = data.doDoubleClick
    local receiverFunction = data.receiverFunction
    local identifier = data.identifier
    local doRightClick = data.doRightClick
    local outlineColor = data.outlineColor
    local bIsLocked = data.isLocked
    local overlayPaint = data.overlayPaint -- optional paint function to draw an overlay

    if IsValid( button.spawnIcon ) then button.spawnIcon:Remove() end
    if IsValid( button.overButton ) then button.overButton:Remove() end

    -- Assign button information for the button receivers
    button.Identifier = identifier
	button.InvEnum = enum
    button.itemData = itemData
    button.slotData = slotData
    button.slot = slot
    button.Slot = slot
    button.outlineColor = outlineColor
    button.CLD = 0

    button.DoClick = doClick or button.DoClick

    button.DoDoubleClick = doDoubleClick or button.DoDoubleClick
    button.DoRightClick = doRightClick or button.DoRightClick

    local bIsRepairable = Monolith.Durability and Monolith.Durability.IsRepairableItem and Monolith.Durability:IsRepairableItem( itemData ) or false

    local fgButton
    local buttonColor = Color( 30, 30, 30, 200 )

    button.Paint = function( this, w, h )
        local globalX, globalY = this:LocalToScreen( 0, 0 )

        --render.SetScissorRect( globalX, globalY, globalX + w, globalY + h, true ) -- Enable the rect

        local element = IsValid( this.overButton ) and this.overButton or IsValid( this.spawnIcon ) and this.spawnIcon or this
        local isHovered = element:IsHovered()
        local color = element.IsDown and element:IsDown() and ELEMENT_DOWN_COLOR or isHovered and ELEMENT_HOVER_COLOR or buttonColor

        if this.isHovered and not isHovered then
            if IsValid( this.TooltipObject ) then
                this.TooltipObject._Deleted = true
            end

            this.CLD = 0
        end

        this.isHovered = isHovered

        -- Draw background
        draw.RoundedBox( 6, 1, 2, w - 2, h - 4, color )

        surface.SetDrawColor( CMB_ITEM_COLOR )
        surface.SetMaterial( CMB_ITEM )
        surface.DrawTexturedRect( 0, 0, w, h )

        -- Decide glow colour
        outlineColor = self:GetItemColor( itemData, slotData, this.InvEnum )

		if itemData and itemData.Category == ITEM_DEPRECATED then
			outlineColor = Monolith.UI.Color( "Red" )
        end

        if( bIsLocked ) then
            surface.SetDrawColor( 0, 0, 0, 100 )
            surface.SetMaterial( ICON_LOCK_MAT )
            local iIconSize = w * 0.6
            surface.DrawTexturedRect( w / 2 - iIconSize / 2, h / 2 - iIconSize / 2, iIconSize, iIconSize )
        end

        if itemData and itemData.Name then
            element:SetTooltip( nil )

            if isHovered and this.slotData and this.slotData.id and this.itemData then
                if this.CLD > 0 and not IsValid( this.TooltipObject ) then
                    this.CLD = this.CLD - FrameTime()
                elseif this.CLD <= 0 and not IsValid( this.TooltipObject ) then
                    this.TooltipObject = Monolith.Inventory:InstantiateItemTooltip( gui.MouseX() + 8 , gui.MouseY() + 8, this.itemData, this.slotData )

                    if IsValid( this.TooltipObject ) then
                        this.TooltipObject.ParentObject = this
                        surface.PlaySound( "ui/hls_ui_scroll_click.wav" )
                    end
                end
            end
        end

        if this.outlineColor then
            outlineColor = this.outlineColor
        end

        outlineColor = Color( outlineColor.r, outlineColor.g, outlineColor.b, element:IsDragging() and 10 or isHovered and 50 or 25 )

        -- if (this.particleSystem) then
        --     this.particleSystem:Render()
        -- end

		if itemData then
			local bCanConfiscate = Monolith.Confiscation.CanConfiscate( itemData )

			if bCanConfiscate then
                outlineColor = Monolith.Color.red
			end
		end

        -- Background glow
        surface.SetDrawColor( outlineColor:SetAlpha( 120 ) )
        surface.SetMaterial( CMB_POLY )
        surface.DrawTexturedRect( 0, 0, w, h )

        if button.PostPaint then button.PostPaint( button, w, h ) end

        if button.ActionStart and button.ActionEnd then
            local actionColor = ACTION_COLOR
            local start, finish = button.ActionStart, button.ActionEnd
            local curTime = CurTime()

            if actionColor and start and finish and finish > curTime then
                local fraction = 1 - math.TimeFraction( start, finish, curTime )
                actionColor = Monolith.ActionColor
                local color = Color( actionColor.r, actionColor.g, actionColor.b, 255 )

                Monolith.DrawActionCircle( 0, 0, w, h, fraction, actionColor, circleMat )
            end
        end

        -- Text for slot count & attachment count
        if slotData then
            if slotData.count > 1 then
                draw.SimpleText( slotData.count, Monolith.Fonts.DIN_Pro_18, 6, 3, TEXT_BACKGROUND_COLOR )
                draw.SimpleText( slotData.count, Monolith.Fonts.DIN_Pro_18, 5, 2, TEXT_FOREGROUND_COLOR )
            end

            if istable( slotData.extra ) then
                if bIsRepairable then
                    local nDurability = slotData.extra.durability or 100

                    if nDurability <= 0 then
                        surface.SetDrawColor( Monolith.UI.Color( "Red" ):SetAlpha( 75 ) )
                        surface.SetMaterial( blipFire )
                        surface.DrawTexturedRect( 4, h - 16 - 4, 16, 16 )
                    else
                        -- local lerpAmt = nDurability / 100
                        -- local cDesiredColor = Color( Lerp( lerpAmt, 255, 0 ), Lerp( lerpAmt, 0, 255 ), Lerp( lerpAmt, 0, 67 ) )

                        -- surface.SetDrawColor( cDesiredColor:SetAlpha( 75 ) )
                        -- surface.SetMaterial( GRADIENT_DOWN )
                        -- surface.DrawTexturedRect( 2, h * 0.9 - 1, w - 4, h * 0.1 )
                    end
                end

                if slotData.extra.attachments and istable( slotData.extra.attachments ) then
                    local posOffset = 0

                    for _, attachmentData in pairs( slotData.extra.attachments ) do
                        if istable( attachmentData ) then
                            local durability = attachmentData.durability or 100
                            local dynamicColor = HSVToColor( ( durability / 100 ) * 120, 1, 1 )
                            dynamicColor.a = 75

                            surface.SetDrawColor( dynamicColor )
                            surface.DrawRect( 8 + posOffset, h - 12 - 6, 3, 12 )

                            posOffset = posOffset + 6
                        else
                            surface.SetDrawColor( HSVToColor( 120, 1, 1 ) )
                            surface.DrawRect( 8 + posOffset, h - 12 - 6, 3, 12 )

                            posOffset = posOffset + 6
                        end
                    end
                end

            end

            if itemData and itemData.InfoTitle then
                draw.SimpleText( itemData.InfoTitle, Monolith.Fonts.DIN_Pro_18, 6, 3, TEXT_BACKGROUND_COLOR )
                draw.SimpleText( itemData.InfoTitle, Monolith.Fonts.DIN_Pro_18, 5, 2, TEXT_FOREGROUND_COLOR )
            end

            if DEBUG then
                draw.SimpleText( slot .. " : " .. this.Slot, "Default", w / 2, h - 12, color_white, TEXT_ALIGN_CENTER )
            end
        end
        
        if( overlayPaint ) then
            overlayPaint( this, w, h )
        end

        --render.SetScissorRect( 0, 0, 0, 0, false ) -- Disable after you are done
    end

    if itemData then
        if itemData.disableIkon then
            button.spawnIcon = button:Add( "SpawnIcon" )
            button.spawnIcon:SetModel( itemData.Model )
            button.spawnIcon:Dock( FILL )
            button.spawnIcon:DockMargin( 8, 8, 8, 8 )

            if itemData.Skin then button.spawnIcon:SetSkin( itemData.Skin ) end

			if player == LocalPlayer() then
				-- Drag&Drop
				button.spawnIcon:Droppable( "inventory" )

				button.spawnIcon:Receiver( "inventory" , function( receiver, tbl, dropped )
					if receiverFunction then receiverFunction( receiver, tbl, dropped ) end
				end )

				button.spawnIcon.DoClick = function( this )
					if doClick then doClick( this ) end
				end

				button.spawnIcon.DoDoubleClick = function( this )
					if doDoubleClick then doDoubleClick( this ) end
				end

				button.spawnIcon.DoRightClick = function( this )
					if doRightClick then doRightClick( this ) end
				end
			end

            button.spawnIcon.PaintOver = function() end

            -- Assign button information for the button receivers
            button.spawnIcon.Identifier = identifier
            button.spawnIcon.InvEnum = enum
            button.spawnIcon.itemData = itemData
            button.spawnIcon.slotData = slotData
            button.spawnIcon.slot = slot
            button.spawnIcon.Slot = slot
        else
			local overButton = button:Add( "DButton" )
			overButton:Dock( FILL )
			overButton:SetText( "" )

			overButton.Paint = function( this, w, h )
				local bIsMouseDown = input.IsMouseDown( MOUSE_LEFT )

                local exIcon = ikon:getIcon( itemData.id )

                if (itemData.Skin) then

                    exIcon = ikon:getIcon( itemData.id, itemData.Skin)
				end

				if (exIcon) then
					surface.SetMaterial( exIcon )
					surface.SetDrawColor( color_white )

					if this:IsDown() and not this.Dragging then
						surface.DrawTexturedRect( 14, 14, w - 28, h - 28 )
					else
						surface.DrawTexturedRect( 8, 8, w - 16, h - 16 )
					end
				else
                    if (itemData.Skin) then

                        ikon:renderIcon(
                            itemData.id,
                            256, 256,
                            itemData.Model,
                            itemData.IconCamData,
                            nil,
                            itemData.Skin
                        )

                    else

                    	ikon:renderIcon(
                            itemData.id,
                            256, 256,
                            itemData.Model,
                            itemData.IconCamData
                        )

                    end

				end
			end

			if player == LocalPlayer() then
           		-- Drag&Drop
            	overButton:Droppable( "inventory" )
				overButton:Receiver( "inventory" , function( receiver, tbl, dropped )
					if receiverFunction then receiverFunction( receiver, tbl, dropped ) end
				end )

				overButton.DoClick = function( this )
					if doClick then doClick( this ) end
				end

				overButton.DoDoubleClick = function( this )
					if doDoubleClick then doDoubleClick( this ) end
				end

				overButton.DoRightClick = function( this )
					if doRightClick then doRightClick( this ) end
				end
			end

            overButton.PaintOver = function() end

            -- Assign button information for the button receivers
            overButton.Identifier = identifier
            overButton.InvEnum = enum
            overButton.itemData = itemData
            overButton.slotData = slotData
            overButton.slot = slot
            overButton.Slot = slot

			button.overButton = overButton
		end

        -- Running our custom item function if it exists
        if itemData.MakeIcon and button and button.modelPanel and slotData then
            itemData:MakeIcon(button.modelPanel, slotData and slotData.data)
        end
    end
end

--[[
    CreateItem
        > creates a workable inventory icon
        args:
            parent - Parent of the inventory icon, preferably a DPanel
            enum - Inventory enumeration (
                    BACKPACK_ENUM,
                    Monolith.Inventory.EQUIPMENT_PRIMARY,
                    Monolith.Inventory.EQUIPMENT_SECONDARY,
                    Monolith.Inventory.EQUIPMENT_MISC
                )
            slot - Container slot ID
            itemData - Item definition for name/model/other information
            slotData - Slot definition for count/id/slot data
            doClick - callback when an inventory icon is pressed
            customSize - allow to override the size of the inventory icon
]]

function INVENTORY_UI:CreateItem(parent, enum, slot, itemData, slotData, doClick, customSize, doDoubleClick)
    local button = parent:Add("DButton")
    button:SetSize( customSize or self:GetSlotSize(), customSize or self:GetSlotSize() )
    button:InvalidateParent( true )
    button:SetText( "" )

	if self:getPlayer() == LocalPlayer() then
		button:Droppable( "inventory" )

		button:Receiver( "inventory" , function( receiver, tbl, dropped )
			-- do shit
			self:SlotReceiver( receiver, tbl, dropped, button )
		end )
	end

    Monolith.Inventory:SetItemIcon( button, {
        enum = enum,
        slot = slot,
        itemData = itemData,
        slotData = slotData,
        doClick = doClick,
        doDoubleClick = doDoubleClick,
        receiverFunction = function( receiver, tbl, dropped )
            self:SlotReceiver( receiver, tbl, dropped, button )
        end,
        identifier = "inventory"
    }, self:getPlayer() )

    return button
end

function INVENTORY_UI:getPlayer()
    return self.Player or LocalPlayer()
end

function INVENTORY_UI:SetPlayer( pPlayer )
    self.Player = pPlayer
end

function INVENTORY_UI:PopulateActions( pPanel, iSlot, tItemData, tSlotData )
    local tPlayerInventory = self:GetInventory()
    local iEmptySlot = tPlayerInventory:FindFirstEmptyEquipmentSlot()

    if tItemData.Category and tItemData.Category == Monolith.InventoryItem.ITEM_EQUIPMENT then
        pPanel:AddAction( L"inventory.equip", function()
            if iSlot ~= nil then
                net.Start( "InventoryToEquipment" )
                    net.WriteInt( iSlot, 16 )
                    net.WriteInt( iEmptySlot, 16 )
                net.SendToServer()
            end
        end )
    end

    if tItemData.Category == tItemData.ITEM_CONSUMABLE then
        pPanel:AddAction( tItemData.UseAlias or L"inventory.use", function()
            if iSlot ~= nil then
                net.Start( "RequestUseItem" )
                net.WriteInt( iSlot, 16 )
                net.WriteUInt( 1, 8 )
                net.SendToServer()
            end
        end )

        if tItemData.CanUseSpecificQuantity and 
            not tItemData.DropStacksOnly and ( tSlotData.count and tSlotData.count > 1 ) then
            local pAction = pPanel:AddAction( L"inventory.use_all", function()
                net.Start( "RequestUseItem" )
                net.WriteInt( iSlot, 16 )
                net.WriteUInt( tSlotData.count, 8 )
                net.SendToServer()
            end )
            pAction:SetTall( 16 )
            pAction:SetFont( Monolith.Fonts.DIN_Pro_16 )

            if tSlotData.count > 1 then
                local pAction = pPanel:AddAction( L"inventory.use_half", function()
                    net.Start( "RequestUseItem" )
                        net.WriteInt( iSlot, 16 )
                        net.WriteInt( tSlotData.count / 2, 16 )
                    net.SendToServer()
                end )
                pAction:SetTall( 16 )
                pAction:SetFont( Monolith.Fonts.DIN_Pro_16 )

                local pAction = pPanel:AddAction( L"inventory.use_custom", function()
                    Monolith.Derma_StringRequest(
                        L"inventory.use_custom",
                        L"inventory.use_helper_description",
                        "1",
                        function( text )
                            text = tonumber( text )
                            if not text then return end

                            net.Start( "RequestUseItem" )
                                net.WriteInt( iSlot, 16 )
                                net.WriteInt( text, 8 )
                            net.SendToServer()
                        end
                    )
                end )
                pAction:SetTall( 16 )
                pAction:SetFont( Monolith.Fonts.DIN_Pro_16 )
            end
        end
    end

    if tItemData.Category == tItemData.ITEM_DEPLOYABLE then
        pPanel:AddAction( L"inventory.deploy", function()
            if iSlot ~= nil then
                AttemptDeploy( tItemData, iSlot )
            end
        end )
    end

    if tItemData.Category == tItemData.ITEM_FOOD then
        pPanel:AddAction( L"inventory.consume", function()
            if iSlot ~= nil then
                net.Start( "RequestUseItem" )
                net.WriteInt( iSlot, 16 )
                net.SendToServer()
            end
        end )
    end

    if tItemData.Category and tItemData.Category == Monolith.InventoryItem.ITEM_APPAREL then
        pPanel:AddAction( L"inventory.equip", function()
            if iSlot ~= nil then
                net.Start( "Monolith.Inventory.InventoryToApparel" )
                    net.WriteInt( iSlot, 16 )
                    net.WriteInt( iEmptySlot, 16 )
                net.SendToServer()
            end
        end )
    end

    for k, v in pairs( ents.FindInSphere( LocalPlayer():GetPos(), 64 ) ) do
        if not v.IsMonolithNPC then continue end

        local tNPC = Monolith.NPCs:GetNPC( v:GetType(), v:GetId() )
        if not tNPC then return end

        local nRawPrice = tItemData:CalculatePrice( tSlotData )
        -- Calculate tax, reversely.
        local nPrice = nRawPrice

        if tNPC.storeId and (istable(tItemData.Store) and table.HasValue(tItemData.Store, tNPC.storeId) or !istable(tItemData.Store) and tNPC.storeId == tItemData.Store) then
            pPanel:AddAction( Monolith.GetPhrase( "inventory.sell_with_price", tItemData.Currency and ( nPrice .. " " .. Monolith.Store.Currencies[tItemData.Currency].Name ) or Monolith.FormatMoney( nPrice ) ), function()
                if v:GetPos():DistToSqr( LocalPlayer():GetPos() ) > 250000 then return end

                net.Start( "RequestSelling" )
                    net.WriteUInt( iSlot, 10 )
                    net.WriteEntity( v )
                net.SendToServer()
            end )

            pPanel:AddAction( L( "inventory.sell_all" ), function()
                if v:GetPos():DistToSqr( LocalPlayer():GetPos() ) > 250000 then return end

                Derma_Query( L( "inventory.sell_all_confirmation" ), "", L"yes", function()
					if v:GetPos():DistToSqr( LocalPlayer():GetPos() ) > 250000 then return end
                    
                    net.Start("Monolith.Inventory.SellAllOfItem")
                        net.WriteInt(iSlot, 16)
                        net.WriteEntity( v )
                    net.SendToServer()
                end, L"no", function() end)
                    end )

        end
    end

    if not tItemData.PremiumOnly and not tItemData.SoulBound and not tItemData.DeleteOnJobChange then
        pPanel:AddAction( L"inventory.drop", function()
            net.Start( "RequestDropItem" )
				net.WriteVector( LocalPlayer():GetAimVector() )
				net.WriteInt( iSlot, 16 )
            net.SendToServer()
        end )

        if not tItemData.DropStacksOnly and ( tSlotData.count and tSlotData.count > 1 ) then
            local pAction = pPanel:AddAction( L"inventory.drop_singular", function()
                net.Start( "RequestDropSingleItem" )
                net.WriteInt( iSlot, 16 )
                net.SendToServer()
            end )
            pAction:SetTall( 16 )
            pAction:SetFont( Monolith.Fonts.DIN_Pro_16 )

            if tSlotData.count > 1 then
                local pAction = pPanel:AddAction( L"inventory.drop_half", function()
                    net.Start( "RequestDropCustomAmountItem" )
                        net.WriteInt( iSlot, 16 )
                        net.WriteInt( tSlotData.count / 2, 16 )
                    net.SendToServer()
                end )
                pAction:SetTall( 16 )
                pAction:SetFont( Monolith.Fonts.DIN_Pro_16 )

                local pAction = pPanel:AddAction( L"inventory.drop_custom", function()
                    Monolith.Derma_StringRequest(
                        L"inventory.drop_custom",
                        L"inventory.drop_helper_description",
                        "1",
                        function( text )
                            text = tonumber( text )
                            if not text then return end

                            net.Start( "RequestDropCustomAmountItem" )
                                net.WriteInt( iSlot, 16 )
                                net.WriteInt( text, 16 )
                            net.SendToServer()
                        end
                    )
                end )
                pAction:SetTall( 16 )
                pAction:SetFont( Monolith.Fonts.DIN_Pro_16 )
            end
        end
    end

    if (not tItemData.DropStacksOnly and ( tSlotData.count and tSlotData.count > 1 ) ) then
        local freeSlot = tPlayerInventory:FindFirstEmptySlot()

        if freeSlot then
            pPanel:AddAction( L"inventory.split", function()
                Monolith.Derma_StringRequest( L"inventory.split", Monolith.GetPhrase( "inventory.split_amount", tSlotData.count - 1 ), math.floor(tSlotData.count / 2), function( txt )
                    if tonumber(txt) ~= nil then
                        local num = tonumber(txt)
                        if not num then return end
                        num = math.Round(num)
                        if num <= 0 or num > tSlotData.count - 1 then return end

                        net.Start("RequestSplitItem")
                            net.WriteInt( iSlot, 16 )
                            net.WriteInt( freeSlot, 16 )
                            net.WriteInt( math.Round(num), 16 )
                        net.SendToServer()
                    end
                end, function() end, L"inventory.split", L("cancel") )
            end )
        end
    end

    if not tItemData.PremiumOnly and not tItemData.SoulBound and not tItemData.DeleteOnJobChange then
        pPanel:AddAction( L"inventory.market", function()
            Monolith.Derma_StringRequest(L"inventory.marketing", L"inventory.marketing_helper_description", "100", function(price)
                if (not isnumber(tonumber(price))) then
                    Derma_Message(L"inventory.form_requirement_number", "", L"ok")

                    return
                end

                if tonumber(price) and tonumber(price) > 0 and tonumber(price) < 100000 then
                    if (string.len(tItemData.Name) >= 18) then
                        dfltTitle = string.sub(tItemData.Name, 1, 17)
                    else
                        dfltTitle = tItemData.Name
                    end

                    net.Start( "RequestSellItem" )
                        net.WriteInt( iSlot, 16 )
                        net.WriteFloat( tonumber(price) )
                        net.WriteBool( true )
                        net.WriteString( L( "market.gui.defaultTitle" ) )
                    net.SendToServer()
                elseif (tonumber(price) < 100000) then
                    Derma_Message( L"inventory.form_requirement_number", "", L"ok" )

                    return
                else
                    Derma_Message( L"inventory.form_requirement_number", "", L"ok" )

                    return
                end
            end)
        end )
    end

    if ( tItemData.EquipSlot == Monolith.InventoryItem.EQUIPMENT_PRIMARY or tItemData.EquipSlot == Monolith.InventoryItem.EQUIPMENT_SECONDARY or tItemData.EquipSlot == Monolith.InventoryItem.EQUIPMENT_TERTIARY or tItemData.EquipSlot == Monolith.InventoryItem.EQUIPMENT_MISC or Monolith.Inventory.ApparelSlot[ tItemData.EquipSlot ] ) and
    ( tSlotData and tSlotData.extra and tSlotData.extra.attachments and table.Count( tSlotData.extra.attachments ) > 0 ) then
        pPanel:AddAction( L"inventory.remove_attachment", function( btn, inspect )
            local pMenu = vgui.Create( "psOptions" )
            pMenu:SetPanel( self )

            for attachmentId, _ in pairs( tSlotData.extra.attachments ) do
                local item = Monolith.InventoryItems:GetItemFromID( attachmentId )
                if not item then continue end

                local attachmentMenu = pMenu:AddOption( item.Name, function()
                    inspect:Remove()

                    net.Start( "DetachAttachment" )
                        net.WriteInt( iSlot, 16 )
                        net.WriteString( attachmentId )
                    net.SendToServer()
                end )
            end
        end, true )
    end

    if (tItemData.Variant) then
        pPanel:AddAction( L"inventory.changeVariant", function()
            net.Start("Monolith.Variants.Toggle")
                net.WriteInt( iSlot, 16 )
            net.SendToServer()
        end )
    end

    if tItemData.BreakdownResult then
        pPanel:AddAction( L"inventory.breakdown", function()
            net.Start( "Monolith.Inventory.BreakdownItem" )
                net.WriteInt( iSlot, 16 )
            net.SendToServer()
        end )
    end

    --[[local pAction = pPanel:AddAction( L"inventory.delete_item", function()
        Monolith.CreateQuery( L"inventory.delete_item", L"inventory.are_you_sure_prompt", L"yes", function()
            net.Start("RequestDelete")
            net.WriteInt( iSlot, 16 )
            net.SendToServer()
        end, L"no", function() end)
    end )
    pAction:SetColor( Color( 137, 60, 60 ):SetAlpha( 75 ) )]]
end

function INVENTORY_UI:InspectItem( iSlot, tItemData, tSlotData )
    if not tItemData then self:SetUtilityContents() return end

    local pPanel = vgui.Create( "psInventoryInspect" )
    pPanel:SetItem( iSlot, tItemData, tSlotData )

    if not tItemData.noActions then
        self:PopulateActions( pPanel, iSlot, tItemData, tSlotData )
    end

    return self:SetUtilityContents( pPanel )
end

function INVENTORY_UI:AddCounter( pParent, cColor, sTitle, fCallbackForAmount, fCallbackForMax )
	local pSpacer = pParent:Add( "Panel" )
	pSpacer:SetSize( ITEM_SLOT_SIZE * 6, 8 )

	local pPanel = pParent:Add( "Panel" )
	pPanel:SetSize( ITEM_SLOT_SIZE * 6, 64 )

	local pHeader = pPanel:Add( "Panel" )
	pHeader:Dock( TOP )
	pHeader:SetTall( 22 )

	local sName = pHeader:Add( "psHeader" )
	sName:Dock( LEFT )
	sName:SetFont( Monolith.Fonts.DIN_Pro_22_BOLD )
	sName:SetText( sTitle )
	sName:SetWide( 256 )
	sName:SetContentAlignment( 4 )

	local fCurrentAmt = fCallbackForAmount and fCallbackForAmount or function() return 0 end
	local fMax = fCallbackForMax and fCallbackForMax or function() return 0 end

	local sCounter = pHeader:Add( "psHeader" )
	sCounter:Dock( RIGHT )
	sCounter:SetWide( 256 )
	sCounter:SetFont( Monolith.Fonts.DIN_Pro_22_BOLD )
	sCounter:SetText( "" )
	sCounter:SetContentAlignment( 6 )

	local pBar = pPanel:Add( "psPanel" )
	pBar:Dock( FILL )

    local gradient = Material( "vgui/gradient-r" )
    local myColor = Color( 25, 25, 25, 125 )

	pBar.Paint = function( this, w, h )
		local nCurrent, nMax = fCurrentAmt(), fMax()

		pPanel:SetVisible( nCurrent > 0  )

		sCounter:SetText( ( "%i/%i" ):format( nCurrent, nMax ) )

        surface.SetDrawColor( 25, 25, 25, 125 )
        surface.DrawRect( 0, 0, w, h )

		surface.SetMaterial( gradient )
		surface.SetDrawColor( cColor )

		local nPercent = nCurrent / nMax

		local _, nY = 4, 4
		local nWidth, nHeight = w - 8, h - 8

		surface.DrawTexturedRect( nWidth + 4 - ( nWidth * nPercent ), nY, nWidth * nPercent, nHeight )
	end

	self.Counters = self.Counters or {}
	table.insert( self.Counters, pPanel )
end

function INVENTORY_UI:PopulateItems()
    if not IsValid( self.itemList ) then return end

    self.itemList:Clear()
    self.itemButtons = {}

	self.Counters = {}

    local tPlayerInventory = self:GetInventory()
    if tPlayerInventory then
        -- Found an inventory
        for slot, slot_data, item_table in tPlayerInventory:Backpack_Iter() do
            local newButton = self:CreateItem(self.itemList, BACKPACK_ENUM, slot, item_table, slot_data, function( button )
                Monolith.Inventory:ClearStatPreview()

                self:InspectItem( slot, item_table, slot_data )
            end, nil, function( button )
				-- Who cares
            end )

            self.itemButtons[ slot ] = newButton

            newButton.slot_data = slot_data
            newButton.slot = slot
            newButton.item_table = item_table
        end

		-- Deployed entity count
		self:AddCounter( self.itemList, Monolith.UI.Color( "Red" ), "Drop Limit", function()
			return self:getPlayer():GetNW2Int( "Monolith.SpawnedEntitiesCount", 0 )
		end, function()
			return self:getPlayer():GetSpawnedEntityLimit()
		end )

		-- Deployed entity count
		self:AddCounter( self.itemList, Monolith.UI.Color( "Orange" ), "Deployed Drug Items", function()
			return self:getPlayer():GetNW2Int( "Monolith.GlobalDrugAmount", 0 )
		end, function()
			return Monolith.Config.GetAssert( "drugs.server.universal.limit", 5 )
		end )
    else
        -- Failed to load an inventory
        local failure = self.itemList:Add( "psButton" )
        failure:Dock( FILL )
        failure:SetText( L"inventory.inventory_load_failure" )
        failure:SetTextColor( Monolith.Color.white )
    end
end

function INVENTORY_UI:ApplyInventoryChanges( tData )

    -- Apply any updates sent for the backpack
    if tData.Backpack then
        for _, update in pairs( tData.Backpack ) do
            -- slot = update[1]
            -- slot_data = update[2]
            -- self.Inventory.Backpack[slot] = slot_data

            local slot = update[1]
            local slot_data = update[2]

            local item_table = Monolith.InventoryItems:GetItemFromID( slot_data and slot_data.id )

            local foundButton = self.itemButtons[ slot ]
            if not IsValid( foundButton ) then return end

            Monolith.Inventory:SetItemIcon( foundButton, {
                enum = BACKPACK_ENUM,
                slot = slot,
                itemData = item_table,
                slotData = slot_data,
                doClick = function()
                    self:InspectItem( slot, item_table, slot_data )
                end,
                doDoubleClick = nil,
                receiverFunction = function( receiver, tbl, dropped )
                    self:SlotReceiver( receiver, tbl, dropped, foundButton )
                end,
                identifier = "inventory"
            })

            foundButton.slot_data = slot_data
            foundButton.slot = slot
            foundButton.item_table = item_table

            if self.utilitySection.child and self.utilitySection.child.slot == slot then
                foundButton:DoClick()
            end
        end
    end

    -- Apply any updates sent for the equipment
    if tData.Equipment then
        self:UpdateEquipment()
    end

    if tData.Apparel then
        self:UpdateApparel()
    end
end

function INVENTORY_UI:CreateEquipmentActions(slot, slot_data, item_table)
    local emptySlot = self:GetInventory():FindFirstEmptySlot()

    if emptySlot then
        if item_table and not (item_table.Category and item_table.Category == Monolith.InventoryItem.ITEM_EQUIPMENT) then return end

        if not slot_data then return end

        local menu = vgui.Create( "psOptions" )
        menu:SetPanel( self )

        -- AddOption( sText, fDoClick, cColor, fDoHover )

        local unEquip = menu:AddOption(L"inventory.unequip", function()
            net.Start( "EquipmentToInventory" )
                net.WriteInt( emptySlot, 16 )
                net.WriteInt( slot, 16 )
            net.SendToServer()
        end, Monolith.Color.red )

        local drop = menu:AddOption( L"inventory.drop", function()
            net.Start( "Monolith.Inventory.DropEquipment" )
                net.WriteInt( slot, 16 )
                
            net.SendToServer()
        end, Color( 0, 255, 0 ) )

        if slot_data.extra and slot_data.extra.attachments then
            for attachmentId, _ in pairs( slot_data.extra and slot_data.extra.attachments or {} ) do
                local item = Monolith.InventoryItems:GetItemFromID( attachmentId )
                if not item then continue end

                menu:AddOption( L"whitelist.gui.queryRemove" .. " " .. item.Name, function()
                    net.Start( "DetachAttachmentEquipped" )
                        net.WriteInt( slot, 16 )
                        net.WriteString( attachmentId )
                    net.SendToServer()
                end )
            end
        end
    end
end

function INVENTORY_UI:CreateApparelActions(slot, slot_data, item_table)
    local emptySlot = self:GetInventory():FindFirstEmptySlot()

    if emptySlot then
        if item_table and not (item_table.Category and item_table.Category == Monolith.InventoryItem.ITEM_APPAREL) then return end
        if not slot_data then return end

        local menu = vgui.Create( "psOptions" )
        menu:SetPanel( self )

        local unEquip = menu:AddOption( L"inventory.remove", function()
            net.Start( "Monolith.Inventory.ApparelToInventory" )
                net.WriteInt( emptySlot, 16 )
                net.WriteInt( slot, 16 )
                net.WriteBool( true )
            net.SendToServer()
        end, Monolith.Color.red )

        local drop = menu:AddOption( L"inventory.drop", function()
            net.Start( "Monolith.Inventory.DropApparel" )
                net.WriteInt( slot, 16 )
            net.SendToServer()
        end, Color( 0, 255, 0 ) )
    end
end

function INVENTORY_UI:SelectButton(button)
    for _, categoryButton in pairs(self.categoryElements) do
        categoryButton.active = nil
    end

    button.active = true
end

function INVENTORY_UI:SelectItemCategory(button)
    self:SelectButton(button)
    self:PopulateItems(button.category)

    self.ActiveCategory = button.category
end

local BLACK_BG = Color( 0, 0, 0, 100 )

function INVENTORY_UI:ItemSetup()
    if not IsValid( self:getPlayer() ) then return end

    self.items:Clear()

    self.itemScrollPanel = self.items:Add( "DScrollPanel" )
    self.itemScrollPanel:Dock( FILL )
    self.itemScrollPanel:DockMargin( 0, 0, 0, 0 )
    self.itemScrollPanel:InvalidateParent( true )

    local sbar = self.itemScrollPanel:GetVBar()

    local GREY_BG = Color( 40, 40, 40 )

	function sbar:Paint( w, h )
        surface.SetDrawColor( BLACK_BG )
        surface.DrawRect( 0, 15, w, h - 30 )
	end

	sbar.btnUp.Paint = function() end
	sbar.btnDown.Paint = function() end

	function sbar.btnGrip:Paint( w, h )
        surface.SetDrawColor( GREY_BG )
        surface.DrawRect( 0, 0, w, h )
	end

    self.itemList = self.itemScrollPanel:Add( "DIconLayout" )
    self.itemList:Dock( TOP )
    self.itemList:SetTall( self.itemScrollPanel:GetTall() )
    self.itemList:InvalidateParent( true )
    self.itemList:SetSpaceX( 2 )
    self.itemList:SetSpaceY( 2 )

    self:PopulateItems()
    self.ActiveCategory = nil
end

function INVENTORY_UI:Close()
    if self.IsFading then return end

	self:SetMouseInputEnabled( false )
	self:SetKeyboardInputEnabled( false )

    self.IsFading = true
	self.alpha = self:GetAlpha()

	self:CreateAnimation( INVENTORY_FADE_TIME, {
		index = 1,
		easing = "outSine",
		target = { alpha = 0 },
		Think = function( animation, panel )
			panel:SetAlpha( panel.alpha )
		end,
		OnComplete = function( animation, panel ) panel:Remove() end
	})

	local xPos = 0
	self.characterPanel.origin = - self.characterPanel:GetWide()
    self.characterPanel:SetPos( xPos, 0 )
	self.characterPanel.currentX = xPos

	self.characterPanel:CreateAnimation( ANIM_TIME, {
		index = 1,
		easing = "inSine",
		target = { alpha = 255 },
		Think = function(animation, panel)
			panel:SetAlpha( panel.alpha )
		end
	})

	self.characterPanel:CreateAnimation( ANIM_TIME, {
		index = 2,
		easing = "inOutSine",
		target = { currentX = self.characterPanel.origin },
		Think = function(animation, panel)
			panel:SetPos( panel.currentX, select( 2, panel:GetPos() ) )
		end
	})

	xPos = select( 1, self.sections:GetPos() )
	self.sections.origin = self:GetWide()
    self.sections:SetPos( xPos, 0 )
	self.sections:NoClipping( false )

	self.sections.currentX = xPos

	self.sections:CreateAnimation( ANIM_TIME, {
		index = 2,
		easing = "inOutSine",
		target = { currentX = self.sections.origin },
		Think = function(animation, panel)
			panel:SetPos( panel.currentX, select( 2, panel:GetPos() ) )
		end
	})
end

local scrW, scrH = ScrW(), ScrH()
local actionW, actionH = 256, 256
local actionX, actionY = scrW / 2, scrH / 2

local logoWidth = 256 / 4
local LOGO_BACKGROUND_COLOR = Color( 25, 25, 25, 100 )

function INVENTORY_UI:Paint( w, h )
    BaseClass.Paint( self, w, h )

    if not LocalPlayer():Alive() then
        self:Close()
    end

    if input.IsKeyDown( KEY_F3 ) then
        self:Close()
    end

    if input.IsKeyDown( Monolith.Keybinds.GetBindFromName( "inventory" ):getKey() ) then
        self:Close()
    end

    if not textHasFocus and input.IsKeyDown( KEY_Q ) then
        self:Close()
    end

    if input.IsKeyDown( KEY_ESCAPE ) then
        self:Close()
    end

    if LocalPlayer():InVehicle() then
        local vVehicle = LocalPlayer():GetVehicle()

        if vVehicle:GetDriver() == LocalPlayer() and vVehicle:GetVelocity():LengthSqr() > MAX_VEHICLE_SPEED_INVENTORY then
            self:Close()
        end
    end

    local actionColor = Monolith.ActionColor
    local start, finish = Monolith.ActionStart, Monolith.ActionEnd
    local curTime = CurTime()

    if actionColor and start and finish and finish > curTime then
        local fraction = 1 - math.TimeFraction( start, finish, curTime )
        actionColor = Monolith.ActionColor
        local color = Color( actionColor.r, actionColor.g, actionColor.b, 255 )

        Monolith.DrawActionCircle( actionX + 2, actionY + 2, actionW, actionH, fraction, BLACK_BG, circleMat )
        Monolith.DrawActionCircle( actionX, actionY, actionW, actionH, fraction, color, circleMat )
    end
end

function INVENTORY_UI:OnRemove()
    Monolith.Inventory:ClearStatPreview()

	hook.Run( "Monolith.Inventory.OnInventoryClosed", self )
end

function INVENTORY_UI:OnClose()
    self:Remove()

    textHasFocus = false
end

hook.Add( "OnTextEntryGetFocus", "Monolith.Inventory", function()
    textHasFocus = true
end )

hook.Add( "OnTextEntryLoseFocus", "Monolith.Inventory", function()
    textHasFocus = false
end )

vgui.Register("psInventory", INVENTORY_UI, "psFrame")