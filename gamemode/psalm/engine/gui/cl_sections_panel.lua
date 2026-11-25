local PANEL = {}

--[[
    psSectionsPanel

    functions:
        @TODO: documentate
]]--

local gradient = Material("vgui/gradient-r")

function PANEL:Init()
    self:GetParent():InvalidateParent( true )
    self:InvalidateParent( true )
end

local SECTION_SIZE = 76 * ( ScrH() < 900 and 0.7 or 1 )

function PANEL:Setup()
    self.sectionContainer = self:Add( "psPanel" )
    self.sectionContainer:Dock( RIGHT )
    self.sectionContainer:DockMargin( 0, 38, 0, 0 )
    self.sectionContainer:DockPadding( 8, 16, 0, 0 )
    self.sectionContainer:SetWide( SECTION_SIZE + 14 - 8 )
    self.sectionContainer:SetBackground( false )
    self.sectionContainer:InvalidateParent( true )

    self.sectionContainer.Paint = function( this, w, h )
        if GetConVar( "developer" ):GetInt() == 1 then
            draw.OutlinedBox( 0, 0, w, h, 2, Color( 255, 0, 0, 100 ) )

            surface.SetDrawColor( 255, 0, 0, 150 )
            surface.DrawRect( 2, 2, w - 4, h - 4 )
        end

        -- surface.SetDrawColor( 0, 0, 0, 100 )
        -- surface.SetMaterial( gradient )
        -- surface.DrawTexturedRect( 0, 0, w, h )

        -- surface.SetDrawColor( 50, 50, 50, 50 )
        -- surface.SetMaterial( gradient )
        -- surface.DrawTexturedRect( 0, - w / 2, w * 2, h )
    end

	local headerColor = GAMEMODE.ThemeColor:SetAlpha( 255 )

	self.HeaderTextWidth = 32

	self.header = self:Add( "Panel" )
	self.header:Dock( TOP )
	self.header:SetTall( 48 )

	self.SmoothRotationAmount = 0

    local cColor = Color( 200, 200, 200, 255 )
    local FALLBACK_SECTION_COLOR = Psalm.Colors( "dimgray" )
	self.header.Paint = function( this, w, h )
		local objSize = h

		if not self.CurrentSectionMaterial then return end

        local glowColor = self.CurrentSectionColor or FALLBACK_SECTION_COLOR

		surface.SetMaterial( self.CurrentSectionMaterial )
		surface.SetDrawColor( cColor )
		surface.DrawTexturedRectRotated( ( w / 2 ) - ( self.HeaderTextWidth / 2 ) - ( objSize / 2 ) - 8, h / 2, objSize, objSize, self.SmoothRotationAmount )
	end

    self.sectionHeader = self.header:Add( "psHeader" )
	self.sectionHeader:Dock( FILL )
    self.sectionHeader:SetText( "" )
    self.sectionHeader:SetFont( Psalm.Fonts.DIN_Pro_40_BOLD )
    self.sectionHeader:DockMargin( 8, -8, 0, 0 )
    self.sectionHeader:SetContentAlignment( 5 )
    self.sectionHeader:SizeToContents()
    self.sectionHeader:InvalidateParent( true )
    self.sectionHeader:SetColor( headerColor )

    self.contentScroll = self:Add( "psPanel" )
    self.contentScroll:Dock( FILL )
    self.contentScroll:DockMargin( 8, 6, 0, 0 )
    self.contentScroll:SetBackground( false )
    self.contentScroll:InvalidateParent( true )

    self.contentScroll.Paint = function( this, w, h )
        if GetConVar( "developer" ):GetInt() == 1 then
            draw.OutlinedBox( 0, 0, w, h, 2, Color( 0, 255, 0, 100 ) )
            
            surface.SetDrawColor( 255, 0, 0, 150 )
            surface.DrawRect( 2, 2, w - 4, h - 4 )
        end
    end

    self:InvalidateLayout()

    self.sections = {}
    self.buttons = {}
end

function PANEL:SetSubHeaderText( text )

end

function PANEL:OnClose()
    self:Remove()
end

function PANEL:SetSectionText( text )
    self.sectionHeader:SetText( text )

	surface.SetFont( Psalm.Fonts.DIN_Pro_40_BOLD )
	self.HeaderTextWidth = select( 1, surface.GetTextSize( text ) )
end


local glowMat = Material( "mrp/spherical_gradient.png" )
local roundedSquare = Material( "mrp/square_rounded.png" )

local CMB_ITEM = Material( "icons/inventory/cmb_item.png" )
local CMB_ITEM_COLOR = Color( 50, 50, 50 )
local CMB_POLY = Material( "icons/inventory/cmb_poly.png" )

function PANEL:AddSectionButton( data )
    if data.extraData and data.extraData.noButton then return end

    local button = self.sectionContainer:Add( "psImage" )
    button:Dock( data.extraData and data.extraData.bottom and BOTTOM or TOP )
    button:DockMargin( 0, 0, 0, 2 )
    button:SetTall( SECTION_SIZE )
    button:SetImage( data.icon )

    if data.extraData and data.extraData.glowColor then
        button:SetGlowColor( data.extraData.glowColor )
    end

    button.DoClick = function( this )
        self:OpenSection( data )
    end

    button.LerpPos = 10
    button.Paint = function( self, w, h )
        local color = self.drawColor or color_white
        color = Color( color.r, color.g, color.b, self.active and 255 or self:IsDown() and 255 or self:IsHovered() and 200 or 150 )

        local glowColor = self.glowColor or Psalm.Colors( "DimGray" )
        self.LerpPos = Lerp( FrameTime() * 6, self.LerpPos, self.active and 15 or 10 )

        if self.active then glowColor = Psalm.Colors( "WhiteSmoke" ) end
        
        surface.SetDrawColor( CMB_ITEM_COLOR )
        surface.SetMaterial( CMB_ITEM )
        surface.DrawTexturedRect( 0, 0, w, h )

        surface.SetDrawColor( glowColor:SetAlpha( 120 ) )
        surface.SetMaterial( CMB_POLY )
        surface.DrawTexturedRect( 0, 0, w, h )

        local localToScreenX, localToScreenY = self:LocalToScreen( 0, 0 )
        
        -- render.SetScissorRect( localToScreenX + 1, localToScreenY + 1, localToScreenX + w - 2, localToScreenY + h - 2, true ) -- Enable the rect
        --     surface.SetDrawColor( glowColor:SetAlpha( 50 ) )
        --     surface.SetMaterial( glowMat )
        --     surface.DrawTexturedRect( ( 0 - ( w / 3 ) ) , ( 0 - ( h / 3 ) ) , ( w * 3 ) , ( h * 3 ) )
        -- render.SetScissorRect( 0, 0, 0, 0, false ) -- Disable after you are done

        surface.SetDrawColor( color )
        surface.SetMaterial( self.image )
        surface.DrawTexturedRect( 16, 16, w - 32, h - 32 )

        -- draw.OutlinedBox( 0, 0, w, h, 2, glowColor:SetAlpha( 60 ) )
    end

    button.IsSection = true -- d&d support

    self.buttons[ data.name ] = button

    if data.extraData and data.extraData.default then
        self:OpenSection( data )
    end

    return button
end

function PANEL:AddSection( name, icon, callback, canDo, extraData )
    local data = {
        name = name,
        icon = Material( icon, "smooth" ),
        callback = callback or function() end,
        canDo = canDo or function() return true end,
        extraData = extraData
    }

    if canDo and not canDo() then return end

    self.sections[ name ] = data
    return self:AddSectionButton( data )
end

function PANEL:GetSection( name )
    return self.sections[ name ]
end

function PANEL:OpenSection( nameOrData, bForce )
    local section = istable( nameOrData ) and nameOrData or self:GetSection( nameOrData )
    if not section then return end

    -- Don't open the same section. Why do that anyway?
    if not bForce and self.currentSectionData == section then return end

    if not section.canDo() then return end

    local sectionButton = self.buttons[ section.name ]

    if self.currentSectionData then
        if self.currentSectionData.extraData and self.currentSectionData.extraData.onClose then
            self.currentSectionData.extraData.onClose( self.currentSectionButton )
        end
    end

    for _, button in pairs( self.buttons ) do
        if button == sectionButton then continue end

        if not IsValid( button ) then continue end

        button:SetActive( false )
    end

    if sectionButton then
        sectionButton:SetActive( true )
    end

    self.currentSection = section.name
    self.currentSectionData = section
    self.currentSectionButton = sectionButton

    self.contentScroll:Clear()
    self:SetSectionText( section.name:utf8upper() )

	self.CurrentSectionMaterial = section.icon
	self.CurrentSectionColor = section.extraData.glowColor

    return section.callback( self.contentScroll )
end

function PANEL:Paint( this, w, h )

end

vgui.Register( "psSectionsPanel", PANEL, "Panel" )
