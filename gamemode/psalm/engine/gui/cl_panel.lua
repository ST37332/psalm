local PANEL = {}

local OUTLINE_COLOR = Color(28, 28, 28, 255)

function PANEL:Init()
    self.Outline = false
end

function PANEL:SetBackground(bool)
    self.DrawBackground = bool
end

function PANEL:SetFadedBackground(bool)
    self.FadedBackground = bool
end

function PANEL:SetOutline(bEnable)
    self.Outline = bEnable
end

local gradient = Material( "gui/gradient" )
function PANEL:Paint(w, h)
    if self.DrawBackground == false then return end

    if not self.FadedBackground then
        surface.SetDrawColor( 50, 50, 50, 100 )
        surface.DrawRect( 0, 0, w, h )

        if (self.Outline) then
            surface.SetDrawColor(OUTLINE_COLOR)
            surface.DrawOutlinedRect(0, 0, w, h)
        end

    else
        surface.SetDrawColor( 0, 0, 0, 100 )
        surface.SetMaterial( gradient )
        surface.DrawTexturedRect( 0, 0, w, h )

        surface.SetDrawColor( 50, 50, 50, 50 )
        surface.SetMaterial( gradient )
        surface.DrawTexturedRect( 0, - w / 2, w * 2, h )

        if (self.Outline) then
            surface.SetDrawColor(OUTLINE_COLOR)
            surface.DrawOutlinedRect(0, 0, w, h)
        end

    end
end

vgui.Register("psPanel", PANEL, "DPanel")
