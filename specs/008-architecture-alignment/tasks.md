---

description: "Task list for spec 008, architecture alignment"
---

# Tasks: Architecture Alignment

**Input**: Design documents from `specs/008-architecture-alignment/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/interfaces.md](contracts/interfaces.md), [verification.md](verification.md), [quickstart.md](quickstart.md)

**Tests**: required. Spec FR-021 and constitution Principle V ask for a test of every logic change that can run
without the game, and the test must fail without the change.

**Organization**: grouped by the user stories of spec.md. Work in the current branch `002-shared-db`; commit only
when the author asks.

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it.
- Addon Lua stays ASCII (UTF-8 only inside `GameData/` string literals), Lua 5.1/5.3 neutral, at most 120
  characters a line.
- The layers hold.
- A new file or a TOC change needs a game restart; say so in the hand-over.
- A test that loads the addon uses `load_addon()` from `tests/wow.lua`; the TOC is read by `tests/run.mjs`, so a
  new addon file needs only its TOC line.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US6)

---

## Phase 1: Setup

**Purpose**: a baseline to compare against at the end.

- [X] T001 Run `npm run check` and `npm test`. Write down in `specs/008-architecture-alignment/quickstart.md` (a
  "Baseline" line under "Before the game") four numbers: the number of `*_test.lua` files, the number of `test(`
  cases (`git grep -c "^test(" -- tests`), the number of VERIFY markers `npm run check` lists (61), and the
  `npm test` result.

---

## Phase 2: Foundational

No blocking task. The `npm run check` rule that guards the model (contract C1) would fail on today's
`GameData/FishingRanks.lua`, which reads `ns.FISHING_SPELL_IDS`. So it lands at the end of US1, once the model is
in place. That keeps `npm run check` green after every task (constitution Principle V).

---

## Phase 3: User Story 1 - Game data lives in one model (Priority: P1) 🎯 MVP

**Goal**: every game fact by ID and every client enum mapping lives in `ns.GameData.<Entity>`, one file per entity
(data-model.md).

**Independent Test**: `tests/gamedata/` passes. A search for the old names finds nothing (quickstart step 3). The
tests of fishing mode, bags, gear, skill, catch and catalog pass unchanged.

### Tests for User Story 1

- [X] T002 [P] [US1] Add `tests/gamedata/shape_test.lua`. After `load_addon()` it checks the "Rules" of
  data-model.md for every entity:
  - IDs are positive whole numbers (`GameData.Bobber.objectID` is a string of digits);
  - `bonus`, `skill`, `cap`, `learnAt` and `level` are whole numbers >= 0;
  - `GameData.Lures` `order` runs 1..n without a gap;
  - `GameData.FishingSpells` caps are exactly 75, 150, 225, 300;
  - every `GameData.FishingRanks` key is a spell's cap, and its `next` is the following rank's `spellID`;
  - `GameData.EquipSlots.byEquipLoc` values are arrays of slot numbers 1-19;
  - `ns.CatchDB.RANGE_STEP == 75` and `ns.CatchDB.MAX_RANGE == 4` (the saved catch keys depend on them).

  It fails before T004-T010.
- [X] T003 [P] [US1] Add `tests/gamedata/load_order_test.lua`. It reads `TOC_FILES` (set by `tests/run.mjs`) and
  checks:
  - every `GameData\` file comes after the last `Locales\` file and before `Core\Core.lua`;
  - `GameData\FishingSpells.lua` is the first of them;
  - after `load_addon()`, `ns.IsFishingSpell(7620)` is true (Core/Data.lua built its lookup at load).

### Implementation for User Story 1

- [X] T004 [US1] Create `OneKeyFishing/GameData/FishingSpells.lua`:
  - `GameData.FishingSpells`, an array in rank order of `{ spellID = 7620, cap = 75 }`, `{ 7731, 150 }`,
    `{ 7732, 225 }`, `{ 18248, 300 }`, with English rank names as comments;
  - the header as in data-model.md (the two `GameData` lines, the source).

  In `OneKeyFishing/GameData/FishingRanks.lua`:
  - `ns.FishingRanks` becomes `GameData.FishingRanks`, with `next` from `GameData.FishingSpells[i].spellID`;
  - delete `ns.FishingRankSpells` (readers switch in T010);
  - move `ns.NpcNames` out (T005);
  - reword the header line 5 so it no longer contains the literal `VERIFY(R11)` (for example "The VERIFY marks of
    research R11 show what the in-game check confirms", without the parentheses form). Keep every value marker.
- [X] T005 [P] [US1] Create `OneKeyFishing/GameData/NpcNames.lua` with `GameData.NpcNames`, moved unchanged from
  FishingRanks.lua: the UTF-8 names, the comments and the `VERIFY(R12)` marker.
- [X] T006 [P] [US1] Create `OneKeyFishing/GameData/Bobber.lua`: `GameData.Bobber = { objectID = "35591" }`, with the
  comment from `Core/Data.lua` line 9 ("as seen in its GUID").
- [X] T007 [P] [US1] Create `OneKeyFishing/GameData/Lures.lua`. `GameData.Lures[itemID] = { bonus, order, skill }`,
  exactly the table "Lures" of data-model.md:
  - 6533 = 100 / 1 / 100;
  - 7307 = 75 / 2 / 100;
  - 6532 = 75 / 3 / 100;
  - 6811 = 50 / 4 / 50;
  - 6530 = 50 / 5 / 50;
  - 6529 = 25 / 6 / 0.

  Each line has the lure's English name and `-- VERIFY(V43)` on its `skill`. The header names the source (Wowhead
  Classic tooltips, 2026-11-06) and says `order` 1 is the best.
- [X] T008 [P] [US1] Create the remaining four entity files:
  - `OneKeyFishing/GameData/FishedContainers.lua`: `GameData.FishedContainers = { [5523] = true, [5524] = true,
    [7973] = true, [15874] = true }`, with names as comments.
  - `OneKeyFishing/GameData/FishingPoles.lua`: `GameData.FishingPoles[itemID] = { bonus, skill }` as the data-model
    table "Fishing poles", and `GameData.FishingPoleClass = { classID = 2, subclassID = 20 }`.
  - `OneKeyFishing/GameData/EquipSlots.lua`: `GameData.EquipSlots = { mainHand = 16, offHand = 17, ranged = 18,
    byEquipLoc = { ... } }`, with `byEquipLoc` copied from `SLOTS_BY_EQUIP_LOC` of `Fishing/Gear.lua` lines 37-53.
  - `OneKeyFishing/GameData/Icons.lua`: `GameData.Icons = { unknownItem = 134400 }`, with the comment
    `INV_Misc_QuestionMark`.
- [X] T009 [US1] In `OneKeyFishing/OneKeyFishing.toc`, move the game data block. Put it right after
  `Locales\zhCN.lua` and before `Core\Core.lua`, with the comment `# Game data (data only, ns.GameData)`, in this
  order: `FishingSpells`, `FishingRanks`, `NpcNames`, `Bobber`, `Lures`, `FishedContainers`, `FishingPoles`,
  `EquipSlots`, `Icons`. Remove the old `GameData\FishingRanks.lua` line after `Core\MapPin.lua`.
- [X] T010 [US1] Switch the readers and delete the old tables:
  - `OneKeyFishing/Core/Data.lua`:
    - delete `ns.FISHING_SPELL_IDS`, `ns.FISHING_SKILL_LINE` and `ns.BOBBER_OBJECT_ID` (lines 4-10);
    - the spell lookup (around line 251) and `ns.GetFishingSpellID` walk `ns.GameData.FishingSpells[i].spellID`;
    - `IsBobberTargeted` compares with `ns.GameData.Bobber.objectID`;
    - the header comment says the game data lives in `GameData/`.
  - `OneKeyFishing/Catch/Catch.lua` line 21: the bobber from `ns.GameData.Bobber.objectID`.
  - `OneKeyFishing/Fishing/Gear.lua`:
    - `GetFishingBonus` reads `ns.GameData.FishingPoles[itemID].bonus` (nil-safe);
    - `IsFishingPole` reads `GameData.FishingPoleClass`;
    - the slot constants, `WEAPON_SLOTS` and `SLOTS_BY_EQUIP_LOC` come from `GameData.EquipSlots`; build the
      weapon set from `mainHand`, `offHand`, `ranged` once at file load;
    - line 82 reads `GameData.FishingSpells[1].spellID`;
    - delete `KNOWN_POLE_BONUS`, `FISHING_POLE_CLASS` and `FISHING_POLE_SUBCLASS`.
  - `OneKeyFishing/Fishing/Bags.lua`:
    - delete `LURES` and `CONTAINERS`;
    - `IsFishedContainer` / `IsOpenable` read `ns.GameData.FishedContainers`;
    - `FindLure` / `DescribeLures` walk the lures sorted by `order` (build the sorted ID list once at file load
      from `ns.GameData.Lures`); no behaviour change here.
  - `OneKeyFishing/Fishing/Skill.lua`:
    - `ns.FishingRankSpells[maxRank]` becomes the spell whose `cap == maxRank` in `GameData.FishingSpells`; add a
      local helper `SpellOfCap(cap)`;
    - `ns.FishingRanks` becomes `GameData.FishingRanks`, and `ns.NpcNames` becomes `GameData.NpcNames`;
    - the fallback rank names (lines 13-21) become `{ L["Apprentice"], L["Journeyman"], L["Expert"],
      L["Artisan"] }`, built on first use and indexed by the position of the spell in `GameData.FishingSpells`
      (research R8). No spell ID literal is left.
  - `OneKeyFishing/UI/Indicator.lua` line 109 and `OneKeyFishing/UI/StatsFrame.lua` lines 573-575: read
    `GameData.FishingSpells` / `GameData.FishingRanks`.
  - `OneKeyFishing/UI/CatchHere.lua`: delete `UNKNOWN_ICON`; use `ns.GameData.Icons.unknownItem`.
  - `OneKeyFishing/CatchDB/CatchDB.lua` lines 16-17: `RANGE_STEP = ns.GameData.FishingSpells[1].cap` and
    `MAX_RANGE = #ns.GameData.FishingSpells`, with a comment that the saved keys depend on both values.
  - `tests/fishing/next_rank_test.lua` lines 108-117: `ns.NpcNames` becomes `ns.GameData.NpcNames`.
  - Any other test that names an old global: find them with
    `git grep -n "FISHING_SPELL_IDS\|BOBBER_OBJECT_ID\|FishingRankSpells\|ns.FishingRanks\|ns.NpcNames" -- tests`.
- [X] T011 [P] [US1] Add `tests/tools/gamedata_check_test.mjs`, in the style of the existing Node tests in
  `tests/tools/`. It feeds the new check fixtures and checks:
  - a GameData file with `function`, one with `ns.L[...]`, and one reading `ns.Bags` each fail;
  - a file of only `local GameData = ns.GameData or {}` / `ns.GameData = GameData` and tables passes;
  - a UTF-8 string literal still passes;
  - a comment naming `ns.FishingRanks`, `Skill.lua` or "function" passes, because comments are not code.

  If the check functions are not exported from `tools/check.mjs` yet, export the rule as a function the test can
  call. Run it before T012 and see it fail.
- [X] T012 [US1] In `tools/check.mjs`, next to the existing `isGameData` ASCII rule (around line 155), add a rule for
  every file under `OneKeyFishing/GameData/`. The rule reads the code only: strip the string literals (reuse the
  string-stripping helper of the ASCII rule) and the comments (`--` to the end of the line, and `--[[ ]]` blocks).
  A line fails when what is left contains:
  - the word `function`;
  - `L[` or `ns.L`;
  - an `ns.<Name>` other than `ns.GameData`.

  Problem text: `GameData/ holds data only (no function, no ns.L, no other module)`. Update the rule comment at the
  top of `tools/check.mjs`. Every GameData file now passes it (T004-T010).
- [X] T013 [US1] Run `git grep -n "FISHING_SPELL_IDS\|BOBBER_OBJECT_ID\|FISHING_SKILL_LINE\|FishingRankSpells\|KNOWN_POLE_BONUS\|SLOTS_BY_EQUIP_LOC\|UNKNOWN_ICON" -- OneKeyFishing tests tools`.
  It must find nothing. Then run `npm run check`, which must report no GameData problem, and `npm test`, where
  T002/T003 now pass.

**Checkpoint**: the model is in place; no behaviour changed.

---

## Phase 4: User Story 2 - A lure above the Fishing skill is never offered (Priority: P1)

**Goal**: contract C3. `FindLure` skips a known lure whose `skill` is above `Skill.Get()`.

**Independent Test**: `tests/fishing/lure_skill_test.lua`; in game, `fishing-mode.md` "Lure too high".

### Tests for User Story 2

- [X] T014 [P] [US2] Add `tests/fishing/lure_skill_test.lua` in the style of `tests/fishing/lures_test.lua`
  (bag_items, `fishing_skill` / `fishing_rank` stubs of `tests/wow.lua` lines 979-1000). Cases:
  1. With `fishing_rank = 49` and Nightcrawlers (6530, skill 50) plus Shiny Bauble (6529, skill 0) in the bags,
     `ns.Bags.FindLure()` returns 6529.
  2. With rank 50, it returns 6530.
  3. With rank 49 and only 6530, `FindLure()` returns nil with no second value (no cooldown to wait for), and
     after `advance(10)` `LURE_READY` has not fired.
  4. The rank rises from 49 to 50 in the same session (change the stub, no reload), and the next `FindLure`
     returns 6530.
  5. With `fishing_skill, fishing_rank = nil, nil` (Fishing unknown: `tests/wow.lua` reads both), 6530 is returned
     (nothing held back).
  6. `ns.Bags.DescribeLures()` lines contain `needs: 50` for 6530.

  It fails before T015.

### Implementation for User Story 2

- [X] T015 [US2] In `OneKeyFishing/Fishing/Bags.lua` `FindLure` (around line 108), skip a lure when
  `ns.GameData.Lures[itemID].skill > rank`, where `local rank = ns.Skill and ns.Skill.Get()` is read once per call.
  - Skip nothing when `rank` is nil.
  - Put `-- VERIFY(V44): the game compares the base skill (GetProfessionInfo rank), not the skill with bonuses`
    on that line.
  - `Skill.lua` loads after Bags.lua: read it at runtime only.
  - `DescribeLures` adds `, needs: %d` with the lure's `skill`.
  - The failure path (`LURE_FAIL_DELAY`, `skippedLures`) stays unchanged.
- [X] T016 [US2] Add the player-visible line:
  - `CHANGELOG.md` `## [Unreleased]` / `### Changed`: "A lure your Fishing skill is too low for is no longer
    offered; it is used once your skill is high enough."
  - The same fact in the lure paragraph of `OneKeyFishing/README.md` (find it with `grep -n -i lure`).
  - Remove the item "A lure above the Fishing skill is offered until it fails (low)" from `docs/tech-debt.md`.
  - Add a low item there, "A fishing pole above the Fishing skill may be chosen", with the requirements recorded in
    `GameData/FishingPoles.lua` (research R5).
- [X] T017 [US2] In `docs/architecture/fishing-mode.md` (the Bags.lua section), describe the skill rule of
  contract C3 and V43/V44.

**Checkpoint**: US1 and US2 are done; this is the minimum worth handing to the game.

---

## Phase 5: User Story 3 - One map pin for every place (Priority: P2)

**Goal**: contract C2. The catalog pins through `ns.MapPin`; the fallback lives in `MapPin.Target`.

**Independent Test**: `tests/core/pin_target_test.lua`, `tests/core/pin_set_test.lua`,
`tests/catalog/spot_pin_test.lua`.

### Tests for User Story 3

- [X] T018 [US3] Split the tests by subject with `git mv`:
  - `tests/core/mappin_test.lua` becomes `tests/core/pin_target_test.lua` (the target cases) and
    `tests/core/pin_set_test.lua` (the setting cases, the popup, combat).
  - From `tests/catalog/pin_test.lua`:
    - the cases "a cave that refuses goes to its zone's map through the world position" and the setting cases go
      into the two core files, rewritten against `ns.MapPin.Target` / `ns.MapPin.Set`;
    - the cases on a dungeon cell and a cell without a position go into a new `tests/catalog/spot_pin_test.lua`,
      against the `pin` field of `ns.Catalog.Spots` rows;
    - delete `tests/catalog/pin_test.lua` once every case has a home (count the cases before and after).
  - Add to `pin_set_test.lua`:
    - pinning the place the addon's own pin already marks shows no popup;
    - a pin set from the catalog tab fires `MAP_PIN_SET` with the place name and shows the toast of
      `UI/Toast.lua` once (no second direct toast).

  The fallback case and the "once" case fail before T019-T021.

### Implementation for User Story 3

- [X] T019 [US3] In `OneKeyFishing/Core/MapPin.lua` `MapPin.Target(maps, x, y)` (line 31), add the fallback from
  `Catalog.PinTarget` (`OneKeyFishing/Catalog/Catalog.lua` lines 368-384):
  - when no candidate allows a pin, take the first candidate the client knows;
  - carry the point through `C_Map.GetWorldPosFromMapPos` to its parent map (`C_Map.GetMapInfo(id).parentMapID`)
    with `C_Map.GetMapPosFromWorldPos`;
  - return that point if the parent allows pins.

  Move the `VERIFY(V33)` comment with it, and update the file header (lines 1-4) so it no longer says the code
  was "taken over" while a copy existed.
- [X] T020 [US3] In `OneKeyFishing/Catalog/Catalog.lua`:
  - delete `Catalog.PinTarget` (lines 352-385) and its waypoint-API and game-rule checks;
  - in `Catalog.Spots` (line 339), keep only the catalog's own rules (no pin for a dungeon cell or a cell without a
    position, as today), then call `ns.MapPin.Target({ mapID }, x, y)`;
  - delete the `VERIFY(V30)` and `VERIFY(V33)` comments of Catalog.lua; add one `VERIFY(V30)` marker in
    `Core/MapPin.lua` at its `CanSetUserWaypointOnMap` call (`Core/MapPin.lua` has none today; V33 came with T019).
- [X] T021 [US3] In `OneKeyFishing/UI/CatalogTab.lua`:
  - `CatalogTab.Pin(target, placeName)` becomes `ns.MapPin.Set(target, placeName)`;
  - delete `IsOwnPin` (lines 436-444), `PIN_EPSILON` (line 21), the direct `ns.Toast` calls, the
    `"ONEKEYFISHING_REPLACE_PIN"` literal and the `VERIFY(V32)` marker;
  - keep `PIN_ATLAS`.

  In `specs/005-catch-catalog/verification.md`, set V32's status to "Replaced 2026-11-06 (spec 008): the catalog
  pins through `Core/MapPin.lua`; the same `OpenWorldMap` taint is R14 (`specs/001-interface-language/verification.md`)",
  and update V30 and V33's file references.
- [X] T022 [US3] Update the docs:
  - `docs/architecture/ui.md`, lines 65-70: the catalog pin flow becomes `MapPin.Set`.
  - `docs/architecture/catalog.md`: the pin target comes through `MapPin.Target`.
  - `docs/architecture/core.md`, the MapPin section: the fallback; the catalog now really uses it.
  - `CLAUDE.md`: the `Core/MapPin.lua` row stays true; the UI row's job list loses "the map pin".
  - `docs/release-plan.md`: drop the item "Switch the catch catalog's pin ... to `ns.MapPin`".
  - `docs/tech-debt.md`, line 23: name `Core/MapPin.lua` and R14 only.

---

## Phase 6: User Story 4 - No dead code, no duplicates, files with one role (Priority: P2)

**Goal**: research R7, R8, R9, R10.

**Independent Test**: quickstart steps 1-3; the dead code search of T040 finds nothing; `npm test` keeps every case.

### Dead code and private tables (R7)

- [X] T023 [US4] Remove `ns.Minimap` in `OneKeyFishing/UI/Minimap.lua` line 7: the table stays local. Check with
  `git grep -n "ns.Minimap\b"` that no reader is left (tests included).
- [X] T024 [US4] Move the test-only names into private tables:
  - `OneKeyFishing/CatchDB/CatchDB.lua` line 395: `CatchDB.OwnProofReady` becomes `P.OwnProofReady`.
  - `OneKeyFishing/CatchDB/Checks.lua` line 159: `CatchDB.STEP_SECONDS` becomes `P.STEP_SECONDS`.
  - `OneKeyFishing/Exchange/Comm.lua`:
    - add `local P = {}` / `Comm.private = P -- internals shared by the Exchange/Comm*.lua files (not an API)`
      after `ns.Comm = Comm`;
    - `Comm.GetPaths` (line 662) becomes `P.GetPaths`.
  - Switch the tests:
    - `tests/catchdb/proof_chain_test.lua`, `tests/catchdb/proof_login_test.lua`: `ns.CatchDB.private.OwnProofReady`;
    - `tests/catchdb/proof_chain_test.lua`, `tests/exchange/channel/sim_test.lua`, `tests/exchange/share/channel_test.lua`,
      `tests/exchange/share/protocol_test.lua`: `ns.CatchDB.private.STEP_SECONDS`;
    - `tests/exchange/comm/*.lua`, `tests/exchange/share/refused_test.lua`: `ns.Comm.private.GetPaths()`.
- [X] T025 [US4] Add a private-table rule to `tools/check.mjs` (contract C4): `ns.<Name>.private` named in an addon
  file outside the folder of the module that defines `<Name>` is a problem. Tests are allowed. Extend
  `tests/tools/gamedata_check_test.mjs`, or add `tests/tools/private_check_test.mjs`, with one failing and one
  passing fixture.
- [X] T026 [US4] Give `ns.earlyLookups` a reader. In `OneKeyFishing/Core/Debug.lua`, add a line to the first
  section of the report: `early L lookups: none`, or the comma-separated keys looked up before the language was
  set. The report is not localized. Extend `tests/core/debug_test.lua` (renamed in T035) with a case: a key looked
  up before the language is set shows in the report.

  In `docs/release-plan.md` step 4 (the spike removal), add `ns.ReportSection` (`Core/Debug.lua`, used only by the
  spike) and `tests/ui/spike_test.lua` to the list.

### Duplicates (R8)

Each task deletes the second copy and keeps one test that covers every caller.

- [X] T027 [P] [US4] Range label:
  - add `function ns.RangeLabel(min, max)` to `OneKeyFishing/UI/Widgets.lua` (move the body of `RangeLabel` from
    `UI/CatchHere.lua` lines 41-42 and the span arithmetic of `SpanLabel` from `UI/CatalogTab.lua` lines 43-55;
    `max` defaults to `min`);
  - both tabs call it;
  - add the cases one range, a span and the top range open ("300+") to `tests/ui/catalogtab_test.lua` (renamed in
    T037).
- [X] T028 [P] [US4] Little data:
  - export `CatchDB.LITTLE_DATA = LITTLE_DATA` in `OneKeyFishing/CatchDB/Views.lua` (line 18);
  - in `OneKeyFishing/Exchange/Share.lua` line 315, delete `RARE_CATCHES` and read `ns.CatchDB.LITTLE_DATA` at
    runtime (Share loads after CatchDB, so a local bound at load is fine too).
- [X] T029 [US4] Own record:
  - add `function CatchDB.OwnRecord(store)` to `OneKeyFishing/CatchDB/CatchDB.lua` (replacing the local at line
    277): `store` defaults to `ns.db.shared`, and it returns the record only when `type(own) == "table"` and
    `seq` / `epoch` are counts (Share's checks, `Exchange/Share.lua` lines 400-405; move or share its `IsCount`);
  - delete Share's local and call `ns.CatchDB.OwnRecord(store)`;
  - read every CatchDB caller of the old local (`git grep -n "OwnRecord(" -- OneKeyFishing/CatchDB`) and make sure
    each handles nil;
  - add a case to `tests/catchdb/damaged_test.lua`: `CatchDB.OwnRecord(store)` is nil for a missing record and for
    a `seq` or `epoch` that is no count, the record itself when sound, the account's own by default. (Done this way:
    a damaged own record of the account is already started over by the login check in `CatchDB/Events.lua`, so a
    catch never meets one; before the merge a damaged record raised an error in `TargetCells` as well.)
- [X] T030 [P] [US4] Scan button:
  - add `function ns.UpdateScanButton(button, hint)` to `OneKeyFishing/UI/Widgets.lua`: it sets
    `button:SetEnabled(ns.Auction.CanScan())`, and `hint:SetShown(not ns.Auction.IsOpen())` when a hint is given;
  - use it in `OneKeyFishing/UI/Settings.lua` lines 248-252 and `OneKeyFishing/UI/StatsFrame.lua` lines 390-392;
  - the existing settings and stats window tests must still pass.
- [X] T031 [P] [US4] Default filter:
  - add `function Catalog.DefaultFilter()` to `OneKeyFishing/Catalog/Catalog.lua`: it returns a new
    `{ range = "all", source = "all", water = "all" }` built from `DEFAULT_FILTER`;
  - `OneKeyFishing/UI/CatalogTab.lua` line 35 uses it.
- [X] T032 [P] [US4] CVars:
  - add `Mode.CVAR_NAMES = { "SoftTargetInteract", "autoLootDefault", "SoftTargetIconGameObject",
    "SoftTargetIconInteract" }` to `OneKeyFishing/Fishing/Mode.lua`, next to `DesiredCVars`, and add a test case
    that every key `DesiredCVars()` can return is in the list (all settings on);
  - `OneKeyFishing/Core/Debug.lua` line 11 deletes `REPORT_CVARS` and reads `ns.Mode.CVAR_NAMES`.

### Splits (R9)

- [X] T033 [US4] Split `OneKeyFishing/CatchDB/Views.lua` into `OneKeyFishing/CatchDB/Index.lua`. Move, unchanged:
  - lines 133-254: `SeedIndex`, `AddToSet`, `CountedUnit`, `IndexRecord`, `RemoveFromSet`, `UnindexRecord`,
    `Frozen`, `Others`, `IsOwnKey`, `OwnIndex`;
  - lines 430-469: `AddItemsOf`, `SeedItems`, `OwnItems`.

  Wiring:
  - Index.lua binds `P.KeyMapRange`, `P.KeyMapID`, `P.AddToOwnIndex`, `P.Seed` from `CatchDB.private` at load;
  - Index.lua exports `P.SeedIndex`, `P.Others`, `P.Frozen`, `P.OwnIndex`, `P.SeedItems`, `P.OwnItems`,
    `P.IsOwnKey`, `P.IndexRecord`, `P.UnindexRecord`;
  - Views.lua binds them from `P` at its top.
  - TOC: `CatchDB\Index.lua` between `CatchDB\Checks.lua` and `CatchDB\Views.lua`.
  - Make `OwnItems` reuse `IsOwnKey` only after a test in `tests/catchdb/items_test.lua` shows a frozen own record
    (`<myID>@<epoch>`) is still counted the same; otherwise leave the check as it is.

  Update:
  - the headers of both files;
  - the file list comments in `CatchDB/CatchDB.lua` lines 6-7 and 37-42;
  - the stale comment at `Views.lua:453-454`.
- [X] T034 [US4] Split `OneKeyFishing/Exchange/Comm.lua` into `OneKeyFishing/Exchange/CommReceive.lua`. Move,
  unchanged:
  - lines 468-636, except `Comm.OnOffline` and `offlineHandlers`, which stay with the send side;
  - the part constants `PART_TIMEOUT`, `PART_BUFFER`, `PART_BUFFER_TOTAL`, `PART_FLOOD_LIMIT`, `PART_FLOOD_MINUTES`;
  - `VIA`;
  - the locals `receivers`, `activityHandlers`, `floodHandlers`, `partFilter`, `dropped`, `lastSweep`.

  Wiring:
  - `Comm.private` (T024) carries `PREFIX`, `MAX_MESSAGE`, `MAX_PARTS`, `Enabled`, `buffers`, `flooded`; the two
    tables are created in Comm.lua.
  - TOC: `Exchange\CommReceive.lua` right after `Exchange\Comm.lua`.

  Update:
  - the header of Comm.lua (lines 1-8) and of the new file;
  - the first-line comments of `tests/exchange/comm/transport_test.lua` and `channel_test.lua` where their cases
    now test CommReceive.lua.

### Tests renamed and moved (R10)

- [X] T035 [P] [US4] `git mv` in `tests/core/`, `tests/catch/` and `tests/fishing/`, updating each file's first
  comment line to name its subject:
  - `catch/prices_test.lua` becomes `catch/auction_price_test.lua`;
  - `catch/stats_test.lua` becomes `ui/stats_window_test.lua`;
  - `fishing/bags_test.lua` becomes `fishing/fished_loot_test.lua`;
  - `fishing/skill_test.lua` becomes `fishing/cap_warning_test.lua`;
  - `core/commands_test.lua` becomes `core/english_commands_test.lua`;
  - `core/debug_test.lua` becomes `core/report_sections_test.lua`.
- [X] T036 [P] [US4] `git mv` the seven `tests/exchange/share/notice*_test.lua` files to `tests/ui/`, keeping their
  suffixes. Their first lines name `UI/ShareNotice.lua` and `Exchange/ShareGame.lua` instead of "Share.lua".
- [X] T037 [P] [US4] `git mv` in `tests/ui/`, with their first comment lines:
  - `catchhere_test.lua`, `catchhere_login_test.lua`, `catchhere_seed_test.lua` become `here_page_test.lua`,
    `here_login_test.lua`, `here_seed_test.lua`;
  - `catalogtab_test.lua`, `catalogtab_fallback_test.lua`, `catalogtab_pending_test.lua` become
    `catalog_list_test.lua`, `catalog_fallback_test.lua`, `catalog_pending_test.lua`;
  - `settings_test.lua`, `settings_gear_test.lua`, `settings_nochannel_test.lua` become `shared_page_test.lua`,
    `gear_page_test.lua`, `shared_page_nochannel_test.lua`.

  Leave `ui/spike_test.lua` (spec 009).

  Also rename the three tests the T038 rule would flag, after their subject:
  - `tests/catchdb/views_test.lua` (QueryMap, QueryCells, Maps, stamps) becomes `tests/catchdb/map_views_test.lua`;
  - `tests/exchange/comm/channel_test.lua` (Comm's channel path and part rules) becomes
    `tests/exchange/comm/channel_path_test.lua`;
  - `tests/exchange/share/channel_test.lua` (the protocol node in the channel) becomes
    `tests/exchange/share/channel_sessions_test.lua`.

  Each new first line names its subject; the old line names "CatchDB.lua", "Comm.lua", "Share.lua".
- [X] T038 [US4] Add a test-name rule to `tools/check.mjs` (contract C5). A file `tests/<folder>[/<sub>]/<name>_test.lua`
  is a problem when `<name>` equals, case-folded, the base name of a `.lua` file in the addon folder of its test
  folder: `core` maps to `Core/`, `fishing` to `Fishing/`, `catch` to `Catch/`, `catchdb` to `CatchDB/`, `catalog`
  to `Catalog/`, `exchange` to `Exchange/`, `ui` to `UI/`, `gamedata` to `GameData/`. `tools/` and the harness at
  the root of `tests/` are not checked. No exception list: after T035-T037 no file matches (`ui/spike_test.lua`
  does not, since Spike.lua is in `Core/`).

  Problem text: `test named after a module of its area; name its subject (docs/development.md)`. Add a fixture test
  in `tests/tools/` with one failing name (`fishing/bags_test.lua`) and one passing name
  (`fishing/lure_skill_test.lua`).
- [X] T039 [US4] Search `specs/002-local-catch-db/quickstart.md` through `specs/006-error-log/quickstart.md` and
  `specs/007-launch-day-fixes/quickstart.md` for the old test names of T018 and T035-T037 (`git grep -n` per old
  name, `views_test` and `channel_test` included), and replace them with the new ones. Leave their spec, plan, research and tasks as written (FR-023).
- [X] T040 [US4] The final dead code check. List the `ns.X = `, `function ns.X(` and `function <Module>.X(`
  definitions in `OneKeyFishing/` with a script in the scratchpad directory (not committed). Then count each name's
  uses in `OneKeyFishing/` outside its own definition. Every one has a use, except:
  - `Core/Spike.lua` and what only it uses (`ns.ReportSection`);
  - names inside `.private` tables;
  - the XML and TOC entries (`Bindings.xml` globals, the `AddonCompartment` functions).

  Report the list in the hand-over.

---

## Phase 7: User Story 5 - The documents tell the truth (Priority: P2)

**Goal**: research R11, R12. Every drift item is fixed, every VERIFY id is explained, and the confirmed facts are
recorded.

**Independent Test**: quickstart step 3, plus a read of each document against the list below.

### VERIFY bookkeeping (R11)

- [X] T041 [P] [US5] Create `specs/001-interface-language/verification.md` in the format of
  `specs/005-catch-catalog/verification.md`: the intro, how to close an item, and one table row per id with
  assumption, evidence, if wrong, how to verify, and status:
  - **R11**:
    - open: `learnAt = 50`, `learnAt = 125` with `level = 20`, `learnAt = 225` with `level = 35`, quest 6607,
      NPC 12919, maps 1445 / 70, point 0.586 / 0.602;
    - closed 2026-11-05/06: area IDs 35, 33, 517, 15, item 16083, NPC 2626, map 1434, Heming's point, level 10,
      Heming's merchant list.
  - **R12**: open, the German Heming name of `GameData/NpcNames.lua`; closed: the creature tooltip.
  - **R14**: failed, `OpenWorldMap` from addon code taints the map, fix in `docs/tech-debt.md`; closed: the arrow,
    the chat map link; it also covers the catalog since spec 008 (V32 replaced).

  Source: `specs/001-interface-language/research.md` R11 lines 139-171, R12 lines 173-202, R14 lines 215-245, and
  the Results of `docs/checklists/interface-language.md`.
- [X] T042 [US5] Close V7:
  - remove the `VERIFY(V7)` marker at `OneKeyFishing/CatchDB/CatchDB.lua` line 165;
  - tick V7 in `specs/002-local-catch-db/verification.md`: "Closed 2026-11-06 (spec 008): the 1.1.0 debug reports
    show `GetBuildInfo` as 1.60.1 / 70790".
- [X] T043 [US5] Record the parts seen in game in the Status column of the `verification.md` files. The markers
  stay.
  - In `specs/002-local-catch-db/verification.md`:
    - V1 / V2: Booty Bay gives map 1434 with a position (`interface-language.md` lines 132-133);
    - V3: the bobber side, object 35591 in the `softinteract` GUID (`fishing-mode.md` Cast/Hook);
    - V4 / V5: the commodity `unitPrice` and the item `buyoutAmount` give prices (the Scan step).
  - In `specs/005-catch-catalog/verification.md`:
    - V30: the game rule is inactive in the open world (the 1.1.0 pin was set through the gate);
    - V34: `GetAreaInfo` names areas in the client's language;
    - V35: `GetItemNameByID(16083)` answers;
    - V38: the post call fires for bag tooltips.

  Where those files name the file or function of a marker that moved in this spec (T010, T019, T020, T033, T034;
  for example `Catalog.PinTarget` for V30 / V33, `Views.lua` or `Comm.lua` for markers now in `Index.lua` or
  `CommReceive.lua`), name the new place. Find the moved markers with `git grep -n "VERIFY("`. Leave rows that name
  no file as they are.
- [X] T044 [US5] Add to `docs/forever-api.md` "Verified in game" (2026-11-05/06, release 1.1.0, game 1.60.1 build
  70790):
  - the bobber's object ID 35591 in the `softinteract` GUID;
  - `GetBuildInfo` values;
  - `GetBestMapForUnit` in Booty Bay is 1434, with a position;
  - `C_Map.HasUserWaypoint` / `GetUserWaypoint` see a pin the player set;
  - commodity result `unitPrice` and item result `buyoutAmount` exist;
  - the `TooltipDataProcessor` Item post call fires on bag items;
  - a lure above the skill fails with "Cannot apply ...";
  - the Addon Compartment exists;
  - a settings page frame created shown gets no `OnShow` on its first view.

  Skip a fact already there.

### Living documents (R12)

- [X] T045 [P] [US5] Create `docs/architecture/game-data.md`:
  - the area's purpose;
  - the rule (contract C1);
  - the load order (research R3);
  - one section per entity file of data-model.md: fields, source, readers, VERIFY ids;
  - what is not game data (research R1);
  - how to add an entity (its file, the TOC line, the shape test).

  Link it from `docs/README.md` and from the `GameData/` rows of `CLAUDE.md`.
- [X] T046 [US5] `CLAUDE.md`:
  - the layer table: `Core/`, `Locales/`, `GameData/` in layer 0;
  - the module table: `GameData/*.lua` rows (one row: the nine files, data only, `ns.GameData`, game-data.md),
    placed after `Locales/*.lua` in TOC order;
  - the CatchDB row with `CatchDB/Index.lua`; the Exchange row with `Exchange/CommReceive.lua`;
  - the UI row in TOC order (CatchHere, CatalogTab, StatsFrame) without "the map pin";
  - the `Core/MapPin.lua` row;
  - the VERIFY sentence: "features 001 to 006 and 008 have one";
  - the cross-module rule "Game data tables that are plain data belong in `GameData/`", which becomes
    "Game data lives in `ns.GameData` (GameData/, layer 0, data only, game-data.md)".

  Keep it consistent with the constitution.
- [X] T047 [P] [US5] `docs/architecture/core.md`:
  - the layer table with `GameData/` and `Core/MapPin.lua`;
  - move the dispatcher / `ns.version` / binding labels bullet (lines 94-95) from the MapPin section to Core.lua;
  - `ns.ReportSection` is listed under Debug.lua, not Core.lua (lines 74-75);
  - delete `ns.FISHING_SKILL_LINE` (line 140) and the spell / bobber IDs from the Data.lua helpers (now
    game-data.md);
  - the saved fields: add `charDB.session` (written by `Catch/Stats.lua`, read by `Fishing/Skill.lua`); `settings`
    is written by `UI/Settings.lua`, `Core/Core.lua` (`languageHintShown`), `Fishing/Camera.lua`
    (`cameraDistance`), `Exchange/ShareGame.lua` (`shareDB`) and `Exchange/Channel.lua` (`shareChannel`);
    `shareNotice*` is written by `Exchange/ShareGame.lua`;
  - also fix the comments at `OneKeyFishing/Core/Core.lua` lines 212-213.
- [X] T048 [P] [US5] Area pages:
  - `docs/architecture/fishing-mode.md`: the "GameData/FishingRanks.lua" section becomes a pointer to
    game-data.md; the lures, containers and poles come from GameData.
  - `docs/architecture/exchange.md`: the intro, line 9 and the Comm section; a new CommReceive section with the
    "Parts" bullet.
  - `docs/architecture/catch-db.md`, lines 10-16: six files, Index.lua.
  - `docs/architecture/catch-and-stats.md`, line 76: the listener is `CatchDB/Events.lua`.
  - `docs/architecture/ui.md`: `ns.RangeLabel` and `ns.UpdateScanButton` in Widgets.
  - `docs/architecture/catalog.md`: `Catalog.DefaultFilter`.
- [X] T049 [P] [US5] `docs/development.md`:
  - the test table and its examples after the renames (R10), with a `gamedata/` row;
  - the naming paragraph stays and now holds;
  - the testable modules list adds Skill, GameData;
  - add the file size rule (research R9: over 600 lines and more than one role means split along the seams, files
    of one module share `<Module>.private`; a coherent file stays);
  - add the private table rule (research R7: what only tests need lives in `<Module>.private`; `npm run check`
    rejects another module reading it);
  - add the `GameData/` check to the list of what `npm run check` does.
- [X] T050 [P] [US5] Root `README.md`:
  - line 35: `OneKeyFishing/CatchDB/SeedData.lua`;
  - the docs table (lines 49-61) gains `docs/development.md`, `docs/forever-api.md`, `docs/tech-debt.md`,
    `docs/architecture/`.

  `docs/README.md`:
  - line 12: release-plan covers "the checks left after 1.1.0 and what 1.2.0 waits for";
  - line 15: tech-debt holds the known issues with their severity;
  - add game-data.md.
- [X] T051 [P] [US5] Small fixes:
  - `docs/checklists/catch-database.md` line 35: `git checkout OneKeyFishing/CatchDB/SeedData.lua`;
  - `docs/checklists/interface-language.md` line 120: "Closes the VERIFY marks of `GameData/FishingRanks.lua`,
    `GameData/NpcNames.lua` and `Core/MapPin.lua`";
  - `tests/wow.lua` line 867: `Core/MapPin.lua`;
  - `docs/tech-debt.md` line 36: the combat claim is in `.specify/memory/constitution.md` Principle III and
    `docs/architecture/fishing-mode.md`, not CLAUDE.md;
  - `docs/release-plan.md` lines 34-36: delete the "Move the older game data into `GameData/`" item.
- [X] T052 [US5] Right after T046, so `CLAUDE.md` and the constitution agree at every step, make the constitution
  PATCH 1.5.2 through `/speckit-constitution` (Governance), with the author:
  - Principle V's list of testable logic adds Channel, Catalog, Skill and GameData;
  - Principle VI names `GameData/` as the layer 0 data model of game entities (data only, `ns.GameData`).

  If the author wants to run it themselves, leave a note in the hand-over instead.

---

## Phase 8: User Story 6 - The in-game checklists cover the changes (Priority: P3)

**Goal**: research R13. The affected steps are unticked; nothing is duplicated.

**Independent Test**: read both checklists; every step below is `[ ]` with the note, and no step repeats.

- [X] T053 [P] [US6] In `docs/checklists/fishing-mode.md`, change `- [x]` to `- [ ]` and append "(re-run after spec
  008)" on these steps:
  - On.; Off.; `/reload` in the mode; Relog in the mode;
  - Gear page, first view; Chosen pole and extra items; Remove; Find fishing items; Leaving during a cast;
    Full bags;
  - Lure; Lure too high;
  - Clam;
  - Can learn; At the cap; Off (the rank notice);
  - Settings page; Debug report.

  Lines as listed in research R13; find them by title. Change the expectation of "Lure too high": "a lure above
  your Fishing skill is never offered (no 'Cannot apply' message); once the skill reaches it, the key offers it."
  The Debug report step also expects `needs: N` on each lure line and an `early L lookups: none` line.
- [X] T054 [P] [US6] In `docs/checklists/interface-language.md`, untick only the steps whose code changed, with the
  same note:
  - Journeyman taught at a trainer;
  - `/okf debug` next rank / names / pin;
  - GetSpellSubtext rank names;
  - the next-rank notice steps: at skill 50, below the level, notifications off, at the cap, the "Next rank" line;
  - the Pin button / minimap "Pin: next Fishing rank";
  - the own-pin replace popup;
  - the chat map link.

  The language steps stay ticked.
- [X] T055 [P] [US6] In `docs/checklists/catch-catalog.md`, steps 3, 4 and 5 (the pin, the player's own pin, caves
  and instances) expect the shared pin:
  - no question when the addon's pin is already at the place;
  - a cave spot pins on its zone map through the world position;
  - the toast is the same as for the rank pin.

  Check that no step of `fishing-mode.md` or `interface-language.md` repeats there.

---

## Phase 9: Polish & cross-cutting

- [X] T056 Run quickstart.md "Before the game" steps 1-3:
  - `npm run check`: its VERIFY list shows V43 and V44, not V7 or V32, and no GameData, private or test-name
    problem;
  - `npm test`: the number of `test(` cases is at least the baseline of T001 plus the new cases;
  - the two `git grep` searches find nothing.

  Compare with the T001 baseline and write the numbers into the "Baseline" line.
- [X] T057 Run `npm run dev` (it packages the working folder). The package must contain the nine `GameData/` files,
  `Exchange/CommReceive.lua` and `CatchDB/Index.lua`, and no test or doc.
- [X] T058 Write the hand-over for the author:
  - what changed;
  - that a game restart is needed (new files, TOC);
  - the unticked checklist steps to run (T053-T055);
  - the open VERIFY ids added (V43, V44);
  - the dead code list of T040;
  - the constitution note of T052 if it is still open.

  Do not commit or push unless the author asks.

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)** comes first.
- **Foundational (Phase 2)**: none. The GameData check (T011, T012) comes after the model (T004-T010), so
  `npm run check` stays green after every task (constitution Principle V).
- **US1 (Phase 3)** comes after Setup. It is the base for US2 (lure `skill`), US3 (no direct dependency), and US4
  T027 / T029 (they read moved data).
- **US2 (Phase 4)** comes after US1 (T007, T010).
- **US3 (Phase 5)** comes after US1, because `Catalog.lua` and `CatalogTab.lua` touch the same files as T010 only
  lightly. It can run beside US2.
- **US4 (Phase 6)** comes after US3 for T026-T031, which touch `CatalogTab.lua` and the renamed pin tests.
  - T035-T037 (renames) come after every task that edits those tests (T018, T024, T026, T027, T029).
  - T038 (the name rule) comes after T035-T037.
  - T033 and T034 (splits) come after T024 (`Comm.private`) and T029 (`CatchDB.OwnRecord`).
- **US5 (Phase 7)** comes after the code it documents: US1-US4. T041-T044 can start once T010, T019-T021, T033 and
  T034 have settled the marker lines.
- **US6 (Phase 8)** comes after US2 and US3 (the expectations it writes).
- **Polish (Phase 9)** comes last.

### Parallel opportunities

- **US1**:
  - T002, T003 and T011 (tests and check fixtures) can be written beside each other;
  - T005, T006, T007 and T008 create different files and can run in parallel;
  - T009, T010, T012 and T013 run in sequence.
- **US4**:
  - T027, T028, T030, T031 and T032 touch different files and can run in parallel;
  - T035, T036 and T037 touch different folders and can run in parallel.
- **US5**: T041, T045, T047, T048, T049, T050 and T051 touch different documents and can run in parallel; T046
  (CLAUDE.md) runs after T045.
- **US6**: T053, T054 and T055 touch different checklists.

### Parallel example: User Story 1

```text
T002 tests/gamedata/shape_test.lua      | T003 tests/gamedata/load_order_test.lua
T005 GameData/NpcNames.lua              | T006 GameData/Bobber.lua
T007 GameData/Lures.lua                 | T008 FishedContainers, FishingPoles, EquipSlots, Icons
T011 tests/tools/gamedata_check_test.mjs
then T009 (TOC) -> T010 (readers) -> T012 (check rule) -> T013 (search, check, test)
```

## Implementation Strategy

### MVP first

The MVP is Phases 1-4: the game data model and the lure rule. Then stop and validate:
- `npm run check`, `npm test`;
- hand `fishing-mode.md` "Lure too high" and the gear and lure steps to the author.

### Incremental delivery

1. US1 + US2: the model and the lure rule. This is the part a player notices.
2. US3: one map pin.
3. US4: cleanup, splits, test names. Each task stays green on its own.
4. US5: the documents, which describe the final code.
5. US6: the checklists for the next in-game run.

## Notes

- Tests first where a task says "fails before": run it and see it fail, then implement.
- A pure move (T033, T034, T035-T037) changes no logic; if a test changes meaning, stop and report.
- No `DB_SCHEMA` bump: no saved field changes (T002 pins the range values).
- English everywhere in code and docs; the hand-over to the author is in Ukrainian.
