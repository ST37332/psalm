Psalm.Hud = Psalm.Hud or {}

local hud = Psalm.Hud

local hide = {
	["CHudHealth"] = true,
	["CHudBattery"] = true,
	["CHudAmmo"] = true,
	["CHudSecondaryAmmo"] = true,
}

hook.Add( "HUDShouldDraw", "HideHUD", function( name )
	if ( hide[ name ] ) then
		return false
	end
end )
-- Новые настройки
local vars = {
    font = "DefaultSmall",          -- более тонкий шрифт
    text_spacing = 4,
    padding = 8,
    icon_font = "DefaultSmall",     -- для иконок можно тот же шрифт
    health_width = 150,             -- ширина полоски здоровья
    health_height = 6
};

-- Цветовая схема (минималистичная)
local colors = {
    background = {
        border = Color(255, 255, 255, 20),   -- очень тонкая граница
        background = Color(0, 0, 0, 140)      -- полупрозрачный чёрный
    },
    text = {
        shadow = Color(0, 0, 0, 180),
        text = Color(255, 255, 255, 255)      -- чисто белый
    },
    health = {
        border = Color(255, 255, 255, 30),
        background = Color(40, 40, 40, 180),
        shade = Color(200, 50, 50, 100),
        fill = Color(220, 70, 70, 255)
    }
};

local function clr(color) return color.r, color.g, color.b, color.a; end

function hud:paintBar(x, y, w, h, colors, value)
    self:paintPanel(x, y, w, h, colors);

    x = x + 1; y = y + 1;
    w = w - 2; h = h - 2;

    local width = w * math.Clamp(value, 0, 1);
    local shade = 4;

    surface.SetDrawColor(clr(colors.shade));
    surface.DrawRect(x, y, width, shade);

    surface.SetDrawColor(clr(colors.fill));
    surface.DrawRect(x, y + shade, width, h - shade);
end

function hud:paintPanel(x, y, w, h, colors)
    surface.SetDrawColor(clr(colors.border));
    surface.DrawOutlinedRect(x, y, w, h);

    x = x + 1; y = y + 1;
    w = w - 2; h = h - 2;

    surface.SetDrawColor(clr(colors.background));
    surface.DrawRect(x, y, w, h);
end

function hud:paintText(x, y, text, font, colors, size)
    surface.SetFont(font);

    surface.SetTextPos(x + 1, y + 1);
    surface.SetTextColor(clr(colors.shadow));
    surface.DrawText(text);

    surface.SetTextPos(x, y);
    surface.SetTextColor(clr(colors.text));
    surface.DrawText(text);
end

function hud:textSize(text, font)
    surface.SetFont(font);
    return surface.GetTextSize(text);
end

hook.Add("HUDPaint", "PaintOurHud", function()
    local client = LocalPlayer();
    if not client:Alive() then return; end

    local x = 35;
    local y = ScrH() - 180;   -- поднимем немного выше

    -- 1. Полоска здоровья (используем paintBar)
    local health = client:Health() / client:GetMaxHealth();
    hud:paintBar(x, y, vars.health_width, vars.health_height, colors.health, health);

    -- Отступ перед текстом
    y = y + vars.health_height + vars.padding;

    -- Функция для отрисовки строки с иконкой
    local function drawLine(icon, text, offsetY)
        local line = icon .. " " .. text;
        local w, h = hud:textSize(line, vars.font);

        -- Подложка под строку (чуть шире текста)
        local bgX = x - 4;
        local bgY = y + offsetY - 2;
        local bgW = w + 8;
        local bgH = h + 4;

        surface.SetDrawColor(0, 0, 0, 140);
        surface.DrawRect(bgX, bgY, bgW, bgH);

        -- Сам текст
        hud:paintText(x, y + offsetY, line, vars.font, colors.text);
    end

    -- Рисуем строки
    drawLine("$", "Moneys: " .. client:GetJobSalary(), 0);
    drawLine("J", "Job: " .. client:GetJobName(), vars.text_spacing + 16);   -- 16 - высота строки (подобрать)

    -- Можно добавить ещё строку, например, броню
    -- if client:Armor() > 0 then
    --     drawLine("🛡", "Броня: " .. client:Armor(), (vars.text_spacing + 16)*2);
    -- end
end);

local COLOR_BLACK_WHITE = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1.5,
	["$pp_colour_colour"] = 0,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

local bloodOverlay = Psalm.Util:GetMaterial("overlays/blood_vignette.png")

function GM:RenderScreenspaceEffects()
    local colorModify = {}
    colorModify["$pp_colour_colour"] = 0.77
    
    if (system.IsWindows()) then
    	colorModify["$pp_colour_brightness"] = -0.02
    	colorModify["$pp_colour_contrast"] = 1.2
    else
    	colorModify["$pp_colour_brightness"] = 0
    	colorModify["$pp_colour_contrast"] = 1
    end
    

    
    DrawColorModify(colorModify)

	if (LocalPlayer():Health() < 50) then
		render.UpdateScreenEffectTexture()

		//playerOverlay:SetFloat("$alpha", 0.5)
		//playerOverlay:SetInt("$ignorez", 1)

		render.SetMaterial(bloodOverlay)
		render.DrawScreenQuad()
	end
end


surface.CreateFont("ixAmmoHud", {
	font = "Consolas",
	extended = true,
	antialias = true,
	bold = true,
	blursize = 1,
	scanlines = 3,
	size = 55,
	weight = 500
})

surface.CreateFont("ixAmmoHudSecondary", {
	font = "Consolas",
	extended = true,
	antialias = true,
	bold = true,
	blursize = 1,
	scanlines = 3,
	size = 45,
	weight = 200
})


function GM:HUDPaintBackground()
	local client = LocalPlayer()
	local alpha = TimedSin(0.25, 220, 300, 0)

	local frameTime = FrameTime()
	local scrW, scrH = ScrW(), ScrH()

	local weapon = client:GetActiveWeapon()


	if (IsValid(weapon) and hook.Run("CanDrawCustomAmmoHUD", weapon) != false and weapon.DrawAmmo != false) then
		local clip = weapon:Clip1()
		local clipMax = weapon:GetMaxClip1()
		local count = client:GetAmmoCount(weapon:GetPrimaryAmmoType())
		local secondary = client:GetAmmoCount(weapon:GetSecondaryAmmoType())
		local x, y = scrW - 275, scrH - 180
		local text = ""
		local color = Color(255,255,255,0)
		

		if (secondary > 0) then
			--ark.util.DrawBlurAt(x, y, 64, 64)

			--surface.SetDrawColor(255, 255, 255, 5)
			--surface.DrawRect(x, y, 64, 64)
			--surface.SetDrawColor(255, 255, 255, 3)
			--surface.DrawOutlinedRect(x, y, 64, 64)

			Psalm.Util:DrawText(secondary, x + 34, y + 52, Color(0,0,0), 1, 1, "ixAmmoHudSecondary")
			Psalm.Util:DrawText(secondary, x + 32, y + 50, team.GetColor(client:Team()), 1, 1, "ixAmmoHudSecondary")
		end

		if (weapon:GetClass() != "weapon_slam" and clipMax > 0 or count > 0) then
			x = x - (secondary > 0 and 144 or 64)

			--ark.util.DrawBlurAt(x, y, 128, 64)

			--surface.SetDrawColor(255, 255, 255, 5)
			--surface.DrawRect(x, y, 128, 64)
			--surface.SetDrawColor(255, 255, 255, 3)
			--surface.DrawOutlinedRect(x, y, 128, 64)

				--.."/"..count

			Psalm.Util:DrawText((clip == -1 or clipMax == -1) and count or clip, x + 27, y + 27, Color(0,0,0), 2, 1, "ixAmmoHud", TEXT_ALIGN_RIGHT)
			Psalm.Util:DrawText((clip == -1 or clipMax == -1) and count or clip, x + 25, y + 25, team.GetColor(client:Team()), 2, 1, "ixAmmoHud", TEXT_ALIGN_RIGHT)
			Psalm.Util:DrawText("/", x + 42, y + 42, Color(0,0,0), 1, 1, "ixAmmoHud", TEXT_ALIGN_LEFT)
			Psalm.Util:DrawText("/", x + 40, y + 40, team.GetColor(client:Team()), 1, 1, "ixAmmoHud", TEXT_ALIGN_LEFT)
			Psalm.Util:DrawText(count, x + 53, y + 52, Color(0,0,0), 0, 1, "ixAmmoHud", TEXT_ALIGN_LEFT)
			Psalm.Util:DrawText(count, x + 51, y + 50, team.GetColor(client:Team()), 0, 1, "ixAmmoHud", TEXT_ALIGN_LEFT)

		end
	end
end
