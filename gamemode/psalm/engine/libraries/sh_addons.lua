-- Discovers addon folders under `gamemode/addons/`, loads each module's
-- `sh_auto.lua` metadata entry point, then auto-loads three convention
-- subfolders in order: `libraries/`, `gui/`, `config/`.
-- Each module's `sh_auto.lua` receives a fresh `ADDON` global; it may also
-- call `Psalm.Loader:Include` / `Psalm.Loader:Directory` (or the shorthand
-- `ADDON:Include` / `ADDON:Directory`) to pull in extra files that live
-- outside the conventional subfolders.
-- @module Psalm.Addons

Psalm.Addons = Psalm.Addons or {}

local addon = Psalm.Addons

addon.registry   = addon.registry   or {} -- [string_id] = meta
addon.order      = addon.order      or {} -- array of ids in load order
addon.loaded     = false
addon.loading    = false
addon.root       = addon.root       or "addons/"
addon.subfolders = addon.subfolders or { "libraries", "gui", "config" }

-- ---------------------------------------------------------------------------
-- Logging
-- ---------------------------------------------------------------------------

local function say(col, tag, msg)
	if Psalm.Print and Psalm.Print.Custom then
		Psalm.Print:Custom("ADDONS", col, "[" .. tag .. "] " .. msg)
	else
		MsgC(Color(180, 150, 255), "[PSALM | ADDONS] [" .. tag .. "] ", col, msg, "\n")
	end
end

local function logHead(msg) say(Color(180, 150, 255), ">>>> ", msg) end
local function logStep(msg) say(Color(180, 200, 255), "LOAD ", msg) end
local function logOk(msg)   say(Color(140, 220, 160), " OK  ", msg) end
local function logSkip(msg) say(Color(200, 180, 120), "SKIP ", msg) end
local function logErr(msg)  say(Color(240, 120, 120), "FAIL ", msg) end

-- ---------------------------------------------------------------------------
-- Path helpers
-- ---------------------------------------------------------------------------

--- Returns whether a path exists anywhere in the gamemode tree.
-- Checks the gamemode root and every sub-base (mirroring `Psalm.Loader`).
-- @realm shared
-- @string rel Path relative to `gamemode/`.
-- @treturn bool
local function existsInGamemode(rel)
	if not (GM and GM.FolderName and GM.FolderName ~= "") then return false end
	local root = GM.FolderName .. "/gamemode/"

	if file.Exists(root .. rel, "LUA") then return true end

	local _, dirs = file.Find(root .. "*", "LUA")
	for _, dir in ipairs(dirs or {}) do
		if file.Exists(root .. dir .. "/" .. rel, "LUA") then return true end
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Addon object
-- ---------------------------------------------------------------------------

local AddonMeta = {}
AddonMeta.__index = AddonMeta

--- Returns the base path of the addon, optionally with a subpath appended.
-- @realm shared
-- @string[opt] sub Subpath.
-- @treturn string
function AddonMeta:GetPath(sub)
	local base = addon.root .. self.folder
	if sub then return base .. "/" .. sub end
	return base
end

--- Includes a file relative to the addon folder.
-- @realm shared
-- @string path Relative path, e.g. `"extra/helpers.lua"`.
-- @return Loader result.
function AddonMeta:Include(path)
	return Psalm.Loader:Include(self:GetPath(path))
end

--- Loads every `.lua` file in a directory relative to the addon folder.
-- @realm shared
-- @string path Relative directory path, e.g. `"extra"`.
-- @treturn int Number of files iterated.
function AddonMeta:Directory(path)
	return Psalm.Loader:Directory(self:GetPath(path))
end

AddonMeta.__tostring = function(self)
	return "Addon[" .. (self.id or "?") .. "]"
end

-- ---------------------------------------------------------------------------
-- Discovery
-- ---------------------------------------------------------------------------

--- Returns sorted list of addon folder names under `addons/`.
-- Hidden folders (`.` prefix) are skipped.
-- @realm shared
-- @treturn table Array of folder names.
function addon:Scan()
	if not (GM and GM.FolderName and GM.FolderName ~= "") then return {} end

	local out = {}
	local root = GM.FolderName .. "/gamemode/" .. self.root
	local _, dirs = file.Find(root .. "*", "LUA")

	for _, dir in ipairs(dirs or {}) do
		if not dir:match("^%.") then
			table.insert(out, dir)
		end
	end

	table.sort(out)
	return out
end

-- ---------------------------------------------------------------------------
-- Loading
-- ---------------------------------------------------------------------------

--- Creates a fresh metadata object for an addon folder.
-- @realm shared
-- @string folder Folder name under `addons/`.
-- @treturn table
function addon:NewMeta(folder)
	return setmetatable({
		id          = folder,
		folder      = folder,
		name        = folder,
		author      = "Unknown",
		description = "",
		version     = nil,
		filesLoaded = {},
		startedAt   = nil,
		elapsedMs   = nil,
	}, AddonMeta)
end

--- Loads a single addon by folder name.
-- Loads `sh_auto.lua` first (which populates the `ADDON` global), then walks
-- `libraries/`, `gui/`, `config/` in that order. Errors inside `sh_auto.lua`
-- are caught and logged; the addon is skipped but the loop continues.
-- @realm shared
-- @string folder Folder name under `addons/`.
-- @treturn table|nil Metadata on success, `nil` on failure.
function addon:Load(folder)
	if self.registry[folder] then
		logSkip("addon '" .. folder .. "' already loaded")
		return self.registry[folder]
	end

	logHead("Loading addon: " .. folder)

	local meta = self:NewMeta(folder)
	meta.startedAt = SysTime()

	-- Step 1: sh_auto.lua
	local shAuto = self.root .. folder .. "/sh_auto.lua"

	if not existsInGamemode(shAuto) then
		logSkip("  " .. folder .. ": no sh_auto.lua (using defaults)")
	else
		logStep("  [1/4] sh_auto.lua")
		_G.ADDON = meta

		local ok, err = pcall(Psalm.Loader.Include, Psalm.Loader, shAuto)

		-- Adopt a replacement table if sh_auto swapped the global.
		if _G.ADDON ~= nil and _G.ADDON ~= meta then
			local adopted = _G.ADDON
			adopted.id          = folder
			adopted.folder      = folder
			adopted.startedAt   = meta.startedAt
			adopted.filesLoaded = meta.filesLoaded or {}
			setmetatable(adopted, AddonMeta)
			meta = adopted
		end
		_G.ADDON = nil

		if not ok then
			logErr("  " .. folder .. ": sh_auto.lua errored — " .. tostring(err))
			return nil
		end

		logOk("  metadata: " .. tostring(meta.name) ..
			" by " .. tostring(meta.author or "?") ..
			(meta.version and (" v" .. meta.version) or ""))
	end

	-- Steps 2-4: libraries, gui, config (or custom order via ADDON.LoadOrder)
	local subs = istable(meta.LoadOrder) and meta.LoadOrder or self.subfolders
	local total = 0

	for i, sub in ipairs(subs) do
		local path = self.root .. folder .. "/" .. sub

		if not existsInGamemode(path) then
			logSkip(string.format("  [%d/4] %s/ — absent", i + 1, sub))
		else
			logStep(string.format("  [%d/4] %s/", i + 1, sub))

			local ok, count = pcall(Psalm.Loader.Directory, Psalm.Loader, path)
			if not ok then
				logErr("  " .. sub .. "/ errored — " .. tostring(count))
				count = 0
			end

			meta.filesLoaded[sub] = count
			total = total + count
			logOk(string.format("  %s/ — %d file(s) iterated", sub, count))
		end
	end

	meta.elapsedMs = (SysTime() - meta.startedAt) * 1000

	self.registry[meta.id] = meta
	table.insert(self.order, meta.id)

	logOk(string.format("✓ Loaded '%s' [%s] — %d file(s) in %.1fms",
		tostring(meta.name), folder, total, meta.elapsedMs))

	if meta.description and meta.description ~= "" then
		logStep("  " .. meta.description)
	end

	hook.Run("Psalm.Addons.Loaded", meta)
	return meta
end

--- Loads every addon discovered under `addons/`, in alphabetical order.
-- Idempotent — subsequent calls are ignored once loading has started.
-- @realm shared
-- @bool[opt=false] force Reload even if `loaded` is true.
-- @treturn table Map of id -> metadata for every loaded addon.
function addon:LoadAll(force)
	if self.loaded and not force then
		logSkip("LoadAll ignored — addons already loaded")
		return self.registry
	end
	if self.loading then
		logSkip("LoadAll ignored — already in progress")
		return self.registry
	end

	self.loading  = true
	self.loaded   = false
	self.registry = {}
	self.order    = {}

	logHead("Scanning for addon modules...")
	local folders = self:Scan()

	if #folders == 0 then
		logSkip("No addons found in " .. self.root)
		self.loading = false
		self.loaded  = true
		return self.registry
	end

	logOk(string.format("Found %d addon folder(s): %s",
		#folders, table.concat(folders, ", ")))

	local okCount, failCount = 0, 0

	for _, folder in ipairs(folders) do
		if self:Load(folder) then
			okCount = okCount + 1
		else
			failCount = failCount + 1
		end
	end

	self.loading = false
	self.loaded  = true

	logHead(string.format("Addon load complete — %d ok, %d failed", okCount, failCount))
	if #self.order > 0 then
		logOk("Load order: " .. table.concat(self.order, " → "))
	end

	hook.Run("Psalm.Addons.AllLoaded", self.registry, self.order)
	return self.registry
end

-- ---------------------------------------------------------------------------
-- Lookup
-- ---------------------------------------------------------------------------

--- Returns metadata for a loaded addon.
-- @realm shared
-- @string id Addon folder name.
-- @treturn table|nil
function addon:Get(id)
	return self.registry[id]
end

--- Returns metadata for every loaded addon in load order.
-- @realm shared
-- @treturn table Array of metadata.
function addon:GetAll()
	local out = {}
	for _, id in ipairs(self.order) do
		local meta = self.registry[id]
		if meta then table.insert(out, meta) end
	end
	return out
end

--- Returns whether an addon is loaded.
-- @realm shared
-- @string id Addon folder name.
-- @treturn bool
function addon:IsLoaded(id)
	return self.registry[id] ~= nil
end

--- Returns the number of loaded addons.
-- @realm shared
-- @treturn number
function addon:Count()
	return #self.order
end

if CLIENT then
    hook.Add('HUDPaint', 'Addons.HUD', function()
        hook.Run('HUD')
    end)
end