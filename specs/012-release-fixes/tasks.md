---

description: "Task list for spec 012, release fixes for 1.2.0"
---

# Tasks: Release Fixes for 1.2.0

**Input**: Design documents from `specs/012-release-fixes/`

**Prerequisites**:
- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/module-api.md](contracts/module-api.md), [quickstart.md](quickstart.md)

**Tests**: required. Spec FR-014 and constitution Principle V ask for a test that fails without its fix. Each test
is written first, and its failure is seen before the fix.

**Organization**: grouped by the user stories of spec.md (US1 to US5). Work on `002-shared-db`; commit only when the
author asks.

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it; a test written before its fix is the only allowed red.
- Addon Lua: ASCII outside `Locales/`, 120-character lines, Lua 5.1/5.3 neutral.
- No Cyrillic in Markdown.
- Write files with LF line endings (`.gitattributes` `eol=lf`). In Python, open with `newline=''` or write bytes.
- No new file in the addon and no TOC change, so a `/reload` is enough in game.
- A new visible text: a literal English key in `Locales/enUS.lua` and its translation in each of the nine other
  locale files in the same task.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US5)

---

## Phase 1: Setup

- [X] T001 Run `npm run check` and `npm test` from the repository root. Note the marker count (20) and the test count
  (753) for the hand-over.

---

## Phase 2: Foundational (test stubs)

**Purpose**: stubs the stories' tests need; no addon change.

- [X] T002 In `tests/wow.lua`, make `strsplit` raise "attempt to perform string conversion on a secret string value"
  when its text is in `secret_values` (the game's behaviour, `docs/forever-api.md` 2026-11-11); document it in the
  header list of stubs.
- [X] T003 In `tests/wow.lua`, give `UnitGUID` a settable soft target: `soft_target_guid` (default nil) returned for
  `UnitGUID("softinteract")`, nil for other units as today; document it in the header list. Check that no existing
  test sets `UnitGUID` in a way this breaks (`grep -rn UnitGUID tests`).
- [X] T004 In `tests/wow.lua`, record `GameTooltip:ClearLines` (`tooltip_cleared = true`, reset by `SetOwner`) in the
  shared tooltip stub; document it.

**Checkpoint**: `npm test` still passes (753).

---

## Phase 3: User Story 1 - Fishing in a dungeon without an error (Priority: P1) 🎯 MVP

**Goal**: a secret soft-target identity or loot source raises no error, and the indicator shows "Hook!" instead of
"No bobber" when it cannot tell (contract S1, G1, G2, B1, B2, I1, I2, L1).

**Independent Test**: `tests/ui/indicator_secret_test.lua` and the extended `tests/fishing/fished_loot_test.lua`.

### Tests (write first, see them fail)

- [X] T005 [P] [US1] New `tests/ui/indicator_secret_test.lua`: in fishing mode, channeling Fishing, with
  `soft_target_guid` set to a GUID string listed in `secret_values`: `Indicator.Update` raises no error and the label
  is "Hook!" (not "No bobber") also after the grace time (`advance(10)`: `BOBBER_GRACE_MS` is local to
  `UI/Indicator.lua` and shorter); `ns.IsSecret` true for that
  value and false for nil and plain strings; `ns.GameObjectID` of it is nil; with a readable GUID of another object
  ("GameObject-0-1-2-3-12345-0") the label is "No bobber" after the grace time (I2); with the bobber's GUID
  (`ns.GameData.Bobber.objectID`) it is "Hook!". Header comment: what it proves, spec 012 US1.
- [X] T006 [P] [US1] Extend `tests/fishing/fished_loot_test.lua`: open a fished container (the existing attempt
  flow), then a loot window whose `loot_sources[1]` is a GUID in `secret_values`: no error, and the loot counts as the
  container's by the timing fallback (the attempt is marked looted), as with no source GUIDs.

### Implementation

- [X] T007 [US1] In `OneKeyFishing/Core/Data.lua`, add `ns.IsSecret(value)` (`issecretvalue and issecretvalue(value)`,
  always a boolean) with a comment; make `ns.GameObjectID` return nil for a secret value before `strsplit`; make
  `ns.IsBobberTargeted()` return `targeted, known` per data-model.md "Bobber answer" (secret: `false, false`; else
  `targeted, true`). Update its comment.
- [X] T008 [US1] In `OneKeyFishing/UI/Indicator.lua` `ShowNoBobber`, read both values of `ns.IsBobberTargeted()` at
  each of the two calls; when `known` is false return false at once (no warning, `bobberSeenCast` and the grace timer
  untouched). Comment why (spec 012 R1).
- [X] T009 [US1] In `OneKeyFishing/Fishing/Bags.lua` `IsFromLastOpen`, skip a loot source for which `ns.IsSecret` is
  true: it neither matches `lastOpen.guid` nor sets `knownSource`. Comment why.
- [X] T010 [US1] Run T005 and T006: both pass; `grep -rn "IsBobberTargeted\|GameObjectID\|GetLootSourceInfo"
  OneKeyFishing` shows no other caller left unguarded.

**Checkpoint**: US1 passes alone; `npm run check` and `npm test` green.

---

## Phase 4: User Story 2 - Status texts that match the data (Priority: P2)

**Goal**: the bundled-data hint and the one-player status line (contract O1, O2, H1-H3, T1, T2).

**Independent Test**: the extended `tests/ui/here_page_test.lua` and `tests/exchange/share/game_test.lua`.

### Tests (write first, see them fail)

- [X] T011 [P] [US2] Extend `tests/ui/here_page_test.lua`: with no seed and source "All": without another player's
  record the hint holds "No bundled data in this version: only your own catches are shown."; after adding a record
  under another player's key to `ns.db.shared.records` (and `SHARED_DATA_CHANGED`) it holds "No bundled data in this
  version." and not the long line; with sharing off (`Share.SetEnabled(false)`) the long line comes back. Use the
  existing helpers of the file for records.
- [X] T012 [P] [US2] Extend `tests/exchange/share/game_test.lua`: the status line for one exchanged player is
  `L["Exchange: 1 player, %s ago"]` formatted; for two players the plural key, as the existing test at line ~167 does.

### Implementation

- [X] T013 [US2] (Replaced by the code review of 2026-11-12: no `CatchDB.HasOthers()`; `BuildView` in
  `OneKeyFishing/CatchDB/Views.lua` sets the view's `others`, research R2.)
- [X] T014 [US2] In `OneKeyFishing/UI/CatchHere.lua` (the hints, line ~276), choose
  `L["No bundled data in this version."]` when `view.others`, else the existing long line.
- [X] T015 [US2] In `OneKeyFishing/Exchange/ShareGame.lua` `StatusLine` (line ~321), use
  `L["Exchange: 1 player, %s ago"]` when `status.exchanged == 1`, else the plural key.
- [X] T016 [US2] Add the keys `"No bundled data in this version."` and `"Exchange: 1 player, %s ago"` to
  `OneKeyFishing/Locales/enUS.lua` next to their long / plural forms, and their translations to `deDE.lua`,
  `esES.lua`, `esMX.lua`, `frFR.lua`, `koKR.lua`, `ptBR.lua`, `ukUA.lua`, `zhCN.lua`, `zhTW.lua`, written like the
  neighbouring keys of each file (the singular form of each language; Korean and Chinese the same shape with 1).
- [X] T017 [US2] Run T011 and T012: both pass; `npm run check` (the locale completeness check) green.

**Checkpoint**: US2 passes alone.

---

## Phase 5: User Story 3 - A refused lure comes back after a skill-up (Priority: P3)

**Goal**: contract L2, L3; data-model.md "Skipped lure".

**Independent Test**: the extended `tests/fishing/lure_skill_test.lua`.

### Tests (write first, see them fail)

- [X] T018 [US3] Extend `tests/fishing/lure_skill_test.lua` (it sets the skill through `fishing_rank`): at
  `fishing_rank = 50` with Nightcrawlers (6530, needs 50) in the bags, make the game refuse it the way
  `tests/fishing/lures_test.lua` does (`Bags.NoteLureAttempt(6530)`, no weapon enchant, advance past the fail delay,
  then `Bags.FindLure()`): 6530 is skipped (not offered). Raise `fishing_rank` to 51 and fire it: still skipped (a
  refusal at the requirement is not retried). Refused while the skill is unknown, it stays skipped at 49 and comes
  back at 50 with `LURE_READY`. A mode re-entry clears every skipped lure (L3, as today). (Corrected by the code
  review of 2026-11-12.)

### Implementation

- [X] T019 [US3] In `OneKeyFishing/Fishing/Bags.lua`: `CheckLastLure` stores `skippedLures[itemID] = ns.Skill.Get() or
  0` instead of `true`; a `SKILL_LINES_CHANGED` handler (only when `next(skippedLures)`) reads the skill once and
  clears each entry whose stored skill does not meet the requirement and the current one does (`SkillAllows`), then
  fires `LURE_READY` if any was cleared. Keep `Bags.DescribeLures` showing `skipped: true/false` (`~= nil`). Comment
  the rule (spec 012 R4).
- [X] T020 [US3] Run T018: passes.

**Checkpoint**: US3 passes alone.

---

## Phase 6: User Story 4 - The minimap tooltip keeps its colours (Priority: P3)

**Goal**: contract M1, M2.

**Independent Test**: the extended `tests/ui/minimap_tooltip_test.lua`.

### Tests (write first, see them fail)

- [X] T021 [US4] Extend `tests/ui/minimap_tooltip_test.lua` (it replaces `GameTooltip` with its own recorder): record
  `ClearLines` and the colour arguments; hovering the button: `ClearLines` came after `SetOwner` and before the first
  line; every line given a colour starts with `|cff` and the hex of that colour (the help lines `cccccc`, the click
  lines `00ff00`, the next-rank line `ffd100`) and ends with `|r`; both sides of the key lines too; the tall-glyph
  blank line of Korean still comes last. The same holds for the addon compartment entry's tooltip (spec US4
  scenario 3: call `OneKeyFishing_OnAddonCompartmentEnter(nil, nil)`).

### Implementation

- [X] T022 [US4] In `OneKeyFishing/UI/Minimap.lua` `ShowTooltip`: call `GameTooltip:ClearLines()` right after
  `SetOwner`; add a local `Colored(text, r, g, b)` giving `"|cff" .. hex .. text .. "|r"`, and wrap every coloured
  `AddLine` / `AddDoubleLine` text with it while keeping the colour arguments; keep the wrap flag of the next-rank
  line. Colour codes stay outside the `L[...]` strings (CLAUDE.md). Comment why (spec 012 R5).
- [X] T023 [US4] Run T021 and the other tooltip tests (`tests/ui/tooltips_test.lua`, `keys_test.lua`): pass.

**Checkpoint**: US4 passes alone.

---

## Phase 7: User Story 5 - The private-table check sees every form (Priority: P3)

**Goal**: contract P1-P3.

**Independent Test**: the extended `tests/tools/private_check_test.mjs`.

### Tests (write first, see them fail)

- [X] T024 [P] [US5] Extend `tests/tools/private_check_test.mjs`: from folder "UI", report `local C = ns.CatchDB\nlocal
  x = C.private`, `local x = ns["CatchDB"].private`, and `local s = "a -- b" local x = CatchDB.private` (one problem
  each, with the line number); from folder "CatchDB" none of them; a file with a syntax error gives `[]`; the existing
  cases keep passing.

### Implementation

- [X] T025 [US5] In `tools/addon.mjs`, rewrite `privateProblems(text, folder, folderOf)` over
  `luaparse.parse(text, { luaVersion: "5.1", scope: true, locations: true })` (import luaparse): walk every node; map
  locals bound to `ns.X`, `ns["X"]` or `X` (a module name `folderOf` knows) to X; report a `MemberExpression` with
  identifier `private` whose base resolves to a module of another folder, at its start line. A string's name comes
  from its `raw` (no encoding mode). Return `[]` when the parse throws. Keep the message text.
- [X] T026 [US5] Run T024 and `npm run check` over the whole addon: no new problem on today's files.

**Checkpoint**: US5 passes alone.

---

## Phase 8: Polish and documents

- [X] T027 [P] `CHANGELOG.md` `[Unreleased]` "Fixed": the error window while fishing in a dungeon (also in 1.1.0);
  the minimap tooltip losing its colours (also in 1.1.0). Check the manual `OneKeyFishing/README.md` by grep for the
  two changed texts; change it only if it quotes them.
- [X] T028 [P] `docs/forever-api.md` (the dungeon line of 2026-11-11) and the `CLAUDE.md` Forever API bullet: the
  addon treats a secret soft-target GUID as "unknown" (`ns.IsSecret`).
- [X] T029 [P] Architecture pages: `docs/architecture/core.md` (`ns.IsSecret`, the bobber answer),
  `docs/architecture/fishing-mode.md` (skipped lures by skill), `docs/architecture/ui.md` (the indicator's unknown
  state, the tooltip colours), `docs/architecture/exchange.md` (the one-player status line), `docs/development.md`
  (what the private check finds).
- [X] T030 `docs/tech-debt.md`: remove the five open items and the batches 5, 7, 8, 9 and 10; the "Fix batches"
  section says no batch is open and names spec 012 with the earlier specs; add a history line for 2026-11-11.
- [X] T031 [P] `docs/release-plan.md` step 3: batches 9 and 10 fixed by spec 012, the dungeon re-check pending;
  `docs/checklists/fishing-mode.md` (a dungeon step: fishing there gives no error, citing batch 10) and
  `docs/checklists/catch-exchange.md` step 4 (the "1 player" text).
- [X] T032 Update the 1.2.0 test page (https://claude.ai/artifact/8bqDcm6BKLMFQgkMgySQpy): a phase "After spec 012"
  with the in-game steps of quickstart.md (dungeon, open-world warning, status texts, minimap colours over a
  session), through the `steps` collection and the page's step list (FR-016).
- [X] T033 Final run: `npm run check` and `npm test`; every new test fails with its fix reverted (revert each fix
  once, run, restore). Report the marker count (unchanged, 20) and the test count.

---

## Dependencies and execution order

- Phase 1, then Phase 2 (stubs) before any story.
- US1 needs T002-T003; US4 needs T004; US2, US3 and US5 need only Phase 1.
- The stories touch different files except `Fishing/Bags.lua` (US1 T009 and US3 T019): do US1 first.
- Phase 8 after the stories it documents; T033 last.

## Parallel examples

- After Phase 2: T005 and T006 (US1 tests), T011 and T012 (US2 tests), T024 (US5 test) in parallel.
- Documents T027, T028, T029, T031 in parallel once the code is done.

## Implementation strategy

- **MVP**: US1 (the dungeon error, high, also in 1.1.0). It can ship alone if the rest waits.
- Then US2 (the texts players read), then US3, US4, US5 in any order.
- One commit for the whole spec when the author asks, as for specs 009-011.
