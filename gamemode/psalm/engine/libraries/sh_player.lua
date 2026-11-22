--- Some shared functions for players.
-- @module Psalm.Player

Psalm.Player = Psalm.Player or {}

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