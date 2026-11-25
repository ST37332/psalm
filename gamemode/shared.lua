GM.Name = 'Psalm'

Psalm.Meta = Psalm.Meta or {}
Psalm.Gui = Psalm.Gui or {}

Psalm.Type = Psalm.Type or {
	[2] = "string",
	[4] = "text",
	[8] = "number",
	[16] = "player",
	[32] = "steamid",
	[64] = "character",
	[128] = "bool",
	[1024] = "color",
	[2048] = "vector",

	string = 2,
	text = 4,
	number = 8,
	player = 16,
	steamid = 32,
	character = 64,
	bool = 128,
	color = 1024,
	vector = 2048,

	optional = 256,
	array = 512
}

Psalm.Loader:Include("psalm/sh_auto.lua")

function GM:PlayerSpawn(ply) end

function GM:PlayerLoadout(ply) end

function GM:GetFallDamage(ply, speed) return 0 end

function GM:Initialize()
	Psalm.Print:Banner('             Welcome!             ', Color(80, 255 , 80))
end


function GM:OnReloaded()
	Psalm.Print:Banner('             Warning!             ', Color(255, 80 , 80))
	Psalm.Print:Banner('    Psalm has been reloaded!      ', Color(255, 80 , 80))
end