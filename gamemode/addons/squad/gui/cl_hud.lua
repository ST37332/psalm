-- cl_hud.lua
if SERVER then return end

local squad = Psalm.Squad

local function DrawSquadHUD()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local squadID = ply:GetSquadID()
    if squadID == -1 then return end

    -- Берем данные из клиентской таблицы
    local squadTable = Psalm.Squad.ClientList and Psalm.Squad.ClientList[squadID]
    
    -- Защита от рассинхрона: если клиента нет в таблице members, но ID есть
    if not squadTable or not squadTable.members[ply:EntIndex()] then return end

    if not IsValid(squadTable.leader) then return end


    -- Настройки худа
    local padding = 10
    local lineHeight = 20
    local baseX, baseY = ScrW() - 250, 50
    local width = 230

    -- Считаем количество строк для определения высоты фона
    local memberCount = 0
    for _ in pairs(squadTable.members) do
        memberCount = memberCount + 1
    end
    local height = 30 + (memberCount * lineHeight) + padding

    -- Фон
    surface.SetDrawColor(0, 0, 0, 180)
    surface.DrawRect(baseX - padding, baseY - padding, width + (padding * 2), height)

    -- Заголовок
    draw.SimpleText(squadTable.name, "Trebuchet24", baseX, baseY, Color(255, 255, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- Отступ для списка
    local curY = baseY + 25

    -- Сортировка: сначала лидер (ранг 0), потом участники (ранг 1)
    local sortedMembers = {}
    for _, m in pairs(squadTable.members) do
        if IsValid(m) then
            table.insert(sortedMembers, m)
        end
    end

    table.sort(sortedMembers, function(a, b)
        local rankA = ply:GetSquadRank() if a == ply then rankA = 0 end
        local rankB = ply:GetSquadRank() if b == ply then rankB = 0 end
        return rankA < rankB
    end)

    -- Отрисовка участников
    for _, member in ipairs(sortedMembers) do
        if not IsValid(member) then continue end

        local name = member:Nick()
        local rankStr = "Участник"
        
        if member == squadTable.leader then
            rankStr = "Лидер"
        end

        local color = Color(200, 200, 200)
        if member == ply then
            color = Color(0, 255, 0) -- Себя выделим зеленым
        end

        draw.SimpleText(name, "DermaDefault", baseX, curY, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(rankStr, "DermaDefault", baseX + width - 10, curY, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        curY = curY + lineHeight
    end
end

hook.Add("HUDPaint", "Psalm.Squad.DrawHUD", DrawSquadHUD)