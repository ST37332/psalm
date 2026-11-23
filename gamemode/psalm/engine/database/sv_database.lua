Psalm.DB = Psalm.DB or {}

local DB = Psalm.DB

include("sv_types.lua")

DB.Config = {
    Adapter = file.Exists("config/database.lua", "LUA") and include("config/database.lua") or nil
}

if not DB.Config.Adapter then
    DB.Config.Adapter = {
        driver = "sqlite",
        database = "gmod_data"
    }
end

DB.Driver = nil
DB.Builder = nil

function DB.Initialize()
    local driverPath = "driver/" .. DB.Config.Adapter.driver .. ".lua"
    if not file.Exists(driverPath, "LUA") then
        ErrorNoHalt("[DB] Driver not found: " .. DB.Config.Adapter.driver .. "\n")
        return
    end

    local driverClass = include(driverPath)
    DB.Driver = driverClass:New(DB.Config.Adapter)
    
    local builderClass = include("sv_query_b.lua") and AddCSLuaFile('sv_query_b.lua')
    DB.Builder = builderClass:New(DB.Driver)

    DB.Driver:Connect()
end

function DB.Query()
    return DB.Builder:NewQuery()
end

hook.Add("InitPostEntity", "DB_Initialize", function()
    DB.Initialize()
end)

hook.Add("Think", "DB_QueueProcessor", function()
    if DB.Driver and DB.Driver.Think then
        DB.Driver:Think()
    end
end)

concommand.Add("db_wipe", function(ply)
    if IsValid(ply) then return end
    print("[DB] Wiping tables...")
    DB.Query():Delete("ix_players"):Execute(function()
        DB.Query():Delete("ix_characters"):Execute(function()
            print("[DB] Wipe complete.")
        end)
    end)
end)