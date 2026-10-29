# Implementation Plan: Local Catch Database

**Branch**: `002-local-catch-db` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-local-catch-db/spec.md`

## Summary

Every catch and miss in fishing mode is also recorded account-wide under a numbers-only place key
(`mapID:range:cell`: the map as the game reports it, the base-rank skill range, a 10 by 10 grid cell), both as
lifetime counts ("Only mine") and as a contribution record that the author's `npm run harvest` turns into a bundled
`SeedData.lua`. The statistics window gets tabs; the new "What can be caught here" tab shows chances, average
pieces and prices for the current spot, falling back to the whole map, with skill and source filters. Epochs and an
`absorbed` list keep data from being counted twice. Auction prices become the average of the cheapest 20% of listed
pieces, with a "few lots" mark under 5 pieces. The game opens on 2026-11-04, so the feature is built now on the
assumptions in [verification.md](verification.md) (V1-V9), each marked `-- VERIFY(Vn)` in the code; a `/okf spike`
command is built now and run after launch, and a release build refuses to package while a marker is left. Details
and rejected alternatives: [research.md](research.md).

## Technical Context

**Language/Version**: Lua 5.1 (WoW Forever client, Interface 16001, build 1.60.1, Mainline API); Node.js 18+ for
`tools/harvest.mjs`

**Primary Dependencies**: WoW API: `C_Map.GetBestMapForUnit`, `C_Map.GetPlayerMapPosition` (spike),
`C_Map.GetMapInfo`, `GetProfessions` / `GetProfessionInfo` (in use), `GetLootSourceInfo` (in use; pool use per
spike), `C_AuctionHouse` commodity and item search results (quantities per spike), `GetBuildInfo`,
`PanelTabButtonTemplate` / `PanelTemplates_*` (unverified, guarded), `MenuUtil` (in use). Node: `luaparse` (dev
dependency, already present)

**Storage**: `OneKeyFishingDB.shared` (`myID`, `mine`, `records`), `OneKeyFishingDB.statsTab`, `prices[id].quantity`;
shipped `OneKeyFishing/SeedData.lua`; repository-only `seed/contributions.json`. See [data-model.md](data-model.md)

**Testing**: `npm test` (fengari, `tests/wow.lua` stubs) with new `catchdb_test.lua`, `prices_test.lua`,
`catchhere_test.lua`; `tests/run.mjs` extended to run `tests/*_test.mjs` for `harvest_test.mjs`; `npm run check`
(seed format and size); in-game checklist in [quickstart.md](quickstart.md)

**Target Platform**: WoW Forever client in any client language (Windows); the harvest runs on the author's PC

**Project Type**: World of Warcraft addon (single package `OneKeyFishing/`) plus a Node build-time tool

**Performance Goals**: login slower by at most 1 s with a whole-world seed (~3,000 places, ~450 KB); no work per
frame beyond today's 1 s tick; a query sums at most one map's cells and is cached per key and filter

**Constraints**: Blizzard UI Add-On Policy (the feature only reads and shows data); IDs and numbers only in keys;
literal `L` keys with nine translations each; ASCII Lua, lines up to 120 characters (also the generated seed);
`SeedData.lua` at most 1 MB; Lua 5.1/5.3-neutral code; no `L` lookup at file load

**Scale/Scope**: up to ~3,000 seed places and a few hundred own places; ~25 new English texts x 9 translations;
3 new runtime files (`CatchDB.lua`, `SeedData.lua`, `UI/CatchHere.lua`), 1 temporary (`Spike.lua`), 1 new tool

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status |
| --- | --- | --- |
| I. Blizzard Policy | No game action added; recording reacts to loot the player already took; auction searches stay one at a time with the existing throttle and timeout; no traffic outside the game (the author's harvest reads local files after playing); no personal data: random ID, counts, averaged positions | Pass |
| II. Language-Independent Game Data | Place keys from map IDs, grid numbers and ranks; items by ID; display names from client data; every new text through `ns.L` with nine translations | Pass |
| III. Safe, Restorable State | Only new saved fields, filled by `ApplyDefaults`; `DB_SCHEMA` 1 -> 2 (no reshape, no migration function); existing statistics untouched; 1.0.0 price entries stay valid | Pass |
| IV. Verified Forever API | Unverified calls (V1-V7) guarded with a fallback and marked `VERIFY(Vn)`; nothing is called verified before the author checks it in game after launch; the release build refuses open markers; facts into CLAUDE.md; new globals into `.luacheckrc` | Pass |
| V. Checked and Tested | Lua tests for CatchDB, Prices and the panel; a Node test for the harvest; `npm run check` validates the seed | Pass |
| VI. Simple Module Boundaries | All slash commands, the new `spike` included, declared in `Commands.lua` (constitution 1.4.0); one module per job: `CatchDB` (record, merge, query), `UI/CatchHere` (panel), `tools/harvest.mjs` (seed); no new message (the panel polls `CatchDB.GetVersion()` in the existing tick) | Pass |

Post-design re-check (after Phase 1): unchanged, all pass. No violations, so Complexity Tracking stays empty.

## Project Structure

### Documentation (this feature)

```text
specs/002-local-catch-db/
├── spec.md
├── plan.md              # this file
├── research.md          # R1-R11 decisions
├── verification.md      # V1-V9: assumptions built on before the game launch, how each is closed
├── data-model.md        # place key, cell, saved data, seed, harvest store, transitions, views
├── quickstart.md        # automated, harvest and in-game validation (spike first)
├── contracts/
│   ├── seed-data.md         # SeedData.lua format
│   ├── harvest-command.md   # npm run harvest: inputs, validation, merge, output
│   └── catchdb-api.md       # ns.CatchDB, ns.Prices, ns.IsPoolLoot
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks (not created here)
```

### Source Code (repository root)

```text
OneKeyFishing/
├── OneKeyFishing.toc          # + Spike.lua (temporary), SeedData.lua and CatchDB.lua after Stats.lua,
│                              #   UI/CatchHere.lua before UI/StatsFrame.lua
├── Commands.lua               # NEW, last in the TOC: every slash command, English descriptions (constitution 1.4.0)
├── Spike.lua                  # TEMPORARY: /okf spike report, run after launch; removed before the release
├── SeedData.lua               # NEW, generated: ns.SeedData
├── CatchDB.lua                # NEW: place key, recording (mine + own record), epoch check, Query, Describe
├── Core.lua                   # DB_SCHEMA 2; DB_DEFAULTS shared, statsTab
├── Catch.lua                  # loot source kept for ns.IsPoolLoot (per spike)
├── Auction.lua                # robust price from the loaded results, quantity stored
├── Prices.lua                 # Get uses vendor under 5 pieces; GetAuction
├── Debug.lua                  # "Catch database" section, price coverage
├── Locales/*.lua              # new texts in all ten languages
└── UI/
    ├── CatchHere.lua          # NEW: the "What can be caught here" panel, filters
    └── StatsFrame.lua         # tabs, today's content in a child frame, remembered tab; value tooltip text

tools/
├── harvest.mjs                # NEW: npm run harvest
├── check.mjs                  # seed format and size check; lists open VERIFY markers
└── build.mjs                  # --release refuses while a VERIFY marker is left

seed/
└── contributions.json         # NEW, written by harvest; repository only

tests/
├── wow.lua                    # map position, professions, auction results with quantities
├── run.mjs                    # also runs tests/*_test.mjs
├── catchdb_test.lua prices_test.lua catchhere_test.lua   # NEW
└── harvest_test.mjs           # NEW

.pkgmeta                       # ignore: seed
.luacheckrc                    # new WoW API globals
package.json                   # "harvest" script
README.md CHANGELOG.md CLAUDE.md docs/publishing.md docs/ROADMAP.md
```

**Structure Decision**: the existing single-addon layout with two new runtime modules, a generated data file, a
temporary spike file, one Node tool and a repository-only `seed/` folder.

## Phases (for /speckit-tasks)

Phases 1 to 8 run now, before the game launch; phase 9 runs after 2026-11-04.

1. **Verification debt tooling**: the `-- VERIFY(Vn)` marker convention (documented in CLAUDE.md), `npm run check`
   listing open markers, `npm run build -- --release` refusing them; `Spike.lua` with `/okf spike` covering V1-V7.
2. **Foundation**: `DB_SCHEMA` 2 and defaults; `tests/wow.lua` stubs; `CatchDB.lua` place key and recording into
   `mine` and the own record (US1, without the panel), on the V1-V3 and V7 assumptions; `catchdb_test.lua`.
3. **Panel (US1)**: tabs in `StatsFrame.lua` (V6 with its fallback), `UI/CatchHere.lua` with the fallback, filters
   and remembered tab; texts and translations; `catchhere_test.lua`.
4. **Seed (US2)**: `SeedData.lua` (empty seed first), epoch check, "All" view, `npm run check` seed rule; tests for
   counting once and the absorbed reset; a generated whole-world seed for the V8 load test.
5. **Harvest (US3)**: `tools/harvest.mjs`, `seed/contributions.json`, `.pkgmeta`, `package.json`; `run.mjs` for
   `.mjs` tests; `harvest_test.mjs`.
6. **Prices (US4)**: robust price in `Auction.lua` on the V4-V5 assumptions, `Prices.Get` / `GetAuction`, the "few
   lots" mark in both tabs, the value tooltip text; `prices_test.lua`.
7. **Debug, docs, release notes**: `/okf debug` section; README, CHANGELOG `[Unreleased]`, CLAUDE.md (modules,
   seed, harvest, the marker convention), `docs/publishing.md` (run the harvest before a release), ROADMAP items 1
   and 2.
8. **Hand-off**: the in-game checklist ([quickstart.md](quickstart.md)) and [verification.md](verification.md)
   ready for launch day; the feature stays unreleased.
9. **After launch (debt)**: the author runs the spike and the feature checklist; each answer goes into CLAUDE.md,
   the code is adjusted where an assumption was wrong, markers are removed and V1-V9 ticked; `Spike.lua` is
   removed; the first real seed is harvested; then the release.

## Complexity Tracking

No constitution violations to justify.
