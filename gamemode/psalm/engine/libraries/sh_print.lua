--- Colored console logging library with severities, hooks, and utilities.
-- @module Psalm.Print

Psalm.Print = Psalm.Print or {}

local Print = Psalm.Print
local color = Psalm.Color

local unpack = unpack or table.unpack
local format = string.format

--- Mapping of level name to numeric severity.
-- @table Print.Levels
local LEVELS = {
	trace   = 0,
	debug   = 1,
	info    = 2,
	success = 3,
	warning = 4,
	error   = 5,
	danger  = 5,
	fatal   = 6,
}

--- Mapping of level name to display color.
-- @table Print.Colors
local LEVEL_COLORS = {
	trace   = color.muted   or color.gray,
	debug   = color.debug   or color.purple,
	info    = color.info    or color.lightblue,
	success = color.success or color.green,
	warning = color.warning or color.yellow,
	error   = color.danger  or color.red,
	danger  = color.danger  or color.red,
	fatal   = color.crimson or color.red,
}

--- Mapping of level name to display label.
-- @table Print.Labels
local LEVEL_LABELS = {
	trace   = "TRACE",
	debug   = "DEBUG",
	info    = "INFO",
	success = "SUCCESS",
	warning = "WARNING",
	error   = "ERROR",
	danger  = "DANGER",
	fatal   = "FATAL",
}

Print.Levels        = LEVELS
Print.Colors        = LEVEL_COLORS
Print.Labels        = LEVEL_LABELS
Print.enabled       = true
Print.level         = "trace"
Print.prefix        = "Psalm"
Print.showTimestamp = true
Print.showLevel     = true
Print.showCaller    = false
Print.hooks         = {}
Print._busy         = false

local function timestamp()
	return os.date("%H:%M:%S")
end

local function callerInfo(skip)
	local info = debug.getinfo((skip or 1) + 1, "Sl")
	if not info then return nil end
	return format("%s:%d", info.short_src or "?", info.currentline or 0)
end

local function serialize(val, depth, seen)
	depth = depth or 0
	seen  = seen  or {}
	local t = type(val)

	if t == "string" then return format("%q", val) end
	if t == "number" or t == "boolean" or t == "nil" then return tostring(val) end
	if t == "function" then return "<function>" end
	if t == "userdata" then return tostring(val) end
	if t == "thread"   then return "<thread>" end
	if t ~= "table"    then return tostring(val) end
	if seen[val]       then return "<cycle>" end
	if depth > 3       then return "{...}" end

	seen[val] = true

	local parts  = {}
	local indent = string.rep("  ", depth + 1)
	local close  = string.rep("  ", depth)

	for k, v in pairs(val) do
		local key = type(k) == "string" and k or "[" .. tostring(k) .. "]"
		parts[#parts + 1] = indent .. key .. " = " .. serialize(v, depth + 1, seen)
	end

	seen[val] = nil

	if #parts == 0 then return "{}" end
	table.sort(parts)
	return "{\n" .. table.concat(parts, ",\n") .. "\n" .. close .. "}"
end

local function emit(level, ...)
	if not Print.enabled then return end
	if (LEVELS[level] or 0) < (LEVELS[Print.level] or 0) then return end

	local n     = select("#", ...)
	local parts = {}
	for i = 1, n do
		local v = select(i, ...)
		if type(v) == "table" then
			parts[#parts + 1] = serialize(v)
		else
			parts[#parts + 1] = tostring(v)
		end
	end
	local message = table.concat(parts, " ")

	local lc    = LEVEL_COLORS[level] or color.white
	local label = format("%-7s", LEVEL_LABELS[level] or string.upper(level))

	local segs = {}
	if Print.showTimestamp then
		segs[#segs + 1] = color.muted    or color.gray
		segs[#segs + 1] = "[" .. timestamp() .. "] "
	end
	if Print.showLevel then
		segs[#segs + 1] = lc
		segs[#segs + 1] = "[" .. label .. "] "
	end
	if Print.prefix and Print.prefix ~= "" then
		segs[#segs + 1] = color.offwhite or color.white
		segs[#segs + 1] = "[" .. Print.prefix .. "] "
	end
	if Print.showCaller then
		local info = callerInfo(3)
		if info then
			segs[#segs + 1] = color.muted or color.gray
			segs[#segs + 1] = "(" .. info .. ") "
		end
	end
	segs[#segs + 1] = lc
	segs[#segs + 1] = message

	MsgC(unpack(segs))
	MsgN("")

	if Print._busy or #Print.hooks == 0 then return end

	Print._busy = true
	for i = 1, #Print.hooks do
		local ok, err = pcall(Print.hooks[i], level, message, ...)
		if not ok then
			MsgC(color.red, "[Psalm.Print] hook #" .. i .. " failed: " .. tostring(err) .. "\n")
		end
	end
	Print._busy = false
end

--- Logs a low-severity trace message. Hidden unless the level is set to `trace`.
-- @realm shared
-- @param ... Any number of values; tables are pretty-printed.
function Print:Trace(...)   emit("trace",   ...) end

--- Logs a debug message. Hidden unless the level is `debug` or `trace`.
-- @realm shared
-- @param ... Any number of values; tables are pretty-printed.
function Print:Debug(...)   emit("debug",   ...) end

--- Logs a standard informational message.
-- @realm shared
-- @param ... Any number of values; tables are pretty-printed.
function Print:Info(...)    emit("info",    ...) end

--- Logs a success message.
-- @realm shared
-- @param ... Any number of values; tables are pretty-printed.
function Print:Success(...) emit("success", ...) end

--- Alias for @{Print:Success}.
-- @realm shared
-- @param ... Any number of values; tables are pretty-printed.
function Print:Done(...)    emit("success", ...) end

--- Alias for @{Print:Success}.
-- @realm shared
-- @param ... Any number of values; tables are pretty-printed.
function Print:Ok(...)      emit("success", ...) end

--- Logs a warning message.
-- @realm shared
-- @param ... Any number of values; tables are pretty-printed.
function Print:Warning(...) emit("warning", ...) end

--- Alias for @{Print:Warning}.
-- @realm shared
-- @param ... Any number of values; tables are pretty-printed.
function Print:Warn(...)    emit("warning", ...) end

--- Logs an error message.
-- @realm shared
-- @param ... Any number of values; tables are pretty-printed.
function Print:Error(...)   emit("error",   ...) end

--- Logs a danger message. Same severity as @{Print:Error}.
-- @realm shared
-- @param ... Any number of values; tables are pretty-printed.
function Print:Danger(...)  emit("danger",  ...) end

--- Logs a fatal message and dumps the current stack trace.
-- @realm shared
-- @param ... Any number of values; tables are pretty-printed.
function Print:Fatal(...)
	emit("fatal", ...)
	Print:StackTrace(20, 2, "fatal")
end

--- Prints the given table with a human-readable, sorted layout.
-- @realm shared
-- @param tbl The table to inspect.
-- @string[opt] name Optional name shown before the table.
function Print:Table(tbl, name)
	emit("info", (name and (name .. " = ") or "") .. serialize(tbl))
end

--- Alias for @{Print:Table}.
-- @realm shared
-- @param tbl The table to inspect.
-- @string[opt] name Optional name shown before the table.
function Print:PrintTable(tbl, name)
	Print:Table(tbl, name)
end

--- Prints a blank line for spacing.
-- @realm shared
function Print:Blank()
	if not Print.enabled then return end
	MsgN("")
end

--- Prints a horizontal divider.
-- @realm shared
-- @string[opt="─"] char The character used to draw the line.
-- @int[opt=60] length The number of characters in the line.
function Print:Divider(char, length)
	if not Print.enabled then return end
	char   = char   or "─"
	length = length or 60
	MsgC(color.muted or color.gray, string.rep(char, length), "\n")
end

--- Prints a centered header with divider lines on either side.
-- @realm shared
-- @string text Header text.
function Print:Header(text)
	if not Print.enabled then return end
	text = tostring(text)
	local total = 60
	local pad   = math.max(0, math.floor((total - #text - 2) / 2))
	MsgC(color.info or color.lightblue,
		string.rep("─", pad), " ", text, " ", string.rep("─", pad), "\n")
end

--- Prints a boxed banner around the given text.
-- @realm shared
-- @string text Text placed inside the banner.
function Print:Banner(text)
	if not Print.enabled then return end
	text = tostring(text)
	local line = string.rep("═", #text + 2)
	MsgC(color.info or color.lightblue,
		"╔" .. line .. "╗\n",
		"║ " .. text .. " ║\n",
		"╚" .. line .. "╝\n")
end

--- Prints a bulleted list with an optional header.
-- @realm shared
-- @string[opt] title Optional header shown before the list.
-- @table items Array of items to bullet.
function Print:List(title, items)
	if not Print.enabled then return end
	if title then Print:Header(title) end
	for _, item in ipairs(items or {}) do
		MsgC(color.muted or color.gray, "  • ", color.offwhite or color.white, tostring(item), "\n")
	end
end

--- Prints text with a rainbow hue gradient.
-- @realm shared
-- @string text Text to colorize.
function Print:Rainbow(text)
	if not Print.enabled then return end
	text = tostring(text)
	local len  = #text
	local segs = {}
	for i = 1, len do
		local h = ((i - 1) / math.max(1, len)) * 360
		segs[#segs + 1] = HSLToColor(h, 0.85, 0.6)
		segs[#segs + 1] = text:sub(i, i)
	end
	MsgC(unpack(segs))
	MsgN("")
end

--- Dumps the current Lua stack trace to the console.
-- @realm shared
-- @int[opt=20] depth Maximum number of frames to show.
-- @int[opt=1] skip Number of frames to skip from the top.
-- @string[opt="trace"] level Level the trace is emitted under.
function Print:StackTrace(depth, skip, level)
	depth = depth or 20
	skip  = skip  or 1
	level = level or "trace"

	local lines = {}
	for i = skip + 1, skip + depth do
		local info = debug.getinfo(i, "Sln")
		if not info then break end
		lines[#lines + 1] = format("  [%02d] %s:%d %s (%s)",
			i - skip, info.short_src or "?", info.currentline or 0,
			info.name or "?", info.what or "?")
	end

	if #lines == 0 then
		emit(level, "(no stack trace available)")
		return
	end

	emit(level, "stack trace:\n" .. table.concat(lines, "\n"))
end

--- Enables or disables the whole library.
-- @realm shared
-- @bool b New enabled state.
function Print:SetEnabled(b)
	Print.enabled = not not b
end

--- Returns whether printing is enabled.
-- @realm shared
-- @treturn bool
function Print:IsEnabled()
	return Print.enabled
end

--- Sets the minimum severity that will be printed.
-- @realm shared
-- @string level One of: trace, debug, info, success, warning, error, fatal.
-- @treturn bool Whether the level was accepted.
function Print:SetLevel(level)
	level = tostring(level or ""):lower()
	if not LEVELS[level] then
		emit("warning", "unknown level: " .. level)
		return false
	end
	Print.level = level
	return true
end

--- Returns the current minimum severity.
-- @realm shared
-- @treturn string
function Print:GetLevel()
	return Print.level
end

--- Returns whether the given level would be printed under the current filter.
-- @realm shared
-- @string level Level name to check.
-- @treturn bool
function Print:Is(level)
	return Print.enabled and (LEVELS[level] or 0) >= (LEVELS[Print.level] or 0)
end

--- Sets the tag shown in the prefix brackets.
-- @realm shared
-- @string p Prefix text, or `nil` to hide it.
function Print:SetPrefix(p)     Print.prefix        = p        end
--- Returns the current prefix.
-- @realm shared
-- @treturn string
function Print:GetPrefix()      return Print.prefix            end
--- Toggles the timestamp segment.
-- @realm shared
-- @bool b Whether to show timestamps.
function Print:SetTimestamp(b)  Print.showTimestamp = not not b end
--- Toggles the level segment.
-- @realm shared
-- @bool b Whether to show level labels.
function Print:SetShowLevel(b)  Print.showLevel     = not not b end
--- Toggles the caller segment.
-- @realm shared
-- @bool b Whether to show caller file:line.
function Print:SetCaller(b)     Print.showCaller    = not not b end

--- Registers a listener invoked on every emitted message.
-- @realm shared
-- @func fn Signature: `fn(level, message, ...)`.
-- @treturn int Id usable with @{Print:RemoveHook}.
function Print:OnMessage(fn)
	if type(fn) ~= "function" then return end
	Print.hooks[#Print.hooks + 1] = fn
	return #Print.hooks
end

--- Removes a previously registered listener by id.
-- @realm shared
-- @int id Id returned by @{Print:OnMessage}.
function Print:RemoveHook(id)
	table.remove(Print.hooks, id)
end

--- Runs `fn`, logging its duration and whether it succeeded.
-- @realm shared
-- @string name Label used in the log message.
-- @func fn Function to execute.
-- @treturn bool Whether `fn` succeeded.
-- @treturn any Error value if it failed.
-- @treturn number Duration in milliseconds.
function Print:Benchmark(name, fn)
	local t0 = SysTime()
	local ok, err = pcall(fn)
	local ms = (SysTime() - t0) * 1000
	if ok then
		emit("success", format("%s completed in %.2fms", name, ms))
	else
		emit("error", format("%s failed after %.2fms: %s", name, ms, tostring(err)))
	end
	return ok, err, ms
end

--- Logs a fatal error and returns `false` when the condition is falsy.
-- @realm shared
-- @bool condition The value to assert.
-- @param ... Message parts forwarded to @{Print:Fatal}.
-- @treturn bool Whether the assertion passed.
function Print:Assert(condition, ...)
	if condition then return true end
	emit("fatal", ...)
	Print:StackTrace(20, 2, "fatal")
	return false
end

--- Runs `fn` with a header, catching and logging any error.
-- @realm shared
-- @string name Header text shown before execution.
-- @func fn Function to execute.
-- @treturn bool Whether `fn` succeeded.
-- @treturn any Error value if it failed.
function Print:Group(name, fn)
	Print:Header(name)
	local ok, err = pcall(fn)
	if not ok then emit("error", tostring(err)) end
	return ok, err
end

--- Writes args to the console without any decoration.
-- @realm shared
-- @param ... Any number of values.
function Print:Raw(...)
	if not Print.enabled then return end
	local n     = select("#", ...)
	local parts = {}
	for i = 1, n do parts[#parts + 1] = tostring(select(i, ...)) end
	MsgN(table.concat(parts, " "))
end

--- Logs a message under a custom category label and color.
-- @realm shared
-- @string label Category name shown in brackets.
-- @param col A @{Color} used for the label and message.
-- @param ... Any number of values; tables are pretty-printed.
function Print:Custom(label, col, ...)
	if not Print.enabled then return end
	col = col or color.white

	local segs = {}
	if Print.showTimestamp then
		segs[#segs + 1] = color.muted or color.gray
		segs[#segs + 1] = "[" .. timestamp() .. "] "
	end
	segs[#segs + 1] = col
	segs[#segs + 1] = "[" .. tostring(label) .. "] "

	local n     = select("#", ...)
	local parts = {}
	for i = 1, n do
		local v = select(i, ...)
		parts[#parts + 1] = type(v) == "table" and serialize(v) or tostring(v)
	end

	segs[#segs + 1] = col
	segs[#segs + 1] = table.concat(parts, " ")

	MsgC(unpack(segs))
	MsgN("")
end

Print.Log    = Print.Info
Print.Notice = Print.Info
Print.Succes = Print.Success

Print.Loaded = true

setmetatable(Print, {
	__call = function(_, ...)
		emit("info", ...)
	end,
})

Psalm.Print:Banner('             Welcome!             ')