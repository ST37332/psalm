
Psalm.Items = Psalm.Items or {}

local core = Psalm.Items

core.ColorType = {}
core.ColorType["white-orange"] = Color(255,255,215)
core.ColorType["chargable"] = Color(75,155,255)
core.ColorType["fuel"] = Color(255,255,0)
core.ColorType["electric"] = Color(0,175,255)
core.ColorType["medical"] = Color(100,255,100)
core.ColorType["weapon"] = Color(255,255,50)
core.ColorType["weapon_s"] = Color(255,255,150)
core.ColorType["impulse_w"] = Color(100,100,255)
core.ColorType["armor_part"] = Color(100,255,255)
core.ColorType["head_part"] = Color(100,255,125)
core.ColorType["crystal_green"] = Color(0,255,0)
core.ColorType["crystal_blue"] = Color(100,150,255)
core.ColorType["red_med"] = Color(255,150,150)
core.ColorType["red"] = Color(255,0,0)
core.ColorType["viol"] = Color(255,0,255)
core.ColorType["ora"] = Color(230,220,0)
core.ColorType["coffe"] = Color(155,155,0)   
core.ColorType["Медицина"] = Color(41,255,106)
core.ColorType["Техника"] = Color(41,70,106)
core.ColorType["Еда"] = Color(235,255,41)
core.ColorType["Разное"] = Color(255,206,41)
core.ColorType["Ресурсы"] = Color(41,249,255)
core.ColorType["Вспомогательное"] = Color(242,41,255)
core.ColorType["Шлема"] = Color(41,213,255)
core.ColorType["Инструменты"] = Color(200,240,255)
core.ColorType["Ивенты"] = Color(200,200,255)
core.ColorType["Патроны"] = Color(153,153,255)
core.ColorType["Оружие"] = Color(255,0,0)
core.ColorType["Броня"] = Color(255,0,127)
-- Функция регистрации предмета
function core:RegisterItem(id, data)
    core[id] = data
end

-- Пример регистрации мед-пака
core:RegisterItem("item_healthkit", {
    category = "Медицина",
    type = "medical",
    name = "Мед-пак",
    desc = "Пакет с биогелем",
    weight = 0.5,
    image = Material("icons/buffs/healing.png"), 
    model = "models/Items/HealthKit.mdl",
    CanUseSay = "У вас полное здоровье",
    CanUse = function(ply) return ply:Health() < ply:GetMaxHealth() and !timer.Exists(ply:AccountID().."heal") end,
    UseFunction = function(ply)
        local acid = ply:AccountID().."heal"
        if timer.Exists(acid) then return end
        ply:EmitSound("items/smallmedkit1.wav")
        timer.Create(acid, 0.5, 30, function()
            if not IsValid(ply) or not ply:Alive() then timer.Remove(acid) return end
            ply:SetHealth(math.Clamp(ply:Health()+1, 0, ply:GetMaxHealth()))
        end)
    end
})

local weapons = {  
    {"weapon_pistol","Pistol","icons/player_factions/faction_ammo.png","weapon", "Энергетическое плазменное оружие"},   
    {"weapon_shotgun","ShotGun","icons/player_factions/faction_ammo.png","weapon","Электромагнитное ружье-ускоритель масс"},   
    {"weapon_ar2","AR-2","icons/player_factions/faction_ammo.png","weapon","Бронебойное лазерное оружие"}, 

    {"weapon_crossbow","Арбалет","monochrome/ui/markers/skull.png","Арбалет больного человека",function(self,ply)
    	ply:RemoveAmmo(4,"XBowBolt")
    end}, 
}

for k,v in ipairs(weapons) do
	core:RegisterItem(v[1], {
	    category= "Оружие",
	    type= v[4], 
	    name=v[2],
	    desc=v[5],
	    model="models/Items/item_item_crate.mdl",
	    weight=1,
	    image = Material(v[3]),
        UseFunction = function(ply)
            ply:Give(v[1])  
        end
    })
end