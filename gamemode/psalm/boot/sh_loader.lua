--- Filesystem-aware module loader for the Psalm gamemode.
-- Routes Lua files to the correct realm based on an explicit realm hint
-- or the file's name prefix (`sv_`, `cl_`, `sh_`), and handles
-- `AddCSLuaFile` automatically so client-only and shared files reach
-- connecting clients.
-- @module Psalm.Loader

Psalm.Loader = Psalm.Loader or {}

local loader = Psalm.Loader

--- Emits a colored loader message, using @{Psalm.Print} when available.
-- @realm shared
-- @param col A @{Color} for the message body.
-- @string message Text to display.
local function loaderMsg(col, message)
	if Psalm.Print and Psalm.Print.Custom then
		Psalm.Print:Custom("PSALM | LOADER", col, message)
	else
		MsgC(Color(82, 255, 189), "[PSALM | LOADER] ", col, message, "\n")
	end
end

--- Determines the realm of a file from an explicit hint or its name.
-- An explicit hint always wins; otherwise the filename is inspected for
-- the `sv_`/`_sv`, `sh_`/`_sh`/`shared.lua`, or `cl_`/`_cl` markers.
-- @realm shared
-- @string sFile Relative path to the Lua file.
-- @string[opt] sRealm Explicit realm hint: `server`/`sv`, `shared`/`sh`, `client`/`cl`.
-- @treturn string One of `server`, `shared`, `client`, or `unknown`.
function loader:GetRealm(sFile, sRealm)
	if type(sRealm) == "string" then
		local r = sRealm:lower()
		if r == "server" or r == "sv" then return "server" end
		if r == "shared" or r == "sh" then return "shared" end
		if r == "client" or r == "cl" then return "client" end
	end

	if type(sFile) ~= "string" then return "unknown" end
    local filename = sFile:match("^.+/(.+)$") or sFile
    if filename:match("^sv_") or filename:match("_sv%.lua$") then 
        return "server" 
    elseif filename:match("^sh_") or filename:match("_sh%.lua$") or filename:match("^shared%.lua$") then 
        return "shared" 
    elseif filename:match("^cl_") or filename:match("_cl%.lua$") then 
        return "client" 
    end

	return "unknown"
end

--- Includes a Lua file on the appropriate realm.
-- - Server-only files run exclusively on the server.
-- - Shared files are queued via `AddCSLuaFile` on the server and executed
--   on both the server and the client.
-- - Client-only files are queued via `AddCSLuaFile` on the server and
--   executed only on the client.
-- - Files that don't match any realm are skipped.
-- @realm shared
-- @string sFile Relative path to the Lua file.
-- @string[opt] sRealm Optional realm hint (see @{loader:GetRealm}).
-- @return The return value of `include`, when the file was executed.
function loader:Include(sFile, sRealm)
	if type(sFile) ~= "string" then
		loaderMsg(Color(255, 100, 100), "Include skipped: expected string, got " .. type(sFile))
		return
	end

	local realm = self.GetRealm and self:GetRealm(sFile, sRealm)
	              or loader:GetRealm(sFile, sRealm)

	if realm == "server" then
		if not SERVER then return end
		loaderMsg(Color(120, 239, 255), "Loaded: " .. sFile)
		return include(sFile)
	end

	if realm == "shared" then
		loaderMsg(Color(120, 255, 143), "Loaded: " .. sFile)
		if SERVER then AddCSLuaFile(sFile) end
		return include(sFile)
	end

	if realm == "client" then
		if SERVER then
			AddCSLuaFile(sFile)
			return
		end
		local ply  = LocalPlayer()
		local nick = IsValid(ply) and ply:Nick() or "Client"
		loaderMsg(Color(255, 196, 120), nick .. " Loaded: " .. sFile)
		return include(sFile)
	end

	loaderMsg(Color(255, 180, 80), "Skipped (unknown realm): " .. sFile)
end

--- Loads every Lua file in a directory, routing each through @{loader:Include}.
-- @realm shared
-- @string sDir Path relative to `gamemode/`, or to the Lua mount root when `bLua` is true.
-- @bool[opt=false] bLua When true, search the Lua mount directly instead of `gamemode/`.
-- @treturn int Number of files iterated (whether or not each was included).
-- https://github.com/NebulousCloud/helix/blob/bb8bf86988b980d576419597ae6b966ee939e409/gamemode/core/sh_util.lua#L65-L87
function loader:Directory(sDir, bLua)
	if type(sDir) ~= "string" then
		loaderMsg(Color(255, 100, 100), "Directory skipped: bad path")
		return 0
	end

	local sBase = GM.FolderName .. "/gamemode/"
	local files = file.Find((bLua and "" or sBase) .. sDir .. "/*.lua", "LUA")

	for _, name in ipairs(files) do
		loader:Include(sDir .. "/" .. name)
	end

	return #files
end
