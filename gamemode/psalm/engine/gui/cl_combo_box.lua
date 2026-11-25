local OPTIONS = {}

local OPTION_HEIGHT = 50

OPTIONS.IsPsalmOption = true

function OPTIONS:Init()
    self:SetPos( self:FindValidPos() )
    self:SetWide( 300 )
    self:MakePopup()

    self.Layout = self:Add( "DIconLayout" )
    self.Layout:Dock( FILL )

    self.HackTimer = CurTime() + 0.25

    self.Options = {}
end

-- @TODO: Add this to Psalmsuite
function OPTIONS:FindValidPos()
    local cursorPosX, cursorPosY = input.GetCursorPos()
    local screenResX, screenResY = ScrW(), ScrH()
    local width = self:GetWide()
    local realPosX = math.min( screenResX - width, cursorPosX )
    local realPosY = math.min( screenResY - self:GetTall(), cursorPosY )

    return realPosX, realPosY
end

function OPTIONS:Paint( w, h )
	if self.HackTimer > CurTime() then return end

	if not self:HasFocus() then self:Remove() end

    if input.IsMouseDown( MOUSE_LEFT ) and not vgui.GetHoveredPanel().IsPsalmOption then
		self:Remove()
	end

    if input.IsMouseDown( MOUSE_RIGHT ) then
		self:Remove()
    end
end

function OPTIONS:SetPanel( pPanel )
    self.ThisPanel = pPanel
end

function OPTIONS:AddCloseOption()
    self:AddOption("Close", function( this )
        self:Remove()
    end, Color( 0, 255, 0 ) )
end

function OPTIONS:AddOption( sText, fDoClick, cColor, fDoHover )
    self:SetTall( self:GetTall() + OPTION_HEIGHT )

    local item = vgui.Create( "psOptionButton", self.Layout )

    item:Setup( sText, fDoClick, cColor, fDoHover )
    item.OptionsPanel = self

    item.ThisPanel = self.ThisPanel

    self.OptionIndex = ( self.OptionIndex or 0 ) + 1

    if self.OptionIndex == 1 then
        item.IsFirst = true
    end

    for k, v in pairs( self.Options ) do
        if k > 1 then
            v.IsLast = nil
        end
    end

    if not item.IsFirst then
        item.IsLast = true
    end

    table.insert( self.Options, item )

    -- update position if we need to
    self:SetPos( self:FindValidPos() )

    return item
end

vgui.Register( "psOptions", OPTIONS, "Panel" )

local OPTION = {}

OPTION.IsPsalmOption = true

surface.CreateFont( "psOption", {
    font = "DIN Pro Regular",
    size = 20,
    weight = 200,
    antialias = true
} )

function OPTION:Init()
    self:Dock( TOP )
    self:DockMargin( 0, 0, 0, 0 )
    --self:TDLib():Stick( TOP, 0 )
    --    :HoverCircle()

    self:SetTall( 50 )

    self:SetText( "MY OPTION" )
    self:SetFont( "psOption" )
    self:SetContentAlignment( 4 )
    self:SetTextInset( 24, 0 )
end

function OPTION:Setup( sText, fDoClick, cColor, fDoHover )
    sText = sText:utf8upper()

    self:SetText( sText )

    self.DoClick = function( this )
        if fDoClick then
            fDoClick( this )

            if IsValid( self.ThisPanel ) and self.ThisPanel:IsVisible() then
                -- self.ThisPanel:MakePopup()
            else
                self.OptionsPanel:SetMouseInputEnabled( false )
                self.OptionsPanel:SetKeyboardInputEnabled( false )
            end

            self.OptionsPanel:Remove()
        end
    end

    self.fnStartHover = fDoHover
end

local FIRST_PACKAGE = { true, true, false, false }
local LAST_PACKAGE = { false, false, true, true }
local DEFAULT_PACKAGE = { false, false, false, false }

function OPTION:Paint( w, h )
    local color = self.Color or Color( 45, 45, 45 )
    color = color:Lighten( self:IsDown() and 0.05 or self:IsHovered() and 0.01 or 0 )

    draw.RoundedBoxEx( 4, 0, 0, w, h, color, unpack( self.IsFirst and FIRST_PACKAGE or self.IsLast and LAST_PACKAGE or DEFAULT_PACKAGE ) )

    if not self.IsFirst then
        surface.SetDrawColor( 60, 60, 60 )
        surface.DrawRect( 0, 0, w, 1 )
    end

    self:SetTextColor( self:IsHovered() and Color( 255, 255, 255 ) or Color( 200, 200, 200 ) )

    if self:IsHovered() and not self.CurrentlyHovered then
        self.CurrentlyHovered = true
        if self.fnStartHover then self:fnStartHover( ) end
    elseif not self:IsHovered() and self.CurrentlyHovered then
        self.CurrentlyHovered = false
    end
end

vgui.Register( "psOptionButton", OPTION, "psButton" )

function PsalmOptions( Panel )
    local pMenu = vgui.Create( "psOptions" )
    pMenu:SetPanel( Panel )

    return pMenu
end