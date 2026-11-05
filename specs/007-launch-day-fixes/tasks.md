---

description: "Task list for the launch day fixes"
---

# Tasks: Launch Day Fixes

**Input**: Design documents from `specs/007-launch-day-fixes/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/ui.md](contracts/ui.md), [quickstart.md](quickstart.md)

**Tests**: requested by the spec (FR-006, FR-017): every fix with logic gets a test written first that fails on the
current code (commit `72c3c44`), then the fix makes it pass.

**Organization**: one phase per user story, in priority order. All work is on the branch `001-interface-language`.
Run `npm run check` and `npm test` after every task.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of `spec.md` (US1 to US6)
- Paths are relative to the repository root; addon files are under `OneKeyFishing/`

---

## Phase 1: Setup (test stubs)

**Purpose**: the stubs the new tests need. Changes to `tests/wow.lua` only; nothing in the addon.

- [X] T001 In `tests/wow.lua`, add controllable bindings: a global table `bindings = {}` (binding name -> list of
  key names, e.g. `bindings.ONEKEYFISHING_ACTION = { "`", "'" }`), `GetBindingKey(name)` returning
  `unpack(bindings[name] or {})`, and `GetBindingText(key, abbreviated)` returning the key unchanged (with
  `"SHIFT-"` written as `"Shift-"` so a test can see it was converted). Reset `bindings` wherever the stub resets
  other game state between tests, if such a reset exists.
- [X] T002 In `tests/wow.lua`, make `Frame:SetWidth(w)` remember the width and `Frame:GetWidth()` return it
  (default 100 as today); keep `GetHeight` working (`SetHeight` / `GetHeight` the same way, default 100).
- [X] T003 In `tests/wow.lua`, make the `Settings` stub keep what is registered:
  `RegisterCanvasLayoutCategory(frame, name)` stores `settings_pages[name] = frame` and
  `RegisterCanvasLayoutSubcategory(category, frame, name)` stores `settings_pages[name] = frame`
  (`settings_pages` a global table), so a test can reach the Fishing gear page.
- [X] T004 Run `npm test`: all 83 existing tests still pass with the changed stubs; fix a stub, not a test, if one
  breaks.

**Checkpoint**: stubs ready; the user story phases can start (they touch different files, see Dependencies).

---

## Phase 2: Foundational

None: each fix lives in its own module; the one shared helper (`ns.KeyText`) belongs to US4 only.

---

## Phase 3: User Story 1 - The Fishing gear page works on its first view (Priority: P1) MVP

**Goal**: from its first view, the page shows one row per extra gear item and nothing else; hovering never errors
(spec FR-001 to FR-004, research R1).

**Independent Test**: `tests/settings_gear_test.lua`; in game, quickstart steps 1-2.

- [X] T005 [US1] Write `tests/settings_gear_test.lua` (load the addon, take `settings_pages[L["Fishing gear"]]` or
  the page registered under the gear page name): (a) with `ns.charDB.gear.items` empty, no frame inside the page
  whose text is `"Remove"` is shown (a frame counts as shown when it and every parent up to the page are shown)
  and the "No items yet." text is shown; (b) after adding two item IDs and firing `GEAR_LIST_CHANGED`, exactly two
  Remove buttons are shown; (c) calling the `OnEnter` script of every row, including hidden ones, raises no error
  (stub `GameTooltip:SetItemByID` to error on a nil argument, as the game does). Confirm (a) and (c) fail on the
  current code.
- [X] T006 [US1] In `OneKeyFishing/UI/Settings.lua` `CreateGearRow`, hide the row right after creating it
  (`row:Hide()`), so no row shows before `Refresh` has given it an item.
- [X] T007 [US1] In `OneKeyFishing/UI/Settings.lua` `ShowItemTooltip(owner, itemID)`, return at once when `itemID`
  is nil (no `SetOwner`, no `SetItemByID`).
- [X] T008 [US1] In `OneKeyFishing/UI/Settings.lua` `CreateGearPage`, call `Refresh()` once at the end, after the
  `OnShow` script and the event handlers are set, so the list is right before the first view; keep the `OnShow`
  refresh and the `GEAR_LIST_CHANGED`, `GET_ITEM_INFO_RECEIVED`, `BAG_UPDATE_DELAYED` refreshes. Check that
  `Refresh`'s guard `if not page:IsShown()` does not skip this first call (the page frame is shown when created;
  if not, run the body without the guard for this call).
- [X] T009 [US1] Run `npm test -- settings_gear` and the full `npm test`; all pass.

**Checkpoint**: US1 works on its own (gear page correct on the first view).

---

## Phase 4: User Story 2 - The debug report is complete without a lure (Priority: P1)

**Goal**: every section of `/okf debug` completes when a value is missing (spec FR-005, FR-006, research R2).

**Independent Test**: `tests/debug_test.lua`; in game, quickstart step 3.

- [X] T010 [P] [US2] Write `tests/debug_test.lua`: load the addon with no lure in `bag_items`, no fishing pole, no
  Fishing profession (the stubs' defaults or set explicitly), replace `ns.ShowCopyWindow` in the test with a
  function that keeps its `lines` argument, call `ns.ShowReport()` (it calls `ns.ShowCopyWindow(title,
  BuildReport())`) and assert that no line contains
  `"!! failed"` and that the Gear section contains `"next lure: nil"` and a `"best pole:"` line. Confirm it fails on
  the current code with the `tostring` error.
- [X] T011 [US2] In `OneKeyFishing/Debug.lua`, add `local function Value(...) return tostring((...)) end` (a comment
  says why: a call that returns nothing would make `tostring()` raise in Lua 5.1) and use it for every printed
  function result: `ns.Bags.NeedsLure()`, `ns.Bags.FindLure()`, `ns.IsFishingPole(...)`,
  `ns.GetFishingBonus(...)`, `ns.Mode.IsActive()`, `ns.Mode.IsExiting()`, `ns.Action.IsChanneling()`,
  `InCombatLockdown()`, `C_Spell.GetSpellName(...)`, `C_CVar.GetCVar(...)` and any other `tostring(f(...))` in the
  file. Plain values (`tostring(rank)`, `tostring(ns.db.settings[name])`) may stay as they are.
- [X] T012 [US2] Run `npm test -- debug` and the full `npm test` (the report builder stays local; the test reads
  the report through `ns.ShowCopyWindow`).

**Checkpoint**: US2 works on its own.

---

## Phase 5: User Story 3 - Popups speak the addon's language (Priority: P1)

**Goal**: every addon popup's buttons are in the addon's language (spec FR-007, FR-008, research R3).

**Independent Test**: `tests/popup_test.lua`; in game, quickstart steps 4-5.

- [X] T013 [P] [US3] Write `tests/popup_test.lua`: with `CLIENT_LOCALE = "ruRU"` and the language setting
  `"ukUA"` (as `tests/locale_test.lua` sets a language), open the statistics window, run the Reset session and
  Reset all buttons' click scripts, and assert `StaticPopupDialogs["ONEKEYFISHING_RESET_SESSION"].button1 ==
  L["Yes"]` and `.button2 == L["No"]` with the Ukrainian texts (not the globals `YES` / `NO`; set
  `YES, NO, CANCEL = "client yes", "client no", "client cancel"` in the test so a leak is visible); same for
  `ONEKEYFISHING_RESET_ALL`; and for the map pin replace popup (`UI/MapPin.lua`, see `tests/mappin_test.lua` for
  how a pin is set) `button2 == L["Cancel"]`; and for the language reload popup (`ns.SettingsUI.ChooseLanguage`
  with a language other than the one in use) `StaticPopupDialogs["ONEKEYFISHING_RELOAD_LANGUAGE"].button1 ==
  L["Reload now"]` and `button2 == L["Later"]` (already true; the test keeps it so). Confirm the reset and pin
  assertions fail on the current code.
- [X] T014 [US3] Add `L["Yes"] = true`, `L["No"] = true`, `L["Cancel"] = true` to `OneKeyFishing/Locales/enUS.lua`
  (next to the other short button texts).
- [X] T015 [P] [US3] Add the three translations to each of `OneKeyFishing/Locales/deDE.lua` (Ja, Nein, Abbrechen),
  `esES.lua` and `esMX.lua` (Sí, No, Cancelar), `frFR.lua` (Oui, Non, Annuler), `ukUA.lua` (the standard Ukrainian
  yes / no / cancel words), `koKR.lua` (예, 아니요, 취소), `ptBR.lua` (Sim, Não, Cancelar), `zhTW.lua` (是, 否, 取消),
  `zhCN.lua` (是, 否, 取消), in the same place and style as each file's other button texts.
- [X] T016 [US3] In `OneKeyFishing/Core.lua` `ns.ShowPopup`, default the buttons to `acceptText or L["Yes"]` and
  `cancelText or L["No"]` (looked up when the popup is shown, never at file load); `Core.lua` has `L` from
  `ns.L` (check the file's top; add `local L = ns.L` only if missing).
- [X] T017 [US3] In `OneKeyFishing/UI/MapPin.lua`, pass `L["Cancel"]` instead of `CANCEL` to `ns.ShowPopup`.
- [X] T018 [US3] Run `npm run check` (locale keys in sync, no unused global `YES` / `NO` / `CANCEL` left in
  `.luacheckrc` `read_globals`; remove them there if nothing else uses them) and `npm test` (translation
  completeness and placeholder order); all pass.

**Checkpoint**: US3 works on its own.

---

## Phase 6: User Story 4 - Both bound keys are shown (Priority: P2)

**Goal**: one shared key text names every key of a binding, the same in the minimap tooltip, the settings key line
and the indicator (spec FR-009 to FR-012, research R4, contract `ns.KeyText`).

**Independent Test**: `tests/keys_test.lua`; in game, quickstart steps 6-7.

- [X] T019 [P] [US4] Write `tests/keys_test.lua` against [contracts/ui.md](contracts/ui.md): with `bindings`
  (T001) set to none, one key, two keys, two keys with `SHIFT-`, and the same key twice, assert `ns.KeyText`
  returns the red "not bound" text, `` "`" ``, `` "` / '" ``, `` "Shift-` / Shift-'" `` and `` "`" ``; with
  `unbound = ""` and no key, `""`. It fails now (no `ns.KeyText`).
- [X] T020 [US4] Add `ns.KeyText(binding, short, unbound)` to `OneKeyFishing/Core.lua` as the contract says: keys
  from `{ GetBindingKey(binding) }` in that order, duplicates dropped, each through `GetBindingText(key, short)`,
  joined with `" / "`; no key returns `unbound`, which defaults to `"|cffff5555" .. L["not bound"] .. "|r"` built at
  call time. Comment: the game's order, as in its Keybindings columns, which it may swap on a reload (CLAUDE.md).
- [X] T021 [P] [US4] In `OneKeyFishing/UI/Minimap.lua`, remove the local `KeyText` and call
  `ns.KeyText("ONEKEYFISHING_ACTION")` / `ns.KeyText("ONEKEYFISHING_TOGGLE")` in the tooltip.
- [X] T022 [P] [US4] In `OneKeyFishing/UI/Settings.lua`, remove the local `KeyText` and use `ns.KeyText(...)` for
  the main page key line.
- [X] T023 [P] [US4] In `OneKeyFishing/UI/Indicator.lua`, remove the local `KeyText` and set
  `frame.key:SetText(ns.KeyText("ONEKEYFISHING_ACTION", true, ""))`; give `frame.key` a width of the icon frame
  minus 8 (`SIZE - 8`) and `SetWordWrap(false)`, `SetJustifyH("RIGHT")`, so a long pair is cut, never wider than the
  frame (FR-012).
- [X] T024 [US4] Extend `tests/keys_test.lua`: with two keys bound, build the minimap tooltip (call the tooltip
  function the button's `OnEnter` uses) and assert the fishing key line holds `` "` / '" ``; run `npm test`.

**Checkpoint**: US4 works on its own.

---

## Phase 7: User Story 5 - Statistics buttons wrap like text (Priority: P3)

**Goal**: when Scan does not fit beside the three left buttons, it starts the row below at the left (spec FR-013,
FR-014, research R5, contract `StatsFrame.ButtonRows`).

**Independent Test**: the new cases in `tests/stats_test.lua`; in game, quickstart steps 8-9.

- [X] T025 [P] [US5] Extend `tests/stats_test.lua`: `ns.StatsFrame.ButtonRows(394, 160, 580)` returns `580, false`
  (English widths: one row); `ButtonRows(700, 200, 580)` returns `700, true`; `ButtonRows(560, 160, 580)` returns
  `580, true` (left row fits, Scan does not). It fails now (no function).
- [X] T026 [US5] In `OneKeyFishing/UI/StatsFrame.lua`, add `function StatsFrame.ButtonRows(leftWidth, scanWidth,
  minWidth)` returning `math.max(minWidth, leftWidth)` and whether `leftWidth + 8 + scanWidth` exceeds that width;
  use it in the window build instead of the inline computation.
- [X] T027 [US5] In the same build code, when it wraps: `f:SetHeight(HEIGHT + 28)`, anchor `resetSession` at
  `BOTTOMLEFT 14, 40` (the other two follow it as now) and `f.scan` at `BOTTOMLEFT 14, 12`; when it does not wrap,
  keep today's anchors (`resetSession` at `BOTTOMLEFT 14, 12`, `f.scan` at `BOTTOMRIGHT -14, 12`). Update the
  comment above it (the Scan button wraps to the left of a second row).
- [X] T028 [US5] Run `npm test -- stats` and the full `npm test`.

**Checkpoint**: US5 works on its own.

---

## Phase 8: User Story 6 - Korean and Chinese text stays inside the minimap tooltip (Priority: P3)

**Goal**: in `koKR`, `zhCN` and `zhTW` the minimap tooltip ends with a blank line; nothing changes in the other
languages (spec FR-015, FR-016, research R6).

**Independent Test**: `tests/minimap_tooltip_test.lua`; in game, quickstart step 10.

- [X] T029 [P] [US6] Write `tests/minimap_tooltip_test.lua`: stub `GameTooltip` in the test to record `AddLine` /
  `AddDoubleLine` calls (or use the stub's recording if it has one); for each of the ten languages (set the language
  as `tests/locale_test.lua` does) build the minimap tooltip and assert the last added line is `" "` exactly for
  `koKR`, `zhCN`, `zhTW` and not for the other seven. It fails now for the three CJK languages.
- [X] T030 [US6] In `OneKeyFishing/UI/Minimap.lua` `ShowTooltip`, before `GameTooltip:Show()`, add
  `GameTooltip:AddLine(" ")` when `ns.language` is `koKR`, `zhCN` or `zhTW` (a small local set, with a comment: the
  game measures the lines with the Latin font, the CJK glyphs are taller, research R6).
- [X] T031 [US6] Run `npm test -- minimap` and the full `npm test`.

**Checkpoint**: all six stories done.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [X] T032 [P] `CHANGELOG.md` `[Unreleased]`: add a `### Fixed` section with three lines a 1.0.0 player can see:
  the Fishing gear page no longer shows empty rows or an error on its first view; `/okf debug` is complete without
  a lure; the minimap tooltip and the settings show both keys bound to an action. No line for the popups, the
  statistics buttons or the CJK tooltip (fixes of unreleased 1.1.0 features, spec FR-019).
- [X] T033 [P] `OneKeyFishing/README.md`: in the "Keyboard language" note (about line 37), add one sentence: the
  minimap tooltip and the settings page show both keys of each binding.
- [X] T034 [P] `CLAUDE.md` Architecture, Core.lua entry: add `ns.KeyText(binding, short, unbound)` (every bound
  key, the game's order, joined with " / ") and that `ns.ShowPopup` defaults to `L["Yes"]` / `L["No"]`.
- [X] T035 [P] `docs/checklists/interface-language.md`: add the re-run steps of [quickstart.md](quickstart.md)
  (steps 1, 3, 4, 5, 6, 8, 10) as a section "Launch day fixes (spec 007)" before Results, each with its US id;
  `docs/checklists/fishing-mode.md`: add steps 1-2 (gear page) and 6-7 (both keys) in its Gear and Minimap
  sections. Keep the boxes unticked.
- [X] T036 `npm run check` and `npm test` pass; `npm run dev` packages without error.
- [ ] T037 Hand the in-game re-run to the author: `npm run install-addon`, then [quickstart.md](quickstart.md) steps
  1-10, one at a time; tick the results in the checklists and in the artifact checklist.

---

## Dependencies & Execution Order

- **Phase 1 (T001-T004)** blocks every test task: T005 needs T003; T019 and T024 need T001; T025 and T027 need T002.
- **Stories** are independent of each other once Phase 1 is done. Shared files: `UI/Settings.lua` (US1 T006-T008,
  US4 T022), `Core.lua` (US3 T016, US4 T020), `UI/Minimap.lua` (US4 T021, US6 T030): do those tasks one after the
  other, not in parallel.
- **Within a story**: the test first (it must fail), then the fix, then the test run.
- **Phase 9** after all stories; T037 last.

### Parallel opportunities

- After Phase 1: the first test of each story (T005, T010, T013, T019, T025, T029) can be written in parallel.
- US3: T015 (nine locale files) in parallel with T016 / T017.
- US4: T021, T022, T023 in parallel after T020 (different files), but T022 not in parallel with US1 work on
  `UI/Settings.lua`.
- Phase 9: T032-T035 in parallel.

### Example: User Story 4

```text
T019 write tests/keys_test.lua (fails)
T020 ns.KeyText in Core.lua
then in parallel: T021 UI/Minimap.lua, T022 UI/Settings.lua, T023 UI/Indicator.lua
T024 extend the test, run npm test
```

## Implementation Strategy

1. **MVP**: Phase 1 + US1 (the most visible break, every player meets it) -> `npm test`, then US2 and US3 (the other
   P1 fixes). After these three, 1.1.0 no longer shows an error or a mixed-language popup.
2. **Then** US4 (P2), US5 and US6 (P3); each is a separate, testable increment.
3. **Polish** (Phase 9), then the in-game re-run (T037). Commit only when the author asks.
