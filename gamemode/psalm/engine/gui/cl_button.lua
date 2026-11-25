local BUTTON_ALPHA = 100
local BUTTON_SELECTED_ALPHA = 255

local BUTTON_REGULAR_COLOR = Color(29, 28, 30, BUTTON_ALPHA)
local BUTTON_HOVERED_COLOR = Color(29, 28, 30, BUTTON_SELECTED_ALPHA)
local BUTTON_PRESSED_COLOR = Color(39, 38, 40, BUTTON_SELECTED_ALPHA)
local BUTTON_ACTIVE_TIP_COLOR = Color(0, 125, 255, BUTTON_SELECTED_ALPHA)

local BUTTON_TEXT_ALPHA = 100
local BUTTON_ACTIVE_TEXT_ALPHA = 255

local BUTTON_TEXT_COLOR = Psalm.Color.white
local BUTTON_HOVERED_TEXT_COLOR = Color(225, 225, 225)
local BUTTON_PRESSED_TEXT_COLOR = Color(200, 200, 200)

local BUTTON_OUTLINE_COLOR = Color(28, 28, 28, 255)

local BUTTON = {}

function BUTTON:Init()
    self:SetFont( Psalm.Fonts.DIN_Pro_22 )
    self.Outline = false
end

function BUTTON:SetColor(color)
    self.buttonColor = color
end

function BUTTON:SetHoveredColor(color)
    self.hoveredColor = color
end

function BUTTON:SetPressedColor(color)
    self.pressedColor = color
end

function BUTTON:SetOutline(bEnabled)
    self.Outline = bEnabled
end

function BUTTON:SetOutlineColor(color)
    self.OutlineColor = color
end

function BUTTON:SetActive( bool )
    self.active = bool
end

function BUTTON:GetColor()
    return self.buttonColor
end

function BUTTON:GetActive()
    return self.active
end

function BUTTON:ForceColor(c)
    self.SColor = c
end

function BUTTON:Paint(w, h)
    local color
    if self:IsHovered() then
        color = self.hoveredColor or BUTTON_HOVERED_COLOR
    elseif self.active then
        color = self.hoveredColor or BUTTON_HOVERED_COLOR
    elseif self:IsDown() then
        color = self.pressedColor or BUTTON_PRESSED_COLOR
    else
        color = self.buttonColor or BUTTON_REGULAR_COLOR
    end

    self.curColor = color

    surface.SetDrawColor(color)
    surface.DrawRect(0, 0, w, h)

    local textAlpha = self.active and BUTTON_ACTIVE_ALPHA
        or self:IsHovered() and BUTTON_ACTIVE_TEXT_ALPHA
            or self:IsDown() and BUTTON_ACTIVE_TEXT_ALPHA
                or BUTTON_TEXT_ALPHA

    local textColor = self.textColorOverride or self.active and self:IsDown() and BUTTON_PRESSED_TEXT_COLOR or self:IsHovered() and BUTTON_HOVERED_TEXT_COLOR or BUTTON_TEXT_COLOR
    self:SetTextColor(Color(textColor.r, textColor.g, textColor.b, textAlpha))
    if (self.SColor) then
        self:SetTextColor(self.SColor)
    end

    if self.active then
        surface.SetDrawColor( BUTTON_ACTIVE_TIP_COLOR )
        surface.DrawRect( 0, 0, 2, h )
    elseif self.tip then
        surface.SetDrawColor( self.tip )
        surface.DrawRect( 0, h - 2, w, 2 )
    end

    if (self.Outline) then
        surface.SetDrawColor(self.OutlineColor or BUTTON_OUTLINE_COLOR)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
end

vgui.Register("psButton", BUTTON, "DButton")