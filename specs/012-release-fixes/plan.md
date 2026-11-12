# Implementation Plan: Release Fixes for 1.2.0

**Branch**: `002-shared-db` (no branch of its own; the feature folder is `specs/012-release-fixes`) |
**Date**: 2026-11-11 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/012-release-fixes/spec.md`

## Summary

Every open item of `docs/tech-debt.md` "Fix batches", built on `002-shared-db` for release 1.2.0:

- **Dungeon (R1, batch 10)**: `ns.IsSecret`; `GameObjectID` returns nil for a secret GUID; `IsBobberTargeted`
  answers `targeted, known`; the indicator shows no "No bobber" when the answer is unknown; a secret loot source is
  skipped in `Bags.lua`.
- **Status texts (R2, R3, batch 9)**: the view's `others` field picks the bundled-data hint; a singular "Exchange: 1
  player" key; nine languages each.
- **Lure (R4, batch 5)**: a skipped lure stores the skill at its refusal and comes back on a skill event once the
  skill meets a requirement that the stored skill did not.
- **Minimap tooltip (R5, batch 7)**: `ClearLines` after `SetOwner`; every coloured line carries a colour code.
- **Private check (R6, batch 8)**: `privateProblems` walks the luaparse tree, following aliases and bracketed names.
- **Documents and the 1.2.0 test page** follow (R7, FR-015, FR-016); `docs/tech-debt.md` ends with no open item.

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+
for the tools

**Primary Dependencies**: the WoW Mainline API as shipped in Forever 1.60.1; luaparse for the repository checks

**Storage**: no saved field changes shape: no `DB_SCHEMA` bump, no migration

**Testing**:
- `npm test` and `npm run check`.
- Stubs in `tests/wow.lua`: `secret_values` and `issecretvalue` exist; new: `strsplit` raises on a secret value (the
  game's behaviour), a soft-target GUID for `UnitGUID("softinteract")`, `GameTooltip:ClearLines` recorded.
- Tooling tests in `tests/tools/private_check_test.mjs`.

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: no measurable cost: one `issecretvalue` call per indicator update; the lure check runs only
when a lure is skipped

**Constraints**:
- Blizzard's Add-On Policy: no new automatic action; the key's channeling binding is unchanged.
- Principle II: the bobber stays matched by its object ID; no name comparison.
- Layers: `UI/CatchHere.lua` reads the `CatchDB.Query` view it already has (2 from 3); `Bags.lua` reads `ns.Skill` at runtime (1).
- Two new visible texts, each with nine translations (`ns.L`, keys in `Locales/enUS.lua`).
- ASCII outside the locales, 120-character lines, Lua 5.1/5.3 neutral.

**Scale/Scope**:
- Addon files: `Core/Data.lua`, `UI/Indicator.lua`, `Fishing/Bags.lua`, `CatchDB/Views.lua`, `UI/CatchHere.lua`,
  `Exchange/ShareGame.lua`, `UI/Minimap.lua`, `Locales/*.lua` (10 files).
- Tools: `tools/addon.mjs`.
- Tests: one new file (`tests/ui/indicator_secret_test.lua`), six extended; `tests/wow.lua`.
- Documents: as in research R7.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Blizzard Policy | No cast, hook or item use is added; the fishing key's binding while channeling does not change; the lure is offered, never applied without a key press | Pass |
| II. Language-Independent Game Data | The bobber is still matched by object ID; a secret value is not compared; the new texts go through `ns.L` with nine translations | Pass |
| III. Safe, Restorable State | Nothing fishing mode changes is touched; no saved field changes | Pass |
| IV. Verified Forever API | The secret soft-target GUID in a dungeon was seen (2026-11-11, `docs/forever-api.md`); the colour codes surviving the reset were seen (2026-11-08); a secret loot source is not seen and is only guarded, so no behaviour rests on it | Pass |
| V. Checked and Tested Changes | A test per fix that fails without it; `npm run check` and `npm test` | Pass |
| VI. Simple Module Boundaries | Each change stays in the module that owns it; no new `CatchDB` function (the review of 2026-11-12 dropped `HasOthers`); no new message | Pass |

Re-check after Phase 1: the contracts add `ns.IsSecret`, give `IsBobberTargeted` a second
return value (one caller), and keep every layer rule. Pass.

## Project Structure

### Documentation (this feature)

```text
specs/012-release-fixes/
├── plan.md              # This file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── module-api.md    # Phase 1
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── Core/Data.lua            # R1: IsSecret, GameObjectID guard, IsBobberTargeted -> targeted, known
├── UI/Indicator.lua         # R1: no "No bobber" when unknown
├── Fishing/Bags.lua         # R1: secret loot source; R4: skipped lures by skill
├── UI/CatchHere.lua         # R2: the hint
├── Exchange/ShareGame.lua   # R3: "1 player"
├── UI/Minimap.lua           # R5: ClearLines, colour codes
└── Locales/*.lua            # R2, R3: two keys, nine translations
tools/addon.mjs              # R6: privateProblems over luaparse
tests/
├── wow.lua                  # strsplit on secrets, soft-target GUID, ClearLines
├── ui/                      # indicator_secret_test.lua (new); here_page, minimap_tooltip extended
├── fishing/                 # fished_loot, lure_skill extended
├── exchange/share/          # game_test extended
└── tools/                   # private_check_test.mjs extended
```

**Structure Decision**: the existing addon layout; each change lives in the module that owns the data (layers of
CLAUDE.md).

## Complexity Tracking

No violation to justify.
