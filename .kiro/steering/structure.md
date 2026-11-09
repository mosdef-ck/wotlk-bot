# Project Structure

## Root Directory

```
MosdefAIBot/
├── classes/          # Class-specific AI implementations
├── raids/            # Boss encounter modules
├── zones/            # Zone-specific behavior modules
├── *.lua             # Core system files
└── *.toc             # Addon manifest
```

## Core Files

- `MosdefAIBot.toc` - Addon manifest defining load order and metadata
- `Config.lua` - Configuration for team composition, thresholds, and settings
- `BotBase.lua` - Main event loop, command handling, and core bot logic
- `BaseFunctions.lua` - Shared utility functions for all classes
- `Util.lua` - General utility functions (string manipulation, UI helpers)
- `SpellEffectCalculator.lua` - Spell damage/healing calculations
- `PathFinding.lua` - A* pathfinding implementation
- `BossModule.lua` - Base class for boss encounter modules
- `Testing.lua` - Development testing utilities

## Class AI Modules (`classes/`)

Each file implements class-specific logic:
- `DruidAI.lua` - Druid healing and DPS rotations
- `MageAI.lua` - Mage DPS rotations and utility
- `PaladinAI.lua` - Paladin healing/tanking logic
- `PriestAI.lua` - Priest healing and DPS
- `ShamanAI.lua` - Shaman healing and DPS
- `WarlockAI.lua` - Warlock DPS and utility

### Class Module Pattern

- Implements `doOnUpdate_<ClassName>AI()` for continuous logic
- Implements `doAutoDps()` for DPS rotation
- Uses `AI.CastSpell()`, `AI.HasBuff()`, etc. from BaseFunctions

## Raid Modules (`raids/`)

Organized by raid instance:
- `naxxramas/` - Naxxramas encounters
- `ulduar/` - Ulduar encounters (Algalon, Hodir, Mimiron, Yogg-Saron)
- `icc/` - Icecrown Citadel (Lich King, Putricide, Valithria)
- `togc/` - Trial of the Grand Crusader
- `voa/` - Vault of Archavon
- `eoe.lua` - Eye of Eternity

### Boss Module Pattern

Each boss module extends `MosDefBossModule`:
```lua
local bossName = MosDefBossModule:new({
    name = "Boss Name",
    id = creatureId,  -- or {id1, id2} for multiple IDs
    onStart = function(self) end,
    onStop = function(self) end,
    onUpdate = function(self) end,
    -- Event handlers (SPELL_CAST_START, UNIT_DIED, etc.)
})
```

## Zone Modules (`zones/`)

- `zonemodule.lua` - Base class and zone-specific behavior
- Handles zone entry/exit events
- Implements zone-specific automation

## Naming Conventions

- **Global namespace**: `AI` table contains all bot functions
- **Functions**: camelCase (e.g., `AI.CastSpell()`, `doOnUpdate()`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `AI.AUTO_DPS`, `AI.CHAT_PREFIX`)
- **Local functions**: camelCase with `local` keyword
- **Module callbacks**: `doOnUpdate_<ModuleName>`, `doOnLoad_<ModuleName>`
- **Config values**: camelCase in `AI.Config` table

## Code Organization Principles

1. **Event-driven**: Main loop in `BotBase.lua` calls registered callbacks
2. **Modular**: Boss/class/zone logic isolated in separate files
3. **Callback registration**: Functions matching patterns like `doOnUpdate*` are auto-discovered
4. **Shared state**: Global `AI` table for cross-module communication
5. **Pending actions**: Queue system for delayed/conditional actions
