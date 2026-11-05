# Implementation Plan: Launch Day Fixes

**Branch**: `001-interface-language` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/007-launch-day-fixes/spec.md`

## Summary

Six fixes from the first in-game run of 1.1.0, shipped with 1.1.0 on its own branch. Each is a small change in
the module that owns the screen, with a test that fails without it:

1. Fishing gear page: rows start hidden and the list is filled when the page is built; the item tooltip needs an
   item (`UI/Settings.lua`).
2. Debug report: a value that is missing prints as `nil` instead of breaking `tostring` (`Debug.lua`).
3. Popups: `ns.ShowPopup` defaults to the addon's `L["Yes"]` / `L["No"]`, the pin popup passes `L["Cancel"]`
   (`Core.lua`, `UI/MapPin.lua`, three new texts in ten locale files).
4. Bound keys: one shared `ns.KeyText(binding, short, unbound, separator)` names every key of a binding; the minimap tooltip, the
   settings key line and the indicator use it (`Core.lua`, `UI/Minimap.lua`, `UI/Settings.lua`,
   `UI/Indicator.lua`).
5. Statistics buttons: when the Scan button does not fit, the three left buttons move up a row and Scan starts
   the row below at the left (`UI/StatsFrame.lua`).
6. CJK tooltip: in Korean and Chinese the minimap tooltip ends with an empty line (`UI/Minimap.lua`).

Root causes and decisions: [research.md](research.md). Function contracts: [contracts/ui.md](contracts/ui.md).
In-game validation: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Lua 5.1 (WoW Forever client, Interface 16001, build 1.60.1.70790); tests run on fengari
(Lua 5.3), kept free of 5.1/5.3 differences.

**Primary Dependencies**: the WoW Mainline UI API (frames, `GameTooltip`, `StaticPopup`, `GetBindingKey` /
`GetBindingText`, the Settings canvas API); no libraries.

**Storage**: none changes. No saved field is added, renamed or reshaped, so no `DB_SCHEMA` bump.

**Testing**: `npm test` (`tests/*_test.lua` on the stubs in `tests/wow.lua`), `npm run check`; in-game re-run of
the failed checklist steps (`quickstart.md`).

**Target Platform**: WoW Forever, any client language; the addon in any of its ten languages.

**Project Type**: game addon (one folder, `OneKeyFishing/`).

**Performance Goals**: none new; the changes run on opening a window, a tooltip or a report.

**Constraints**: Blizzard UI Add-On Policy (no change to what happens on a key press); ASCII Lua outside
translations; lines up to 120 characters; every new text in all ten languages in the same change; no `L[...]`
lookup at file load.

**Scale/Scope**: about 8 addon files, 10 locale files (3 new keys each), 3 to 4 test files, 2 checklists, the
manual and the changelog.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Policy | No change to casting, hooking, lures or containers; only display, layout and a report. | Pass |
| II. Language-independent data | Keys are read by binding name and shown with the game's `GetBindingText`; popup buttons move from client globals to `ns.L` (fixes a Principle II gap); three new literal keys with nine translations. | Pass |
| III. Restorable state | No CVar, gear, camera or saved field touched. | Pass |
| IV. Verified Forever API | Uses only APIs already in use and verified in game (`GetBindingKey`, `GetBindingText`, `GameTooltip:AddLine`, frame `Show` / `Hide`). `GameTooltip:SetPadding` exists in the export but was rejected (research R6). Each fix gets an in-game step; the API facts learned on 2026-11-05 are already in `CLAUDE.md`. | Pass |
| V. Checked and tested | A failing-first test per fix with logic: gear rows, debug report, popup buttons, key text, button rows; the CJK line is checked by a test of the tooltip lines. | Pass |
| VI. Simple boundaries | One shared helper (`ns.KeyText`) replaces three copies; no new message, setting, frame or saved field. | Pass |

Re-check after Phase 1: unchanged, all pass. No complexity tracking needed.

## Project Structure

### Documentation (this feature)

```text
specs/007-launch-day-fixes/
├── spec.md
├── plan.md              # this file
├── research.md          # root causes and decisions (R1-R7)
├── data-model.md        # what the fixes read and show; no saved data
├── quickstart.md        # in-game re-run
├── contracts/
│   └── ui.md            # ns.KeyText, ns.ShowPopup defaults, the statistics button rows
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── Core.lua                 # ns.ShowPopup defaults (L), ns.KeyText (new, shared)
├── Debug.lua                # missing values print plainly
├── UI/Settings.lua          # gear rows hidden at creation, list filled at build; key line through ns.KeyText
├── UI/StatsFrame.lua        # button rows: Scan wraps to the left of the row below
├── UI/Minimap.lua           # tooltip keys through ns.KeyText; empty last line for CJK
├── UI/Indicator.lua         # key through ns.KeyText (short form)
├── UI/MapPin.lua            # L["Cancel"] instead of CANCEL
└── Locales/*.lua            # "Yes", "No", "Cancel" in all ten files

tests/
├── wow.lua                  # stubs: GetBindingKey / GetBindingText with set bindings, SetWidth remembered,
│                            #   the gear page frame kept by the Settings stub
├── debug_test.lua           # new: report without lure, pole, skill
├── settings_gear_test.lua   # new: no shown Remove button on an empty list; rows for added items
├── keys_test.lua            # new: ns.KeyText with 0, 1, 2 and duplicate keys
├── popup_test.lua           # new: popup buttons in the addon's language
├── minimap_tooltip_test.lua # new: blank last tooltip line only in koKR, zhCN, zhTW
└── stats_test.lua           # extended: button rows in a long language
```

**Structure Decision**: the existing single-addon layout; fixes stay in the module that owns each screen, with
one shared helper in `Core.lua` (loaded before every UI file, so the UI files may call it at runtime and at load).

## Complexity Tracking

None: the Constitution Check has no violations.
