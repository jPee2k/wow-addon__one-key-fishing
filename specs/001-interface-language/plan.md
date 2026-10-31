# Implementation Plan: Interface Language

**Branch**: `001-interface-language` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-interface-language/spec.md`

## Summary

The addon gets a language setting ("Game client language" by default, or one of ten languages named in their
own language) and ships complete translations for nine languages besides English, with Ukrainian in place of
Russian. The language is resolved once per UI session in `ADDON_LOADED`, after the saved variables exist; all
text lookups that run at file load today move to runtime, guarded by a test. A change is saved and applied
through a "Reload now / Later" popup. Translations live in `Locales/<code>.lua` files that register
themselves with a native name; tests enforce completeness, placeholder order and the absence of load-time
lookups. Details and rejected alternatives: [research.md](research.md).

## Technical Context

**Language/Version**: Lua 5.1 (WoW Forever client, Interface 16001, build 1.60.1, Mainline API)

**Primary Dependencies**: WoW API only: `GetLocale`, `ReloadUI`, `StaticPopup`, `MenuUtil` (verified via the
minimap menu), menu `CreateRadio` (unverified, guarded); game font objects

**Storage**: `OneKeyFishingDB.settings.language` (account-wide saved variable), see
[data-model.md](data-model.md)

**Testing**: `npm test` (fengari, `tests/wow.lua` stubs) with a new `tests/locale_test.lua`; `npm run check`;
in-game checklist in [quickstart.md](quickstart.md)

**Target Platform**: WoW Forever client in any client language (Windows)

**Project Type**: World of Warcraft addon (single package `OneKeyFishing/`)

**Performance Goals**: no measurable cost: one table lookup per text; only the effective translation is built
in memory

**Constraints**: Blizzard UI Add-On Policy (reload only on a click); no `L` lookup at file load; literal keys;
ASCII outside the translation files; lines up to 120 characters; Lua 5.1/5.3-neutral code

**Scale/Scope**: 163 English texts x 9 translations; 10 selectable languages; 16 files use `L`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status |
|---|---|---|
| I. Blizzard Policy | No game action added; `ReloadUI` only from the popup's "Reload now" click | Pass |
| II. Language-Independent Game Data | Game data still matched by ID; every visible text via `ns.L` with literal keys; translations are the documented exception to "English only" | Pass |
| III. Safe, Restorable State | One new saved field, filled by `ApplyDefaults`; no schema change; unknown values resolve to auto | Pass |
| IV. Verified Forever API | `MenuUtil`, `StaticPopup`, `GetLocale` already in use; `CreateRadio` guarded with a fallback; new globals into `.luacheckrc`; fonts and layout handed to the author as an in-game checklist | Pass |
| V. Checked and Tested | New `tests/locale_test.lua` (resolution, no early lookups, completeness, placeholders, popup); `npm run check` key sync covers the new files and reports any `SetFont` call | Pass |
| VI. Simple Module Boundaries | One new file `Localization.lua` (first in the TOC) owns `ns.L` and the registry; translation files only register data; no new message | Pass |

Post-design re-check (after Phase 1): unchanged, all pass. No violations, so Complexity Tracking stays empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-interface-language/
├── spec.md
├── plan.md              # this file
├── research.md          # R1-R10 decisions
├── data-model.md        # preference, registry, lookup, transitions
├── quickstart.md        # automated and in-game validation
├── contracts/
│   └── translation-file.md   # translation file format, localization API, settings control
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks (not created here)
```

### Source Code (repository root)

```text
OneKeyFishing/
├── OneKeyFishing.toc          # + Localization.lua first, + Locales/<code>.lua after enUS.lua
├── Localization.lua           # NEW: ns.L, AddTranslation, ResolveLanguage, SetLanguage, GetLanguages,
│                              #      LANGUAGE_ORDER, early-lookup guard
├── Locales/
│   ├── enUS.lua               # English list only (engine moves out); registers "English"; new texts
│   ├── deDE.lua esES.lua esMX.lua frFR.lua ukUA.lua koKR.lua ptBR.lua zhTW.lua zhCN.lua   # NEW
├── Core.lua                   # settings.language default; resolve + SetLanguage in ADDON_LOADED;
│                              # binding names set there; RegisterCommand descriptions as functions
│                              # (superseded: commands moved to Commands.lua with English descriptions);
│                              # ns.CreateButton grows to its text
├── Skill.lua                  # rank tables built at runtime
├── Debug.lua                  # report: preference, effective language, client locale
├── Auction.lua Mode.lua       # command descriptions as functions
└── UI/
    ├── Settings.lua           # TOGGLES at runtime; language button, menu, tooltip, reload popup
    ├── StatsFrame.lua         # ROWS at runtime; command description
    └── Indicator.lua          # LABELS at runtime

tests/
├── wow.lua                    # GetLocale configurable, ReloadUI recorded
└── locale_test.lua            # NEW

tools/check.mjs                # unchanged rules; translation exemption already in place
.luacheckrc                    # + ReloadUI and any new API globals
docs/languages.md              # translation file format updated to the contract
README.md CHANGELOG.md CLAUDE.md   # languages for players, Unreleased entry, architecture (Localization.lua)
```

**Structure Decision**: the existing single-addon layout; one new runtime file (`Localization.lua`) and nine
translation files under `OneKeyFishing/Locales/`, plus one test file.

## Phases (for /speckit-tasks)

1. **Foundation**: `Localization.lua`, TOC order, `enUS.lua` slimmed to the list, Core resolution in
   `ADDON_LOADED`, test stubs, `locale_test.lua` for resolution and the early-lookup guard.
2. **No load-time lookups**: move Core binding names, command descriptions, `TOGGLES`, `ROWS`, `LABELS`, rank
   tables to runtime until the guard test passes.
3. **Translations (US1)**: Ukrainian first (author reviews), then deDE, esES, esMX, frFR, ptBR, koKR, zhTW,
   zhCN; completeness and placeholder tests; button auto-width and layout for longer texts.
4. **Setting (US2)**: language button, menu, tooltip, reload popup, debug report lines.
5. **Docs and release notes**: `docs/languages.md`, README, CHANGELOG `[Unreleased]`, CLAUDE.md.
6. **In-game validation**: hand [quickstart.md](quickstart.md) to the author.

## Addendum 2026-11-03: User Story 3 (the next Fishing rank)

Spec: User Story 3, FR-015 - FR-025, SC-007 - SC-009. Research: [research.md](research.md) R11-R16. Data:
[data-model.md](data-model.md) "Rank steps" and "Map pin".

### Summary

The rank advice in `Skill.lua` stops translating game names: zone, sub-zone, book, quest and rank names are
read by ID in the client's language, NPC names come from a tooltip, a per-locale table or English. Each
learning source (trainer, book, quest) gets its own sentence. Notices follow the game's rules (can learn at
50 / 125 / 225 with level 10 / 20 / 35, cap at 75 / 150 / 225, raid warning once per session). The advice
stays visible in the statistics window and the minimap tooltip, and the book seller and quest giver get the
game's map pin through a shared `MapPin` module taken over from `002-shared-db`.

### Technical Context (delta)

**Primary Dependencies**: `C_Map.GetAreaInfo`, `C_Map.GetMapInfo`, `C_Map.CanSetUserWaypointOnMap`,
`C_Map.SetUserWaypoint`, `C_Map.HasUserWaypoint`, `C_Map.GetUserWaypoint`, `UiMapPoint.CreateFromCoordinates`,
`C_SuperTrack.SetSuperTrackedUserWaypoint`, `C_GameRules.IsGameRuleActive`, `OpenWorldMap`,
`C_Item.GetItemNameByID`, `C_Item.RequestLoadItemDataByID`, `C_QuestLog.GetTitleForQuestID`,
`C_QuestLog.RequestLoadQuestByID`, `C_Spell.GetSpellSubtext`, `C_TooltipInfo.GetHyperlink`, `UnitLevel`; events
`ITEM_DATA_LOAD_RESULT`, `QUEST_DATA_LOAD_RESULT`, `SPELL_DATA_LOAD_RESULT`, `SPELL_TEXT_UPDATE`,
`PLAYER_LEVEL_UP`; `C_Spell.RequestLoadSpellData`. All present in the
Forever export (R12, R14); behaviour marked VERIFY until the in-game check.

**Storage**: `OneKeyFishingCharDB.pin` (`{ mapID, x, y }`, the addon's last pin; new key, no migration), the same
field as on `002-shared-db`. `settings.skillCapWarning` keeps its key, its label changes.

**Testing**: new `tests/skill_test.lua` and `tests/mappin_test.lua`; stubs in `tests/wow.lua` for the APIs
above (configurable names, level, map candidates, game rule, existing waypoint).

**Scale/Scope**: about 12 new English texts (state and source sentences, "Next rank" line, pin texts, the
renamed setting) x 9 translations; 5 old texts removed.

### Constitution Check (User Story 3)

| Principle | Check | Status |
|---|---|---|
| I. Blizzard Policy | Pins are set only from the player's click (button, menu, chat link); nothing automated | Pass |
| II. Language-Independent Game Data | Game names read by ID in the client language; data in `GameData/`; sentences via `ns.L` with literal keys | Pass |
| III. Safe, Restorable State | One new char field `pin` (nil by default, no migration); a pin of the player's own is replaced only after a confirmation | Pass |
| IV. Verified Forever API | Every API is in the Forever export; IDs, maps, coordinates, subtext, tooltip names and the map link are VERIFY items in the in-game checklist | Pass |
| V. Checked and Tested | `skill_test.lua` (thresholds, level wait, once per session, name fallbacks) and `mappin_test.lua` (map choice, game rule, replace popup) | Pass |
| Technical Constraints (1.3.0) | UTF-8 only inside string literals of `GameData/` files (NPC names); `tools/check.mjs` allows exactly that, code and comments stay ASCII | Pass |
| VI. Simple Module Boundaries | `GameData/FishingRanks.lua` data only; `UI/MapPin.lua` owns pins; `Skill.lua` owns the advice; no new message (the statistics window is marked dirty through existing paths) | Pass |

### Source Code (delta)

```text
OneKeyFishing/
├── OneKeyFishing.toc          # + GameData\FishingRanks.lua after Data.lua; + UI\MapPin.lua before StatsFrame
├── GameData/
│   └── FishingRanks.lua       # NEW, data only: ns.FishingRanks (steps per cap), ns.FishingRankSpells,
│                              #      ns.NpcNames (per client locale, UTF-8 string literals)
├── Skill.lua                  # thresholds, level wait, names by ID, Skill.GetNextRank(), notices, map link
├── UI/
│   ├── MapPin.lua             # NEW: MapPin.Target(maps, x, y), MapPin.Set(target, placeName), replace popup
│   ├── StatsFrame.lua         # "Next rank" line + pin button under the skill line
│   ├── Minimap.lua            # tooltip line + menu entry "Pin: next Fishing rank"
│   └── Settings.lua           # renamed rank reminder toggle
├── Debug.lua                  # next-rank state, name sources, pin target
├── Core.lua                   # unchanged: charDB.pin defaults to nil (data-model.md "Map pin")
└── Locales/*.lua              # new sentences, old rank phrases removed (all ten files)

tests/wow.lua tests/skill_test.lua tests/mappin_test.lua
tools/check.mjs                # GameData/: non-ASCII allowed only inside string literals (constitution 1.3.0)
CLAUDE.md                      # npm run check description: the GameData/ exception
.luacheckrc                    # new API globals
docs/checklists/interface-language.md   # new section "Next rank"; fishing-mode.md section 8 updated
OneKeyFishing/README.md CHANGELOG.md CLAUDE.md docs/release-plan.md docs/ROADMAP.md
```

### Phases (for /speckit-converge)

7. **Data and tests**: `GameData/FishingRanks.lua`, test stubs, `skill_test.lua` and `mappin_test.lua` failing
   first.
8. **Advice logic**: `Skill.lua` thresholds, level wait, names by ID with fallbacks, notices, map link.
9. **Map pin**: `UI/MapPin.lua` from the `002-shared-db` code, same saved field and texts.
10. **UI**: statistics line and pin button, minimap tooltip and menu, settings label, debug report.
11. **Texts**: new English sentences and their nine translations, added with the code that uses them (tasks.md
    "Phase 6 execution order"), old keys removed; a final pass checks completeness and the Ukrainian review.
12. **Docs**: checklists, README, CHANGELOG `[Unreleased]`, CLAUDE.md (modules, `charDB.pin`, the `GameData/`
    rule), `docs/release-plan.md` (1.2.0: move older tables to `GameData/`, catalog uses `MapPin`),
    `docs/ROADMAP.md` (pin on the nearest trainer).
13. **In-game validation**: the "Next rank" section of [quickstart.md](quickstart.md), handed to the author.

## Complexity Tracking

No constitution violations to justify.
