local BUTTON = {}

function BUTTON:Init()

end

local gradient = Material( "gui/gradient" )
function BUTTON:Paint(w, h)
    surface.SetDrawColor( 0, 0, 0, 100 )
    surface.SetMaterial( gradient )
    surface.DrawTexturedRect( 0, 0, w, h )

    surface.SetDrawColor( 50, 50, 50, 50 )
    surface.SetMaterial( gradient )
    surface.DrawTexturedRect( 0, - w / 2, w * 2, h )
end

vgui.Register("psButtonFade", BUTTON, "psButton")
