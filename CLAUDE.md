# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. It holds the
rules that always apply and maps to the details; read the linked document before working in its area.

## Project

OneKeyFishing is a World of Warcraft addon for **WoW Forever** (Interface `16001`, build 1.60.1,
`WOW_PROJECT_ID = 18`), published under the MIT license. The Forever client runs the modern (Mainline) API, not
the Classic one. The addon lives in `OneKeyFishing/` (exactly what goes into `Interface/AddOns`, the player manual
`README.md` included); `tools/`, `tests/`, `docs/`, `specs/` and project files stay in the repository root. Paths
such as `Core/Core.lua` or `Locales/enUS.lua` are inside `OneKeyFishing/`, which holds one folder per area
(layout in [docs/development.md](docs/development.md)).

## Hard rules

- **Blizzard's UI Add-On Policy.** Every game action (cast, hook, use item) happens on a real key press through
  secure buttons and override bindings. No automatic reaction to the bobber splash, no external tools.
- **By ID, never by name.** The game client can run in any language, so game data is matched by ID.
- **English is the development language.** Code, identifiers, comments, documentation (`README.md`, `docs/`,
  `specs/`, `CHANGELOG.md`, this file), commit messages, branch names and pull requests are in English, whatever
  language the conversation with the author is in. Exceptions: the translations (`Locales/<code>.lua`) and
  language names written in their own language. `npm run check` rejects Cyrillic in Markdown files.
- **Every visible text goes through `ns.L`** with a literal English key listed in `Locales/enUS.lua`; color codes
  stay outside the strings; a new text needs its nine translations in the same change; **no `L[...]` lookup while
  the files load** (it would be stuck in English). Not localized: the debug report, slash commands and their
  help, the addon name, language names. Details: [docs/architecture/core.md](docs/architecture/core.md),
  [docs/languages.md](docs/languages.md).
- **Claude cannot run the game.** In-game testing is always handed to the user with a checklist
  (`docs/checklists/`, template and order in its `README.md`). Code built on an assumption only the game can
  confirm carries `-- VERIFY(<id>): <what>`, explained in the feature's `verification.md` (features 002 to 005
  have one); a marker is removed only after the author confirms the behaviour in game.

## Documents

| Area | Documents |
|---|---|
| Players | `OneKeyFishing/README.md` (the manual, shipped in the package), `CHANGELOG.md` |
| Repository | `README.md` (layout, tools, docs map), [docs/README.md](docs/README.md) (the index of `docs/`) |
| Development | [docs/development.md](docs/development.md) (tools, tests, packaging, definition of done), [docs/forever-api.md](docs/forever-api.md) (API facts, how to check a call, open questions), `docs/architecture/` (modules in detail, below), [docs/languages.md](docs/languages.md), [docs/tech-debt.md](docs/tech-debt.md) (known issues; remove an item once it is fixed with a test) |
| Rules | `.specify/memory/constitution.md` (principles; this file must stay consistent with it) |
| Releases and plans | [docs/publishing.md](docs/publishing.md) (branches, release steps, policy checklist), [docs/release-plan.md](docs/release-plan.md) (what 1.1.0 and 1.2.0 wait for), [docs/ROADMAP.md](docs/ROADMAP.md) (not built yet) |
| Features | `specs/<nnn>-<name>/` (spec, plan, research, data model, contracts, tasks, `verification.md`, `quickstart.md` for what the tests prove), `docs/checklists/` (in-game checklists: `fishing-mode.md`, `interface-language.md`, `spike.md`, one per part of the catch database) |
| History | `docs/history/` (finished plans: `mvp-plan.md` with the API spike results, `publishing-plan.md` for 1.0.0, `shared-db-plan.md`, the design of the shared catch database) |

## Workflow

- **Definition of done.** A change a player can see or use updates `CHANGELOG.md` under `[Unreleased]` and the
  manual `OneKeyFishing/README.md` in the same commit (`npm run check` fails when a slash command is missing
  from the manual; fixes of an unreleased feature need no changelog line). A new message, module or saved field
  updates this file and the area document in `docs/architecture/`; a finished feature leaves `docs/ROADMAP.md`.
- `npm run check` and `npm test` after every change (Node.js 18+, `npm install` once). A new WoW API global goes
  into `.luacheckrc` `read_globals`. Add or extend a test when changing logic that can run without the game; a new
  test file goes into the folder of its area under `tests/` (one per architecture document, layout and naming in
  [docs/development.md](docs/development.md)).
  Tests run in fengari (Lua 5.3), the game is 5.1: keep the addon free of 5.1/5.3 differences.
- `npm run dev` (package the working folder), `npm run build` (package the last commit; refuses uncommitted
  changes and `VERIFY` markers), `npm run link` / `unlink`, `npm run install-addon`, `npm run harvest` (the
  bundled seed). Details: [docs/development.md](docs/development.md).
- A new file or a TOC change needs a game restart, not just `/reload`.
- Addon Lua and XML must not contain packager keywords (`@project-version@`, `--@debug@` blocks).
- Branches: a feature is built on its own branch (`NNN-<feature>`) off `develop` and merged back when its release
  is due ([docs/release-plan.md](docs/release-plan.md)); `main` holds released code and changes only by merging
  `develop`. Never push directly to `main`. Releases: [docs/publishing.md](docs/publishing.md).
- In game: `/okf` lists commands; `/okf debug` shows the state report used in bug reports; `/okf share` shows the
  state of the catch exchange.

## Architecture

All files share the addon namespace (`local _, ns = ...`). Load order is the TOC order (the table below follows
it); a module may only call another module at runtime, not at file load time, unless it comes earlier in the TOC.

The code is **a core plus feature modules over a message bus**, in layers; the addon folder has one subfolder per
area, the same areas as `docs/architecture/` and `tests/`. The layers, the rule and how MVC maps onto them are in
[core.md](docs/architecture/core.md), "Layers":

| Layer | Folders | May use the module tables (`ns.<Name>`) of |
|---|---|---|
| 0 Core | `Core/`, `Locales/` | nothing above: no module of an area |
| 1 Game | `Fishing/`, `Catch/` | layers 0-1 |
| 2 Data | `CatchDB/`, `Exchange/`, `Catalog/` | layers 0-2 |
| 3 View | `UI/` | everything |

`Core/Commands.lua` is the entry that may open a window; `Core/Debug.lua` and `Core/Spike.lua` read every module
but the UI. `npm run check` enforces the rule and allows `CreateFrame` outside `UI/` only where `tools/addon.mjs`
lists it. **Every new feature is built inside this architecture**: its data and rules in a module of layer 1 or 2
(a new folder only for a new area, with its document in `docs/architecture/` and its folder in `tests/`), its
frames in `UI/`, the two joined by messages and module functions, never by a lower layer naming a frame; its
commands in `Core/Commands.lua`.

| Module | Job | Details |
|---|---|---|
| `Core/Localization.lua` (first) | `ns.L`, the translation registry, language resolution | [core.md](docs/architecture/core.md) |
| `Locales/*.lua` | `enUS.lua` (the keys), then one complete translation per language, before `Core/Core.lua` | [core.md](docs/architecture/core.md) |
| `Core/Core.lua` | events, the message bus `ns.On` / `ns.Fire`, chat output and popups, saved variables and migrations, the slash dispatcher | [core.md](docs/architecture/core.md) |
| `Core/Data.lua` | shared data and helpers (fishing IDs, bag iterator, names, text folding, base32, SHA-256, rolling counts) | [core.md](docs/architecture/core.md) |
| `Fishing/Gear.lua`, `Fishing/Bags.lua`, `Fishing/Camera.lua` | the fishing gear swap; lures and fished containers; the camera zoom | [fishing-mode.md](docs/architecture/fishing-mode.md) |
| `Fishing/Action.lua` | the single fishing key: secure button, override bindings, `INTERACTTARGET` while channeling | [fishing-mode.md](docs/architecture/fishing-mode.md) |
| `Fishing/Mode.lua` | enter and exit fishing mode, restore after `/reload`, logout, crash | [fishing-mode.md](docs/architecture/fishing-mode.md) |
| `Catch/Catch.lua` | casts and loot become `FISH_CAUGHT` / `FISH_MISSED` | [catch-and-stats.md](docs/architecture/catch-and-stats.md) |
| `Catch/Prices.lua`, `Catch/Auction.lua` | item values; auction scans | [catch-and-stats.md](docs/architecture/catch-and-stats.md) |
| `Fishing/Skill.lua` | the Fishing rank and cap warnings | [fishing-mode.md](docs/architecture/fishing-mode.md) |
| `Catch/Stats.lua` | statistics | [catch-and-stats.md](docs/architecture/catch-and-stats.md) |
| `CatchDB/SeedData.lua`, `CatchDB/CatchDB.lua` | the catch database: recording by place, the seed, views | [catch-db.md](docs/architecture/catch-db.md) |
| `Exchange/Comm.lua`, `Exchange/Channel.lua`, `Exchange/Share.lua` | the catch exchange: transport; the hidden public channel; protocol, others' records, state | [exchange.md](docs/architecture/exchange.md) |
| `Catalog/Catalog.lua` | the catch catalog: the index across every map in frame steps, item names and search, places, spots, tooltip lines, the pin target | [catalog.md](docs/architecture/catalog.md) |
| `UI/Widgets.lua`, `UI/CopyWindow.lua`, `UI/Indicator.lua`, `UI/Toast.lua`, `UI/StatsFrame.lua`, `UI/CatchHere.lua`, `UI/CatalogTab.lua`, `UI/AuctionButton.lua`, `UI/ShareNotice.lua` | the frame helpers, copy window, indicator, toast, the statistics window and its tabs, the auction scan button, the one-time notice about the exchange | [ui.md](docs/architecture/ui.md) |
| `Core/Debug.lua` | the `/okf debug` report | [core.md](docs/architecture/core.md) |
| `Core/Spike.lua` | temporary (`VERIFY(spike)`): `/okf spike`, removed before release 1.2.0 | [ui.md](docs/architecture/ui.md), [docs/checklists/spike.md](docs/checklists/spike.md) |
| `UI/Settings.lua`, `UI/ItemHooks.lua`, `UI/Minimap.lua` | settings pages, item hooks and tooltips, the minimap button | [ui.md](docs/architecture/ui.md) |
| `Core/Commands.lua` (last) | `ns.COMMANDS`: every slash command, sorted, English descriptions | [core.md](docs/architecture/core.md) |

Cross-module rules:

- Bump `DB_SCHEMA` and add a migration in `Core/Core.lua` whenever a saved field is renamed, moved or reshaped;
  `ApplyDefaults` fills missing keys without overwriting. `OneKeyFishingDB` is account-wide, `OneKeyFishingCharDB`
  per character; the fields are listed in [core.md](docs/architecture/core.md).
- Everything fishing mode changes (CVars, gear, camera) is stored in the character DB *before* it is changed;
  what is restored when is in constitution Principle III and [fishing-mode.md](docs/architecture/fishing-mode.md).
- Slash commands are declared only in `Core/Commands.lua`; modules register none.
- The layers (table above): a lower layer never names a UI module; the UI listens to messages and calls module
  functions. `npm run check` reports a break.
- Sharing is switched by `Share.SetEnabled`, never by a direct write of `settings.shareDB` (it fires
  `SHARED_DATA_CHANGED`, which drops cached views). The public channel likewise by `Channel.SetEnabled`, never by a
  write of `settings.shareChannel` (it joins or leaves at once).
- Game data is read by ID; tooltip parsing derives its needle from the client's own localized data.
- The catalog follows the data through `CatchDB.MapStamp` (and `GetStampVersion`), not through a message; it sends
  none, and the tab polls `Catalog.GetVersion()` on the window's tick. Data written past `CatchDB`'s `Settle` needs a
  `SHARED_DATA_CHANGED` before the views see it.

Messages (`ns.Fire` -> `ns.On`; a new one must be listed here):

- `MODE_CHANGED` (on/off), `ACTION_STATE` (the key's binding changed)
- `FISHING_CAST_START` / `FISHING_CAST_STOP` (spellID)
- `FISH_CAUGHT` (items, fromPool, castID) / `FISH_MISSED` (castID; each settles that cast and every earlier one)
- `LURE_READY`, `SETTINGS_CHANGED` (the key that changed), `GEAR_LIST_CHANGED`
- `SKILL_WARNING` (text, loud: a cap warning of `Fishing/Skill.lua`; the toast shows it)
- `AUCTION_STATE` (scan progress), `PRICES_CHANGED` (a scan finished or stopped)
- `SHARED_DATA_CHANGED` (keys, and the store when Share changed one: records under `<id>@<epoch>` came or went:
  other players', or the own one a roll kept; or sharing was switched), `SHARE_PAUSE` (Comm's pause reason or nil)
- `CHANNEL_STATE` (state, index, joins: the hidden public channel's state changed, Channel.lua; joins counts the
  joins started this session, so a new one tells a join from the end of a pause)

## Forever API

The traps that matter most; every verified fact, the facts read from the client export, how to check a call, and
the open questions for the spike are in [docs/forever-api.md](docs/forever-api.md). New facts confirmed in game
go there.

- Missing: `GetSpellInfo`, `GetItemInfo`, `EquipItemByName` and the classic auction API; use the `C_*` namespaces.
  Deprecated globals (`Blizzard_Deprecated*`) are not loaded; use the namespaced functions.
- `C_Item.EquipItemByName` fails silently while casting or channeling.
- The bobber is unit `softinteract` (name and GUID) with no nameplate; `UnitExists` is false for it.
- The Fishing skill comes from `GetProfessions()` and `GetProfessionInfo` (skillLine 356).
- Key bindings on punctuation keys break when the Windows keyboard language is switched.
- `C_Map.OpenWorldMap` is restricted: open the map with the global `OpenWorldMap(mapID)`; a map pin follows
  Blizzard's `/mappin`. The subzone of a cast comes from the explored areas at the player's position matched
  against `GetSubZoneText()`.
- Chat: 20 channels per player, a locked channel opens the game's password popup, a channel is hidden with the chat
  window's `RemoveChannel`; chat filters and handlers must skip secret values (`issecretvalue`).
