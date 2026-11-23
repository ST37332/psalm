if not mysqloo then return end

local BASE = include("base.lua")
local MYSQL = setmetatable({}, {__index = BASE})
MYSQL.__index = MYSQL

function MYSQL:New(config)
    local obj = BASE.New(self, config)
    return obj
end

function MYSQL:Connect()
    if self.connection and self.connection:ping() then return end

    self.connection = mysqloo.connect(
        self.config.Host, 
        self.config.User, 
        self.config.Pass, 
        self.config.Database, 
        self.config.Port or 3306
    )

    self.connection.onConnected = function()
        self.isConnected = true
        self.connection:setCharacterSet("utf8mb4")
        MsgC(Color(100, 255, 100), "[DB:MySQLoo] Connected to database.\n")
        hook.Run("DatabaseConnected")
    end

    self.connection.onConnectionFailed = function(reason)
        ErrorNoHalt("[DB:MySQLoo] Connection failed: " .. reason .. "\n")
        hook.Run("DatabaseConnectionFailed", reason)
    end

    self.connection:connect()
end

function MYSQL:IsConnected()
    return self.connection and self.connection:ping()
end

function MYSQL:Raw(query, params, callback)
    if not self:IsConnected() then
        ErrorNoHalt("[DB:MySQLoo] Not connected!\n")
        return
    end

    local queryObj = self.connection:query(query)
    queryObj:setOption(mysqloo.OPTION_NAMED_FIELDS)

    if params and #params > 0 then
        queryObj:setPrepared(true)
        for i, v in ipairs(params) do
            queryObj:addParameter(i, v)
        end
    end

    queryObj.onSuccess = function(qObj, data)
        if callback then 
            local ok, err = pcall(callback, data, true, tonumber(qObj:lastInsert())) 
            if not ok then ErrorNoHalt("[DB:MySQLoo] Callback error: " .. err .. "\n") end
        end
    end

    queryObj.onError = function(qObj, err)
        ErrorNoHalt("[DB:MySQLoo] Query Error!\nQuery: " .. query .. "\nError: " .. err .. "\n")
        if callback then callback(false) end
    end

    queryObj:start()
end

function MYSQL:Escape(str)
    if self.connection then
        return self.connection:escape(str)
    end
    return sql.SQLStr(str, true)
end

function MYSQL:Think()
    BASE.Think(self)
    if mysqloo and mysqloo.poll then mysqloo.poll() end
end

return MYSQL