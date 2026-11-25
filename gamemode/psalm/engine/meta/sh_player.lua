--- Some shared functions for players.
-- @module Psalm.Player

Psalm.Player = Psalm.Player or {}
Global = Global or {}

local PLAYER = FindMetaTable("Player")

if (SERVER) then
	PLAYER.m_bMedicFound = false
end

function Global.IsMale( sModel )
	if string.find( string.lower( sModel ), "female" ) then
		return false
	else
		return true
	end
end

function PLAYER:IsMale()
	return Global.IsMale( self:GetModel() )
end

function Global.GetModelBase( sModel )
	local sModelBase

	local found, foundend, _ = string.find(sModel, "female_0")

	if (found ~= nil) then
		sModelBase = "female_0" .. (sModel[foundend + 1])
	else
		found, foundend, _ = string.find(sModel, "male")
		if found ~= nil then
			sModelBase = "male" .. string.sub( sModel, foundend + 1, foundend + 2 )
		end
	end

	-- something went wrong or the player tried faking their model. If this happens
	if not sModelBase or string.len( sModelBase ) > 11 then
		sModelBase = Monolith.CharacterCreation.DefaultModel
	end

	return sModelBase
end

function PLAYER:IsNewbie()
    -- @TODO: Figure out something for IsNewbie system
	
	return false
end

function PLAYER:CanSeeEntity( eTarget, iThreshold )
	if self:GetEyeTraceNoCursor().Entity == eTarget then return true end

	local traceParams = {
		start = self:GetShootPos(),
		endpos = eTarget:LocalToWorld( eTarget:OBBCenter() ),
		filter = { self, eTarget },
		mask = CONTENTS_SOLID + CONTENTS_MOVEABLE + CONTENTS_OPAQUE + CONTENTS_DEBRIS + CONTENTS_HITBOX + CONTENTS_MONSTER
	}

	local traceResult = util.TraceLine( traceParams )
	if traceResult.Fraction >= ( iThreshold or 0.75 ) then
		return true
	end

	return false
end

function PLAYER:GetModelBase()
	return Global.GetModelBase( self:GetModel() )
end

local tTraceCache = setmetatable( {}, { __mode = "kv" } )
function PLAYER:GetEyeTraceBullet()
	local nCurTime = CurTime()
	local tTraceResult = tTraceCache[self]
	if not tTraceResult or tTraceResult._time < nCurTime then
		local vEyes, vEyeF = self:EyePos(), self:EyeAngles():Forward()

		tTraceResult = util.TraceLine {
			start = vEyes,
			endpos = vEyes + vEyeF * 16384,
			mask = MASK_SHOT,
			filter = { self, self:GetObserverMode() == OBS_MODE_IN_EYE and self:GetObserverTarget() }
		}
		tTraceResult._time = nCurTime

		tTraceCache[self] = tTraceResult
	end
	return tTraceResult
end

-- Lua `type()` strings we treat as players. Using a lookup keeps the entry point cheap and makes future additions (e.g. bots-with-different-types) trivial.
local PLAYER_TYPES = {
    Player = true,
}

--- Returns true if `client` is a player entity. Checks the Lua type string via `type()` rather than `IsValid()`, so it is safe to call on any value including nil, non-entity tables, or invalid entities (which would make `IsValid()` error). Use this instead of `IsValid(client) and client:IsPlayer()` when you don't yet know whether the value is even an entity.
---@realm shared
---@param client any The value to test.
---@return boolean # True if `client` has Lua type `"Player"`.
function Psalm.Player:IsValid(client)
    return PLAYER_TYPES[type(client)] == true
end

--- Whether a value looks like a SteamID64. Boot-level rather than owned by any one subsystem, because everything that addresses an offline account - the access gate, usergroup assignment, staff commands - has to agree on what a valid id looks like before it can reach a query.
---@realm shared
---@param steamID64 any The value to test.
---@return boolean # True when the value is a 17-digit SteamID64 string.
function Psalm.Player:IsSteamID64(steamID64)
    if ( !isstring(steamID64) ) then return false end

    return string.match(steamID64, "^7656%d%d%d%d%d%d%d%d%d%d%d%d%d$") != nil
end

--- Converts any of the three SteamID spellings into a SteamID64, without touching the player list. Returns nil for anything that is not an id, so callers can tell "this was an id that matched nobody" apart from "this was a name".
---@realm shared
---@param input string Trimmed text that may be an id.
---@return string|nil steamID64
function Psalm.Player:ParseSteamID(input)
    if ( !isstring(input) ) then return nil end

    if ( self:IsSteamID64(input) ) then return input end

    if ( string.match(input, "^STEAM_%d:%d:%d+$") ) then
        local converted = util.SteamIDTo64(input)
        return self:IsSteamID64(converted) and converted or nil
    end

    local account = string.match(input, "^%[U:1:(%d+)%]$")
    if ( !account ) then return nil end

    local number = tonumber(account)
    local converted = util.SteamIDTo64(string.format("STEAM_0:%d:%d", number % 2, math.floor(number / 2)))

    return self:IsSteamID64(converted) and converted or nil
end

--- Resolves text to a single connected player. Boot-level and shared because three separate places were each matching names their own way, and only one of them knew that `PLAYER:Nick` is overridden to the *character* name - which is why searching by Steam name silently failed everywhere.
--- Order is deliberate: an id is unambiguous by intent and never falls through to a name search, an exact name beats a partial one, and both the character name and the Steam name are searched so either spelling of a person works.
---@realm shared
---@param needle string Id, character name, or Steam name.
---@return Player|nil found The single match, or nil when nothing or several matched.
---@return table matches Display labels of everything that matched, for an ambiguity message.
function Psalm.Player:Player(needle)
    if ( !isstring(needle) ) then return nil, {} end

    needle = string.Trim(needle)
    if ( needle == "" ) then return nil, {} end

    --- A person's two names, collapsed when they are the same, so an ambiguity list reads usefully.
    ---@param target Player
    ---@return string label
    local function label(target)
        local character = target:GetName()

        return character
    end

    local steamID64 = self:ParseSteamID(needle)
    if ( steamID64 ) then
        for _, target in player.Iterator() do
            if ( !IsValid(target) or target:SteamID64() != steamID64 ) then continue end

            return target, { label(target) }
        end

        return nil, {}
    end

    local lower = string.lower(needle)
    local matches = {}

    for _, target in player.Iterator() do
        if ( !IsValid(target) ) then continue end

        local character = string.lower(target:GetName())

        if ( character == lower ) then return target, { label(target) } end

        if ( string.find(character, lower, 1, true)) then
            matches[#matches + 1] = target
        end
    end

    if ( #matches == 1 ) then return matches[1], { label(matches[1]) } end

    local labels = {}
    for i = 1, #matches do
        labels[i] = label(matches[i])
    end

    return nil, labels
end

if CLIENT then
    concommand.Add( "_cachePos", function()
    	local vPos = LocalPlayer():GetPos():ceil()
    	local aAng = LocalPlayer():GetAngles()
    
    	print( ( "Vector( %i, %i, %i )" ):format( vPos.x, vPos.y, vPos.z ) )
    	print( ( "Angle( %i, %i, %i )" ):format( aAng.p, aAng.y, aAng.r ) )
    end )
end