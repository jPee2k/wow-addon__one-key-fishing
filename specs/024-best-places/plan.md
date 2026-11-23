# Implementation Plan: The Best Places to Farm, and the Three-Level Place List

**Branch**: `024-best-places` | **Date**: 2026-11-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/024-best-places/spec.md`; the author's quiz and clarifications of
2026-11-23 ([docs/best-places-research.md](../../docs/best-places-research.md)).

## Summary

A fourth tab "Best places" ranks the top 10 zones by gold per hour for the chosen skill, with the filters Skill, Safe
for me, Kinds, Source, Water, Camp bonus and Continent; each zone opens into subzones (summed, with a pin on the best
spot) and spots. The catalog's item places get the same three levels. The minimap menu gains "Catalog" and "Best
places"; `/okf best` opens the tab.

- **Data (R1)**: the views of `CatchDB` sum the cells' casting time (`seconds`, `catchesPerHour`), raw and
  unfiltered; no saved data changes.
- **Logic (R2-R6, R8, R9)**: a new module `ns.BestPlaces` (`Catalog/BestPlaces.lua`, layer 2): gold per hour,
  ranking, levels (`C_Map.GetMapLevels`, V75), continents (map parents, V76), the per-character state;
  `Catalog.GroupSpots` builds the subzone groups for both tabs; `GameData/Continents.lua`.
- **UI (R7, R10)**: `UI/PlaceList.lua` (the three-level list with pins, shared by the catalog and the new tab),
  `UI/BestPlacesTab.lua`, a fourth page in `UI/StatsFrame.lua`, two menu entries in `UI/Minimap.lua`, `/okf best`.

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+ for
the tools

**Primary Dependencies**: the WoW Mainline API of Forever 1.60.1; new calls `C_Map.GetMapLevels` (replaced on 2026-11-23 by `GameData/ZoneLevels.lua`: it gives 0 in Forever; client export,
not yet seen in game: V75) and `UnitLevel("player")`; `C_Map.GetMapInfo` (in use) for the continent (V76)

**Storage**: `OneKeyFishingCharDB.bestPlaces = { safe, continent }` (per character, new, filled by `ApplyDefaults`, no
`DB_SCHEMA` bump); the catch cells already hold `t`

**Testing**: `npm test`, `npm run check`; `tests/wow.lua` gains `map_levels[mapID]` for `C_Map.GetMapLevels` and a
player level; new tests listed in quickstart.md

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: the ranking from about a hundred cached map views, built in frame steps of 3 ms when many
maps changed (as the catalog index); opening a zone queries one map's cells; no work while the tab is closed

**Constraints**:
- Principle II: maps, areas, items by ID; levels and continents from the game's map data; texts through `ns.L` with
  nine translations, looked up when drawn.
- Layers: `GameData` (0) data only; `CatchDB`, `Catalog`, `BestPlaces` (2) no frames; the UI (3) calls them. Prices
  (layer 1) are read by `BestPlaces` (allowed: layers 0-2).
- Two `VERIFY` markers (V75, V76) with their `verification.md`; the build refuses them until checked or accepted.
- New files in the TOC (`GameData/Continents.lua`, `Catalog/BestPlaces.lua`, `UI/PlaceList.lua`,
  `UI/BestPlacesTab.lua`): a game restart after the update.
- ASCII outside the locales; 120-character lines.

**Scale/Scope**:
- Addon: new `GameData/Continents.lua`, `Catalog/BestPlaces.lua`, `UI/PlaceList.lua`, `UI/BestPlacesTab.lua`;
  changed `CatchDB/Views.lua`, `Catalog/Catalog.lua` (`GroupSpots`), `UI/CatalogTab.lua`, `UI/StatsFrame.lua`,
  `UI/Minimap.lua`, `Core/Core.lua` (char default), `Core/Commands.lua`, `Core/Debug.lua`, `OneKeyFishing.toc`,
  `Locales/*.lua`, `.luacheckrc` (`GetMapLevels` if needed), `tools/addon.mjs` (if a new file needs listing).
- Documents: `CHANGELOG.md`, `OneKeyFishing/README.md`, `CLAUDE.md` (module map, saved field, setter rule),
  `docs/architecture/catalog.md`, `catch-db.md`, `game-data.md`, `ui.md`, `core.md`; `specs/024-best-places/
  verification.md`; `docs/checklists/best-places.md`; `docs/ROADMAP.md`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Blizzard policy | Read-only lists and map pins on a click; no game action | Pass |
| II. Language-independent data | Map, area, item IDs; levels and continents from map data, never names; nine translations | Pass |
| III. Safe, restorable state | One new per-character table of two values, defaults by `ApplyDefaults`; nothing of the game changed | Pass |
| IV. Verified Forever API | `GetMapLevels` and the continent parents carry `VERIFY(V75/V76)` with a `verification.md` and a checklist | Pass |
| V. Checked and tested | Tests for the time sums, the gold, the ranking, the groups, the tab, the menu and the command | Pass |
| VI. Simple module boundaries | Rules in layer 2 (`BestPlaces`, `Catalog.GroupSpots`), frames in layer 3; one shared list widget, no duplicate list code | Pass |

Re-check after Phase 1: unchanged, all pass.

## Project Structure

### Documentation (this feature)

```text
specs/024-best-places/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/best-places.md
├── checklists/requirements.md
├── verification.md      # V75, V76 (written with the code)
└── tasks.md             # /speckit-tasks
```

### Source Code

```text
OneKeyFishing/
├── GameData/Continents.lua      # new: Kalimdor 1414, Eastern Kingdoms 1415
├── CatchDB/Views.lua            # seconds, casts, catchesPerHour in every view
├── Catalog/Catalog.lua          # GroupSpots
├── Catalog/BestPlaces.lua       # new: ns.BestPlaces
├── UI/PlaceList.lua             # new: the three-level list with pins
├── UI/CatalogTab.lua            # places through PlaceList
├── UI/BestPlacesTab.lua         # new: the tab
├── UI/StatsFrame.lua, UI/Minimap.lua, Core/Commands.lua, Core/Core.lua, Core/Debug.lua
└── Locales/*.lua
tests/catchdb/, tests/catalog/, tests/ui/, tests/core/
```

**Structure Decision**: the existing areas; `BestPlaces` lives in the catalog's folder (same layer and data), a
module of its own so the catalog file does not grow further.

## Complexity Tracking

No violations.

## Revisions after the reviews and the in-game check (2026-11-23)

- Zone levels: `C_Map.GetMapLevels` gives 0 in Forever, the client has no zone levels; `GameData/ZoneLevels.lua`
  (ranges from LibTouristClassicEra, the capitals and Moonglade 1-60) replaced it; a cave or building map takes its
  zone's range; a continent map is never ranked. V75 and V76 confirmed in game, their markers removed; the test stub
  `map_levels` / `GetMapLevels` was removed again.
- The pace: a weighted seed cell's time goes with its counted `c` (not `r`); another player's time is weighted by its
  catches before the filters and, like a seed cell's, counts at least 5 s a cast; the harvest scales `t` with the
  catch factor.
- Rankings: a copy of the filter per ranking, a build fills a table swapped in at its end, a dropped ranking stops its
  steps, only the latest two rankings are kept; recounts on the price switches and on an unpriced item's info, not on
  Safe for me, the continent or a level-up (they only redraw, the level a second later).
- Groups: one group in a zone opens straight into its spots; a group carries its spots' shared camp bonus tag with
  its own numbers, mixed tags sum the plain numbers; the unpriced share counts pieces; spots under a subzone show only
  their coordinates; a group's pin label names its spot.
- Bonus catches only: an item's chance under the bonus (`Catalog.ItemNumbers`), and little data from those numbers.
