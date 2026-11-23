local BASE = include("base.lua")
local SQLITE = setmetatable({}, {__index = BASE})
SQLITE.__index = SQLITE

function SQLITE:New(config)
    local obj = BASE.New(self, config)
    obj.dbName = config.Database or "gmoddb"
    return obj
end

function SQLITE:Connect()
    self.isConnected = true
    MsgC(Color(100, 255, 100), "[DB:SQLite] Using database: " .. self.dbName .. ".db\n")
    hook.Run("DatabaseConnected")
end

function SQLITE:Raw(query, params, callback)
    if not self:IsConnected() then
        ErrorNoHalt("[DB:SQLite] Not connected!\n")
        return
    end

    local finalQuery = query
    if params and #params > 0 then
        for i, v in ipairs(params) do
            if isbool(v) then v = v and 1 or 0 end
            finalQuery = string.gsub(finalQuery, "?", sql.SQLStr(tostring(v), true), 1)
        end
    end

    local result = sql.Query(finalQuery)
    
    if result == false then
        ErrorNoHalt("[DB:SQLite] Query Error!\nQuery: " .. finalQuery .. "\nError: " .. sql.LastError() .. "\n")
        if callback then callback(false) end
    else
        local lastID = tonumber(sql.QueryValue("SELECT last_insert_rowid()")) or 0
        if callback then callback(result, true, lastID) end
    end
end

function SQLITE:Escape(str)
    return sql.SQLStr(str, true)
end

return SQLITE