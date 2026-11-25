
Psalm.Squad = Psalm.Squad or {}

local squad = Psalm.Squad

squad.ClientList = squad.ClientList or {}
squad.List = squad.List or {} -- [number_squadID] = squadTable
squad.Factions = {FACTION_COMBINE} -- Сюда добавляются индексы фракций (числа), а не их объекты

-- Внутренний счетчик ID
squad._nextID = squad._nextID or 1

-- Helper: Проверка, доступна ли фракция для сквадов
local function IsFactionAllowed(factionID)
    local faction = Psalm.Jobs:ResolveFaction(factionID)
    if not faction then return false end
    for _, allowedID in ipairs(squad.Factions) do
        if faction.index == allowedID then
            return true
        end
    end
    return false
end

-- Helper: Получение таблицы сквада игрока
local function GetPlayerSquadData(ply)
    if not IsValid(ply) then return nil end
    local data = ply:GetData("squad", {})
    return {
        id = data.id or -1,
        rank = data.rank or 0 -- 0 - Owner, 1 - Member
    }
end

-- Helper: Сохранение данных сквада игрока
local function SetPlayerSquadData(ply, squadID, rank)
    if not IsValid(ply) then return end
    ply:SetData("squad", { id = squadID, rank = rank })
end

--- Создает новый сквад.
-- @realm server
-- @player leader Игрок-основатель.
-- @string name Название сквада.
-- @treturn number|nil ID сквада или nil при ошибке.
function squad:Create(leader, name)
    if not IsValid(leader) or not isstring(name) or name == "" then return nil end

    local job = leader:GetJobTable()
    if not job then return nil end

    local faction = Psalm.Jobs:GetJobFaction(job)
    if not faction or not IsFactionAllowed(faction.index) then
        leader:ChatPrint("[Squad] Ваша фракция не может создавать сквады.")
        return nil
    end

    local id = self._nextID
    self._nextID = self._nextID + 1

    self.List[id] = {
        id = id,
        name = name,
        leader = leader,
        members = {},
        invites = {},
    }
    
    self.List[id].members[leader:EntIndex()] = leader
    SetPlayerSquadData(leader, id, 0)
    
    -- Сразу заполняем серверную таблицу для клиента (ВАЖНО!)
    self.ClientList = self.ClientList or {}
    self.ClientList[id] = self.List[id]
    
    -- Отправляем всем клиентам
    net.Start("Psalm.Squad.Sync")
    net.WriteUInt(id, 32)
    net.WriteTable(self.List[id])
    net.Broadcast()

    leader:ChatPrint("[Squad] Вы создали сквад '" .. name .. "' (ID: " .. id .. ")")
    return id
end

--- Приглашает игрока в сквад.
-- @realm server
-- @player inviter Игрок, отправляющий приглашение (должен быть лидером).
-- @player target Цель приглашения.
function squad:Invite(inviter, target)
    if not IsValid(inviter) or not IsValid(target) then return end

    local inviterData = GetPlayerSquadData(inviter)
    local targetData = GetPlayerSquadData(target)

    -- Проверка лидерства
    if inviterData.id == -1 then
        inviter:ChatPrint("[Squad] Вы не состоите в скваде.")
        return
    end

    local sq = self.List[inviterData.id]
    if not sq or sq.leader ~= inviter then
        inviter:ChatPrint("[Squad] Только лидер может приглашать.")
        return
    end

    -- Проверка занятости цели
    if targetData.id ~= -1 then
        inviter:ChatPrint("[Squad] Игрок уже в скваде.")
        return
    end

    sq.invites[target:EntIndex()] = true

    net.Start("Psalm.Squad.Invite")
    net.WriteUInt(sq.id, 32)
    net.WriteString(sq.name)
    net.Send(target)
end

--- Принятие приглашения.
-- @realm server
-- @player ply Игрок.
-- @number squadID ID сквада.
function squad:AcceptInvite(ply, squadID)
    if not IsValid(ply) then return end

    local data = GetPlayerSquadData(ply)
    if data.id ~= -1 then
        ply:ChatPrint("[Squad] Вы уже в скваде.")
        return
    end

    local sq = self.List[squadID]
    if not sq or not sq.invites[ply:EntIndex()] then
        ply:ChatPrint("[Squad] Нет активного приглашения от этого сквада.")
        return
    end

    sq.invites[ply:EntIndex()] = nil
    sq.members[ply:EntIndex()] = ply
    SetPlayerSquadData(ply, squadID, 1)

    net.Start("Psalm.Squad.Sync")
    net.WriteUInt(squadID, 32)
    net.WriteTable(sq)
    net.Broadcast()

    ply:ChatPrint("[Squad] Вы вступили в сквад '" .. sq.name .. "'")
end

--- Выход из сквада или его роспуск.
-- @realm server
-- @player ply Игрок.
function squad:Leave(ply)
    if not IsValid(ply) then return end

    local data = GetPlayerSquadData(ply)
    if data.id == -1 then return end

    local sq = self.List[data.id]
    if not sq then return end

    -- Если лидер покидает сквад — распускаем его
    if sq.leader == ply then
        for _, m in pairs(sq.members) do
            if IsValid(m) and m ~= ply then
                SetPlayerSquadData(m, -1, 0)
                m:ChatPrint("[Squad] Лидер покинул сквад. Сквад распущен.")
            end
        end
        self.List[data.id] = nil
    else
        sq.members[ply:EntIndex()] = nil
        SetPlayerSquadData(ply, -1, 0)
        ply:ChatPrint("[Squad] Вы покинули сквад.")
    end

    net.Start("Psalm.Squad.Sync")
    net.WriteUInt(data.id, 32)
    net.WriteBool(sq.leader == ply) -- true = удалить полностью
    net.Broadcast()
end

--- Выкидывает участника из сквада.
-- @realm server
-- @player leader Лидер.
-- @player target Цель.
function squad:Kick(leader, target)
    if not IsValid(leader) or not IsValid(target) then return end

    local data = GetPlayerSquadData(leader)
    if data.id == -1 or leader ~= self.List[data.id].leader then return end

    local sq = self.List[data.id]
    if not sq.members[target:EntIndex()] then return end

    sq.members[target:EntIndex()] = nil
    SetPlayerSquadData(target, -1, 0)

    net.Start("Psalm.Squad.Sync")
    net.WriteUInt(data.id, 32)
    net.WriteTable(sq)
    net.Broadcast()

    target:ChatPrint("[Squad] Вас выгнали из сквада.")
end

-- Синхронизация данных при спавне
hook.Add("PlayerInitialSpawn", "Psalm.Squad.Init", function(ply)
    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        local data = GetPlayerSquadData(ply)
        if data.id ~= -1 and squad.List[data.id] then
            squad.List[data.id].members[ply:EntIndex()] = ply
        end
    end)
end)

hook.Add("PlayerDisconnected", "Psalm.Squad.Disconnect", function(ply)
    local data = GetPlayerSquadData(ply)
    if data.id ~= -1 and squad.List[data.id] then
        squad.List[data.id].members[ply:EntIndex()] = nil
        squad.List[data.id].invites[ply:EntIndex()] = nil
        -- Если ушел лидер
        if squad.List[data.id].leader == ply then
            squad:Leave(ply) -- Функция сама обработает роспуск
        end
    end
end)

local playerMeta = FindMetaTable('Player')

function playerMeta:GetSquadID()
    local data = self:GetData("squad", {})
    return data.id or -1
end

function playerMeta:GetSquadRank()
    local data = self:GetData("squad", {})
    return data.rank or 0
end

function playerMeta:GetSquadTable()
    local id = self:GetSquadID()
    if id == -1 then return nil end
    if SERVER then return Psalm.Squad.List[id] end
    return Psalm.Squad.ClientList[id]
end