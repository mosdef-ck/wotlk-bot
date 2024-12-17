
AI = AI or {}
AI.Config = AI.Config or {}

setfenv(1, AI.Config)
-- the main tank to pay close attention to
tank = "mosdefptank"

healers = { "mosdefrsham", "mosdefrdruid" }

dpsers = { "mosdefswp", "mosdeflocka", "mosdefelsham", "mosdeffmage" }

-- the mana potion to use first before popping mana cd like mana tide or innervate
manaPotion = "Runic Mana Potion"

-- the pct of our mana to reach before we deploy mana cds like mana pots and mana tide
manaPctThreshold = 30

--
panicHpPct = 20

--
dpsPotion = "potion of wild magic"


dps1 = "mosdefswp"

dps2 = "mosdeflocka"

dps3 = "mosdefelsham"