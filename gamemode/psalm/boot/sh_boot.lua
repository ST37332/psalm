MsgC(Color(82, 255, 189), '[PSALM | BOOT]', Color(184, 184, 184), ' Loading the boot system\n')

Psalm = Psalm or {}


if SERVER then
    AddCSLuaFile('sh_loader.lua')
    include('sh_loader.lua')
else
    include('sh_loader.lua')
end

