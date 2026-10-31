---

description: "Task list for the Interface Language feature"
---

# Tasks: Interface Language

**Input**: Design documents from `specs/001-interface-language/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/translation-file.md](contracts/translation-file.md),
[quickstart.md](quickstart.md)

**Tests**: Included. The constitution (Principle V) requires tests for logic that runs without the game, and
[quickstart.md](quickstart.md) lists them. Tests come first in each phase and must fail before the
implementation.

**Organization**: Tasks are grouped by user story (US1 = automatic client language with translations, P1;
US2 = language setting in the options, P2).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story the task belongs to
- Paths are relative to the repository root; addon files are under `OneKeyFishing/`.
- After every task: `npm run check` and `npm test` (project rule). A new WoW API global goes into
  `.luacheckrc` `read_globals` in the same task that first uses it (the check also fails on unused globals).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: test stubs the new tests need.

- [X] T001 In `tests/wow.lua`, make `GetLocale()` return the global `CLIENT_LOCALE` (default `"enUS"`, set
  before `load_addon()` to simulate another client) and add a `ReloadUI()` stub that increments the global
  `reload_count` (starting at 0). Keep `StaticPopup_Show` / `accept_popup` as they are and add `cancel_popup()`
  that calls `StaticPopupDialogs[last_popup].OnCancel` when present, and `reset_popup()` that sets `last_popup`
  to nil (to assert that no popup was shown).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the localization engine, language resolution in `ADDON_LOADED`, and no text lookup at file load
(research R1-R3). Blocks both stories.

**CRITICAL**: no user story work can begin until this phase is complete.

### Tests first

- [X] T002 Create `tests/locale_test.lua` (fails until T003-T011 are done): after `load_addon()` assert
  `ns.language == "enUS"`, `ns.earlyLookups` is an empty table (no `L` lookup before the language was set),
  and `ns.ResolveLanguage` returns: `("auto", "enUS") -> "enUS"`, `("auto", "ruRU") -> "enUS"`,
  `("auto", "xxXX") -> "enUS"`, `("enUS", "deDE") -> "enUS"`, `("gone", "enUS") -> "enUS"` (an unregistered
  stored code behaves as auto); `ns.GetLanguages()[1]` is `{ code = "enUS", name = "English" }`; an unknown
  key such as `ns.L["No such text"]` returns the key itself.
- [X] T003 Update the existing tests for the new engine: in `tests/load_test.lua` "every slash command has a
  description", `command.description` is now a function, so assert it returns a non-empty string; in
  `tests/core_test.lua` and `tests/version_test.lua` load `{ "Localization.lua", "Locales/enUS.lua",
  "Core.lua" }`; move the three "locale:" tests of `tests/core_test.lua` into `tests/locale_test.lua`
  (a listed key returns the English text, an unlisted key falls back to itself, a translation registered
  with `ns.AddTranslation` under a test code such as `"xxXX"` and set with `ns.SetLanguage` replaces the
  English text, then the test calls `ns.SetLanguage("enUS")` so later tests run in English). `core_test` fires
  `ADDON_LOADED` once per test, so `ns.SetLanguage` must accept repeated calls (T004).

### Implementation

- [X] T004 Create `OneKeyFishing/Localization.lua` (ASCII only) per
  [contracts/translation-file.md](contracts/translation-file.md) and [data-model.md](data-model.md):
  `ns.L` (English list in `strings`, `__newindex` stores `value == true and key or value`; `__index` returns
  `active[key] or strings[key] or key` and, while `ns.language` is nil, appends the key to
  `ns.earlyLookups`); `ns.translations` (code -> `{ name, fill }`) and `ns.AddTranslation(code, name, fill)`
  (error on a duplicate code); `LANGUAGE_ORDER = { "enUS", "deDE", "esES", "esMX", "frFR", "ukUA", "koKR",
  "ptBR", "zhTW", "zhCN" }`; `ns.GetLanguages()` (registered codes in that order, as `{ code, name }`);
  `ns.ResolveLanguage(preference, clientLocale)` (registered preference, else registered client locale, else
  `"enUS"`); `ns.SetLanguage(code)` (empties `active`, runs `fill(active)`, sets `ns.language`; every call rebuilds the
  active translation, so repeated `ADDON_LOADED` in tests works; in game it runs once per session).
- [X] T005 Slim `OneKeyFishing/Locales/enUS.lua` to the English list: remove the engine (now in
  `Localization.lua`), keep every `L["..."] = true` line, add
  `ns.AddTranslation("enUS", "English", function() end)`, and update the header comment to describe the new
  translation files (`Locales/<code>.lua` registering through `ns.AddTranslation`).
- [X] T006 In `OneKeyFishing/OneKeyFishing.toc`, list `Localization.lua` before `Locales\enUS.lua`.
- [X] T007 In `OneKeyFishing/Core.lua`: add `language = "auto"` to `DB_DEFAULTS.settings` (new key only, no
  `DB_SCHEMA` bump, data-model.md); in the `ADDON_LOADED` handler run `Migrate`, `ApplyDefaults`, then
  `ns.SetLanguage(ns.ResolveLanguage(OneKeyFishingDB.settings.language, GetLocale()))`, then the
  "newer version" warning; move `BINDING_NAME_ONEKEYFISHING_ACTION` / `_TOGGLE` assignments into that handler
  after `SetLanguage` (`BINDING_HEADER_ONEKEYFISHING` stays at load: it is not translated).
- [X] T008 In `OneKeyFishing/Core.lua`, change `ns.RegisterCommand(name, description, fn)` so `description`
  is a function returning the text, and `PrintHelp` calls it; update every caller to pass
  `function() return L["..."] end`: `OneKeyFishing/Auction.lua` (scan), `OneKeyFishing/Debug.lua` (debug),
  `OneKeyFishing/Mode.lua` (toggle), `OneKeyFishing/UI/Settings.lua` (config),
  `OneKeyFishing/UI/StatsFrame.lua` (stats).
- [X] T009 [P] In `OneKeyFishing/UI/Settings.lua`, build the `TOGGLES` list inside a function called from
  `CreateMainPage` instead of at file load.
- [X] T010 [P] In `OneKeyFishing/UI/StatsFrame.lua`, build `ROWS` on the first `Create()` (a function
  returning the list, stored in the module-level `ROWS` before any code reads it); check every use of `ROWS`
  (`CreateTable`, `FillCells`, `RefreshTime`) runs after `Create()`.
- [X] T011 [P] In `OneKeyFishing/UI/Indicator.lua` build `LABELS`, in `OneKeyFishing/Skill.lua` build
  `RANK_NAMES` and `NEXT_RANK`, through functions called at runtime (on first use), not at file load; in
  `OneKeyFishing/Action.lua` look up `NO_KEY_HINT` inside `Action.Enable` instead of at file load. (A parse of
  every addon file found these and the lookups of T007-T010 as the complete list of load-time lookups.)
- [X] T012 Run `npm run check` and `npm test`; any remaining entry in `ns.earlyLookups` names a load-time
  lookup to move the same way. Done when T002 and T003 pass.

**Checkpoint**: the addon behaves exactly as before in English; the language is resolved in `ADDON_LOADED`.

---

## Phase 3: User Story 1 - The addon speaks the client's language (Priority: P1) MVP

**Goal**: on a client whose language has a translation, every addon text is in that language without any
setting; other clients (including `ruRU`) get English.

**Independent Test**: load with `CLIENT_LOCALE = "deDE"` (test) or start a German client (game): texts are
German; with `ruRU` they are English.

### Tests for User Story 1

- [X] T013 [P] [US1] Extend `tests/locale_test.lua`: for every `Locales/<code>.lua` in `TOC_FILES` other than
  `enUS.lua`, assert the code in `ns.translations` equals the file name, the native name is non-empty, and
  calling its `fill` on a plain table yields every key of the English list (completeness, FR-011) with no
  extra key; for each translated key, the sequence of `%` specifiers (pattern
  `%%[-+ #0]*%d*%.?%d*[cdeEfgGioqsuxX%%]`) and of `|` escapes (`|n`, `||`) equals the English key's.
- [X] T014 [P] [US1] Create `tests/locale_client_test.lua`: set `CLIENT_LOCALE = "deDE"`, `load_addon()`,
  assert `ns.language == "deDE"`, `ns.L["Cast"]` equals the German entry of `Locales/deDE.lua`, and
  `BINDING_NAME_ONEKEYFISHING_ACTION` is the German text; then `ns.Mode.Toggle()` runs without a Lua error
  and the last chat line holds the German text of "You have not learned Fishing." (the stubs know no Fishing
  spell, so `Action.Enable` stops there exactly as on an English client; FR-010, SC-005).
- [X] T015 [P] [US1] In `tools/check.mjs`, report any `SetFont(` call with a string font path in addon Lua
  files ("set fonts through the game's font objects", research R6); in `CLAUDE.md` add that rule to the
  `npm run check` list.

### Implementation for User Story 1

- [X] T016 [US1] Create `OneKeyFishing/Locales/ukUA.lua` ("Українська"): complete Ukrainian translation of
  every key in `Locales/enUS.lua`, following [contracts/translation-file.md](contracts/translation-file.md)
  (two-line form for long entries, 120-character lines, same placeholders, no color codes, Ukrainian
  community terms for ranks and places). The author reviews it.
- [X] T017 [P] [US1] Create `OneKeyFishing/Locales/deDE.lua` ("Deutsch"), same rules, German client terms.
- [X] T018 [P] [US1] Create `OneKeyFishing/Locales/esES.lua` ("Español (EU)"), same rules, European Spanish
  client terms.
- [X] T019 [P] [US1] Create `OneKeyFishing/Locales/esMX.lua` ("Español (AL)"), same rules, Latin American
  Spanish client terms.
- [X] T020 [P] [US1] Create `OneKeyFishing/Locales/frFR.lua` ("Français"), same rules, French client terms.
- [X] T021 [P] [US1] Create `OneKeyFishing/Locales/koKR.lua` ("한국어"), same rules, Korean client terms.
- [X] T022 [P] [US1] Create `OneKeyFishing/Locales/ptBR.lua` ("Português"), same rules, Brazilian Portuguese
  client terms.
- [X] T023 [P] [US1] Create `OneKeyFishing/Locales/zhTW.lua` ("繁體中文"), same rules, Traditional Chinese
  client terms.
- [X] T024 [P] [US1] Create `OneKeyFishing/Locales/zhCN.lua` ("简体中文"), same rules, Simplified Chinese
  client terms.
- [X] T025 [US1] In `OneKeyFishing/OneKeyFishing.toc`, list the nine files after `Locales\enUS.lua` and before
  `Core.lua`, in `LANGUAGE_ORDER` order.
- [X] T026 [US1] In `OneKeyFishing/Core.lua`, make `ns.CreateButton` widen the button to
  `fontString:GetStringWidth() + 24` when that is larger than the given width (guard a nil width in tests).
- [X] T027 [US1] Make room for longer translations (SC-006): in `OneKeyFishing/UI/Settings.lua` give checkbox
  labels a width that stays inside their column (`COLUMN_OFFSET - 40`) with word wrap, let the hint lines wrap
  at the page width, and on the gear page truncate each row's item text at the row width (buttons widen
  through `ns.CreateButton`, T026); in
  `OneKeyFishing/UI/StatsFrame.lua` give the row labels and section titles a width that ends before the first
  value column (`COLUMN_X[1]`) with word wrap off and the text truncated, so the full label stays readable in
  the row tooltip.
- [X] T028 [US1] Run `npm run check` and `npm test`; T013 and T014 pass.

**Checkpoint**: US1 works on its own: clients in the nine languages see their translation; others see English.

---

## Phase 4: User Story 2 - Pick another language in the options (Priority: P2)

**Goal**: a language setting ("Game client language" or any language by native name) with the FR-013 tooltip
and a "Reload now / Later" popup; the choice is account-wide.

**Independent Test**: pick a language in the settings, accept the popup: the interface reloads in that
language and stays so on another character; "Game client language" returns to US1 behaviour.

### Tests for User Story 2

- [X] T029 [US2] Extend `tests/locale_test.lua`: `ns.SettingsUI.ChooseLanguage("ukUA")` stores
  `ns.db.settings.language == "ukUA"` and shows a popup; `accept_popup()` makes `reload_count == 1`;
  choosing `"auto"` stores `"auto"`; choosing the value already stored shows no popup (`reset_popup()` first,
  then `last_popup` stays nil); `ns.language` does not
  change before a reload; after `ChooseLanguage("deDE")`, `cancel_popup()` ("Later") leaves `reload_count`
  unchanged and the stored preference `"deDE"`; `SettingsUI.LanguageLabel("gone")` (a code that is not
  registered) returns the "Game client language" text, `LanguageLabel("auto")` the same, and
  `LanguageLabel("enUS")` returns `"English"`; `/okf debug` report text (captured by replacing
  `ns.ShowCopyWindow` with a function that stores its `text` argument, then calling `ns.ShowReport()`)
  contains the preference, the effective language and the client locale.

### Implementation for User Story 2

- [X] T030 [US2] In `OneKeyFishing/UI/Settings.lua`, add `SettingsUI.ChooseLanguage(value)`: if `value`
  differs from `ns.db.settings.language`, store it (`"auto"` or a registered code) and show
  `StaticPopupDialogs.ONEKEYFISHING_RELOAD_LANGUAGE` (text: "The language changes after reloading the
  interface.", button1 "Reload now" -> `ReloadUI()`, button2 "Later", `timeout = 0`, `whileDead = true`,
  `hideOnEscape = true`); add `ReloadUI` to `.luacheckrc` `read_globals`. Never reload without the click
  (Principle I).
- [X] T031 [US2] In `OneKeyFishing/UI/Settings.lua` `CreateMainPage`, right of the title and version: a
  "Language:" label and a button showing `SettingsUI.LanguageLabel(ns.db.settings.language)`: the native name
  of a registered language, else ("auto" or a code no longer shipped) the translated "Game client language".
  Click: `MenuUtil.CreateContextMenu` with `root:CreateRadio(text, isSelected, ChooseLanguage, value)` for
  "Game client language" then every `ns.GetLanguages()` entry; if `root.CreateRadio` is missing use
  `root:CreateButton` with a check mark on the current entry; without `MenuUtil` a click cycles through the
  values. Hover: `GameTooltip` with the FR-013 warning ("Korean and Chinese may show as squares on a game
  client in another language." / "Pick English to get a readable interface back."). Refresh the button text
  in the page's `OnShow`.
- [X] T032 [US2] In `OneKeyFishing/Debug.lua`, add three report lines (English, not localized): language
  preference, effective language (`ns.language`) and client locale (`GetLocale()`).
- [X] T033 [US2] Add the new texts of T030-T031 to `OneKeyFishing/Locales/enUS.lua` and translate them in all
  nine files `OneKeyFishing/Locales/{ukUA,deDE,esES,esMX,frFR,koKR,ptBR,zhTW,zhCN}.lua` (completeness test).
- [X] T034 [US2] Run `npm run check` and `npm test`; T029 passes.

**Checkpoint**: both stories work; Ukrainian is reachable through the setting.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T035 [P] Update `docs/languages.md`: all ten languages "Done"; "Choosing the language" matches the menu,
  tooltip and reload popup; "Translation files" shows the `ns.AddTranslation` format and links
  `specs/001-interface-language/contracts/translation-file.md` rules (completeness and placeholder tests).
- [X] T036 [P] Update `README.md`: replace "The addon's own interface is in English for now" with the
  languages and how to pick one (Settings -> OneKeyFishing -> Language), plus the Korean/Chinese font note.
- [X] T037 [P] Add a `## [Unreleased]` section with an "Added" entry for interface languages and the language
  setting at the top of `CHANGELOG.md`.
- [X] T038 [P] Update `CLAUDE.md`: Architecture gets `Localization.lua` (loaded first: `ns.L`, registry,
  resolution in `ADDON_LOADED`); the Locales bullet describes `ns.AddTranslation` files and the rule "no
  `L[...]` lookup at file load, guarded by `tests/locale_test.lua`"; the Messages/commands notes mention
  descriptions as functions.
- [X] T039 [P] Update `docs/ROADMAP.md` section 3 (Localization): done in this feature; keep only future
  volunteer corrections.
- [X] T040 Run `npm run check`, `npm test` and `npm run dev`; confirm `dist/OneKeyFishing/` contains the ten
  locale files and `Localization.lua`.
- [X] T041 Hand the in-game checklist `docs/checklists/interface-language.md` to the author (including the font
  `/run` line); record the font results in [research.md](research.md) R6 and any API finding in
  `docs/forever-api.md`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: after Setup; blocks both stories.
- **US1 (Phase 3)**: after Foundational.
- **US2 (Phase 4)**: after Foundational; T033 also needs the nine translation files of US1 (T016-T024).
- **Polish (Phase 5)**: after both stories.
- **Convergence (Phase 6, User Story 3)**: after Phase 5; its order is in "Phase 6 execution order" below.

### Within phases

- T002-T003 (tests) before T004-T011; T004 before T005-T008; T009-T011 after T004.
- T013-T015 before T016-T027; T016 (Ukrainian, author review) first, then T017-T024 in parallel; T025 after
  the files exist.
- T029 before T030-T033.

### Parallel Opportunities

- T009, T010, T011 (different files).
- T013, T014, T015 (different files).
- T017-T024: the eight translations are independent files.
- T035-T039: documentation files.

---

## Parallel Example: User Story 1

```text
Task: "Create OneKeyFishing/Locales/deDE.lua (Deutsch)"
Task: "Create OneKeyFishing/Locales/esES.lua (Español (EU))"
Task: "Create OneKeyFishing/Locales/esMX.lua (Español (AL))"
Task: "Create OneKeyFishing/Locales/frFR.lua (Français)"
Task: "Create OneKeyFishing/Locales/koKR.lua (한국어)"
Task: "Create OneKeyFishing/Locales/ptBR.lua (Português)"
Task: "Create OneKeyFishing/Locales/zhTW.lua (繁體中文)"
Task: "Create OneKeyFishing/Locales/zhCN.lua (简体中文)"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 and Phase 2: the engine, English unchanged, guard test green.
2. Phase 3: Ukrainian file first (reviewed by the author), then the eight others.
3. Stop and validate: a German client test and the in-game check on a client with a translation.

### Incremental Delivery

1. Setup + Foundational: nothing visible changes (safe to commit).
2. US1: translations follow the client language.
3. US2: the setting, Ukrainian reachable, reload popup.
4. Polish: docs, changelog, in-game checklist.

---

## Notes

- Commit after each phase on `001-interface-language`; merge into `develop`, never into `main`.
- Translation files are the only Lua files allowed to contain non-ASCII text; everything else stays ASCII.
- Claude cannot run the game: T041 hands the in-game checks to the author.

---

## Phase 6: Convergence

- [X] T042 CRITICAL: amend `.specify/memory/constitution.md` Technical Constraints (through `/speckit-constitution`, PATCH) so the ASCII rule also excepts the translated TOC lines `## Notes-<code>` and `## Category-<code>`, which `OneKeyFishing/OneKeyFishing.toc`, `tools/check.mjs` and `CLAUDE.md` already allow per Constitution Technical Constraints (contradicts)
- [X] T043 In `tests/wow.lua`, add configurable stubs for User Story 3: `C_Map.GetAreaInfo`, `GetMapInfo`, `CanSetUserWaypointOnMap`, `SetUserWaypoint`, `HasUserWaypoint`, `GetUserWaypoint`, `ClearUserWaypoint`, `UiMapPoint.CreateFromCoordinates`, `C_SuperTrack.SetSuperTrackedUserWaypoint`, `C_GameRules.IsGameRuleActive` with `Enum.GameRule.WorldMapTrackingPinDisabled`, `OpenWorldMap`, `C_Item.GetItemNameByID` / `RequestLoadItemDataByID`, `C_QuestLog.GetTitleForQuestID` / `RequestLoadQuestByID`, `C_Spell.GetSpellSubtext`, `C_TooltipInfo.GetHyperlink`, `UnitLevel`, a settable Fishing rank / max rank through `GetProfessions` / `GetProfessionInfo`, and a recorded `RaidNotice_AddMessage` per plan: Testing (missing)
- [X] T044 Create `tests/skill_test.lua` (fails before T047-T048): quiet notice at skill 50 / 125 with level 10 / 20 (FR-018); no notice below the level, notice after `PLAYER_LEVEL_UP` (FR-019); at the cap a raid-warning message the first time, a chat line only on the next `MODE_CHANGED` on, and at 225 only the cap notice (FR-020); `Skill.GetNextRank()` nil at 300 (FR-021); no notices with `skillCapWarning` off (FR-023); names from the game, then `ns.NpcNames` for `GetLocale()`, then English, and a rank name from the spell subtext or `L` (FR-015, FR-016); the where sentence per source kind (FR-017) per US3/AC1-AC5, AC7, AC8 (missing)
- [X] T045 Create `tests/mappin_test.lua` (fails before T049): `MapPin.Target(maps, x, y)` returns the first candidate the client knows and allows pins on, nil without the waypoint API, under the game rule and when no candidate is allowed; `MapPin.Set` sets the waypoint, turns on super tracking and saves `charDB.pin`; a pin of the player's own shows the replace popup first, the addon's own pin (same map, within 0.0005) is replaced without it per FR-022, US3/AC6 (missing)
- [X] T046 In `tools/check.mjs`, allow non-ASCII characters only inside string literals of `OneKeyFishing/GameData/*.lua` (code, keys and comments stay ASCII) and update the rule comment per Constitution 1.3.0 Technical Constraints and plan: Source Code (missing)
- [X] T047 Create `OneKeyFishing/GameData/FishingRanks.lua` (data only, no `L`) per data-model.md "Rank steps": `ns.FishingRanks[75|150|225]` with `next`, `learnAt`, `level`, `source` (trainer; book 16083 / NPC 2626 / areas 35, 33 / maps 1434, 224 / 0.274, 0.770; quest 6607 / NPC 12919 / areas 517, 15 / maps 1445, 70 / 0.586, 0.602) and English `fallback` names; `ns.FishingRankSpells`; `ns.NpcNames[2626|12919]` for enUS, deDE, esES, esMX, frFR, itIT, ptBR, ruRU, koKR, zhCN, zhTW from Wowhead's localized pages (only names that are found); a `-- VERIFY(R11)` marker on every value checked in game; list it in `OneKeyFishing/OneKeyFishing.toc` after `Data.lua` per FR-024, research R11, R15 (missing)
- [X] T048 Rewrite the advice in `OneKeyFishing/Skill.lua`: remove `WARN_BEFORE`, `RankNames`, `NextRanks`; `Skill.GetRankName(maxRank)` from `C_Spell.GetSpellSubtext` with the `L` rank names as fallback; `Skill.GetNextRank()` per data-model.md "Next-rank advice" (state, level, where sentence, pin target through `ns.MapPin.Target`, name sources); names by ID (`C_Map.GetAreaInfo`, `C_Item.GetItemNameByID`, `C_QuestLog.GetTitleForQuestID`), requested at login and refreshed on `ITEM_DATA_LOAD_RESULT`, `QUEST_DATA_LOAD_RESULT`, `SPELL_DATA_LOAD_RESULT`; NPC names from `C_TooltipInfo.GetHyperlink` line 1, then `ns.NpcNames`, then English; notices per FR-018 - FR-020 on `SKILL_LINES_CHANGED`, `CHAT_MSG_SKILL`, `PLAYER_LEVEL_UP`, login and `MODE_CHANGED`, with the `worldmap:` map link in the chat line when a pin target exists (research R14); guard every uncertain API per FR-015 - FR-020, Constitution IV (missing)
- [X] T049 Create `OneKeyFishing/UI/MapPin.lua` from the `002-shared-db` code (`Catalog.PinTarget`, `CatalogTab.Pin`, `IsOwnPin`): `MapPin.Target(maps, x, y)` with the game-rule check, `MapPin.Set(target, placeName)` with `SetUserWaypoint`, `SetSuperTrackedUserWaypoint(true)`, `OpenWorldMap` out of combat, toast `L["Map pin: %s"]` and the `ONEKEYFISHING_REPLACE_PIN` popup (`L["Replace your map pin with this place?"]`, `L["Replace"]`); `charDB.pin` defaults to nil, so no `CHAR_DB_DEFAULTS` entry (data-model.md "Map pin"); list the file in the TOC before `UI\StatsFrame.lua`; add the new globals to `.luacheckrc` per FR-022, research R14 (missing)
- [X] T050 In `OneKeyFishing/UI/StatsFrame.lua`, add the "Next rank" line under the skill line (rank, where sentence, level needed) and a pin button (`ns.CreateButton`, shown only with a pin target) that calls `ns.MapPin.Set`; mark the window dirty on the name-load events and `PLAYER_LEVEL_UP` per FR-021, FR-022, US3/AC6, AC7 (missing)
- [X] T051 In `OneKeyFishing/UI/Minimap.lua`, add the next-rank advice to the tooltip and a menu entry "Pin: next Fishing rank" (only with a pin target) per FR-021, FR-022 (missing)
- [X] T052 In `OneKeyFishing/UI/Settings.lua`, rename the `skillCapWarning` toggle to "Remind me about the next Fishing rank" (saved key unchanged) per FR-023 (partial)
- [X] T053 In `OneKeyFishing/Debug.lua`, add English report lines: next-rank state and level, the source of each name (game / table / english) and the pin target or why there is none per FR-025 (missing)
- [X] T054 In `OneKeyFishing/Locales/enUS.lua`, add the state sentences, the trainer / book / quest sentences, the "Next rank" line texts, the level text, the pin texts and the new setting label; remove `a fishing trainer`, the book and quest phrases, `Fishing skill capped (%d/%d): learn %s Fishing from %s.`, `Fishing %d/%d: %d point(s) left in this rank. Next: %s Fishing from %s.` and the old setting label; translate every new text in the nine `Locales/<code>.lua` files (keep the author's uncommitted review changes in `ukUA.lua`; the author reviews the Ukrainian texts) per FR-017, FR-011, research R13 (partial)
- [X] T055 Update the docs per plan: Phase 12: a "Next rank" section in `docs/checklists/interface-language.md` (the steps of quickstart.md "User Story 3") and section 8 of `docs/checklists/fishing-mode.md`; the rank reminder in `OneKeyFishing/README.md`; `CHANGELOG.md` `[Unreleased]` Added/Changed lines; `CLAUDE.md` (`GameData/` and its rule, `UI/MapPin.lua`, `charDB.pin`, the `Skill.lua` description, the `npm run check` exception); `docs/release-plan.md` 1.2.0 (move lures, containers, pole bonuses, spell and bobber IDs to `GameData/`; the catalog uses `ns.MapPin`); `docs/ROADMAP.md` (pin on the nearest fishing trainer) (missing)
- [X] T056 Add functional requirements to `specs/001-interface-language/spec.md` for the work already in the code but not in the spec: the one-time language hint on clients without a translation (`ns.NeedsLanguageHint`, `settings.languageHintShown`), the translated TOC `Notes-<code>` / `Category-<code>` lines, and the client decimal separator (`ns.FormatDecimal`); update research.md R10, which still calls localized TOC fields out of scope per spec: Requirements (unrequested)
- [ ] T057 Run `npm run check` and `npm test` (T044, T045 pass) and hand the "User Story 3" steps of quickstart.md to the author; record the in-game results (IDs, map IDs, coordinates, subtext, tooltip names, map link) in research.md R11/R12 and `CLAUDE.md` "Known API facts" per plan: Phase 13, Constitution IV (missing)

### Phase 6 execution order

Added after `/speckit-analyze` (findings O1, O2, I2, D1, W1); the tasks above keep their IDs.

1. T042 (done), then T043, T044, T045, T046: stubs, failing tests, the check rule.
2. T047: the data file.
3. T049 before T048: `Skill.lua` calls `ns.MapPin.Target`, so the module comes first (calls stay at runtime,
   Constitution VI).
4. T048 (the chat map link is the game's standard `worldmap:` link, set by the game without the addon's
   confirmation; T044 only checks that the link is built for a pin target, FR-022), then T050, T051, T052,
   T053. **Texts go with the code**: every task that adds an `L["..."]` adds the
   English key to `Locales/enUS.lua` and its nine translations in the same task, and removes the keys it
   retires; T054 is then the final pass (author review of the Ukrainian texts, nothing missing; its wording
   above predates this order), so
   `npm run check` and `npm test` stay green after every task.
5. T055 docs, T056 spec backfill.
6. T057 together with T041: one in-game run of the checklist (both stories).

**Commits**: T048-T055 go into one commit, so the player-visible change carries its `CHANGELOG.md` and
`OneKeyFishing/README.md` lines (Development Workflow); T042-T047 and T056 may be committed before it.
