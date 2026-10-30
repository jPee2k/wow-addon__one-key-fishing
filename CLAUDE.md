# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. It holds the
rules that always apply and maps to the details; read the linked document before working in its area.

## Project

OneKeyFishing is a World of Warcraft addon for **WoW Forever** (Interface `16001`, build 1.60.1,
`WOW_PROJECT_ID = 18`), published under the MIT license. The Forever client runs the modern (Mainline) API, not
the Classic one. The addon lives in `OneKeyFishing/` (exactly what goes into `Interface/AddOns`); `tools/`,
`tests/`, `docs/`, `specs/` and project files stay in the repository root. Paths such as `Core.lua` or
`Locales/enUS.lua` are inside `OneKeyFishing/`.

## Hard rules

- **Blizzard's UI Add-On Policy.** Every game action (cast, hook, use item) happens on a real key press through
  secure buttons and override bindings. No automatic reaction to the bobber splash, no external tools.
- **By ID, never by name.** The game client can run in any language, so game data is matched by ID.
- **English is the development language.** Code, identifiers, comments, documentation (`README.md`, `docs/`,
  `specs/`, `CHANGELOG.md`, this file), commit messages, branch names and pull requests are in English, whatever
  language the conversation with the author is in. Exceptions: the translations (`Locales/<code>.lua`) and
  language names written in their own language. No tool enforces this.
- **Every visible text goes through `ns.L`** with a literal English key listed in `Locales/enUS.lua`; color codes
  stay outside the strings; a new text needs its nine translations in the same change; **no `L[...]` lookup while
  the files load** (it would be stuck in English). Not localized: the debug report, slash commands and their
  help, the addon name, language names. Details: [docs/architecture/core.md](docs/architecture/core.md),
  [docs/languages.md](docs/languages.md).
- **Claude cannot run the game.** In-game testing is always handed to the user with a checklist
  (`docs/checklists/`). Code built on an assumption only the game can confirm carries
  `-- VERIFY(<id>): <what>`, explained in the feature's `verification.md`; a marker is removed only after the
  author confirms the behaviour in game.

## Documents

| Area | Documents |
|---|---|
| Players | `README.md`, `CHANGELOG.md` |
| Development | [docs/development.md](docs/development.md) (tools, tests, packaging), [docs/forever-api.md](docs/forever-api.md) (API facts, how to check a call), `docs/architecture/` (modules in detail, below), [docs/languages.md](docs/languages.md), [docs/tech-debt.md](docs/tech-debt.md) (known issues; remove an item once it is fixed with a test) |
| Rules | `.specify/memory/constitution.md` (principles; this file must stay consistent with it) |
| Releases and plans | [docs/publishing.md](docs/publishing.md) (release steps, policy checklist), [docs/ROADMAP.md](docs/ROADMAP.md), [docs/shared-db-plan.md](docs/shared-db-plan.md) (the shared catch database in four parts, released together as 1.2.0) |
| Features | `specs/<nnn>-<name>/` (spec, plan, data model, contracts, tasks, `verification.md`), `docs/checklists/` (in-game checklists) |
| History | `docs/history/` (finished plans: `mvp-plan.md` with the API spike results, `publishing-plan.md` for 1.0.0) |

## Workflow

- `npm run check` and `npm test` after every change (Node.js 18+, `npm install` once). A new WoW API global goes
  into `.luacheckrc` `read_globals`. Add or extend a test when changing logic that can run without the game.
  Tests run in fengari (Lua 5.3), the game is 5.1: keep the addon free of 5.1/5.3 differences.
- `npm run dev` (package the working folder), `npm run build` (package the last commit; refuses uncommitted
  changes and `VERIFY` markers), `npm run link` / `unlink`, `npm run install-addon`, `npm run harvest` (the
  bundled seed). Details: [docs/development.md](docs/development.md).
- A new file or a TOC change needs a game restart, not just `/reload`.
- Addon Lua and XML must not contain packager keywords (`@project-version@`, `--@debug@` blocks).
- Branches: work happens on `develop`; `main` holds released code and changes only by merging `develop`. Push to
  `develop`, never directly to `main`. Releases: [docs/publishing.md](docs/publishing.md).
- In game: `/okf` lists commands; `/okf debug` shows the state report used in bug reports; `/okf share` shows the
  state of the catch exchange.

## Architecture

All files share the addon namespace (`local _, ns = ...`). Load order is the TOC order; a module may only call
another module at runtime, not at file load time, unless it comes earlier in the TOC.

| Module | Job | Details |
|---|---|---|
| `Localization.lua` (first) | `ns.L`, the translation registry, language resolution | [core.md](docs/architecture/core.md) |
| `Locales/*.lua` | `enUS.lua` (the keys), then one complete translation per language, before `Core.lua` | [core.md](docs/architecture/core.md) |
| `Core.lua` | events, the message bus `ns.On` / `ns.Fire`, shared widgets, saved variables and migrations, the slash dispatcher | [core.md](docs/architecture/core.md) |
| `Data.lua` | shared data and helpers (bag iterator, base32, rolling counts, game object IDs) | [core.md](docs/architecture/core.md) |
| `Action.lua` | the single fishing key: secure button, override bindings, `INTERACTTARGET` while channeling | [fishing-mode.md](docs/architecture/fishing-mode.md) |
| `Mode.lua` | enter and exit fishing mode, restore after `/reload`, logout, crash | [fishing-mode.md](docs/architecture/fishing-mode.md) |
| `Gear.lua`, `Camera.lua` | the fishing gear swap; the camera zoom | [fishing-mode.md](docs/architecture/fishing-mode.md) |
| `Bags.lua` | lures and fished containers | [fishing-mode.md](docs/architecture/fishing-mode.md) |
| `Skill.lua` | the Fishing rank and cap warnings | [fishing-mode.md](docs/architecture/fishing-mode.md) |
| `Catch.lua` | casts and loot become `FISH_CAUGHT` / `FISH_MISSED` | [catch-and-stats.md](docs/architecture/catch-and-stats.md) |
| `Stats.lua`, `Prices.lua`, `Auction.lua` | statistics; item values; auction scans | [catch-and-stats.md](docs/architecture/catch-and-stats.md) |
| `SeedData.lua`, `CatchDB.lua` | the catch database: recording by place, the seed, views | [catch-db.md](docs/architecture/catch-db.md) |
| `Comm.lua`, `Share.lua` | the catch exchange: transport; protocol, others' records, state | [exchange.md](docs/architecture/exchange.md) |
| `UI/*.lua` | indicator, settings, statistics window, "What can be caught here", toast, minimap, item hooks, copy window | [ui.md](docs/architecture/ui.md) |
| `Debug.lua` | the `/okf debug` report | [core.md](docs/architecture/core.md) |
| `Spike.lua` | temporary (`VERIFY(spike)`): `/okf spike`, removed before the release | [ui.md](docs/architecture/ui.md) |
| `Commands.lua` (last) | `ns.COMMANDS`: every slash command, sorted, English descriptions | [core.md](docs/architecture/core.md) |

Cross-module rules:

- Bump `DB_SCHEMA` and add a migration in `Core.lua` whenever a saved field is renamed, moved or reshaped;
  `ApplyDefaults` fills missing keys without overwriting. `OneKeyFishingDB` is account-wide, `OneKeyFishingCharDB`
  per character.
- Everything fishing mode changes (CVars, gear, camera) is stored in the character DB *before* it is changed;
  what is restored when is in constitution Principle III and [fishing-mode.md](docs/architecture/fishing-mode.md).
- Slash commands are declared only in `Commands.lua`; modules register none.
- Sharing is switched by `Share.SetEnabled`, never by a direct write of `settings.shareDB` (it fires
  `SHARED_DATA_CHANGED`, which drops cached views).
- Game data is read by ID; tooltip parsing derives its needle from the client's own localized data.

Messages (`ns.Fire` -> `ns.On`; a new one must be listed here):

- `MODE_CHANGED` (on/off), `ACTION_STATE` (the key's binding changed)
- `FISHING_CAST_START` / `FISHING_CAST_STOP`
- `FISH_CAUGHT` (items, fromPool, castID) / `FISH_MISSED` (castID; each settles that cast and every earlier one)
- `LURE_READY`, `SETTINGS_CHANGED`, `GEAR_LIST_CHANGED`
- `AUCTION_STATE` (scan progress), `PRICES_CHANGED` (a scan finished or stopped)
- `SHARED_DATA_CHANGED` (records under `<id>@<epoch>` came or went: other players', or the own one a roll kept; or
  sharing was switched), `SHARE_PAUSE` (Comm's pause reason or nil)

## Forever API

The traps that matter most; all verified facts, and how to check a call against the client's own export and the
public dumps, are in [docs/forever-api.md](docs/forever-api.md). New facts confirmed in game go there.

- Missing: `GetSpellInfo`, `GetItemInfo`, `EquipItemByName` and the classic auction API. Use `C_Spell`, `C_Item`,
  `C_Item.EquipItemByName` and `C_AuctionHouse`.
- `C_Item.EquipItemByName` fails silently while casting or channeling.
- `INTERACTTARGET` exists; the bobber is unit `softinteract` (name and GUID) but has no nameplate and `UnitExists`
  is false.
- The Fishing skill comes from `GetProfessions()` → `GetProfessionInfo` (skillLine 356); `GetSkillLineInfo` does
  not exist.
- Deprecated globals (`Blizzard_Deprecated*`) are not loaded; use the namespaced functions
  (`C_BattleNet.SendGameData`, `ChatFrameUtil.AddMessageEventFilter`).
- Key bindings on punctuation keys break when the Windows keyboard language is switched.
