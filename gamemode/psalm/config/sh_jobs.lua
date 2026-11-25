FACTION_COMBINE = Psalm.Jobs:RegisterFaction("Combine", {
    color = Color(35, 214, 248),
    isGovernment = true,
})

CATEGORY_SOLDIERS = Psalm.Jobs:RegisterCategory("Soldiers", {
    faction   = FACTION_COMBINE,
    color     = Color(137, 60, 60),
    sortOrder = 1,
})

CATEGORY_MEDICS = Psalm.Jobs:RegisterCategory("Medics", {
    faction = FACTION_COMBINE,
    color   = Color(145, 97, 96),
})

TEAM_RCT = Psalm.Jobs:Register("Recruit", {
    category = CATEGORY_SOLDIERS,
    salary   = 45,
})
TEAM_CPL = Psalm.Jobs:Register("Corporal", {
    category = CATEGORY_SOLDIERS,
    salary   = 60,
})
TEAM_MEDIC = Psalm.Jobs:Register("Field Medic", {
    category = CATEGORY_MEDICS,
    salary   = 55,
})
