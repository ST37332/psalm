
Psalm.DB = Psalm.DB or {
	type = {
		-- TODO: more specific types, lengths, and defaults
		-- i.e INT(11) UNSIGNED, SMALLINT(4), LONGTEXT, VARCHAR(350), NOT NULL, DEFAULT NULL, etc
		[Psalm.Type.string] = "VARCHAR(255)",
		[Psalm.Type.text] = "TEXT",
		[Psalm.Type.number] = "INT(11)",
		[Psalm.Type.steamid] = "VARCHAR(20)",
		[Psalm.Type.bool] = "TINYINT(1)"
	}
}

local DB = Psalm.DB

DB.config = Psalm.DB.Database or {}

function DB.Connect()
	DB.config.adapter = DB.config.adapter or "sqlite"

	local dbmodule = DB.config.adapter
	local hostname = DB.config.hostname
	local username = DB.config.username
	local password = DB.config.password
	local database = DB.config.database
	local port = DB.config.port

	mysql:SetModule(dbmodule)
	mysql:Connect(hostname, username, password, database, port)
end

function DB.LoadTables()
	local query

	query = mysql:Create("ps_inventories")
		query:Create("inventory_id", "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT")
		query:Create("character_id", "INT(11) UNSIGNED NOT NULL")
		query:Create("inventory_type", "VARCHAR(150) DEFAULT NULL")
		query:PrimaryKey("inventory_id")
	query:Execute()

	query = mysql:Create("ps_items")
		query:Create("item_id", "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT")
		query:Create("inventory_id", "INT(11) UNSIGNED NOT NULL")
		query:Create("unique_id", "VARCHAR(60) NOT NULL")
		query:Create("character_id", "INT(11) UNSIGNED DEFAULT NULL")
		query:Create("player_id", "VARCHAR(20) DEFAULT NULL")
		query:Create("data", "TEXT DEFAULT NULL")
		query:Create("x", "SMALLINT(4) NOT NULL")
		query:Create("y", "SMALLINT(4) NOT NULL")
		query:PrimaryKey("item_id")
	query:Execute()

	query = mysql:Create("ps_players")
		query:Create("steamid", "VARCHAR(20) NOT NULL")
		query:Create("steam_name", "VARCHAR(32) NOT NULL")
		query:Create("play_time", "INT(11) UNSIGNED DEFAULT NULL")
		query:Create("address", "VARCHAR(15) DEFAULT NULL")
		query:Create("last_join_time", "INT(11) UNSIGNED DEFAULT NULL")
		query:Create("data", "TEXT")
		query:PrimaryKey("steamid")
	query:Execute()
end

function DB.WipeTables(callback)
	local query
	query = mysql:Drop("ps_inventories")
	query:Execute()

	query = mysql:Drop("ps_items")
	query:Execute()

	query = mysql:Drop("ps_players")
		query:Callback(callback)
	query:Execute()
end

hook.Add("InitPostEntity", "psDatabaseConnect", function()
	-- Connect to the database using SQLite, mysqoo, or tmysql4.
	DB.Connect()
end)

local resetCalled = 0

concommand.Add("ps_wipedb", function(client, cmd, arguments)
	-- can only be ran through the server's console
	if (!IsValid(client)) then
		if (resetCalled < RealTime()) then
			resetCalled = RealTime() + 3

			MsgC(Color(255, 0, 0),
				"[Psalm] WIPING THE DATABASE WILL PERMENANTLY REMOVE ALL PLAYER, CHARACTER, ITEM, AND INVENTORY DATA.\n")
			MsgC(Color(255, 0, 0), "[Psalm] THE SERVER WILL RESTART TO APPLY THESE CHANGES WHEN COMPLETED.\n")
			MsgC(Color(255, 0, 0), "[Psalm] TO CONFIRM DATABASE RESET, RUN 'ps_wipedb' AGAIN WITHIN 3 SECONDS.\n")
		else
			resetCalled = 0
			MsgC(Color(255, 0, 0), "[Psalm] DATABASE WIPE IN PROGRESS...\n")

			hook.Run("OnWipeTables")
			DB.WipeTables(function()
				MsgC(Color(255, 255, 0), "[Psalm] DATABASE WIPE COMPLETED!\n")
				RunConsoleCommand("changelevel", game.GetMap())
			end)
		end
	end
end)
