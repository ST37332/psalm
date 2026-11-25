Psalm.Containers = Psalm.Containers or {}

function Psalm.Containers:RegisterContainer(id, data)
    Psalm.Containers[id] = data
end

Psalm.Containers:RegisterContainer("cont_junk", {
    name     = "Мусорный бак",
    category = "Город",
    model    = "models/props_junk/TrashDumpster01a.mdl",
    desc     = "Обычный городской мусорный бак.",
    password = false,
    weight   = 200,
    gridW    = 6, gridH = 4,    -- ← размер сетки контейнера
    loot     = true,
    loot_list = {
        "item_healthkit",
    },
})

Psalm.Containers:RegisterContainer("cont_woodbox", {
    name     = "Деревянный ящик",
    category = "Склад",
    model    = "models/props_junk/wood_crate001a.mdl",
    desc     = "Обычный деревянный ящик.",
    password = false,
    weight   = 100,
    gridW    = 4, gridH = 3,    -- ← размер сетки контейнера
    loot     = false,
})