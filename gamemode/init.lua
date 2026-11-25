DeriveGamemode('sandbox')

AddCSLuaFile('psalm/boot/sh_boot.lua')
include('psalm/boot/sh_boot.lua')
AddCSLuaFile('shared.lua')
include('shared.lua')

//concommand.Remove("gm_spawn")
//concommand.Remove("gm_spawnsent")
//concommand.Remove("gm_spawnvehicle")
//concommand.Remove("gm_giveswep")
concommand.Remove("gm_snap")

hook.Add("PlayerNoClip", "DisableNoclip", function(ply, state)
    if ply:IsAdmin() then
        return true 
    else
        return false
    end
end)