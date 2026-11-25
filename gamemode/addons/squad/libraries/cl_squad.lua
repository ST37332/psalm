
net.Receive("Psalm.Squad.Invite", function()
    local id = net.ReadUInt(32)
    local name = net.ReadString()

    Derma_Query(
        "Приглашение в сквад '" .. name .. "'",
        "Сквад",
        "Принять", function() net.Start("Psalm.Squad.Request") net.WriteUInt(id, 32) net.WriteBool(true) net.SendToServer() end,
        "Отклонить", function() end
    )
end)

net.Receive("Psalm.Squad.Sync", function()
    local id = net.ReadUInt(32)
    local sq = net.ReadTable()

    if not istable(sq) or (sq == true) then
        Psalm.Squad.ClientList[id] = nil
        return
    end

    Psalm.Squad.ClientList[id] = sq
end)

net.Receive("Psalm.Squad.Request", function()
    local id = net.ReadUInt(32)
    local accept = net.ReadBool()
    if accept then
        squad:AcceptInvite(LocalPlayer(), id)
    end
end)

concommand.Add("psalm_squad_create", function(ply, _, args)
    if not IsFirstTimePredicted() then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if SERVER then squad:Create(ply, args[1] or "Unnamed Squad") end
end)

concommand.Add("psalm_squad_leave", function(ply)
    if not IsFirstTimePredicted() then return end
    if SERVER then squad:Leave(ply) end
end)