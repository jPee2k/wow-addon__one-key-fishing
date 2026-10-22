# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

OneKeyFishing is a personal, unpublished World of Warcraft addon for **WoW Forever** only (Interface `16001`, build 1.60.1, `WOW_PROJECT_ID = 18`). The Forever client runs the modern (Mainline) API, not the Classic one. The UI text is English; the game client may be localized (the author plays **ruRU**), so game data is matched **by ID, never by name**. `PLAN.md` holds the original plan and the stage 0 API findings.

Hard rule: the addon must stay within Blizzard's rules. Every game action (cast, hook, use item) happens on a real key press through secure buttons and override bindings. No automatic reaction to the bobber splash, no external tools.

## Commands

There is no build step. The repo folder *is* the addon: the author copies `OneKeyFishing/` into the Forever beta client's `Interface\AddOns` and tests in game with `/reload`. Claude cannot run the game, so in-game testing is always handed to the user with a checklist.

- Syntax check (no Lua or luacheck installed; uses luaparse through Node in a temp folder):
  `node -e "require('luaparse').parse(require('fs').readFileSync(FILE,'utf8'),{luaVersion:'5.1'})"`
- Undeclared globals: parse with `{scope:true}` and compare `ast.globals` against the names in `.luacheckrc`. Add every new WoW API global to `.luacheckrc` `read_globals`.
- `luacheck .` uses `.luacheckrc` if luacheck is ever installed.
- Package for someone else: `git archive --format=zip --prefix=OneKeyFishing/ -o OneKeyFishing.zip HEAD`.
- In game: `/okf` lists commands; `/okf debug` shows the API availability report (use it whenever an API is in doubt).

## Architecture

All files share the addon namespace (`local _, ns = ...`). Load order is the TOC order; a module may only call another module at runtime, not at file load time, unless it comes earlier in the TOC.

- **Core.lua**: `ns.RegisterEvent` (several handlers per event), the internal message bus `ns.On` / `ns.Fire`, saved variable defaults (`ApplyDefaults` fills missing keys without overwriting), slash commands (`ns.RegisterCommand`), and binding labels. `OneKeyFishingDB` holds account-wide data (settings, fished item IDs, auction prices, positions); `OneKeyFishingCharDB` holds per-character data (fishing gear, statistics, and pending restore state).
- **Action.lua**: the single fishing key. Keys bound to `ONEKEYFISHING_ACTION` (Bindings.xml) are overridden only while the mode is on. When the player is not channeling, the key clicks `OneKeyFishingButton` (SecureActionButtonTemplate). Its `PreClick` resolves the action by priority: apply lure, then open a fished container, then cast Fishing. While channeling Fishing, the key is bound to `INTERACTTARGET` (soft-target interact hooks the bobber). The overrides are owned by a `SecureHandlerStateTemplate` frame whose `[combat]` state driver clears them inside combat.
- **Mode.lua**: enter and exit fishing mode. Every changed CVar, the gear swap, the camera zoom and a `resumeMode` flag are stored in the character DB *before* changing anything. As a result, exit, logout, `/reload` (which also fires `PLAYER_LOGOUT`) and crashes all restore correctly. After `/reload` the mode resumes after a 1 second delay, because bindings and the spellbook are not ready on `PLAYER_ENTERING_WORLD`.
- **Gear.lua**: equips the chosen pole (or the best pole by fishing bonus) plus user-picked extra items. It records only the slots it changed (`charDB.gearSwap`). On exit a slot is restored only if it still holds what the addon put there. The fishing bonus is parsed from tooltip lines that contain the client's localized Fishing spell name minus its first UTF-8 character (tooltips may lowercase it, and `string.lower` cannot handle Cyrillic). Weapons return immediately in combat; the rest waits until combat ends.
- **Catch.lua** turns casts and loot into `FISH_CAUGHT` / `FISH_MISSED` messages. **Stats.lua**, **UI/Toast.lua** and **Skill.lua** consume them. Stats counts time in segments (fishing mode on, optionally not AFK) and flushes them on zone change and logout. It keeps per-session, per-zone and total buckets; the item value is computed at read time through **Prices.lua** (the higher of the vendor and the scanned auction price). **Auction.lua** runs one `C_AuctionHouse.SendSearchQuery` at a time, with throttle retry and timeout.
- **UI/**: Indicator (next action, cast bar, session timer, "No bobber" when the soft interact GUID is not game object 35591), Settings (canvas pages built from plain widgets, not the Settings setting-type API), StatsFrame, Minimap (the button and the Addon Compartment entry from the TOC), ItemHooks (Alt+Click on items through `HandleModifiedItemClick`, plus a tooltip line), CopyWindow, and Debug (`/okf debug`).

## Known API facts for Forever (verified in game)

- `INTERACTTARGET` exists. The bobber is readable as unit `softinteract` (name and GUID), but it has **no nameplate** and `UnitExists` is false, so nothing can be anchored to it.
- Fishing rank spells are 7620 / 7731 / 7732 / 18248. The skill comes from `GetProfessions()` → `GetProfessionInfo` (skillLine 356); `GetSkillLineInfo` does not exist.
- These are missing: `GetSpellInfo`, `GetItemInfo`, `EquipItemByName` and the classic auction API. Use `C_Spell`, `C_Item`, `C_Item.EquipItemByName` and `C_AuctionHouse` instead.
- `C_Item.EquipItemByName` fails silently while casting or channeling, so a gear swap entry is only cleared on `PLAYER_EQUIPMENT_CHANGED`, and a restore during a cast waits for the cast to end.
- Bags cannot be opened while the Settings panel is open, so items are added through Alt+Click in bags, not from the panel.
