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
│                              # binding names set there; RegisterCommand descriptions as functions;
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

## Complexity Tracking

No constitution violations to justify.
