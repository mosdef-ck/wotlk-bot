# wotlk-bot

MosdefAIBot: WoW 3.3.5a AI bot addon (Lua) driven by the injected MosdefAI2 DLL
(API functions registered into the game Lua state; see c:/Users/cmkam/source/repos/MosdefAI2).

## Indexed: AIO_Client addon
Location: `a:\wow_3.3.5a\Interface\AddOns\AIO_Client\` — Rochet2's AIO v1.74 (GPLv2).
Purpose: server↔client communication + server→client addon delivery for Eluna-based
servers (TrinityCore). The same AIO.lua runs on both sides; side detection is
`type(GetLuaEngine) == "function"` → server.

### Files
- `AIO.lua` — entire framework (~1300 lines): messaging, addon distribution, saved vars, slash commands
- `queue.lua` — `NewQueue()` ring-buffer used for message reassembly bookkeeping
- `Dep_Smallfolk/smallfolk.lua` — serializer (message ↔ string, no loadstring of raw data)
- `lualzw-zeros/lualzw.lua` — LZW compression for delivered addon code
- `Dep_LibWindow-1.1/` — LibStub + LibWindow (frame position persistence, client-only)
- Server additionally requires Eluna scripts: `LuaSrcDiet` (obfuscation) and `crc32lua`

### Messaging flow (relevant when coexisting with MosdefAIBot's own ADDON_PREFIX channel)
- Transport is ChatAddonMessage. Prefixes: server→client `"SAIO"`, client→server `"CAIO"`
  (both truncated to 16 chars as `S|C` + "AIO"). Client sends by whispering itself;
  server accepts only when sender == target and msg < 510 bytes.
- Small messages: 2-byte tag `\1\1` + payload, single packet.
- Large messages: split into chunks (client tx limit 255B, server tx uses 2560B);
  header = 16-bit msgID + 16-bit part-count + 16-bit part-ID, base-254 encoded so no
  byte is ever `\0`; reassembled per player (GUID) with LRU-ish cache caps
  (500 KB/player), 15 s expiry for incomplete messages.
- Payload = smallfolk-serialized list of blocks `{n, name, ...args}`; block `name`
  dispatches to handlers registered via `AIO.RegisterEvent(name, func)` or
  `AIO.AddHandlers(name, table)` (then `AIO.Handle(name, "Key", ...)`).
- Client buffers blocks received before `AIO Init` completes (`preinitblocks`) and
  replays them after init. Server wraps handler execution in instruction-count
  debug.sethook timeout (1e8) to prevent malicious/hung code.

### Addon delivery (server → client)
- `if AIO.AddAddon() then return end` idiom at top of a server lua_script: on server it
  reads/registers the file and returns; on client the rest of the file executes.
- Server pipeline per addon: LuaSrcDiet obfuscate → lualzw compress → crc32 → queue in
  send-order list. Client sends its cached {name→crc} map on init; server replies with
  only new/changed code + names of valid cached ones; client caches in `AIO_sv_Addons`
  SavedVariable and `loadstring`s each addon in order (order = server registration order).
- Init is rate-limited per player (5 s) to prevent spam; version mismatch hard-stops client.

### Client-side utilities useful for addons here
- `AIO.AddSavedVar(key)` / `AIO.AddSavedVarChar(key)` — persist any `_G` key
  (account/character scoped); restored before delivered addons run on login, saved on PLAYER_LOGOUT.
- `AIO.SavePosition(frame[, char])` — persists frame position via LibWindow.
- `AIO.Handle(name, handlerName, ...)` / `AIO.Msg():Add(...):Send()`.

### Slash commands
`/aio reset` (clear cache + reload) | `trace` | `debug` | `pcall` | `printio` (toggle all IO printing).
Server console/chat: `.aio help|trace|debug|pcall`.

### Config knobs (top of AIO.lua, local to each side)
`AIO_ENABLE_PCALL/TRACEBACK/DEBUG_MSGS/MSGPRINT`, `AIO_TIMEOUT_INSTRUCTIONCOUNT` (server),
`AIO_MSG_CACHE_SPACE/TIME`, `AIO_UI_INIT_DELAY` (server), `AIO_MSG_COMPRESS`,
`AIO_CODE_OBFUSCATE` (server; breaks error line numbers when on), `AIO_ERROR_LOG`
(client forwards errors to server when pcall enabled).

### Integration notes for MosdefAIBot
- AIO executes delivered code with the same privileges as a normal addon — MosdefAI2's
  registered globals (`AI.*`, `GetObjectInfo`, etc.) are visible to AIO-delivered addons.
- Both addons listen on CHAT_MSG_ADDON but use different prefixes; no interference expected.
- Delivered-addon SavedVariables go through AIO's AddSavedVar mechanism, not their own .toc.
