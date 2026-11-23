-- Hierarchy: Faction -> Category -> Job.
-- Registration API is name-first: the first argument is the display name,
-- the return value is a numeric ID suitable for `TEAM_*` constants.
-- Internally every entity is keyed by a stable string `uniqueID` (a slug of
-- the name, or an explicit `data.uniqueID`), so lookups, persistence, and
-- networking never depend on registration order.
-- @module Psalm.Jobs

Psalm.Jobs = Psalm.Jobs or {}

local Jobs = Psalm.Jobs

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------

Jobs.factions        = Jobs.factions        or {} -- [string_slug]     = faction
Jobs.factionIndices  = Jobs.factionIndices  or {} -- [number_index]    = faction
Jobs.categories      = Jobs.categories      or {} -- [string_slug]     = category
Jobs.categoryIndices = Jobs.categoryIndices or {} -- [number_index]    = category
Jobs.teams           = Jobs.teams           or {} -- [string_slug]     = job
Jobs.indices         = Jobs.indices         or {} -- [number_index]    = job
Jobs.whitelistCache  = Jobs.whitelistCache  or {} -- [string_whitelistId] = number_jobIndex
Jobs.jobsWithQueues  = Jobs.jobsWithQueues  or {} -- [number_jobIndex] = bool

if SERVER then
	Jobs.jobQueues = Jobs.jobQueues or {}
end

Jobs.spawnPoints        = Jobs.spawnPoints        or {} -- [string_categorySlug][string_name]
Jobs.defaultSpawnPoints = Jobs.defaultSpawnPoints or {}

Jobs.DefaultJob           = Jobs.DefaultJob           or nil
Jobs.QUEUE_CLAIM_TIME     = Jobs.QUEUE_CLAIM_TIME     or 120
Jobs.QUEUE_SWITCH_COOLDOWN = Jobs.QUEUE_SWITCH_COOLDOWN or 60

--- Default playermodels used when a job doesn't specify any.
-- @table Jobs.DefaultModels
Jobs.DefaultModels = {
	"models/humans/group01/male_01.mdl", "models/humans/group01/male_02.mdl", "models/humans/group01/male_04.mdl",
	"models/humans/group01/male_05.mdl", "models/humans/group01/male_06.mdl", "models/humans/group01/male_07.mdl",
	"models/humans/group01/male_08.mdl", "models/humans/group01/male_09.mdl", "models/humans/group02/male_01.mdl",
	"models/humans/group02/male_03.mdl", "models/humans/group02/male_05.mdl", "models/humans/group02/male_07.mdl",
	"models/humans/group02/male_09.mdl", "models/humans/group01/female_01.mdl", "models/humans/group01/female_02.mdl",
	"models/humans/group01/female_03.mdl", "models/humans/group01/female_06.mdl", "models/humans/group01/female_07.mdl",
	"models/humans/group02/female_01.mdl", "models/humans/group02/female_03.mdl", "models/humans/group02/female_06.mdl",
	"models/humans/group01/female_04.mdl"
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Converts a display name into a stable string ID.
-- Lowercases ASCII, replaces runs of non-word characters with `_`, and trims.
-- When the result would be empty (all non-ASCII input), falls back to a
-- stable FNV-style hash so `uniqueID` is never empty.
-- @realm shared
-- @string name Display name.
-- @treturn string Slug.
local function slugify(name)
	name = tostring(name or "")
	local s = name:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
	if s == "" then
		local h = 0
		for i = 1, #name do
			h = (h * 33 + string.byte(name, i)) % 4294967296
		end
		s = "id_" .. string.format("%08x", h)
	end
	return s
end

local function assertName(name, kind)
	if not isstring(name) or name == "" then
		error("Psalm.Jobs: " .. kind .. " requires a non-empty name", 3)
	end
end

-- ---------------------------------------------------------------------------
-- Resolvers (index / slug / display name -> entity)
-- ---------------------------------------------------------------------------

--- Resolves a faction by numeric index, string slug, or display name.
-- @realm shared
-- @param ref Number index, slug, or display name.
-- @treturn table|nil
function Jobs:ResolveFaction(ref)
	if isnumber(ref) then return Jobs.factionIndices[ref] end
	if not isstring(ref) then return nil end

	if Jobs.factions[ref] then return Jobs.factions[ref] end
	local slug = slugify(ref)
	if Jobs.factions[slug] then return Jobs.factions[slug] end
	return nil
end

--- Resolves a category by numeric index, string slug, or display name.
-- @realm shared
-- @param ref Number index, slug, or display name.
-- @treturn table|nil
function Jobs:ResolveCategory(ref)
	if isnumber(ref) then return Jobs.categoryIndices[ref] end
	if not isstring(ref) then return nil end

	if Jobs.categories[ref] then return Jobs.categories[ref] end
	local slug = slugify(ref)
	if Jobs.categories[slug] then return Jobs.categories[slug] end
	return nil
end

--- Resolves a job by numeric index, string slug, or display name.
-- @realm shared
-- @param ref Number index, slug, or display name.
-- @treturn table|nil
function Jobs:ResolveJob(ref)
	if isnumber(ref) then return Jobs.indices[ref] end
	if not isstring(ref) then return nil end

	if Jobs.teams[ref] then return Jobs.teams[ref] end
	local slug = slugify(ref)
	if Jobs.teams[slug] then return Jobs.teams[slug] end
	return nil
end

-- ---------------------------------------------------------------------------
-- Registration: factions
-- ---------------------------------------------------------------------------

--- Registers a faction.
-- @realm shared
-- @string name Display name, e.g. `"Combine"`.
-- @table[opt] data Faction fields: `uniqueID`, `color`, `isDefault`,
--   `isGovernment`, `description`, `canSwitchTo(ply, faction)`.
-- @treturn number Numeric faction index, suitable for a `FACTION_*` constant.
function Jobs:RegisterFaction(name, data)
	assertName(name, "RegisterFaction")
	data = data or {}

	local uniqueID = slugify(data.uniqueID or name)
	if Jobs.factions[uniqueID] then
		ErrorNoHalt("Psalm.Jobs: faction '" .. name .. "' (" .. uniqueID .. ") already registered\n")
		return Jobs.factions[uniqueID].index
	end

	local index = table.Count(Jobs.factions) + 1
	local faction = table.Merge({
		color        = Color(150, 150, 150),
		isDefault    = false,
		isGovernment = false,
		description  = "No description.",
		categories   = {}, -- array of category slugs
		looseJobs    = {}, -- array of job slugs (legacy, for jobs without category)
		canSwitchTo  = function(ply, faction) return true end,
	}, data)

	faction.name     = name
	faction.uniqueID = uniqueID
	faction.index    = index

	Jobs.factions[uniqueID]    = faction
	Jobs.factionIndices[index] = faction

	hook.Run("Psalm.Jobs.FactionRegistered", faction)
	return index
end

-- ---------------------------------------------------------------------------
-- Registration: categories
-- ---------------------------------------------------------------------------

--- Registers a job category inside a faction.
-- @realm shared
-- @string name Display name, e.g. `"Soldiers"`.
-- @table data Category fields. `faction` is required and accepts a numeric
--   index, a slug, or a display name. Other fields: `uniqueID`, `color`,
--   `icon`, `avatar`, `niceName`, `description`, `sortOrder`, `xpPerRank`,
--   `maxLevel`, `place`.
-- @treturn number Numeric category index, suitable for a `CATEGORY_*` constant.
function Jobs:RegisterCategory(name, data)
	assertName(name, "RegisterCategory")

	if not istable(data) then
		error("Psalm.Jobs: RegisterCategory('" .. name .. "') requires a data table", 2)
	end
	if data.faction == nil then
		error("Psalm.Jobs: category '" .. name .. "' must specify a faction", 2)
	end

	local faction = self:ResolveFaction(data.faction)
	if not faction then
		error("Psalm.Jobs: unknown faction '" .. tostring(data.faction) ..
		      "' for category '" .. name .. "'", 2)
	end

	local uniqueID = slugify(data.uniqueID or name)
	if Jobs.categories[uniqueID] then
		ErrorNoHalt("Psalm.Jobs: category '" .. name .. "' (" .. uniqueID .. ") already registered\n")
		return Jobs.categories[uniqueID].index
	end

	local index = table.Count(Jobs.categories) + 1
	local category = table.Merge({
		color       = Color(0, 0, 0),
		icon        = nil,
		avatar      = nil,
		realName    = nil,
		description = "No description.",
		sortOrder   = 99,
		xpPerRank   = nil,
		maxLevel    = nil,
		jobs        = {}, -- array of job slugs
	}, data)

	category.name     = name
	category.uniqueID = uniqueID
	category.index    = index
	category.faction  = faction.uniqueID

	Jobs.categories[uniqueID]    = category
	Jobs.categoryIndices[index]  = category
	table.insert(faction.categories, uniqueID)

	hook.Run("Psalm.Jobs.CategoryRegistered", category, faction)
	return index
end

--- Alias for @{Jobs:RegisterCategory}.
-- @realm shared
-- @string name Display name.
-- @table data Category data.
-- @treturn number Category index.
function Jobs:AddJobCategory(name, data)
	return self:RegisterCategory(name, data)
end

-- ---------------------------------------------------------------------------
-- Registration: jobs
-- ---------------------------------------------------------------------------

--- Registers a job (team).
-- The job's faction is always derived from its category. If `category` is
-- omitted, the legacy `faction` field is used and the job is attached to
-- `faction.looseJobs` instead of a category.
-- @realm shared
-- @string name Display name, e.g. `"Recruit"`.
-- @table[opt] data Job fields: `uniqueID`, `category`, `faction` (legacy),
--   `model`, `models`, `modelbase`, `modelfallback`, `color`, `description`,
--   `salary`, `weapons`, `ammo`, `isDefault`, `immunity`, `max`,
--   `levelRequired`, `pointsRequired`, `registeredRequired`, `whitelistId`,
--   `canSwitchTo(ply, job)`, `OnJoin`, `OnLeave`, `PlayerLoadout`.
-- @treturn number Numeric job index, suitable for a `TEAM_*` constant.
function Jobs:Register(name, data)
	assertName(name, "Register")
	data = data or {}

	local uniqueID = slugify(data.uniqueID or name)
	if Jobs.teams[uniqueID] then
		ErrorNoHalt("Psalm.Jobs: job '" .. name .. "' (" .. uniqueID .. ") already registered\n")
		return Jobs.teams[uniqueID].index
	end

	local index = table.Count(Jobs.teams) + 1
	local job = table.Merge({
		category      = nil,
		faction       = nil,
		model         = "models/humans/group01/male_01.mdl",
		models        = nil,
		modelbase     = nil,
		modelfallback = nil,
		color         = Color(150, 150, 150),
		description   = "No description.",
		salary        = 45,
		weapons       = {},
		ammo          = {},
		isDefault     = false,
		players       = {},
		immunity      = -1,
		max           = nil,
		levelRequired      = nil,
		pointsRequired     = nil,
		registeredRequired = false,
		whitelistId        = nil,
		canSwitchTo = function(ply, job) return true end,
		OnJoin      = function(client, oldJob) end,
		OnLeave     = function(client, newJob) end,
		PlayerLoadout = nil,
	}, data)

	job.name     = name
	job.uniqueID = uniqueID
	job.index    = index

	-- Resolve hierarchy. Category wins; faction is derived from it.
	local category = nil
	if job.category ~= nil then
		category = self:ResolveCategory(job.category)
		if not category then
			error("Psalm.Jobs: unknown category '" .. tostring(job.category) ..
			      "' for job '" .. name .. "' (register categories before jobs)", 2)
		end
		job.category = category.uniqueID
		job.faction  = category.faction
	elseif job.faction ~= nil then
		local faction = self:ResolveFaction(job.faction)
		if faction then
			job.faction = faction.uniqueID
		else
			ErrorNoHalt("Psalm.Jobs: job '" .. name ..
				"' references unknown faction '" .. tostring(job.faction) .. "'\n")
			job.faction = nil
		end
	end

	-- Resolve models. `modelbase` is per-player and overrides `resolvedModels`.
	if not job.modelbase then
		if job.models then
			if istable(job.models[1]) then
				job.resolvedModels = job.models
			else
				job.resolvedModels = {}
				for _, v in ipairs(job.models) do
					table.insert(job.resolvedModels, { model = v })
				end
			end
		else
			job.resolvedModels = { { model = job.model } }
		end

		for _, v in ipairs(job.resolvedModels) do
			if isstring(v.model) then util.PrecacheModel(v.model) end
		end
	end

	-- Register with the Sandbox team system.
	if GM and GM.CreateTeam then
		GM:CreateTeam(index, { color = job.color, name = job.name })
	end

	Jobs.teams[uniqueID] = job
	Jobs.indices[index]  = job

	if job.isDefault then
		Jobs.DefaultJob = index
	end

	-- Attach to category or to faction's looseJobs.
	if category then
		table.insert(category.jobs, uniqueID)
	elseif job.faction then
		local faction = Jobs.factions[job.faction]
		if faction then table.insert(faction.looseJobs, uniqueID) end
	end

	if job.whitelistId then
		Jobs.whitelistCache[job.whitelistId] = index
	end

	if SERVER and job.max and not job.noQueue then
		Jobs.jobQueues[index] = {}
	end

	hook.Run("Psalm.Jobs.JobRegistered", job, category)
	return index
end

-- ---------------------------------------------------------------------------
-- Lookups
-- ---------------------------------------------------------------------------

--- Returns a faction by numeric index, slug, or display name.
-- @realm shared
-- @param identifier Number index, slug, or display name.
-- @treturn table|nil
function Jobs:GetFaction(identifier)
	return self:ResolveFaction(identifier)
end

--- Returns a category by numeric index, slug, or display name.
-- @realm shared
-- @param identifier Number index, slug, or display name.
-- @treturn table|nil
function Jobs:GetCategory(identifier)
	return self:ResolveCategory(identifier)
end

--- Alias for @{Jobs:GetCategory}.
-- @realm shared
-- @param identifier Number index, slug, or display name.
-- @treturn table|nil
function Jobs:GetJobCategory(identifier)
	return self:ResolveCategory(identifier)
end

--- Returns a job by numeric index, slug, or display name.
-- @realm shared
-- @param identifier Number index, slug, or display name.
-- @treturn table|nil
function Jobs:GetJob(identifier)
	return self:ResolveJob(identifier)
end

--- Returns the category a job belongs to, or `nil` for legacy uncategorized jobs.
-- @realm shared
-- @param jobID Number index, slug, or display name.
-- @treturn table|nil
function Jobs:GetJobCategoryTable(jobID)
	local job = self:ResolveJob(jobID)
	if not job or not job.category then return nil end
	return Jobs.categories[job.category]
end

--- Returns the faction a category belongs to.
-- @realm shared
-- @param categoryID Number index, slug, or display name.
-- @treturn table|nil
function Jobs:GetCategoryFaction(categoryID)
	local category = self:ResolveCategory(categoryID)
	if not category then return nil end
	return Jobs.factions[category.faction]
end

--- Returns the faction a job belongs to, resolving through its category.
-- @realm shared
-- @param jobID Number index, slug, or display name.
-- @treturn table|nil
function Jobs:GetJobFaction(jobID)
	local job = self:ResolveJob(jobID)
	if not job then return nil end

	if job.category then
		local category = Jobs.categories[job.category]
		if category then return Jobs.factions[category.faction] end
	end

	return job.faction and Jobs.factions[job.faction] or nil
end

--- Returns all categories registered under a faction, in registration order.
-- @realm shared
-- @param factionID Number index, slug, or display name.
-- @treturn table Array of category tables.
function Jobs:GetFactionCategories(factionID)
	local faction = self:ResolveFaction(factionID)
	if not faction then return {} end

	local out = {}
	for _, slug in ipairs(faction.categories) do
		local cat = Jobs.categories[slug]
		if cat then out[#out + 1] = cat end
	end
	return out
end

--- Returns all jobs belonging to a category, in registration order.
-- @realm shared
-- @param categoryID Number index, slug, or display name.
-- @treturn table Array of job tables.
function Jobs:GetCategoryJobs(categoryID)
	local category = self:ResolveCategory(categoryID)
	if not category then return {} end

	local out = {}
	for _, slug in ipairs(category.jobs) do
		local job = Jobs.teams[slug]
		if job then out[#out + 1] = job end
	end
	return out
end

--- Returns every job belonging to a faction (categories first, then loose jobs).
-- @realm shared
-- @param factionID Number index, slug, or display name.
-- @treturn table Array of job tables.
function Jobs:GetFactionJobs(factionID)
	local faction = self:ResolveFaction(factionID)
	if not faction then return {} end

	local out = {}
	for _, catSlug in ipairs(faction.categories) do
		local category = Jobs.categories[catSlug]
		if category then
			for _, jobSlug in ipairs(category.jobs) do
				local job = Jobs.teams[jobSlug]
				if job then out[#out + 1] = job end
			end
		end
	end
	for _, jobSlug in ipairs(faction.looseJobs) do
		local job = Jobs.teams[jobSlug]
		if job then out[#out + 1] = job end
	end
	return out
end

--- Returns the full hierarchy path for a job.
-- @realm shared
-- @param jobID Number index, slug, or display name.
-- @treturn table|nil `{ faction, category, job }`
function Jobs:GetJobPath(jobID)
	local job = self:ResolveJob(jobID)
	if not job then return nil end
	return {
		faction  = self:GetJobFaction(job),
		category = self:GetJobCategoryTable(job),
		job      = job,
	}
end

--- Returns the faction associated with a job ID (back-compat wrapper).
-- @realm shared
-- @param jobID Number index, slug, or display name.
-- @treturn table|nil
function Jobs:GetFactionByJobID(jobID)
	return self:GetJobFaction(jobID)
end

--- Returns the job registered for a whitelist ID.
-- @realm shared
-- @string whitelistId Whitelist identifier.
-- @treturn table|nil
function Jobs:GetJobByWhitelistId(whitelistId)
	local index = Jobs.whitelistCache[whitelistId]
	return index and Jobs.indices[index] or nil
end

-- ---------------------------------------------------------------------------
-- Player tracking
-- ---------------------------------------------------------------------------

--- Adds a player to a job's `players` table (idempotent).
-- @realm shared
-- @player ply Player to add.
-- @param jobID Number index, slug, or display name.
function Jobs:AddPlayer(ply, jobID)
	local job = self:ResolveJob(jobID)
	if not (job and IsValid(ply)) then return end
	job.players[ply:EntIndex()] = ply
end

--- Removes a player from a job's `players` table.
-- @realm shared
-- @player ply Player to remove.
-- @param jobID Number index, slug, or display name.
function Jobs:RemovePlayer(ply, jobID)
	local job = self:ResolveJob(jobID)
	if not (job and IsValid(ply)) then return end
	job.players[ply:EntIndex()] = nil
end

--- Returns the live player table for a job.
-- @realm shared
-- @param jobID Number index, slug, or display name.
-- @treturn table
function Jobs:GetPlayers(jobID)
	local job = self:ResolveJob(jobID)
	return job and job.players or {}
end

--- Returns the number of players currently in a job.
-- @realm shared
-- @param jobID Number index, slug, or display name.
-- @treturn number
function Jobs:GetJobPlayerCount(jobID)
	local job = self:ResolveJob(jobID)
	if not job then return 0 end
	return #team.GetPlayers(job.index)
end

--- Returns every player across every job in a category.
-- @realm shared
-- @param categoryID Number index, slug, or display name.
-- @treturn table
function Jobs:GetPlayersFromCategory(categoryID)
	local category = self:ResolveCategory(categoryID)
	if not category then return {} end

	local out = {}
	for _, jobSlug in ipairs(category.jobs) do
		local job = Jobs.teams[jobSlug]
		if job then table.Add(out, team.GetPlayers(job.index)) end
	end
	return out
end

--- Returns every player across every job in a faction.
-- @realm shared
-- @param factionID Number index, slug, or display name.
-- @treturn table
function Jobs:GetPlayersFromFaction(factionID)
	local faction = self:ResolveFaction(factionID)
	if not faction then return {} end

	local out = {}
	for _, catSlug in ipairs(faction.categories) do
		table.Add(out, self:GetPlayersFromCategory(catSlug))
	end
	for _, jobSlug in ipairs(faction.looseJobs) do
		local job = Jobs.teams[jobSlug]
		if job then table.Add(out, team.GetPlayers(job.index)) end
	end
	return out
end

--- Returns every player that belongs to any registered job.
-- @realm shared
-- @treturn table
function Jobs:GetAllPlayers()
	local out = {}
	for _, faction in pairs(Jobs.factions) do
		table.Add(out, self:GetPlayersFromFaction(faction.uniqueID))
	end
	return out
end

--- Returns the total count of players belonging to any registered job.
-- @realm shared
-- @treturn number
function Jobs:GetAllPlayersCount()
	local count = 0
	for _, faction in pairs(Jobs.factions) do
		count = count + #self:GetPlayersFromFaction(faction.uniqueID)
	end
	return count
end

--- Returns the total count of players in a category.
-- @realm shared
-- @param categoryID Number index, slug, or display name.
-- @treturn number
function Jobs:GetCountOfCategory(categoryID)
	local category = self:ResolveCategory(categoryID)
	if not category then return 0 end

	local count = 0
	for _, jobSlug in ipairs(category.jobs) do
		local job = Jobs.teams[jobSlug]
		if job then count = count + #team.GetPlayers(job.index) end
	end
	return count
end

--- Returns the total count of players in a faction.
-- @realm shared
-- @param factionID Number index, slug, or display name.
-- @treturn number
function Jobs:GetCountOfFaction(factionID)
	return #self:GetPlayersFromFaction(factionID)
end

-- ---------------------------------------------------------------------------
-- Whitelist helpers
-- ---------------------------------------------------------------------------

--- Returns whether the player has a faction whitelist.
-- @realm shared
-- @player ply Player to check.
-- @param factionID Number index, slug, or display name.
-- @treturn bool
function Jobs:PlayerHasFactionWhitelist(ply, factionID)
	if not IsValid(ply) then return false end

	local faction = self:ResolveFaction(factionID)
	if not faction then return false end
	if faction.isDefault then return true end

	local whitelists
	if SERVER then
		whitelists = ply:GetData("whitelists", {})
	else
		whitelists = Psalm.localData and Psalm.localData.whitelists or {}
	end

	local schema = (Schema and Schema.folder) or ""
	return (whitelists[schema] and whitelists[schema][faction.uniqueID] == true) or false
end

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

--- Returns whether a player can see a job in the menu.
-- @realm shared
-- @player ply Player to check.
-- @table job Job table.
-- @treturn bool
function Jobs:CanPlayerSeeJob(ply, job)
	if not (IsValid(ply) and job) then return false end

	local faction = self:GetJobFaction(job)
	if faction and faction.canSwitchTo and not faction.canSwitchTo(ply, faction) then
		return false
	end

	if job.canSwitchTo and not job.canSwitchTo(ply, job) then
		return false
	end

	return true
end

--- Returns whether a player can become a job, with a reason on failure.
-- @realm shared
-- @param jobID Number index, slug, or display name.
-- @player ply Player to check.
-- @treturn bool
-- @treturn string Empty on success, reason on failure.
function Jobs:PlayerCanBecomeJob(jobID, ply)
	local job = self:ResolveJob(jobID)
	if not job then return false, "Unknown job" end
	if not IsValid(ply) then return false, "Invalid player" end

	if not self:CanPlayerSeeJob(ply, job) then
		return false, "Недостаточно прав"
	end

	local faction = self:GetJobFaction(job)
	if faction and job.whitelistId and not self:PlayerHasFactionWhitelist(ply, faction) then
		return false, "Требуется вайтлист"
	end

	if job.registeredRequired and not ply:GetData("registered", false) then
		return false, "Требуется регистрация"
	end

	if job.levelRequired and job.category then
		if ply:GetCategoryLevel(job.category) < job.levelRequired then
			return false, "Требуется уровень " .. job.levelRequired
		end
	end

	if job.pointsRequired then
		local points = ply:GetData("loyaltyPoints", 0) or 0
		if points < job.pointsRequired then
			return false, "Требуется " .. job.pointsRequired .. " очков лояльности"
		end
	end

	if self:DoesJobHaveQueue(jobID) then
		return false, "Джоб переполнен"
	end

	return true, ""
end

--- Returns whether a job is at capacity and requires a queue.
-- @realm shared
-- @param jobID Number index, slug, or display name.
-- @treturn bool
function Jobs:DoesJobHaveQueue(jobID)
	local job = self:ResolveJob(jobID)
	if not job or not job.max then return false end
	if Jobs.jobsWithQueues[job.index] == true then return true end
	return #team.GetPlayers(job.index) >= job.max
end

-- ---------------------------------------------------------------------------
-- Spawn points (keyed by category slug)
-- ---------------------------------------------------------------------------

--- Registers a spawn point for a category.
-- @realm server
-- @param categoryID Number index, slug, or display name.
-- @string name Spawn point name.
-- @table data Fields: `Position` (Vector, array, or `function(ply)`),
--   `LoyaltyPoints`, `RegistrationRequired`.
function Jobs:RegisterSpawnPoint(categoryID, name, data)
	local category = self:ResolveCategory(categoryID)
	if not category then
		ErrorNoHalt("Psalm.Jobs: unknown category '" .. tostring(categoryID) ..
			"' for spawn point '" .. tostring(name) .. "'\n")
		return
	end

	local key = category.uniqueID
	self.spawnPoints[key] = self.spawnPoints[key] or {}
	self.spawnPoints[key][name] = table.Merge({ Name = name }, data or {})
end

--- Registers a default spawn point used when the player's category has none.
-- @realm server
-- @string name Spawn point name.
-- @table data Same shape as @{Jobs:RegisterSpawnPoint}.
function Jobs:RegisterDefaultSpawnPoint(name, data)
	self.defaultSpawnPoints[name] = table.Merge({ Name = name }, data or {})
end

--- Returns the spawn-point table for a category, plus whether it was specific.
-- @realm shared
-- @param categoryID Number index, slug, or display name.
-- @treturn table
-- @treturn bool
function Jobs:GetSpawnPoints(categoryID)
	local category = self:ResolveCategory(categoryID)
	local key = category and category.uniqueID

	if key and self.spawnPoints[key] then
		return self.spawnPoints[key], true
	end
	return self.defaultSpawnPoints, false
end

--- Returns a single spawn-point entry.
-- @realm shared
-- @param categoryID Number index, slug, or display name.
-- @string name Spawn point name.
-- @treturn table|nil
function Jobs:GetSpawnPoint(categoryID, name)
	local points = self:GetSpawnPoints(categoryID)
	return points and points[name]
end

--- Resolves a spawn-point position.
-- @realm shared
-- @player ply Player requesting the spawn.
-- @table spawnPoint Spawn-point entry.
-- @treturn Vector|nil
-- @treturn string|nil
function Jobs:GetSpawnPointPos(ply, spawnPoint)
	if not spawnPoint or not spawnPoint.Position then return nil end

	local pos
	if isfunction(spawnPoint.Position) then
		pos = spawnPoint.Position(ply)
	elseif istable(spawnPoint.Position) then
		pos = spawnPoint.Position[math.random(1, #spawnPoint.Position)]
	else
		pos = spawnPoint.Position
	end

	return pos, spawnPoint.Name
end

--- Returns the best spawn point for a player based on their current category.
-- @realm shared
-- @player ply Player.
-- @treturn Vector|nil
-- @treturn string|nil
function Jobs:GetPlayerSpawnPoint(ply)
	local job = Jobs.indices[ply:Team()]
	local category = job and job.category

	if category then
		local points, ok = self:GetSpawnPoints(category)
		if ok and points then
			local entry = table.Random(points)
			if entry then return self:GetSpawnPointPos(ply, entry) end
		end
	end

	local entry = table.Random(self.defaultSpawnPoints)
	return self:GetSpawnPointPos(ply, entry)
end

-- ---------------------------------------------------------------------------
-- Model resolution
-- ---------------------------------------------------------------------------

--- Resolves the playermodel a player should receive for a job.
-- @realm shared
-- @player ply Player to resolve for.
-- @param jobID Number index, slug, or display name. Defaults to the player's job.
-- @treturn table|nil `{ model, skin?, bodygroups? }`
function Jobs:GetPlayerJobModel(ply, jobID)
	local job = self:ResolveJob(jobID or (IsValid(ply) and ply:Team()))
	if not job then return nil end

	if job.modelbase and IsValid(ply) then
		local base = ply.GetModelBase and ply:GetModelBase() or "male_01"
		local resolved = string.format(job.modelbase, base)
		if util.IsValidModel(resolved) then return { model = resolved } end

		if job.modelfallback then
			local fb = job.modelfallback.male
			if ply.IsMale then
				fb = ply:IsMale() and job.modelfallback.male or job.modelfallback.female
			end
			if fb then return { model = string.format(job.modelbase, fb) } end
		end
	end

	if job.resolvedModels and #job.resolvedModels > 0 then
		return table.Random(job.resolvedModels)
	end

	if job.model then return { model = job.model } end
	return nil
end

-- ---------------------------------------------------------------------------
-- Server: networking and lifecycle hooks
-- ---------------------------------------------------------------------------

if SERVER then
	util.AddNetworkString("Psalm.Jobs.Sync")

	--- Sends the full registry to a client.
	-- @realm server
	-- @player ply Target player.
	local function SendJobsToClient(ply)
		net.Start("Psalm.Jobs.Sync")
		net.WriteTable({
			factions        = Jobs.factions,
			factionIndices  = Jobs.factionIndices,
			categories      = Jobs.categories,
			categoryIndices = Jobs.categoryIndices,
			teams           = Jobs.teams,
			indices         = Jobs.indices,
		})
		net.Send(ply)
	end

	hook.Add("PlayerInitialSpawn", "Psalm.Jobs.SendData", function(ply)
		SendJobsToClient(ply)
		local job = Jobs.indices[ply:Team()]
		if job then Jobs:AddPlayer(ply, ply:Team()) end
	end)

	hook.Add("PlayerDisconnected", "Psalm.Jobs.UntrackPlayer", function(ply)
		for _, job in pairs(Jobs.indices) do
			if job.players then job.players[ply:EntIndex()] = nil end
		end
	end)

	hook.Add("PlayerLoadout", "Psalm.Jobs.PlayerLoadout", function(client)
		local job = Jobs.indices[client:Team()]
		if not job then return end

		if job.PlayerLoadout then return job:PlayerLoadout(client) end

		for _, wep in ipairs(job.weapons) do client:Give(wep) end
		for ammoType, amount in pairs(job.ammo or {}) do
			client:GiveAmmo(amount, ammoType, true)
		end
	end)

	hook.Add("OnPlayerChangedTeam", "Psalm.Jobs.OnChangedTeam", function(client, oldTeam, newTeam)
		local oldJob = Jobs.indices[oldTeam]
		local newJob = Jobs.indices[newTeam]

		if oldJob then
			Jobs:RemovePlayer(client, oldTeam)
			if oldJob.OnLeave then oldJob:OnLeave(client, newJob) end
		end

		if newJob then
			Jobs:AddPlayer(client, newTeam)
			if newJob.OnJoin then newJob:OnJoin(client, oldJob) end
		end

		local modelData = Jobs:GetPlayerJobModel(client, newTeam)
		if modelData then
			client:SetModel(modelData.model)
			if modelData.skin then client:SetSkin(modelData.skin) end
			if modelData.bodygroups then
				for i = 0, client:GetNumBodyGroups() - 1 do
					client:SetBodygroup(i, 0)
				end
				if isstring(modelData.bodygroups) then
					for i = 1, #modelData.bodygroups do
						local bg = tonumber(modelData.bodygroups:sub(i, i))
						if bg and client:GetBodyGroup(i - 1) ~= nil then
							client:SetBodygroup(i - 1, bg)
						end
					end
				end
			end
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Player meta: shared data access
-- ---------------------------------------------------------------------------

local playerMeta = FindMetaTable("Player")

do
	if SERVER then
		--- Returns a value from the player's persistent data store.
		-- @realm server
		-- @param key Data key, or `true` for the whole store.
		-- @param default Value returned when missing.
		function playerMeta:GetData(key, default)
			if key == true then return self.psData end
			local data = self.psData and self.psData[key]
			if data == nil then return default end
			return data
		end

		--- Sets a value in the player's persistent data store and syncs it.
		-- @realm server
		-- @param key Data key.
		-- @param value Value to store.
		-- @bool[opt=false] bNoNetworking Skip the per-key sync.
		function playerMeta:SetData(key, value, bNoNetworking)
			self.psData = self.psData or {}
			self.psData[key] = value

			if not bNoNetworking then
				net.Start("psData")
					net.WriteString(key)
					net.WriteType(value)
				net.Send(self)
			end
		end
	else
		--- Returns a value from the player's locally synced data store.
		-- @realm client
		-- @param key Data key.
		-- @param default Value returned when missing.
		function playerMeta:GetData(key, default)
			local data = Psalm.localData and Psalm.localData[key]
			if data == nil then return default end
			return data
		end

		net.Receive("psDataSync", function()
			Psalm.localData = net.ReadTable()
			Psalm.playTime  = net.ReadUInt(32)
		end)

		net.Receive("psData", function()
			Psalm.localData = Psalm.localData or {}
			Psalm.localData[net.ReadString()] = net.ReadType()
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Player meta: job helpers
-- ---------------------------------------------------------------------------

--- Returns the player's job table, or `nil`.
-- @realm shared
-- @treturn table|nil
function playerMeta:GetJobTable()
	return Jobs.indices[self:Team()]
end

--- Alias for @{playerMeta:GetJobTable}.
-- @realm shared
-- @treturn table|nil
function playerMeta:GetJob()
	return self:GetJobTable()
end

--- Returns the player's job index, or `-1`.
-- @realm shared
-- @treturn number
function playerMeta:GetJobID()
	local job = self:GetJobTable()
	return job and job.index or -1
end

--- Returns the player's job slug, or `nil`.
-- @realm shared
-- @treturn string|nil
function playerMeta:GetJobUniqueID()
	local job = self:GetJobTable()
	return job and job.uniqueID or nil
end

--- Returns the player's job display name, or `"Unknown"`.
-- @realm shared
-- @treturn string
function playerMeta:GetJobName()
	local job = self:GetJobTable()
	return job and job.name or "Unknown"
end

--- Returns the player's job color.
-- @realm shared
-- @treturn Color
function playerMeta:GetJobColor()
	return team.GetColor(self:Team()) or Color(255, 255, 255)
end

--- Returns the player's job salary, or `0`.
-- @realm shared
-- @treturn number
function playerMeta:GetJobSalary()
	local job = self:GetJobTable()
	return job and job.salary or 0
end

--- Returns the player's category slug, or `nil`.
-- @realm shared
-- @treturn string|nil
function playerMeta:GetJobCategory()
	local job = self:GetJobTable()
	return job and job.category or nil
end

--- Returns the player's category table.
-- @realm shared
-- @treturn table|nil
function playerMeta:GetJobCategoryTable()
	return Jobs:GetJobCategoryTable(self:Team())
end

--- Returns the player's faction slug.
-- @realm shared
-- @treturn string|nil
function playerMeta:GetJobFactionID()
	local faction = Jobs:GetJobFaction(self:Team())
	return faction and faction.uniqueID or nil
end

--- Returns the player's faction table.
-- @realm shared
-- @treturn table|nil
function playerMeta:GetJobFaction()
	return Jobs:GetJobFaction(self:Team())
end

--- Returns the player's job immunity, or `-1`.
-- @realm shared
-- @treturn number
function playerMeta:GetJobImmunity()
	local job = self:GetJobTable()
	return job and job.immunity or -1
end

--- Returns whether the player has a non-default job.
-- @realm shared
-- @treturn bool
function playerMeta:IsEmployed()
	local job = self:GetJobTable()
	return job ~= nil and not job.isDefault
end

--- Returns the player's level in a category.
-- When `category` is omitted, uses the player's own category.
-- @realm shared
-- @param category Number index, slug, or display name.
-- @treturn number
function playerMeta:GetCategoryLevel(category)
	local cat = category and Jobs:ResolveCategory(category) or self:GetJobCategoryTable()
	if not cat then return 1 end

	local xp = self:GetData("jobXP", {}) or {}
	local entry = xp[cat.uniqueID]
	return math.max(1, (entry and entry.level) or 1)
end

--- Returns the player's XP in a category.
-- @realm shared
-- @param category Number index, slug, or display name.
-- @treturn number
function playerMeta:GetCategoryXP(category)
	local cat = category and Jobs:ResolveCategory(category) or self:GetJobCategoryTable()
	if not cat then return 0 end

	local xp = self:GetData("jobXP", {}) or {}
	local entry = xp[cat.uniqueID]
	return math.max(0, (entry and entry.xp) or 0)
end

--- Returns the player's loyalty points.
-- @realm shared
-- @treturn number
function playerMeta:GetLoyaltyPoints()
	return self:GetData("loyaltyPoints", 0) or 0
end

--- Returns whether the player belongs to a government-style faction.
-- @realm shared
-- @treturn bool
function playerMeta:IsGovernmentJob()
	local faction = self:GetJobFaction()
	return (faction and faction.isGovernment == true)
	    or (self:GetJobTable() and self:GetJobTable().isGovernment == true)
	    or false
end

--- Returns whether the player is in a restricted faction.
-- @realm shared
-- @bool[opt=false] carOnly
-- @bool[opt=false] wepOnly
-- @bool[opt=false] houseOnly
-- @treturn bool
function playerMeta:IsRestrictedJob(carOnly, wepOnly, houseOnly)
	local faction = self:GetJobFaction()
	if faction and faction.restricted then return true end
	local job = self:GetJobTable()
	return job and job.restricted == true or false
end

--- Returns whether the player belongs to a given category.
-- @realm shared
-- @param categoryID Number index, slug, or display name.
-- @treturn bool
function playerMeta:IsJobCategory(categoryID)
	local cat = Jobs:ResolveCategory(categoryID)
	if not cat then return false end
	return self:GetJobCategory() == cat.uniqueID
end

--- Returns whether the player belongs to a given faction.
-- @realm shared
-- @param factionID Number index, slug, or display name.
-- @treturn bool
function playerMeta:IsJobFaction(factionID)
	local faction = Jobs:ResolveFaction(factionID)
	if not faction then return false end
	return self:GetJobFactionID() == faction.uniqueID
end

-- ---------------------------------------------------------------------------
-- Client: syncing and whitelist lookup
-- ---------------------------------------------------------------------------

if CLIENT then
	net.Receive("Psalm.Jobs.Sync", function()
		local data = net.ReadTable()
		Jobs.factions        = data.factions        or {}
		Jobs.factionIndices  = data.factionIndices  or {}
		Jobs.categories      = data.categories      or {}
		Jobs.categoryIndices = data.categoryIndices or {}
		Jobs.teams           = data.teams           or {}
		Jobs.indices         = data.indices         or {}
	end)

	--- Returns whether the local player has a faction whitelist.
	-- @realm client
	-- @param factionID Number index, slug, or display name.
	-- @treturn bool
	function Jobs:HasWhitelist(factionID)
		local faction = self:ResolveFaction(factionID)
		if not faction then return false end
		if faction.isDefault then return true end

		local whitelists = Psalm.localData and Psalm.localData.whitelists or {}
		local schema = (Schema and Schema.folder) or ""
		return (whitelists[schema] and whitelists[schema][faction.uniqueID] == true) or false
	end
end

hook.Run("Psalm.Jobs.Initialized")