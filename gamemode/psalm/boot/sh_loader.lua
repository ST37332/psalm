-- Routes Lua files to the correct realm based on an explicit realm hint
-- or the file's name prefix (`sv_`, `cl_`, `sh_`), and handles
-- `AddCSLuaFile` automatically so client-only and shared files reach
-- connecting clients.
-- Paths are resolved against the `LUA` mount with multi-base support:
-- a path like `"engine/libraries/sh_color.lua"` will match any of
--   psalm/gamemode/engine/libraries/sh_color.lua
--   psalm/gamemode/psalm/engine/libraries/sh_color.lua
--   psalm/gamemode/<other-subfolder>/engine/libraries/sh_color.lua
-- in priority order.
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

--- Returns the ordered list of candidate base prefixes (each ends with `/`).
-- `""` is always the gamemode root; explicit `:SetBase()` runs first, then
-- every sub-folder of `gamemode/` discovered via `file.Find`. Cached until
-- `:RefreshBases()` is called.
-- @realm shared
-- @treturn table Array of base prefixes.
local function getMountBases()
	if Psalm.Loader._mountBases then return Psalm.Loader._mountBases end

	local bases = {}
	if Psalm.Loader._forcedBase then
		table.insert(bases, Psalm.Loader._forcedBase)
	end
	table.insert(bases, "")

	if GM and GM.FolderName and GM.FolderName ~= "" then
		local root = GM.FolderName .. "/gamemode/"
		local _, dirs = file.Find(root .. "*", "LUA")
		for _, dir in ipairs(dirs or {}) do
			table.insert(bases, dir .. "/")
		end
	end

	Psalm.Loader._mountBases = bases
	return bases
end

--- Forces a preferred sub-folder prefix to try before auto-detected ones.
-- Call once from boot before any `Include`. Pass `nil` to clear.
-- @realm shared
-- @string[opt=nil] path Sub-folder relative to `gamemode/`, e.g. `"psalm"`.
function Psalm.Loader:SetBase(path)
	if path == nil or path == "" then
		self._forcedBase = nil
	else
		self._forcedBase = tostring(path):gsub("/+$", "") .. "/"
	end
	self._mountBases = nil
end

--- Clears the cached base list, forcing a re-scan on the next include.
-- Useful after adding/removing gamemode sub-folders at runtime.
-- @realm shared
function Psalm.Loader:RefreshBases()
	self._mountBases = nil
end

--- Resolves a path to a file that actually exists in the `LUA` mount.
-- Tries the path verbatim, then prefixes it with each candidate base
-- (`psalm/gamemode/` + base + path).
-- @realm shared
-- @string sFile Relative or absolute path to a Lua file.
-- @treturn string|nil The resolved path, or `nil` if nothing was found.
local function resolveLuaPath(sFile)
	if type(sFile) ~= "string" then return nil end

	if file.Exists(sFile, "LUA") then return sFile end

	if GM and GM.FolderName and GM.FolderName ~= "" then
		local folder = GM.FolderName .. "/gamemode/"
		for _, base in ipairs(getMountBases()) do
			local p = folder .. base .. sFile
			if file.Exists(p, "LUA") then return p end
		end
	end

	return nil
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
-- - Files that don't match any realm or cannot be resolved are skipped.
-- @realm shared
-- @string sFile Relative path to the Lua file.
-- @string[opt] sRealm Optional realm hint (see @{loader:GetRealm}).
-- @return The return value of `include`, when the file was executed.
function loader:Include(sFile, sRealm)
	if type(sFile) ~= "string" then
		loaderMsg(Color(255, 100, 100), "Include skipped: expected string, got " .. type(sFile))
		return
	end

	local resolved = resolveLuaPath(sFile)
	if not resolved then
		loaderMsg(Color(255, 100, 100), "Include skipped: not found: " .. sFile)
		return
	end

	local realm = self:GetRealm(sFile, sRealm)

	if realm == "server" then
		if not SERVER then return end
		loaderMsg(Color(120, 239, 255), "Loaded: " .. sFile)
		return include(resolved)
	end

	if realm == "shared" then
		loaderMsg(Color(120, 255, 143), "Loaded: " .. sFile)
		if SERVER then AddCSLuaFile(resolved) end
		return include(resolved)
	end

	if realm == "client" then
		if SERVER then
			AddCSLuaFile(resolved)
			return
		end
		local ply  = LocalPlayer()
		local nick = IsValid(ply) and ply:Nick() or "Client"
		loaderMsg(Color(255, 196, 120), nick .. " Loaded: " .. sFile)
		return include(resolved)
	end

	loaderMsg(Color(255, 180, 80), "Skipped (unknown realm): " .. sFile)
end

--- Loads every Lua file in a directory, routing each through @{loader:Include}.
-- Every candidate base is scanned in priority order; files that exist under
-- multiple bases are included once (the first base that contains them wins,
-- matching how @{loader:Include} resolves the path).
-- @realm shared
-- @string sDir Path relative to `gamemode/`, or to the Lua mount root when `bLua` is true.
-- @bool[opt=false] bLua When true, search the Lua mount directly instead of `gamemode/`.
-- @treturn int Number of files iterated.
-- https://github.com/NebulousCloud/helix/blob/bb8bf86988b980d576419597ae6b966ee939e409/gamemode/core/sh_util.lua#L65-L87
function loader:Directory(sDir, bLua)
	if type(sDir) ~= "string" then
		loaderMsg(Color(255, 100, 100), "Directory skipped: bad path")
		return 0
	end

	local total = 0
	local seen  = {}

	local function process(files)
		for _, name in ipairs(files) do
			if not seen[name] then
				seen[name] = true
				loader:Include(sDir .. "/" .. name)
				total = total + 1
			end
		end
	end

	if bLua then
		process(file.Find(sDir .. "/*.lua", "LUA"))
	elseif GM and GM.FolderName and GM.FolderName ~= "" then
		local folder = GM.FolderName .. "/gamemode/"
		for _, base in ipairs(getMountBases()) do
			process(file.Find(folder .. base .. sDir .. "/*.lua", "LUA"))
		end
	end

	return total
end