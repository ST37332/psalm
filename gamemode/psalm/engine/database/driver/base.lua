local BASE = {}
BASE.__index = BASE

function BASE:New(config)
    local obj = setmetatable({
        config = config,
        isConnected = false,
        queue = {},
        queueProcessing = false
    }, self)
    return obj
end

function BASE:Connect()
    error("DB Error: Connect() method not implemented in driver.")
end

function BASE:Raw(query, params, callback)
    error("DB Error: Raw() method not implemented in driver.")
end

function BASE:Escape(str)
    error("DB Error: Escape() method not implemented in driver.")
end

function BASE:Think()
    if self.queueProcessing or #self.queue == 0 or not self:IsConnected() then return end

    self.queueProcessing = true
    local task = table.remove(self.queue, 1)
    
    self:Raw(task[1], task[2], function(result)
        if task[3] then
            local ok, err = pcall(task[3], result)
            if not ok then
                ErrorNoHalt("[DB] Callback error: " .. err .. "\n")
            end
        end
        self.queueProcessing = false
    end)
end

function BASE:IsConnected()
    return self.isConnected
end

function BASE:Queue(query, params, callback)
    table.insert(self.queue, {query, params, callback})
end

return BASE