
AI = AI or {}
AI.Config = AI.Config or {}

AI.ObjectType = {
    Item = 1,
    Container = 2,
    Unit = 3,
    Player = 4,
    Gameobject = 5,
    DynamicObject = 6,
    Corpse = 7,    
}

AI.ObjectTypeFlag = {
    Object = 0x1,
    Item = 0x2,
    Container = 0x4,
    Unit = 0x8,
    Player = 0x10,
    Gameobject = 0x20,
    DynamicObject = 0x40,
    Corpse = 0x80,
    Units = 0x18,
    Objects = 0x60,
    UnitsAndGameObjects = 0x28,
    All = 0xFFFFFFFF
}

setfenv(1, AI.Config)
-- the main tank to pay close attention to
--tank = "mosdefptank"
tank="yahiko"

healers = { "mosdefrsham", "mosdefrdruid", "kakuzu" }

dpsers = { "mosdefswp", "mosdeflocka", "mosdefelsham", "mosdeffmage", "hidan", "deidara", "nagato"}

-- the mana potion to use first before popping mana cd like mana tide or innervate
manaPotion = "Runic Mana Potion"

-- the pct of our mana to reach before we deploy mana cds like mana pots and mana tide
manaPctThreshold = 30

manaTideThreshold = 70

--
panicHpPct = 30

--
dpsPotion = "potion of wild magic"
dpsPotion2 = "potion of speed"


dps1 = { "mosdefswp", "hidan"}

dps2 = { "mosdeflocka", "nagato" }

dps3 = { "mosdefelsham", "mosdeffmage", "deidara" }

startHealOverrideThreshold = 100

useHealingWaveOnToons = false


--focusMagicTarget = "mosdeflocka"
focusMagicTarget = "nagato"
-- focusMagicTarget = "mosdefswp"

-- curseToUse = "curse of the elements"
curseToUse = "curse of doom"

starFormationRadius = 15

judgementToUse = "judgement of wisdom"

useMindBlast = false