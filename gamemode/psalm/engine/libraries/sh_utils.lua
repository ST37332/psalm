Psalm.Util = Psalm.Util or {}
local Util = Psalm.Util

function Util:MetatableSafeTableMerge(destination, source)
	for k, v in pairs(source) do
		if (istable(v) and istable(destination[k]) and getmetatable(v) == nil) then
			-- don't overwrite one table with another
			-- instead merge them recurisvely
			self:MetatableSafeTableMerge(destination[k], v);
		else
			destination[ k ] = v;
		end
	end
	return destination;
end

-- Returns the address:port of the server.
function Util:GetAddress()
	return game.GetIPAddress()
end

--- Returns a cached copy of the given material, or creates and caches one if it doesn't exist. This is a quick helper function
-- if you aren't locally storing a `Material()` call.
-- @realm shared
-- @string materialPath Path to the material
-- @treturn[1] material The cached material
-- @treturn[2] nil If the material doesn't exist in the filesystem
function Util:GetMaterial(materialPath)
	-- Cache the material.
	self.cachedMaterials = self.cachedMaterials or {}
	self.cachedMaterials[materialPath] = self.cachedMaterials[materialPath] or Material(materialPath)

	return self.cachedMaterials[materialPath]
end

if CLIENT then
	surface.CreateFont("ixGenericFont", {
		font = "Roboto Th",
		size = 20,
		extended = true,
		weight = 1000
	})
	function Util:DrawText(text, x, y, color, alignX, alignY, font, alpha)
		color = color or color_white
		return draw.TextShadow({
			text = text,
			font = font or "ixGenericFont",
			pos = {x, y},
			color = color,
			xalign = alignX or TEXT_ALIGN_LEFT,
			yalign = alignY or TEXT_ALIGN_LEFT
		}, 1, alpha or (color.a * 0.575))
	end
end