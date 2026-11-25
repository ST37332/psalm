Psalm.Fonts = Psalm.Fonts or {}

local Fonts = {}
local Font = Psalm.Fonts
local function foundError(sErr)
	ErrorNoHalt("[Fonts]: Failed to create font: " .. sErr .. "\n")
	debug.Trace()
end

function Font:Register( args )
    if not args then foundError("missing args") return end
	if not args.font then foundError("missing font name") return end
	if not args.size then foundError("missing font size") return end

    local fontArgs = {
    	font = args.font,
    	extended = args.extended,
    	size = args.size,
    	weight = args.weight,
    	blursize = args.blursize,
    	scanlines = args.scanlines,
    	antialias = args.antialias,
    	underline = args.underline,
    	italic = args.italic,
    	strikeout = args.strikeout,
    	symbol = args.symbol,
    	rotary = args.rotary,
    	shadow = args.shadow,
    	additive = args.additive,
    	outline = args.outline
    }

    local fntName = ""
	local isFirst = true
	for name, var in pairs( fontArgs ) do
		fntName = fntName .. ( isbool( var ) and ( ( isFirst and "" or "_" ) .. name ) or ( ( isFirst and "" or "_" ) .. var ) )
		isFirst = false
	end

	if Fonts[ fntName ] then
        ErrorNoHalt( "[Fonts]: Failed to create font as it already exists (" .. fntName ..")" )
	end

	Fonts[ fntName ] = true

    surface.CreateFont( fntName, fontArgs )

	return fntName
end

-- Regular UI Fonts

local LIGHT_FONT = "DIN Pro Light"
local LIGHT_ITALIC_FONT = "DIN Pro Light Italic"

local MEDIUM_FONT = "DIN Pro Medium"
local MEDIUM_ITALIC_FONT = "DIN Pro Medium Italic"

local REGULAR_FONT = "DIN Pro"
local ITALIC_FONT = "DIN Pro Italic"

local BOLD_FONT = "DIN Pro Bold"
local BOLD_ITALIC_FONT = "DIN Pro Bold Italic"

local BLACK_FONT = "DIN Pro Black"
local BLACK_ITALIC_FONT = "DIN Pro Black Italic"

Font:Registers.DIN_Pro_128 = Font:Register({
    font = REGULAR_FONT,
    size = 128
})

Font:Registers.DIN_Pro_128_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 128
})

Font:Registers.DIN_Pro_100 = Font:Register({
    font = REGULAR_FONT,
    size = 100
})

Font:Registers.DIN_Pro_90_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 100
})

Font:Registers.DIN_Pro_86_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 86
})

Font:Registers.DIN_Pro_86 = Font:Register({
    font = REGULAR_FONT,
    size = 86
})

Font:Registers.DIN_Pro_80 = Font:Register({
    font = REGULAR_FONT,
    size = 80
})

Font:Registers.DIN_Pro_80_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 80
})

Font:Registers.DIN_Pro_72 = Font:Register({
    font = REGULAR_FONT,
    size = 72
})

Font:Registers.DIN_Pro_66_shadow = Font:Register({
    font = REGULAR_FONT,
    size = 66,
	shadow = true
})

Font:Registers.DIN_Pro_66_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 66
})

Font:Registers.DIN_Pro_64 = Font:Register({
    font = REGULAR_FONT,
    size = 64
})

Font:Registers.DIN_Pro_64_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 64
})

Font:Registers.DIN_Pro_62 = Font:Register({
    font = REGULAR_FONT,
    size = 62
})

Font:Registers.DIN_Pro_62_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 62
})

Font:Registers.DIN_Pro_56_BOLD_Shadow = Font:Register({
    font = BOLD_FONT,
    size = 56,
	shadow = true
})

Font:Registers.DIN_Pro_52 = Font:Register({
    font = REGULAR_FONT,
    size = 52
})

Font:Registers.DIN_Pro_50_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 50,
	shadow = true
})

Font:Registers.DIN_Pro_50_500 = Font:Register({
    font = REGULAR_FONT,
    size = 50,
    weight = 500,
	shadow = true
})

Font:Registers.DIN_Pro_50 = Font:Register({
    font = REGULAR_FONT,
    size = 50
})

Font:Registers.DIN_Pro_56_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 56
})

Font:Registers.DIN_Pro_48 = Font:Register({
    font = REGULAR_FONT,
    size = 48
})

Font:Registers.DIN_Pro_48_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 48
})

Font:Registers.DIN_Pro_45 = Font:Register({
    font = REGULAR_FONT,
    size = 45
})

Font:Registers.DIN_Pro_42 = Font:Register({
    font = REGULAR_FONT,
    size = 42
})


Font:Registers.DIN_Pro_42_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 42
})

Font:Registers.DIN_Pro_42_blur = Font:Register({
    font = REGULAR_FONT,
    size = 42,
	blursize = 4
})

Font:Registers.DIN_Pro_40 = Font:Register({
    font = REGULAR_FONT,
    size = 40
})

Font:Registers.DIN_Pro_40_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 40
})

Font:Registers.DIN_Pro_40_ITALIC = Font:Register({
    font = ITALIC_FONT,
    size = 40
})

Font:Registers.DIN_Pro_38 = Font:Register({
    font = REGULAR_FONT,
    size = 38
})

Font:Registers.DIN_Pro_38_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 38
})

Font:Registers.DIN_Pro_36 = Font:Register({
    font = REGULAR_FONT,
    size = 36
})

Font:Registers.DIN_Pro_36_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 36,
})

Font:Registers.DIN_Pro_32 = Font:Register({
    font = REGULAR_FONT,
    size = 32
})

Font:Registers.DIN_Pro_32_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 32
})

Font:Registers.DIN_Pro_32_Italics = Font:Register({
    font = REGULAR_FONT,
    size = 32,
    italic = true
})

Font:Registers.DIN_Pro_32_BOLD_ITALIC = Font:Register({
    font = BOLD_ITALIC_FONT,
    size = 32,
    italic = true
})

Font:Registers.DIN_Pro_32_Shadow = Font:Register({
    font = REGULAR_FONT,
    size = 32,
	shadow = true
})

Font:Registers.DIN_Pro_30 = Font:Register({
    font = REGULAR_FONT,
    size = 30
})

Font:Registers.DIN_Pro_28 = Font:Register({
    font = REGULAR_FONT,
    size = 28
})

Font:Registers.DIN_Pro_28_Italics = Font:Register({
    font = REGULAR_FONT,
    size = 28,
    italic = true
})

Font:Registers.DIN_Pro_28_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 28
})

Font:Registers.DIN_Pro_28_Blur = Font:Register({
    font = REGULAR_FONT,
    size = 28,
	blursize = 3
})

Font:Registers.DIN_Pro_26 = Font:Register({
    font = REGULAR_FONT,
    size = 26
})

Font:Registers.DIN_Pro_25 = Font:Register({
    font = REGULAR_FONT,
    size = 25
})

Font:Registers.DIN_Pro_24 = Font:Register({
    font = REGULAR_FONT,
    size = 24
})

Font:Registers.DIN_Pro_24_italic = Font:Register({
    font = ITALIC_FONT,
    size = 24,
	italic = true
})

Font:Registers.DIN_Pro_24_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 24
})

Font:Registers.DIN_Pro_24_outline = Font:Register({
    font = REGULAR_FONT,
    size = 24,
	outline = true
})

Font:Registers.DIN_Pro_24_Shadow = Font:Register({
    font = REGULAR_FONT,
    size = 24,
	shadow = true
})

Font:Registers.DIN_Pro_22_BOLD_ITALIC = Font:Register({
    font = BOLD_ITALIC_FONT,
    size = 22
})

Font:Registers.DIN_Pro_22_ITALIC = Font:Register({
    font = ITALIC_FONT,
    size = 22
})

Font:Registers.DIN_Pro_24_Blur = Font:Register({
    font = REGULAR_FONT,
    size = 24,
	blursize = .5
})

Font:Registers.DIN_Pro_23 = Font:Register({
    font = REGULAR_FONT,
    size = 23
})

Font:Registers.DIN_Pro_22 = Font:Register({
    font = REGULAR_FONT,
    size = 22
})

Font:Registers.DIN_Pro_22_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 22
})

Font:Registers.DIN_Pro_22_Blur = Font:Register({
    font = REGULAR_FONT,
    size = 22,
	blursize = 2
})

Font:Registers.DIN_Pro_20_Blur = Font:Register({
    font = REGULAR_FONT,
    size = 20,
	blursize = .5
})

Font:Registers.DIN_Pro_22_20_antialias_shadow_additive_outline = Font:Register({
	font = REGULAR_FONT,
	size = 22,
	weight = 400,
	shadow = true
})

Font:Registers.DIN_Pro_22_20 = Font:Register({
	font = REGULAR_FONT,
	size = 22,
	weight = 20
})

Font:Registers.DIN_Pro_22_500 = Font:Register({
	font = REGULAR_FONT,
	size = 22,
	weight = 500
})

Font:Registers.DIN_Pro_21 = Font:Register({
    font = REGULAR_FONT,
    size = 21
})

Font:Registers.DIN_Pro_20 = Font:Register({
    font = REGULAR_FONT,
    size = 20
})

Font:Registers.DIN_Pro_20_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 20
})

Font:Registers.DIN_Pro_20_600 = Font:Register({
    font = REGULAR_FONT,
    size = 20,
	weight = 600
})

Font:Registers.DIN_Pro_20_600_italic = Font:Register({
    font = REGULAR_FONT,
    size = 20,
	italic = true,
	weight = 600
})

Font:Registers.DIN_Pro_20_BOLD_italic_strikeout = Font:Register({
    font = BOLD_ITALIC_FONT,
    size = 20,
	strikeout = true
})

Font:Registers.DIN_Pro_19 = Font:Register({
    font = REGULAR_FONT,
    size = 19
})

Font:Registers.DIN_Pro_18 = Font:Register({
    font = REGULAR_FONT,
    size = 18
})

Font:Registers.DIN_Pro_18_Blur = Font:Register({
    font = REGULAR_FONT,
    size = 18,
    blursize = 3
})

Font:Registers.DIN_Pro_17_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 17
})

Font:Registers.DIN_Pro_17_italic = Font:Register({
    font = REGULAR_FONT,
    size = 17,
    italic = true,
})

Font:Registers.DIN_Pro_17 = Font:Register({
    font = REGULAR_FONT,
    size = 17
})

Font:Registers.DIN_Pro_16 = Font:Register({
    font = REGULAR_FONT,
    size = 16
})

Font:Registers.DIN_Pro_16_italic_strikeout = Font:Register({
    font = REGULAR_FONT,
    size = 16,
	italic = true,
	strikeout = true
})

Font:Registers.DIN_Pro_15 = Font:Register({
    font = REGULAR_FONT,
    size = 15
})

Font:Registers.DIN_Pro_15_blur = Font:Register({
    font = REGULAR_FONT,
    size = 15,
	blursize = 3
})

Font:Registers.DIN_Pro_15_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 15
})

Font:Registers.DIN_Pro_14 = Font:Register({
    font = REGULAR_FONT,
    size = 14
})

Font:Registers.DIN_Pro_13_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 13
})

Font:Registers.DIN_Pro_13 = Font:Register({
    font = REGULAR_FONT,
    size = 13
})

Font:Registers.DIN_Pro_12 = Font:Register({
    font = REGULAR_FONT,
    size = 12
})

Font:Registers.DIN_Pro_11 = Font:Register({
    font = REGULAR_FONT,
    size = 11
})

Font:Registers.DIN_Pro_11_BOLD = Font:Register({
    font = BOLD_FONT,
    size = 11
})

Font:Registers.DIN_Pro_10 = Font:Register({
    font = REGULAR_FONT,
    size = 10
})

-- Civic Terminal Fonts

Font:Registers.BoxLight12 = Font:Register({
    font = "BoxedRoundLight",
    size = 12,
    weight = 400
})

Font:Registers.BoxLight13 = Font:Register({
    font = "BoxedRoundLight",
    size = 13,
    weight = 400
})

Font:Registers.BoxLight14 = Font:Register({
    font = "BoxedRoundLight",
    size = 15,
    weight = 400
})

Font:Registers.BoxLight16 = Font:Register({
    font = "BoxedRoundLight",
    size = 16,
    weight = 400
})

Font:Registers.BoxLight17 = Font:Register({
    font = "BoxedRoundLight",
    size = 17,
    weight = 400
})

Font:Registers.BoxLight18 = Font:Register({
    font = "BoxedRoundLight",
    size = 18,
    weight = 400
})

Font:Registers.BoxLight19 = Font:Register({
    font = "BoxedRoundLight",
    size = 19,
    weight = 400
})

Font:Registers.BoxLight20 = Font:Register({
    font = "BoxedRoundLight",
    size = 20,
    weight = 400
})

Font:Registers.BoxLight21 = Font:Register({
    font = "BoxedRoundLight",
    size = 21,
    weight = 400
})

Font:Registers.BoxLight22 = Font:Register({
    font = "BoxedRoundLight",
    size = 22,
    weight = 400
})

Font:Registers.BoxLight23 = Font:Register({
    font = "BoxedRoundLight",
    size = 23,
    weight = 400
})

Font:Registers.BoxLight24 = Font:Register({
    font = "BoxedRoundLight",
    size = 24,
    weight = 400
})

Font:Registers.BoxLight25 = Font:Register({
    font = "BoxedRoundLight",
    size = 25,
    weight = 400
})

Font:Registers.BoxLight26 = Font:Register({
    font = "BoxedRoundLight",
    size = 26,
    weight = 400
})

Font:Registers.BoxLight27 = Font:Register({
    font = "BoxedRoundLight",
    size = 27,
    weight = 400
})

Font:Registers.BoxLight28 = Font:Register({
    font = "BoxedRoundLight",
    size = 28,
    weight = 400
})

Font:Registers.BoxLight29 = Font:Register({
    font = "BoxedRoundLight",
    size = 29,
    weight = 400
})

Font:Registers.BoxLight30 = Font:Register({
    font = "BoxedRoundLight",
    size = 30,
    weight = 400
})

Font:Registers.BoxLight40 = Font:Register({
    font = "BoxedRoundLight",
    size = 40,
    weight = 400
})

Font:Registers.BoxLight50 = Font:Register({
    font = "BoxedRoundLight",
    size = 50,
    weight = 400
})

-- Combine Fonts
Font:Registers.BudgetLabelOrig = Font:Register({
    font = "BoxedRoundLight",
    size = 14,
    weight = 400,
    outline = true
})

Font:Registers.BudgetLabelMono = Font:Register({
    font = "OCR A Extended",
    size = 17,
    weight = 800,
    outline = true
})

Font:Registers.BudgetLabelSmallMono = Font:Register({
    font = "OCR A Extended",
    size = 10,
    weight = 800,
    outline = true
})

Font:Registers.BudgetLabel_13 = Font:Register({
    font = "BoxedRoundLight",
    size = 13,
    weight = 400,
    outline = true
})

Font:Registers.BudgetLabel_16_600 = Font:Register({
    font = "OCR A Extended",
    size = 16,
    weight = 600,
    outline = true
})

Font:Registers.BudgetLabel_20 = Font:Register({
    font = "BoxedRoundLight",
    size = 20,
    weight = 400,
    outline = true
})

Font:Registers.BudgetLabel_20_600 = Font:Register({
    font = "OCR A Extended",
    size = 20,
    weight = 600,
    outline = true
})

Font:Registers.BudgetLabel_22 = Font:Register({
    font = "BoxedRoundLight",
    size = 22,
    weight = 400,
    outline = true
})

Font:Registers.BudgetLabel_24_600 = Font:Register({
    font = "OCR A Extended",
    size = 24,
    weight = 600,
    outline = true
})

Font:Registers.BudgetLabel_36 = Font:Register({
    font = "BoxedRoundLight",
    size = 36,
    weight = 400,
    outline = true
})

-- Combine Blue fonts
Font:Registers.BudgetLabelOrig_ALT = Font:Register({
    font = "BoxedRoundLight",
    size = 14,
    weight = 400
})

Font:Registers.BudgetLabel_36_ALT = Font:Register({
    font = "BoxedRoundLight",
    size = 36,
    weight = 400
})

local fntSegoeUI = system.IsOSX() and "Trebuchet" or "Segoe UI"
Font:Registers.SegoeUI_26 = Font:Register({
    font = fntSegoeUI,
    size = 26
})

Font:Registers.SegoeUI_24 = Font:Register({
    font = fntSegoeUI,
    size = 24
})

Font:Registers.SegoeUI_18 = Font:Register({
    font = fntSegoeUI,
    size = 18
})

Font:Registers.SegoeUI_22_chatbox = Font:Register({
    font = "DIN Pro",
    size = 20,
    weight = 20,
    shadow = true,
    additive = false,
    outline = false
})

Font:Registers.SegoeUI_50_blur = Font:Register({
    font = fntSegoeUI,
    size = 50,
	blursize = .5
})

local fntOpen_24_Display_St = "LCDDot TR"
Font:Registers.Open_24_Display_St_64 = Font:Register({
    font = fntOpen_24_Display_St,
    size = 64
})

Font:Registers.Open_24_Display_St_42 = Font:Register({
    font = fntOpen_24_Display_St,
    size = 42
})

local fntDSEG13_Modern = "DSEG14 Modern"
Font:Registers.DSEG14_Modern_125 = Font:Register( {
    font = fntDSEG13_Modern,
    size = 125
} )

Font:Registers.DSEG14_Modern_35 = Font:Register( {
    font = fntDSEG13_Modern,
    size = 35
} )

-- Combine Alphabet Font

local fntCombine = "Combine_Alphabet1"

Font:Registers.Combine_60 = Font:Register {
    font = fntCombine,
    weight = 400,
    size = 60
}

Font:Registers.Combine_40 = Font:Register {
    font = fntCombine,
    weight = 400,
    size = 40
}

Font:Registers.Combine_30_O = Font:Register {
    font = fntCombine,
    weight = 400,
    size = 30,
    outline = true
}

Font:Registers.Combine_30 = Font:Register {
    font = fntCombine,
    weight = 400,
    size = 30
}

Font:Registers.Combine_24 = Font:Register {
    font = fntCombine,
    weight = 400,
    size = 24
}

Font:Registers.Combine_20 = Font:Register {
    font = fntCombine,
    weight = 400,
    size = 20
}

Font:Registers.Combine_18_O = Font:Register {
    font = fntCombine,
    weight = 400,
    size = 18,
    outline = true
}

Font:Registers.Combine_18 = Font:Register {
    font = fntCombine,
    weight = 400,
    size = 18
}

Font:Registers.Combine_16 = Font:Register {
    font = fntCombine,
    weight = 400,
    size = 16
}

Font:Registers.Combine_14 = Font:Register {
    font = fntCombine,
    weight = 0,
    size = 14,
    outline = true
}

Font:Registers.Combine_12 = Font:Register {
    font = fntCombine,
    weight = 0,
    size = 12,
    outline = true
}

Font:Registers.Combine_10 = Font:Register {
    font = fntCombine,
    weight = 0,
    size = 10
}

function draw.TextRotated( text, x, y, color, font, ang )
    render.PushFilterMag( TEXFILTER.ANISOTROPIC )
    render.PushFilterMin( TEXFILTER.ANISOTROPIC )
    surface.SetFont( font )
    surface.SetTextColor( color )
    surface.SetTextPos( 0, 0 )
    local textWidth, textHeight = surface.GetTextSize( text )
    local rad = -math.rad( ang )
    local halvedPi = math.pi / 2
    x = x - ( math.sin( rad + halvedPi ) * textWidth / 2 + math.sin( rad ) * textHeight / 2 )
    y = y - ( math.cos( rad + halvedPi ) * textWidth / 2 + math.cos( rad ) * textHeight / 2 )
    local m = Matrix()
    m:SetAngles( Angle( 0, ang, 0 ) )
    m:SetTranslation( Vector( x, y, 0 ) )
    cam.PushModelMatrix( m )
        surface.DrawText( text )
    cam.PopModelMatrix()
    render.PopFilterMag()
    render.PopFilterMin()
end

function draw.RotatedBox( x, y, w, h, ang, color )
    draw.NoTexture()
    surface.SetDrawColor( color or color_white )
    surface.DrawTexturedRectRotated( x, y, w, h, ang )
end
