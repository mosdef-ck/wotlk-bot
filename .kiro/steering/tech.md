# Technology Stack

## Platform

- **Game Version**: World of Warcraft: Wrath of the Lich King (Interface 30300)
- **Language**: Lua 5.1
- **Framework**: WoW Addon API

## Build System

This is a WoW addon with no build process. Files are loaded directly by the game client.

### Installation

1. Copy the `MosdefAIBot` folder to `World of Warcraft/Interface/AddOns/`
2. Restart WoW or reload UI with `/reload`
3. Enable the addon in the character selection screen

### File Loading

The `.toc` file (`MosdefAIBot.toc`) defines the load order for all Lua files. Files are loaded sequentially in the order listed.

## Key Libraries & APIs

- **WoW API**: Native game functions for unit management, spell casting, movement, events
- **Custom Pathfinding**: Internal A* pathfinding implementation (`PathFinding.lua`)
- **Addon Communication**: Cross-client messaging using `CHAT_MSG_ADDON` events

## Common Commands

### In-Game Commands

- `/aibot on` - Enable the bot
- `/aibot off` - Disable the bot
- `/aibot auto-dps on/off` - Toggle automatic DPS
- `/aibot come-to-me` - Command bots to move to your position
- `/aibot follow-me` - Command bots to follow you
- `/aibot stop-follow` - Stop following
- `/aibot same-facing` - Sync facing direction
- `/reload` - Reload UI to apply code changes

### Development

- Edit `.lua` files directly
- Use `/reload` in-game to test changes
- Check for errors with `/console scriptErrors 1`
- Debug with `print()` statements (output to chat)

## Testing

No automated test framework. Testing is done manually in-game by:
1. Loading into a raid instance
2. Engaging boss encounters
3. Observing bot behavior and checking for Lua errors
