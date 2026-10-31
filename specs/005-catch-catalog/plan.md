# Implementation Plan: Catch Catalog, Map Pins and Catch Chances in Tooltips

**Branch**: `002-shared-db` (all four parts of the shared catch database) | **Date**: 2026-10-31 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-catch-catalog/spec.md`

## Summary

The statistics window gets a third tab, "Catch catalog".
- **The list.** It shows every item of the database, with a search over the client's own item names. A new module,
  `Catalog.lua`, indexes the whole database for this.
- **The item page.** Choosing an item lists its zones, and each zone expands into its spots. A spot carries its
  subzone name, its coordinates and the game's own map pin.
- **How the index is built.** It is made of per-map views of `CatchDB`. Each view is rebuilt only when its own map
  changes (a stamp per map), in frame steps of 3 ms.
- **Tooltips.** The same index answers the item tooltips ("Caught in" with the top 3 zones). The minimap tooltip shows
  the top 3 catches of the current place while fishing.

Two smaller changes to the data:
- **Subzones.** Each cast records the game's area ID of its subzone (`a`, research R4), so every client names a spot
  in its own language.
- **Water.** The views read the pool part of a cell through a "Water" filter (R5), which shows only when pool data
  exists.

The pin follows Blizzard's own `/mappin` sequence. The addon remembers its last pin per character, so a pin the
player set gets a question before it is replaced. The map opens out of combat. Shared auction prices and the source
mark are out of this part (the author's choice).

The game opens on 2026-11-04, so this is built on the assumptions V30-V40 in [verification.md](verification.md),
marked in the code, and `/okf spike` gets a "Map pins and areas" section. Details and rejected alternatives:
[research.md](research.md).

## Technical Context

**Language/Version**: Lua 5.1 (WoW Forever client, Interface 16001, build 1.60.1, Mainline API); Node.js 18+ for the
tools.

**Primary Dependencies**: WoW API only, all in the 1.60.1 export (research R4-R9):
- Pins: `C_Map.CanSetUserWaypointOnMap`, `SetUserWaypoint`, `HasUserWaypoint`, `GetUserWaypoint`,
  `GetWorldPosFromMapPos`, `GetMapPosFromWorldPos`, `GetMapInfo`; `UiMapPoint.CreateFromCoordinates`;
  `C_SuperTrack.SetSuperTrackedUserWaypoint`; `C_GameRules.IsGameRuleActive` (`Enum.GameRule.WorldMapTrackingPinDisabled`);
  the global `OpenWorldMap`; `InCombatLockdown`.
- Areas: `C_MapExplorationInfo.GetExploredAreaIDsAtPosition`, `C_Map.GetAreaInfo`, `GetSubZoneText`, `CreateVector2D`.
- Items: `C_Item.GetItemNameByID`, `GetItemQualityByID`, `GetItemInfoInstant`, `RequestLoadItemDataByID`,
  `ITEM_DATA_LOAD_RESULT`, `GET_ITEM_INFO_RECEIVED`; `CaseAccentInsensitiveParse`, `strcmputf8i`.
- UI: `WowScrollBoxList`, `CreateScrollBoxListLinearView`, `ScrollUtil.InitScrollBoxListWithScrollBar`,
  `MinimalScrollBar`, `CreateDataProvider`, `SearchBoxTemplate`; `TooltipDataProcessor` (already used),
  `ItemRefTooltip`.

No Lua libraries.

**Storage**:
- New saved fields: `settings.tooltipChances`, `OneKeyFishingCharDB.pin`, the cell field `a` (in `mine`, records and
  the seed).
- `statsTab` gains `"catalog"`.
- `DB_SCHEMA` stays 1.
- See [data-model.md](data-model.md).

**Testing**: `npm test` (fengari, `tests/wow.lua` stubs for the waypoint, super tracking, game rule, area and item name
APIs, the scroll and search templates).
- New: `fold_test.lua`, `catchdb_views_test.lua`, `catchdb_area_test.lua`, `catchdb_water_test.lua`,
  `catalog_test.lua`, `catalog_load_test.lua`, `catalogtab_test.lua`, `catalog_pin_test.lua`, `tooltips_test.lua`.
- Extended: catchhere, settings, commands, share store, spike, locale and harvest tests (the harvest test with a
  minimal CBOR encoder for the record size, research R11).
- `npm run check` (seed shape with `a`).
- The in-game checklist on two client languages ([quickstart.md](quickstart.md)).

**Target Platform**: WoW Forever client in any client language (Windows).

**Project Type**: World of Warcraft addon (single package `OneKeyFishing/`) plus the Node harvest tool.

**Performance Goals**:
- Every catalog step stays under 5 ms (SC-003). Steps end at 3 ms (`debugprofilestop`), or at 8 maps without a
  clock.
- An own catch costs one map's sum. A tooltip is a table lookup.
- At most 20 item name requests per frame step.

**Constraints**:
- Blizzard UI Add-On Policy: the pin only on the player's click, nothing else acts.
- Game data by ID: areas and items. The subzone is matched with the client's own strings.
- Literal `L` keys with nine translations each; ASCII Lua, lines up to 120 characters; Lua 5.1/5.3-neutral code (no
  `utf8` library, byte patterns only); no `L` lookup at file load.

**Scale/Scope**:
- The largest database: the seed up to 1 MB (about 3,000 cells), 20,000 places of other players, the own catch;
  about 150-200 maps and some hundreds of items.
- About 30 new English texts × 9 translations.
- 2 new runtime files (`Catalog.lua`, `UI/CatalogTab.lua`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status |
| --- | --- | --- |
| I. Blizzard Policy | **No game action:** the pin is the game's own user waypoint, set only when the player presses the pin button. Super tracking and opening the map are what the game does for a hand-set pin. Nothing is cast, moved or clicked for the player. **Server:** item name requests are queued, 20 per frame step, once per item and session. **Nothing in chat**, no traffic change: the area adds a few bytes to records within part 2's budget. | Pass |
| II. Language-Independent Game Data | **IDs only:** items, maps and areas travel and are stored as numbers, and names are built on each client in its own language. **The subzone match** compares the client's own `GetSubZoneText` with the client's own `GetAreaInfo` names, both folded with `ns.FoldCase`: the needle comes from the client's localized data, and case changes in non-ASCII text do not break it. **Search:** the player's text against the client's names, with case folding that handles non-ASCII letters (the game's `CaseAccentInsensitiveParse`, `ns.FoldCase`). **Localized:** every new visible text goes through `ns.L` with nine translations. **English:** the command and the debug lines. | Pass |
| III. Safe, Restorable State | **No setting changed:** no CVar (the navigation CVar stays untouched), no gear, no camera. **Saved data:** only new fields (`tooltipChances`, `charDB.pin`, `a`), so `DB_SCHEMA` stays 1. **The player's pin:** replaced only after the question. | Pass |
| IV. Verified Forever API | **Checked against the export:** every call, and `C_Map.OpenWorldMap` is avoided because it is `HasRestrictions` (research R6). **Marked:** behaviour is marked `VERIFY(V30..V40)`; each one degrades on its own (no pin button, coordinates only, the fixed-row list, the plain fold). **Guards:** existence checks and `pcall` around template creation. **Spike:** a "Map pins and areas" section. **Bookkeeping:** facts go into `docs/forever-api.md` and new globals into `.luacheckrc`. | Pass |
| V. Checked and Tested | **Without the game:** the area, the water filter, the stamps, the views, the index, names and search, the pin flow, the tab, the tooltips and the load bound run in fengari; the harvest in Node. **Lua 5.1/5.3:** the fold works by byte patterns, so it is the same in both. | Pass |
| VI. Simple Module Boundaries | **One job per module:** `Catalog.lua` (views across maps, names, tooltip lines, the pin target) is new, because cross-map indexing serves tooltips and the tab without the window. `UI/CatalogTab.lua` is the page. CatchDB keeps the sums. **Messages:** none new; the tab polls `Catalog.GetVersion()` on the window's tick. **Commands:** `catalog`, declared in Commands.lua. **One setting:** for a stated need (the quiz). | Pass |

Post-design re-check (after Phase 1): unchanged, all pass. No violations, so Complexity Tracking stays empty.

Re-checked after `/speckit-analyze` on 2026-10-31: the subzone match first compared the names exactly, against
Principle II's rule that matching against localized text tolerates case changes in non-ASCII text; it now compares
the folded names (research R4, T021). All pass.

Re-checked against the code after `/speckit-implement` on 2026-10-31: I. the pin is set only in `CatalogTab.Pin`, from
the pin button; item names are asked 20 per frame step, once a session. II. areas, items and maps are stored and
sent as numbers; the subzone match folds both names with `ns.FoldCase`; every new text is an `ns.L` key with nine
translations; the command and the debug section are English. III. no CVar is touched; the only new saved fields are
`settings.tooltipChances`, `charDB.pin` and the cell field `a`; a player's pin is replaced only after the question.
IV. markers V30-V38 sit in the code (V39 and V40 in the checklist), templates are created under `pcall`, the spike
has its section, and the new globals are in `.luacheckrc`. V. every part above runs in the tests (`npm test`).
VI. `Catalog.lua` and `UI/CatalogTab.lua` are the two new modules, no message was added, the command is declared in
`Commands.lua`. All pass.

## Project Structure

### Documentation (this feature)

```text
specs/005-catch-catalog/
├── spec.md
├── plan.md              # this file
├── research.md          # R1-R13 decisions
├── verification.md      # V30-V40: assumptions built on before the game launch, how each is closed
├── data-model.md        # the cell field a, saved fields, views, stamps, the catalog's session state, the pin target
├── quickstart.md        # automated, spike (map pins and areas) and in-game validation
├── contracts/
│   ├── api.md           # Data, CatchDB, Catalog, CatalogTab, other modules; harvest changes
│   └── ui.md            # the tab, the pin, the tooltips, the minimap lines, the setting, the command, texts
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks (not created here)
```

### Source Code (repository root)

```text
OneKeyFishing/
├── OneKeyFishing.toc          # + Catalog.lua after Share.lua, + UI\CatalogTab.lua after UI\CatchHere.lua
├── Data.lua                   # + ns.FoldCase, ns.SearchKey, ns.CompareText
├── CatchDB.lua                # + the area of a cast and a (Settle, CheckCell), the water filter, point/area/ranges
│                              #   in the sums, QueryMap, QueryCells, Maps, MapStamp, HasPoolData, own-cells index
├── Catalog.lua                # NEW: indexes in frame steps, names and search keys, the name request queue, Places,
│                              #   Spots, TooltipLines, MinimapLines, ZoneName, SpotName, PinTarget, Find, Describe
├── Share.lua                  # CleanCell copies a
├── Core.lua                   # default settings.tooltipChances
├── Commands.lua               # + catalog
├── Debug.lua                  # the "Catch catalog" section
├── Spike.lua                  # TEMPORARY: + "Map pins and areas (V30-V36)" section (research R13)
├── Locales/*.lua              # new texts in all ten languages
└── UI/
    ├── CatalogTab.lua         # NEW: search, filters, the list, the item page, the pin flow
    ├── StatsFrame.lua         # the third page, OpenCatalog
    ├── CatchHere.lua          # the Water button, no miss line under it, the row click
    ├── ItemHooks.lua          # the "Caught in" lines
    ├── Minimap.lua            # the "Likely catch here" lines
    └── Settings.lua           # the tooltip checkbox

tools/harvest.mjs              # a: clean, check, sum (8 largest), scale, write, seedProblems
tests/
├── wow.lua                    # waypoint, super track, game rule, OpenWorldMap, areas, item names and quality,
│                              #   scroll and search templates, ItemRefTooltip
├── fold_test.lua catchdb_views_test.lua catchdb_area_test.lua catchdb_water_test.lua catalog_test.lua
│   catalog_load_test.lua catalogtab_test.lua catalog_pin_test.lua tooltips_test.lua   # NEW
└── catchhere_test.lua settings_test.lua commands_test.lua share_store_test.lua spike_test.lua locale_test.lua
    harvest_test.mjs                                                                 # extended

.luacheckrc                    # new WoW API globals
README.md CHANGELOG.md CLAUDE.md docs/architecture/catch-db.md docs/architecture/ui.md docs/architecture/core.md
docs/forever-api.md docs/shared-db-plan.md docs/checklists/catch-catalog.md
specs/002-local-catch-db/data-model.md specs/002-local-catch-db/contracts/seed-data.md   # the cell field a
```

**Structure Decision**: the existing single-addon layout with two new runtime files: `Catalog.lua` (the views across
all maps) and `UI/CatalogTab.lua` (its page). The data changes stay in the modules that own the data: CatchDB (the
cell and its sums), Share (the copy of a received cell), the harvest (the seed).

## Phases (for /speckit-tasks)

Phases 1 to 8 run now, before the game launch; phase 9 runs after 2026-11-04 with the debt of the other parts.
Release: 1.2.0 ships all four parts together from `002-shared-db` once no `VERIFY` marker is left.

1. **Verification and spike**:
   - the V30-V40 markers;
   - the "Map pins and areas" section of `/okf spike`;
   - `tests/wow.lua` fakes for the waypoint, super tracking, game rule, map conversion, areas, item names and
     quality, the scroll and search templates, `ItemRefTooltip`;
   - the new globals in `.luacheckrc`.
2. **Data (US1, US4)**:
   - `ns.FoldCase`, `SearchKey`, `CompareText`;
   - CatchDB: the area of a cast, `a` in `Settle`, `CheckCell`, the stamps and the own-cells index;
   - the water filter in the sums (`missRate` nil), `point`, `area` and `ranges`; `QueryMap`, `QueryCells`, `Maps`,
     `HasPoolData`;
   - `CleanCell` copies `a`;
   - tests.
3. **Harvest (US1)**:
   - `a` in clean, check, sums (8 largest), scaling, `seedText` and `seedProblems`;
   - the 500-place size check;
   - `harvest_test.mjs`;
   - `specs/002-local-catch-db/contracts/seed-data.md` and its `data-model.md`.
4. **Catalog (US1)**:
   - `Catalog.lua`: indexes in frame steps (default index 10 s after the first login), names and the request queue,
     `Items`, `Places`, `Spots`, `ZoneName`, `SpotName`, `Find`, `Describe`;
   - `catalog_test.lua`, `catalog_load_test.lua`.
5. **The tab (US1)**:
   - `UI/CatalogTab.lua` (search, filters, the list, the item page, the fixed-row fallback);
   - the third page and `OpenCatalog` in StatsFrame;
   - the CatchHere row click and its hint;
   - `/okf catalog`;
   - `catalogtab_test.lua`.
6. **The pin (US2)**:
   - `Catalog.PinTarget`;
   - `CatalogTab.Pin` (the question, the calls, `charDB.pin`, the toasts, the map out of combat);
   - `catalog_pin_test.lua`.
7. **Tooltips and the water filter (US3, US4)**:
   - `Catalog.TooltipLines` in ItemHooks; `Catalog.MinimapLines` in Minimap;
   - the `tooltipChances` checkbox;
   - the Water button in both tabs;
   - tests;
   - the texts and nine translations.
8. **Docs and hand-off**:
   - README: the catalog, the pin, the tooltips, the setting, the arrow note.
   - CHANGELOG `[Unreleased]`.
   - CLAUDE.md: the module map, the traps (pins, `OpenWorldMap`).
   - `docs/architecture/catch-db.md`, `ui.md`, `core.md`.
   - `docs/forever-api.md`: the export facts.
   - `docs/checklists/catch-catalog.md`.
   - The spike and the checklist ready for launch day.
9. **After launch (debt)**: the author runs the spike and the checklist (two client languages). Then:
   - answers go into `docs/forever-api.md`;
   - code is fixed where an assumption was wrong;
   - markers are removed and V30-V40 ticked;
   - release 1.2.0 with the other parts.

## Complexity Tracking

No constitution violations to justify.
