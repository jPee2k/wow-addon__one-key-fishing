# Implementation Plan: Cumulative Skill Filter

**Branch**: `021-cumulative-skill-filter` | **Date**: 2026-11-20 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/021-cumulative-skill-filter/spec.md`; the author's decisions 1 to 9 in its
clarifications (grilling session of 2026-11-20).

## Summary

The Skill filter reads the catches of every range up to the chosen one. `Ranges(filter)` in `CatchDB/Views.lua`
returns `0..r` instead of `r`, so every list follows at once (R1, R2). The miss rate is the one exception: `Query`
sums the chosen range alone at the scope it chose and builds the miss rate from that sum, with its own little-data
state (R3). The UI gets new labels, a menu that marks the own range, a tooltip on the Skill button, and loses the
"All skill levels" value and its hint (R4 to R6). Nothing stored or exchanged changes.

## Technical Context

**Language/Version**: Lua 5.1 (WoW Forever, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+ for the tools

**Primary Dependencies**: the addon's `CatchDB/Views.lua`, `CatchDB/CatchDB.lua`, `Catalog/Catalog.lua`,
`UI/CatchHere.lua`, `UI/CatalogTab.lua`, `UI/Widgets.lua`, `Locales/*.lua`; `GameTooltip`; no new game API

**Storage**: none changed (no saved field, no cell field, no `DB_SCHEMA` bump)

**Testing**: `npm test`, `npm run check`

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: `Query` sums one more range at one scope per view (cached with it); none when the range is
0-74; the catalog's indexes, `QueryMap` and `QueryCells` add no pass. Lists of a higher range sum up to five ranges
instead of one, the same work as "All skill levels" today.

**Constraints**:
- Principle I: display only; no game action.
- Principle II: ten new texts through `ns.L` as whole strings with their numbers, nine translations each; three keys
  removed from all ten files; nothing looked up while files load.
- Principle III: nothing stored changes.
- Principle IV: no new API; `GameTooltip` is already used by the buttons of spec 020.
- Layers: the rule in `CatchDB` (layer 2), the labels, the menu and the tooltip in `UI/` (layer 3).
- ASCII outside the locales; 120-character lines; Lua 5.1 / 5.3 neutral.

**Scale/Scope**:
- Addon: `CatchDB/Views.lua` (`Ranges`, `MissRange`, `Query`, `BuildView`, `QueryMap` / `QueryCells` drop
  `missRate`), `CatchDB/CatchDB.lua` (`SkillFilter`, `RangeOf`), `Catalog/Catalog.lua` (`MinimapLines`),
  `UI/Widgets.lua` (`SkillFilterLabel`, `SkillMenuText`, `ShowSkillTooltip`, `RangeLabel` without `"all"`),
  `UI/CatchHere.lua` (menu, label, tooltip, counts line, hint, `EffectiveRange`), `UI/CatalogTab.lua` (label,
  tooltip), `Locales/*.lua` (10 files).
- Tests: five new files, six adjusted, `tests/catalog/index_test.lua` extended (quickstart).
- Documents: `CHANGELOG.md` (Unreleased), `OneKeyFishing/README.md` ("Skill" in the "What can be caught here" and
  catalog sections), `docs/architecture/catch-db.md` (the filter's ranges, the miss rate), `docs/architecture/
  catalog.md` (the minimap lines), `docs/architecture/ui.md` (the Skill button), new `docs/checklists/skill-filter.md`
  and its row in `docs/checklists/README.md`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Blizzard Policy | Display only: which stored catches a list sums; no cast, item use or automatic reaction | Pass |
| II. Language-Independent Game Data | No game data by name; every new text a whole string through `ns.L` with its number, nine translations, read at runtime | Pass |
| III. Safe, Restorable State | No saved field added, renamed or reshaped; no CVar, gear or camera | Pass |
| IV. Verified Forever API | No new API; `GameTooltip` on a button as in spec 020; no `VERIFY` needed (behaviour fully testable outside the game, the widths checked by the checklist) | Pass |
| V. Checked and Tested Changes | Sums, miss rate, threshold, `"all"`, defaults, labels and menu each get a test that fails on `develop` (quickstart) | Pass |
| VI. Simple Module Boundaries | One function in `CatchDB`, two helpers in `UI/Widgets.lua`; no message, command, setting or frame; the rule in one place | Pass |
| Technical Constraints | No new file in the addon, no TOC change | Pass |

Re-check after Phase 1: the contracts add `CatchDB.SkillFilter`, `CatchDB.RangeOf`, `view.missLittleData`,
`ns.SkillFilterLabel`, `ns.SkillMenuText`, `ns.ShowSkillTooltip`; `QueryMap` / `QueryCells` lose a field no caller
reads; the filter's values and `FilterKey` keep their form. Pass.

## Project Structure

### Documentation (this feature)

```text
specs/021-cumulative-skill-filter/
├── spec.md
├── plan.md              # this file
├── research.md          # R1-R7
├── data-model.md        # the filter values, the view's changed fields
├── quickstart.md        # what the tests prove, the in-game checklist
├── contracts/
│   └── api.md           # module functions and texts
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── CatchDB/
│   ├── CatchDB.lua      # SkillFilter, RangeOf
│   └── Views.lua        # Ranges 0..r, MissRange, Query's miss sum, BuildView(scope, sum, rules, missSum)
├── Catalog/Catalog.lua  # MinimapLines through SkillFilter
├── UI/
│   ├── Widgets.lua      # SkillFilterLabel, ShowSkillTooltip, RangeLabel without "all"
│   ├── CatchHere.lua    # menu with "(yours)", button text and tooltip, counts line, no hint
│   └── CatalogTab.lua   # button text and tooltip
└── Locales/*.lua        # 10 added keys, 3 removed, in all ten files
tests/
├── catchdb/             # skill_ranges_test, skill_misses_test, skill_filter_test; three adjusted
└── ui/                  # here_skill_test, catalog_skill_test; three adjusted
docs/checklists/skill-filter.md
```

**Structure Decision**: the existing layout; no new module or area.

## Order of work (for the tasks)

1. `CatchDB`: `SkillFilter`, `RangeOf`, `Ranges` 0..r, `MissRange` and the miss sum in `Query`, `missLittleData`, no
   `missRate` in `QueryMap` / `QueryCells`; tests `skill_filter`, `skill_ranges`, `skill_misses`; adjust the three
   miss-rate tests.
2. Texts: the ten keys in `enUS.lua` and the nine translations; remove the three keys.
3. `UI/Widgets.lua`: `SkillFilterLabel`, `ShowSkillTooltip`, `RangeLabel` without `"all"`.
4. `UI/CatchHere.lua`: `EffectiveRange` through `SkillFilter`, the menu, the button text and tooltip, the counts line,
   the hint removed; test `here_skill`; adjust `here_page`, `here_login`.
5. `UI/CatalogTab.lua` and `Catalog.MinimapLines`; tests `catalog_skill`, `catalog/index` (MinimapLines); adjust
   `catalog_list`.
6. Documents: changelog, manual, architecture pages, checklist and its row.

## Risks

- **Width**: a translation of "Skill: Up to 224" longer than 150 px. The longest present text ("Skill: All skill
  levels" in each language) already fits; the translations are kept no longer than it (T004), and the checklist
  confirms German and French, then the other seven languages.
- **"all" miss rate**: almost always "little data" today (29 catches at 300+); accepted by decision 3.
- **Existing tests** read miss rates under `"all"` with data below 300+: they are adjusted, not weakened (research R7).

## Complexity Tracking

No violations.
