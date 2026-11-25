function DrawBlur(panel, amount, passes, alpha)
    -- Intensity of the blur.
    amount = amount or 5

    if not useBlur then
        surface.SetDrawColor(50, 50, 50, amount * 20)
        surface.DrawRect(0, 0, panel:GetWide(), panel:GetTall())
    else
        surface.SetMaterial(blur)
        surface.SetDrawColor(255, 255, 255, alpha or 255 )

        local x, y = panel:LocalToScreen(0, 0)

        for i = -(passes or 0.2), 1, 0.2 do
            -- Do things to the blur material to make it blurry.
            blur:SetFloat("$blur", i * amount)
            blur:Recompute()

            -- Draw the blur material over the screen.
            render.UpdateScreenEffectTexture()
            surface.DrawTexturedRect(x * -1, y * -1, ScrW(), ScrH())
        end
    end
end

function DrawBlurAt(x, y, w, h, amount, passes)
    -- Intensity of the blur
    amount = amount or 5

    if not useBlur then
        surface.SetDrawColor(30, 30, 30, amount * 20)
        surface.DrawRect(x, y, w, h)
    else
        surface.SetMaterial(blur)
        surface.SetDrawColor(255, 255, 255)

        local scrW, scrH = ScrW(), ScrH()
        local x2, y2 = x / scrW, y / scrH
        local w2, h2 = (x + w) / scrW, (y + h) / scrH

        for i = -(passes or 0.2), 1, 0.2 do
            blur:SetFloat("$blur", i * amount)
            blur:Recompute()

            render.UpdateScreenEffectTexture()
            surface.DrawTexturedRectUV(x, y, w, h, x2, y2, w2, h2)
        end
    end
end


local FRAME = {}

function FRAME:Init()
    self:StretchToParent( 0, 0, 0, 0 )
    self:SetTitle( "" )
    self:ShowCloseButton( false )

    self.startTime = CurTime()

    -- Add "CLOSE X"
    self:ShowQuit()
end

function FRAME:HideQuit()
    if IsValid( self.QuitButton ) then self.QuitButton:Remove() end
end

function FRAME:ShowQuit()
    self:HideQuit()

    self.QuitButton = self:Add( "psButton" )
    self.QuitButton:SetSize( 96, 32 )
    self.QuitButton:SetPos( self:GetWide() - self.QuitButton:GetWide(), 0 )
    self.QuitButton:SetText( L( "kernel.ui.elements.close" ) )
    self.QuitButton.DoClick = function()
        self:Close()
    end
end

local MAT_SHADOWS = Material( "logos/syn_bannerlogo.png", "smooth" )
local MAT_BACKGROUND = Material( "mrp/menu_stuff/bg_grunge.png", "noclamp smooth" )
local MAT_VIGNETTE = Material( "mrp/menu_stuff/vignette.png" , "noclamp smooth" )
local VIGNETTE_ISERROR = MAT_VIGNETTE:IsError()

function FRAME:Paint( w, h )
    self.Alpha = Lerp( FrameTime() * 6, self.Alpha or ( self.StartingAlpha or 0 ), self.TargetAlpha or 150 )

    if not self.DisableVignette and not VIGNETTE_ISERROR then
        surface.SetDrawColor( 255, 255, 255 )
        surface.SetMaterial( MAT_VIGNETTE )
        surface.DrawTexturedRect( 0, 0, w, h )
    end

    if not self.DisableBlur then
        --Derma_DrawBackgroundBlur( self, self.startTime )
        DrawBlur( self, 2, 3 )
    end

    if not self.DisableBackground then
        surface.SetMaterial( MAT_BACKGROUND )
        surface.SetDrawColor( GAMEMODE.ThemeColor:SetAlpha( self.Alpha ) )
        surface.DrawTexturedRect( 0, 0, w, h )
    end

    if not self.DisableShadows then
        surface.SetMaterial( MAT_SHADOWS )
        surface.SetDrawColor( Psalm.Colors( "dimgray" ):SetAlpha( 50 ) )
        surface.DrawTexturedRectRotated( w / 2, h - 50, 512, 128, 0 )
    end
end

vgui.Register( "psFrame", FRAME, "DFrame" )

local SCROLL = {}

local gradientUp = Material( "vgui/gradient-u" )
local gradientDown = Material( "vgui/gradient-d" )

function SCROLL:Init()
	local vBar = self:GetVBar()

	vBar.Paint = function() end
	vBar.btnUp.Paint = function() end
	vBar.btnDown.Paint = function() end

	vBar.btnGrip.Paint = function( this, w, h )
		this.GripColorTarget = vBar.Dragging and 150 or this:IsHovered() and 125 or 75

		this.CurrentColor = Lerp( CurTime() * 2, this.CurrentColor, this.GripColorTarget )
		local col = Color( this.CurrentColor, this.CurrentColor, this.CurrentColor )

		surface.SetDrawColor( col )
		surface.SetMaterial( gradientDown )
		surface.DrawTexturedRect( w - 4, 0, 4, h / 2 )

		surface.SetDrawColor( col )
		surface.SetMaterial( gradientUp )
		surface.DrawTexturedRect( w - 4, h / 2, 4, h / 2 )
	end
end

vgui.Register( "psScrollPanel", SCROLL, "DScrollPanel" )
