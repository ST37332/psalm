Psalm.Net = Psalm.Net or {}

local Net = Psalm.Net

---@class Psalm.Net
--- Multiplexed networking layer. All framework + module net traffic flows through a single `Psalm.Net.msg` net string.
--- Outbound traffic queues so we never start a new `net.Start` while another one is mid-flight; inbound traffic is decoded once
--- and dispatched to handlers registered via `:Hook(name, callback, bNoDelay)`. Server-side, the dispatcher applies a per-player
--- per-name cooldown unless the receiver opted out.
---@field stored table<string, table> Registered inbound handlers keyed by message name, each `{callback, bNoDelay}`.
---@field cooldown table<string, table<string, number>> Per-steam64, per-name cooldown deadlines.
---@field queue table Pending outbound jobs awaiting their `net.Start` turn.
---@field queueActive boolean True while a queued job currently owns the outbound lock.
Net.stored      = Net.stored      or {}
Net.cooldown    = Net.cooldown    or {}
Net.queue       = Net.queue       or {}
Net.queueActive = Net.queueActive or false

-- ---------------------------------------------------------------------------
-- Safe argument unpacking (prevents stack overflow / DoS via unpack)
-- ---------------------------------------------------------------------------
function Psalm.SafeUnpack(t, i, j, callback)
    i = i or 1
    j = j or #t
    local args = {}
    for k = i, j do
        args[k - i + 1] = t[k]
        -- Flush buffer every 32 items to keep stack frames small
        if #args >= 32 then
            callback(table.unpack(args))
            args = {}
        end
    end
    if #args > 0 then
        callback(table.unpack(args))
    end
end

-- ---------------------------------------------------------------------------
-- Outbound queue
-- ---------------------------------------------------------------------------
function Net:Enqueue(job)
    if not isfunction(job) then return end

    self.queue[#self.queue + 1] = job

    if self.queueActive then return end
    self:ProcessQueue()
end

function Net:ProcessQueue()
    if self.queueActive then return end

    local job = self.queue[1]
    if not isfunction(job) then return end

    self.queueActive = true
    table.remove(self.queue, 1)

    local bReleased = false
    local function done()
        if bReleased then return end
        bReleased = true
        self.queueActive = false

        -- If there are more jobs, process them next tick to avoid deep recursion
        if self.queue[1] then
            timer.Simple(0, function()
                if Psalm and Net then
                    self:ProcessQueue()
                end
            end)
        end
    end

    local bOk, err = pcall(job, done)
    if not bOk then
        Psalm.Print:Error("[NET] Queued send failed: " .. tostring(err))
        done()
    end
end

--- Packs sender's varargs into a table, recording the argument count under `n`.
--- This prevents holes in the table (caused by nil arguments) from truncating the payload.
---@realm shared
---@param ... any Sender arguments, holes included.
---@return table arguments Packed arguments carrying an `n` count.
local function packArguments(...)
    local arguments = {...}
    arguments.n = select("#", ...)
    return arguments
end

--- SFS-encodes the argument table into the wire payload.
---@realm shared
---@param arguments table The arguments to encode.
---@return string|boolean payload Encoded payload, or false on failure.
function Net:BuildPayload(arguments)
    local encoded = sfs.encode(arguments)
    if not isstring(encoded) or #encoded < 1 then
        return false
    end
    return encoded
end

--- Queues a single net message.
---@realm shared
---@param name string Receiver hook name.
---@param arguments table Arguments to SFS-encode into the payload.
---@param sendFunc function The `net.Send*` call to issue inside the queue.
---@param debugMessage? string Optional message passed to `PrintDebug` after sendFunc.
---@param warningMessage? string Optional message passed to `PrintWarning` after sendFunc.
---@param canSend? fun(): boolean Optional recipient check run when the job takes its turn.
function Net:QueueMessage(name, arguments, sendFunc, debugMessage, warningMessage, canSend)
    if not isfunction(sendFunc) then return end

    local encoded = self:BuildPayload(arguments)
    if not encoded then
        Psalm.Print:Error("[NET] Failed to encode payload for '" .. tostring(name) .. "', message dropped")
        return
    end

    self:Enqueue(function(done)
        if isfunction(canSend) and canSend() == false then
            done()
            return
        end

        net.Start("Psalm.Net.msg")
        -- FIX: Use WriteString for binary-safe data transfer. WriteData with string length is unreliable.
        net.WriteString(name)
        net.WriteString(encoded)

        sendFunc()

        if isstring(debugMessage) and debugMessage ~= "" then
            Psalm.Print:Debug(debugMessage)
        end
        if isstring(warningMessage) and warningMessage ~= "" then
            Psalm.Print:Warning(warningMessage)
        end

        done()
    end)
end

--- Registers an inbound handler.
---@realm shared
---@param name string Unique identifier matching the sender's `:Start(... name ...)`.
---@param callback function Receives `(player, ...)` on the server, `(...)` on the client.
---@param bNoDelay? boolean Pass true to skip the per-player cooldown gate on the server side.
function Net:Hook(name, callback, bNoDelay)
    self.stored[name] = {callback, bNoDelay or false}
end

-- ---------------------------------------------------------------------------
-- Outbound senders
-- ---------------------------------------------------------------------------

if SERVER then
    util.AddNetworkString("Psalm.Net.msg")

    -- Descriptor builders for the outbound debug line.
    local function describeNick(target) return target:Nick() end
    local function describeCount(recipients) return #recipients .. " recipients" end
    local function describePVS(position) return "PVS at " .. tostring(position) end
    local function describePAS(position) return "PAS at " .. tostring(position) end
    local function describeOmit(target)
        if Psalm.Player:IsValid(target) then
            return "everyone except " .. target:Nick()
        end
        return "everyone except " .. #target .. " recipient(s)"
    end

    local function debugLine(name, describe, subject)
        local descriptor = isfunction(describe) and describe(subject) or tostring(describe)
        return "[NET] Sent '" .. tostring(name) .. "' to " .. descriptor
    end

    local function collectPlayers(target)
        local recipients = {}
        for _, v in ipairs(target) do
            if IsValid(v) and Psalm.Player:IsValid(v) then
                recipients[#recipients + 1] = v
            end
        end
        return recipients
    end

    local function broadcastFallback(self, name, arguments, callerName)
        self:QueueMessage(name, arguments, net.Broadcast, nil,
            "Psalm.Net:" .. callerName .. " called with invalid target, broadcasting to all clients instead")
    end

    function Net:StartPVS(position, name, ...)
        if not isvector(position) then return end
        self:QueueMessage(name, packArguments(...), function()
            net.SendPVS(position)
        end, debugLine(name, describePVS, position))
    end

    function Net:StartPAS(position, name, ...)
        if not isvector(position) then return end
        self:QueueMessage(name, packArguments(...), function()
            net.SendPAS(position)
        end, debugLine(name, describePAS, position))
    end

    function Net:Start(target, name, ...)
        local arguments = packArguments(...)

        if target == nil then
            self:QueueMessage(name, arguments, net.Broadcast, debugLine(name, "all clients"))
            return
        end

        if Psalm.Player:IsValid(target) then
            self:QueueMessage(name, arguments, function()
                net.Send(target)
            end, debugLine(name, describeNick, target), nil, function()
                return IsValid(target)
            end)
            return
        end

        if istable(target) then
            local recipients = collectPlayers(target)
            if recipients[1] then
                self:QueueMessage(name, arguments, function()
                    net.Send(recipients)
                end, debugLine(name, describeCount, recipients), nil, function()
                    local live = collectPlayers(recipients)
                    return live[1] ~= nil
                end)
            end
            return
        end

        broadcastFallback(self, name, arguments, "Start")
    end

    function Net:StartOmit(target, name, ...)
        local arguments = packArguments(...)

        if target == nil then
            self:QueueMessage(name, arguments, net.Broadcast, debugLine(name, "all clients"))
            return
        end

        if Psalm.Player:IsValid(target) or istable(target) then
            local omit = nil
            self:QueueMessage(name, arguments, function()
                -- FIX: Check if omit is valid before calling SendOmit to prevent engine errors
                if omit then
                    net.SendOmit(omit)
                else
                    net.Broadcast()
                end
            end, debugLine(name, describeOmit, target), nil, function()
                if Psalm.Player:IsValid(target) then
                    omit = IsValid(target) and target or nil
                else
                    local live = collectPlayers(target)
                    omit = live[1] ~= nil and live or nil
                end
                return true
            end)
            return
        end

        broadcastFallback(self, name, arguments, "StartOmit")
    end

    -- Clear cooldowns on disconnect to prevent memory leaks
    hook.Add("PlayerDisconnected", "Psalm.Net.ClearCooldowns", function(client)
        if not IsValid(client) then return end
        Net:ClearCooldowns(client:SteamID64())
    end)
else
    function Net:Start(name, ...)
        self:QueueMessage(name, packArguments(...), net.SendToServer, "[NET] Sent '" .. tostring(name) .. "' to server")
    end
end

-- ---------------------------------------------------------------------------
-- Inbound dispatch
-- ---------------------------------------------------------------------------

local function getCooldown(steam64, name)
    local perPlayer = Net.cooldown[steam64]
    if not istable(perPlayer) then
        perPlayer = {}
        Net.cooldown[steam64] = perPlayer
    end
    return perPlayer[name] or 0, perPlayer
end

--- Forgets every cooldown deadline held for one account.
---@realm server
---@param steam64 string The departing account's SteamID64.
function Net:ClearCooldowns(steam64)
    if not isstring(steam64) then return end
    self.cooldown[steam64] = nil
end

local function applyCooldown(client, name)
    local cooldown = 0.1
    if not isnumber(cooldown) or cooldown <= 0 then return false end

    local steam64 = client:SteamID64()
    local deadline, perPlayer = getCooldown(steam64, name)

    if deadline > CurTime() then
        Psalm.Print:Warning("[NET] '" .. name .. "' is on cooldown for " .. math.ceil(deadline - CurTime()) .. " seconds, ignoring request from " .. tostring(client))
        return true
    end

    perPlayer[name] = CurTime() + cooldown
    return false
end

local MAX_ARGUMENTS = 128

local function decodedArity(decoded)
    local declared = decoded.n
    if declared == nil then
        local count = #decoded
        return count <= MAX_ARGUMENTS and count or nil
    end

    declared = tonumber(declared)
    if not isnumber(declared) then return nil end
    if declared ~= math.floor(declared) then return nil end
    if declared < 0 or declared > MAX_ARGUMENTS then return nil end

    return declared
end

net.Receive("Psalm.Net.msg", function(len, client)
    local name = net.ReadString()

    local bytesLeft = net.BytesLeft and net.BytesLeft() or math.floor((len / 8) - (#name + 1))
    if not isnumber(bytesLeft) or bytesLeft <= 0 then return end

    local raw = net.ReadData(bytesLeft)
    local ok, decoded = pcall(sfs.decode, raw)
    if not ok or not istable(decoded) then
        Psalm.Print:Error("[NET] Decode failed for '" .. name .. "'")
        return
    end

    local stored = Net.stored[name]
    if not istable(stored) or not isfunction(stored[1]) then
        Psalm.Print:Error("[NET] No handler for '" .. name .. "'")
        return
    end

    local callback = stored[1]
    local bNoDelay = stored[2]

    local count = decodedArity(decoded)
    if not count then
        Psalm.Print:Error("[NET] Refusing '" .. name .. "': implausible argument count")
        return
    end

    if SERVER then
        if not bNoDelay and applyCooldown(client, name) then return end
        -- FIX: Use SafeUnpack to prevent stack overflow / DoS via massive argument tables
        Psalm.SafeUnpack(decoded, 1, count, function(...)
            callback(client, ...)
        end)
    else
        Psalm.SafeUnpack(decoded, 1, count, function(...)
            callback(...)
        end)
    end

    Psalm.Print:Debug("[NET] Received '" .. name .. "' from " .. (SERVER and client:Nick() or "server"))
end)