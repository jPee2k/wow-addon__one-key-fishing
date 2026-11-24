# Implementation Plan: "Safe for me" Keeps the Other Faction's Zones Out of the Best Places

**Branch**: `026-safe-faction` | **Date**: 2026-11-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/026-safe-faction/spec.md`; the research and the author's quiz of
2026-11-24 ([docs/best-places-research.md](../../docs/best-places-research.md), section 4).

## Summary

"Safe for me" in the best places also hides the zones and capitals of the other faction; contested zones keep the
level rule only. A zone's faction comes from a new data table `GameData.ZoneFactions` (17 UiMap IDs, from the game's
`AreaTable.FactionGroupMask`); a map inside a zone takes its zone's faction by the parent walk `ZoneLevels` already
uses. With Safe for me off, an enemy zone shows its Level in red. No text, setting, message or saved field is added.

- **Data (R1, R2)**: `GameData/ZoneFactions.lua`, hand-written with its source in the header; one `VERIFY(V77)`.
- **Logic (R3-R6)**: `Catalog/BestPlaces.lua`: `ZoneFaction(mapID)`, `PlayerFaction()`, `Hostile(zone)`; the zone
  numbers carry `faction`; `Passes` and `Unsafe` use them; `Describe` names the character's faction.
- **UI**: none changed: `UI/BestPlacesTab.lua` already colours the Level by `BestPlaces.Unsafe`.

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+ for
the tools

**Primary Dependencies**: the WoW Mainline API of Forever 1.60.1; new global `UnitFactionGroup("player")` (client
export `UnitDocumentation.lua`: `factionGroupTag`, `localized`); `C_Map.GetMapInfo` (in use) for the parent walk.
`C_PvP.GetZonePVPInfo` only in the in-game check, not in the code.

**Storage**: none new; `charDB.bestPlaces.safe` keeps its meaning (one switch, more rules); no `DB_SCHEMA` bump

**Testing**: `npm test`, `npm run check`; `tests/wow.lua` gains a `UnitFactionGroup` stub over a settable
`player_faction`; tests listed in quickstart.md

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: no recount: the faction is set on a zone's numbers when the zone is computed (as its levels)
and the filter reads it with the character's faction when the list is read; one `UnitFactionGroup` call per read

**Constraints**:
- Principle II: zones by UiMap ID, the faction tag compared as the game's untranslated `factionGroupTag`; no name.
- Layers: `GameData` (0) data only; `BestPlaces` (2) reads it; the UI (3) unchanged.
- One `VERIFY(V77)` marker with its row in `verification.md`; the build refuses it until checked in game.
- A new file in the TOC (`GameData/ZoneFactions.lua`): a game restart after the update.
- ASCII; 120-character lines.

**Scale/Scope**:
- Addon: new `GameData/ZoneFactions.lua`; changed `Catalog/BestPlaces.lua`, `OneKeyFishing.toc`, `.luacheckrc`
  (`UnitFactionGroup`).
- Tests: `tests/wow.lua` (stub), `tests/catalog/best_places_test.lua`, `tests/gamedata/shape_test.lua`,
  `tests/ui/best_tab_test.lua` (the red Level of an enemy zone).
- Documents: `CHANGELOG.md`, `OneKeyFishing/README.md` (Safe for me), `CLAUDE.md` (GameData list in the module map,
  the VERIFY feature list), `docs/architecture/game-data.md`, `docs/architecture/catalog.md`,
  `docs/forever-api.md` (after the check), `specs/026-safe-faction/verification.md`,
  `docs/checklists/best-places.md` (the check steps) and its row in `docs/checklists/README.md`, `docs/README.md`,
  `docs/ROADMAP.md` (hostile towns, the known limit; research R8), `docs/best-places-research.md` (a pointer to this
  spec).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Blizzard policy | A filter of a read-only list; no game action | Pass |
| II. Language-independent data | UiMap IDs; the faction as the game's untranslated tag; no new text | Pass |
| III. Safe, restorable state | No saved field added or reshaped; nothing of the game changed | Pass |
| IV. Verified Forever API | `UnitFactionGroup` added to `.luacheckrc`, guarded (nil or "Neutral" means no faction); the table carries `VERIFY(V77)` with a `verification.md` row and checklist steps | Pass |
| V. Checked and tested | Tests for the table's shape, the parent walk, the filter for both factions and none, the red Level | Pass |
| VI. Simple module boundaries | Data in `GameData` (one file per entity), the rule in `BestPlaces`, no new setting, button, message or frame | Pass |

Re-check after Phase 1: unchanged, all pass.

## Project Structure

### Documentation (this feature)

```text
specs/026-safe-faction/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/safe-faction.md
├── checklists/requirements.md
├── verification.md      # V77 (written with the code)
└── tasks.md             # /speckit-tasks
```

### Source Code

```text
OneKeyFishing/
├── GameData/ZoneFactions.lua    # new: [UiMapID] = "Alliance" | "Horde", 17 entries
├── Catalog/BestPlaces.lua       # ZoneFaction, PlayerFaction, Hostile; Passes, Unsafe, Describe
└── OneKeyFishing.toc            # the new file after GameData\ZoneLevels.lua
.luacheckrc                      # UnitFactionGroup
tests/wow.lua, tests/gamedata/shape_test.lua, tests/catalog/best_places_test.lua, tests/ui/best_tab_test.lua
```

**Structure Decision**: the existing areas; the rule stays in `BestPlaces` beside the level rule it joins.

## Complexity Tracking

No violations.
