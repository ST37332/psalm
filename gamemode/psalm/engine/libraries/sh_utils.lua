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