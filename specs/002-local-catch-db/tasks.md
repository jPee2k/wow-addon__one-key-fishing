---

description: "Task list for the Local Catch Database feature"
---

# Tasks: Local Catch Database

**Input**: Design documents from `specs/002-local-catch-db/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md),
[verification.md](verification.md)

**Tests**: Included. The constitution (Principle V) requires tests for logic that runs without the game. Tests come
first in each phase and must fail before the implementation.

**Organization**: Tasks are grouped by user story (US1 = see what the current spot gives, P1; US2 = data from the
first login, P2; US3 = the author refreshes the bundled data, P3; US4 = trustworthy auction prices, P4).

**Verification debt**: the game opens on 2026-11-04. Phases 1 to 7 are done before that, on the assumptions V1-V9 of
[verification.md](verification.md); every line of code that relies on one carries `-- VERIFY(Vn): <what>`. Phase 8
runs after launch and closes the debt.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story the task belongs to
- Paths are relative to the repository root; addon files are under `OneKeyFishing/`.
- After every task: `npm run check` and `npm test` (project rule). A new WoW API global goes into
  `.luacheckrc` `read_globals` in the same task that first uses it (the check also fails on unused globals).
- A new English text goes into `OneKeyFishing/Locales/enUS.lua` and all nine translations in the same task
  (`npm test` checks completeness and placeholder order); no `L[...]` lookup at file load.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: the verification-debt gate, test tooling and the spike command.

- [X] T001 In `tools/check.mjs`, find every `VERIFY(<id>)` marker (regex `VERIFY\(([^)]+)\)`) in the Lua files of
  `OneKeyFishing/` and print them as a list `open verification markers: <file>:<line> <id> <text>` after the result
  line; open markers do not fail the check. Print nothing when there are none.
- [X] T002 In `tools/build.mjs`, in `--release` mode, scan the packaged Lua files read from the last commit for the
  same marker regex and `fail(...)` with the list when any is found ("open VERIFY markers: close the verification
  debt first"). `--dev` builds ignore markers.
- [X] T003 [P] In `CLAUDE.md`, document the `-- VERIFY(Vn): <what>` convention (assumption not yet checked in game,
  listed in the feature's `verification.md`; `npm run check` lists them; a release build refuses them) under
  "Commands" next to `npm run build`, and add the API dump links from research.md R11 to "Known API facts" as a
  way to check signatures without the game.
- [X] T004 [P] In `tests/run.mjs`, after the Lua tests, import every `tests/*_test.mjs` (filtered by the same
  name filter) and run its exported `tests` array of `{ name, fn }` (async allowed); count passes and failures with
  the Lua ones and print failures the same way. Keep the exit code rule.
- [X] T005 [P] In `tests/wow.lua`, add stubs, each driven by a global the tests set (document each in a comment):
  `C_Map.GetBestMapForUnit` returns `player_map_id` (default 1); `C_Map.GetMapInfo(id)` returns
  `{ mapID = id, name = map_names[id] or "Test Zone", mapType = 3, parentMapID = 0 }`;
  `C_Map.GetPlayerMapPosition(id, unit)` returns nil when `player_map_position` is nil, else an object with
  `GetXY()` returning its two numbers; `GetProfessions` returns `nil, nil, nil, 1` when `fishing_rank` is set and
  `GetProfessionInfo(1)` returns `"Fishing", 136245, fishing_rank, 300, 0, 0, 356`; `GetLootSourceInfo(slot)`
  returns `loot_sources[slot]` (a GUID) or nil; `GetBuildInfo` returns `build_version` (default `"1.60.1"`);
  `PanelTemplates_SetNumTabs`, `PanelTemplates_SetTab`, `PanelTemplates_TabResize` record calls in `panel_tabs`.
  Reset these globals in the per-test reset the file already has.
- [X] T006 Create `OneKeyFishing/Commands.lua` (TOC: last file) as the one place that declares every slash
  command (constitution 1.3.0, Principles II and VI): a table of `{ name, description, run }` with English
  descriptions and `run` calling the module function at runtime: `scan` -> `ns.Auction.Scan()`, `toggle` ->
  `ns.Mode.Toggle()`, `debug` -> `ns.ShowReport()`, `stats` -> `ns.StatsFrame.Toggle()`, `config` ->
  `ns.SettingsUI.Open()`. Remove the `ns.RegisterCommand` calls from `OneKeyFishing/Auction.lua`, `Mode.lua`,
  `Debug.lua`, `UI/StatsFrame.lua` and `UI/Settings.lua`; in `OneKeyFishing/Core.lua` replace `ns.RegisterCommand`
  with the dispatcher reading that table and print the help in English (`"v%s commands:"` without `L`); remove the
  six texts (`"v%s commands:"` and the five descriptions) from `Locales/enUS.lua` and all nine translations; update
  `tests/load_test.lua` (it calls `ns.RegisterCommand`) and add a test that `/okf` prints the English help on a
  non-English client; update `CLAUDE.md` (Core.lua slash commands, Localization.lua "in a `RegisterCommand`
  description", a new **Commands.lua** line).
- [X] T007 Create `OneKeyFishing/Spike.lua` (TOC: after `Debug.lua`) with a first line `-- VERIFY(spike): temporary;
  remove this file, its TOC line, its Commands.lua entry and tests/spike_test.lua` and `ns.ShowSpikeReport()`, declared
  as `spike` with the English description "print API facts for the verification checklist" in
  `OneKeyFishing/Commands.lua` (marked `-- VERIFY(spike)` there too); the report is English like the debug report; it
  shows in `ns.ShowCopyWindow` a report of: `GetBuildInfo()` (all four values, V7); `UnitChannelInfo("player")` spell
  ID; `C_Map.GetBestMapForUnit("player")`, its `GetMapInfo` mapType, parentMapID and name, the parent chain up to 0
  (V2); `C_Map.GetPlayerMapPosition(mapID, "player")` x and y or "nil" (V1); the restriction state for
  `Enum.AddOnRestrictionType.Map` via `C_RestrictedActions.GetAddOnRestrictionState` when it exists; for the last
  fishing loot (kept from `LOOT_READY` while `IsFishingLoot()`): every slot's link and every `GetLootSourceInfo(slot)`
  GUID with its type and object ID (split by `-`) (V3); for the last auction search (kept from the result events): item
  ID, number of results, `GetCommoditySearchResultsQuantity`, `HasFullCommoditySearchResults`, the first 5 results'
  `unitPrice` / `quantity` (commodities) or `buyoutAmount` / `quantity` (items), and whether the prices are ascending
  (V4, V5); whether `PanelTabButtonTemplate` tabs could be created (V6). Each part in `pcall`, like `Debug.lua`
  sections. Add new globals to `.luacheckrc`.

**Checkpoint**: `npm run check` lists the spike marker; `npm run build -- --release` (on a clean commit) refuses.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: saved data, the place key and recording into `mine` and the own record (research R2, R3, R8;
data-model.md). Blocks every story.

**CRITICAL**: no user story work can begin until this phase is complete.

### Tests first

- [X] T008 [P] Create `tests/catchdb_test.lua` with failing tests for the place key: `CatchDB.PlaceKey(1415, 3,
  "47")` is `"1415:3:47"`; with `player_map_id = 1415`, `player_map_position = { 0.43, 0.78 }`, `fishing_rank = 230`
  `CatchDB.GetCurrentPlace()` is `1415, 3, "47"`; x or y of exactly 1.0 gives digit 9; no position gives cell `"x"`;
  ranks 0, 74, 75, 299, 300, 375 give ranges 0, 0, 1, 3, 4, 4 ("`min(4, floor(rank / 75))`"); no Fishing gives nil;
  every produced key matches `^%d+:[0-4]:(%d%d|x)$`.
- [X] T009 [P] In `tests/catchdb_test.lua`, failing tests for recording: after `load_addon()` and a cast in fishing
  mode (`FISHING_CAST_START`, `advance(10)`, loot `{ fishing = true, items = { { 6291, 2 } } }` + `LOOT_READY`,
  `FISHING_CAST_STOP`), `ns.db.shared.mine["1415:3:47"]` and
  `ns.db.shared.records[myID].builds["1.60.1"]["1415:3:47"]` both have `c = 1, m = 0, t = 10`,
  `i[6291] = { 1, 2 }`, `px = 430, py = 780`; a cast without loot settles as `m = 1`; the place is the one at cast
  start even if `player_map_position` changes before the loot; a cast picked up after a `/reload`
  (`charDB.countedCast` equal to the channel start) still records its catch once, at the place read when it was
  picked up, with `t` counted from the pickup; fishing with the mode off records
  nothing; `myID` is 8 characters of `[a-z2-7]` and stays the same after a reload; `seq` grows at most once per
  60 s of `advance` and on `PLAYER_LOGOUT`; `CatchDB.GetVersion()` grows on every change.
- [X] T010 [P] In `tests/catchdb_test.lua`, failing tests for the pool part: with `loot_sources[1] =
  "GameObject-0-1-2-3-180582-4"` the cell gets `p = { c = 1, i = { [6291] = { 1, 2 } } }` (no `m`: a miss has no loot
  source) and the totals as well; with the bobber `"GameObject-0-1-2-3-35591-4"` or no source, no `p` is written.

- [X] T011 [P] In `tests/core_test.lua`, a failing test for the upgrade from 1.0.0 (FR-008, SC-007): saved data with
  `schema = 1`, `prices[6291] = { price = 500, time = 1 }` and a character DB with `stats.total`, `stats.zones` and
  `session` filled; after `load_addon()` `schema` is still 1, `shared.myID` exists, and `stats`, `session` and `prices`
  are unchanged field by field; the statistics window shows the same values as before.

### Implementation

- [X] T012 In `OneKeyFishing/Core.lua`, keep `DB_SCHEMA = 1` (only new fields, which `ApplyDefaults` fills; no
  migration, research R8) and add to `DB_DEFAULTS`: `statsTab = "stats"` (comment: `"stats" | "here"`) and `shared = {
  mine = {}, records = {} }`. `tests/core_test.lua` asserts that the schema stays 1.
- [X] T013 Create `OneKeyFishing/SeedData.lua` (TOC: after `Stats.lua`) as the empty seed in the format of
  [contracts/seed-data.md](contracts/seed-data.md): header `-- Generated by npm run harvest; do not edit.`,
  `ns.SeedData = { epoch = 0, built = "", build = "", absorbed = {}, resets = {}, cells = {} }`.
- [X] T014 In `OneKeyFishing/Catch.lua`, add `ns.IsPoolLoot()`: for the open loot, read `GetLootSourceInfo(slot)`
  GUIDs; true when a source is `GameObject` with an object ID (6th `-` field) other than `35591`, false when the only
  sources are the bobber, nil when there is no source; mark it `-- VERIFY(V3): pool loot comes from the pool's
  GameObject GUID, open water from the bobber (35591)`. Pass the result along: `ns.Fire("FISH_CAUGHT", items,
  fromPool)` (Stats ignores the new argument; update the message line in `CLAUDE.md`).
- [X] T015 Create `OneKeyFishing/CatchDB.lua` (TOC: after `SeedData.lua`) with `ns.CatchDB`: `PlaceKey`,
  `GetCurrentPlace` (map from `C_Map.GetBestMapForUnit("player")` as returned, `-- VERIFY(V2)`; position from
  `C_Map.GetPlayerMapPosition`, `-- VERIFY(V1): a position while fishing in the open world and cities, nil in
  instances`; range from `ns.Skill.Get()`), `GetVersion`; in `ADDON_LOADED` (after Core's handler) create
  `ns.db.shared.myID` when missing (8 random characters of `abcdefghijklmnopqrstuvwxyz234567`) and the own record `{ id,
  epoch = next epoch, seq = 0, builds = {} }`; the build key from `GetBuildInfo()` (first value, `"unknown"` when empty,
  `-- VERIFY(V7)`). Recording per data-model.md "State transitions": place and position read at `FISHING_CAST_START`,
  always, also for a cast picked up after a `/reload` (nothing is counted at the start, so nothing can be counted twice;
  `t` runs from the pickup), the stop time kept on `FISHING_CAST_STOP`, and the cast settled on `FISH_CAUGHT`
  (`c`/items/`p`) or `FISH_MISSED` (`m`), adding `t` (start to stop, at least 1 s) and `px`/`py` (rounded `x * 1000`, `y
  * 1000`, absent for cell `"x"`) then, each into both `mine` and the own record; items as `{ catches, pieces }` with
  "`i[id][1] <= i[id][2] <= 20 * i[id][1]`" (cap pieces per catch at 20); `seq` bump rule from research R3. No work at
  file load. Make T008-T010 pass.

**Checkpoint**: catches are recorded account-wide under numeric place keys; existing `stats_test.lua` unchanged.

---

## Phase 3: User Story 1 - See what the current spot gives (Priority: P1) MVP

**Goal**: tabs in the statistics window and the "What can be caught here" panel on the player's own data, with the
whole-map fallback and both filters (FR-009 to FR-017).

**Independent Test**: fish at one spot, open the tab, check items, chances, counts and miss rate; move to a spot with
few catches and to a new map; switch filters (quickstart.md "In game: the feature" steps 1, 3-7).

### Tests first

- [X] T016 [P] [US1] In `tests/catchdb_test.lua`, failing tests for `CatchDB.Query(mapID, cell, filter)` per
  [contracts/catchdb-api.md](contracts/catchdb-api.md) on own data only (empty seed): 60 catches at the spot ->
  `scope = "spot"`, `littleData = false`, items sorted by chance with `chance = catches containing / c` and
  `pieces = pieces / catches containing`; 20 at the spot and 300 on the map -> `scope = "map"` summing every key of
  the map including `"x"`; 20 and 30 -> `littleData = true`; nothing -> `scope = "none"`; `range = "all"` sums
  ranges 0-4; `source = "mine"` reads `mine`, `source = "all"` reads the own record; the result is cached until
  `GetVersion()` changes.
- [X] T017 [P] [US1] Create `tests/catchhere_test.lua` with failing tests: `/okf stats` shows two tabs with the
  texts "Statistics" and "What can be caught here"; clicking the second shows the panel and saves
  `ns.db.statsTab = "here"`; after `load_addon()` again the window opens on that tab; the skill filter starts at the
  own range and the source filter at "All" after a new login; when `fishing_rank` crosses into the next range the
  filter follows it, but not after the player picked a range by hand; with own catches the panel lists item rows
  with the chance as a percentage and "60 catches"; with 20 catches it says the numbers are for the whole map; with
  no data it
  shows the empty text; when `player_map_position` changes and `tick` runs, the panel follows; with
  `PanelTemplates_SetNumTabs` missing (set to nil) the tabs are plain buttons and still switch.

### Implementation

- [X] T018 [US1] In `OneKeyFishing/CatchDB.lua`, implement `Query` (sums per data-model.md "Views"; fallback and
  little-data threshold 50; cache per key and filter until the version changes) and `Describe` (lines for the debug
  report, no `myID`). Make T016 pass.
- [X] T019 [US1] Add the panel texts to `OneKeyFishing/Locales/enUS.lua` and all nine translations: the tab names
  "Statistics" and "What can be caught here"; "Skill: %s", "All skill levels", "Source: %s", "All", "Only mine";
  "%d catches", "Nothing caught: %s", "Numbers for the whole map: few catches at this spot.", "Little data",
  "Nothing has been caught here yet.", "Try \"All skill levels\": little data for your skill.", "and %d more",
  "No bundled data in this version: only your own catches are shown.";
  column headers "Item", "Chance", "Per catch", "Price"; the skill range labels "0-74", "75-149", "150-224",
  "225-299", "300+" stay plain text without `L`.
- [X] T020 [US1] Create `OneKeyFishing/UI/CatchHere.lua` (TOC: before `UI/StatsFrame.lua`) with `ns.CatchHere.Create
  (parent)` and `Refresh()`: header with the place name (`ns.Stats.PlaceName(mapID)`, "Zone - Subzone"), the scope text,
  "%d catches" and the miss line ("Nothing caught: %s" with the percentage); a skill filter button and a source filter
  button opening `MenuUtil.CreateContextMenu` menus (guarded as in `UI/Settings.lua`); up to 16 rows (icon, name, chance
  or "Little data", average pieces with one decimal, price via `ns.Prices.FormatValue`) and "and %d more"; a row tooltip
  with the item and its price (`ns.ShowItemTooltip`); filter state in locals, reset on login; the skill filter follows
  the current range while the player has not picked a range by hand since login, and a hand-picked range stays until the
  next login. Item names that are not loaded yet fill in on `GET_ITEM_INFO_RECEIVED`.
- [X] T021 [US1] In `OneKeyFishing/UI/StatsFrame.lua`, move today's content into a child frame `f.statsPage`, add
  `f.herePage = ns.CatchHere.Create(f)`, and two tabs at the bottom from `PanelTabButtonTemplate`
  (`f.Tabs`, `PanelTemplates_SetNumTabs(f, 2)`, `PanelTemplates_SetTab`, `PanelTemplates_TabResize`), guarded
  (`-- VERIFY(V6): PanelTabButtonTemplate renders in Forever`) with a fallback to `ns.CreateButton` buttons; switch
  pages on click and save `ns.db.statsTab`; open on the saved tab; the 1 s tick also refreshes the panel when
  `CatchDB.GetVersion()`, the current place key or a filter changed. Make T017 pass.

**Checkpoint**: US1 works on own data; the "Statistics" tab is unchanged (SC-007).

---

## Phase 4: User Story 2 - Data from the first login (Priority: P2)

**Goal**: the panel merges the bundled seed with the own record without counting anything twice (FR-018 to FR-020).

**Independent Test**: with a seed covering a spot and no own catches, the panel shows seed numbers; 5 own catches
add exactly 5; "Only mine" shows only own catches (quickstart.md "In game: the feature" steps 2, 3, 5).

### Tests first

- [X] T022 [P] [US2] In `tests/catchdb_test.lua`, failing tests with a test seed set on `ns.SeedData` before
  `load_addon()`: seed 1,000 catches at a key plus 5 own catches -> `Query` "All" gives 1,005 and "Only mine" 5;
  `absorbed[myID] = { [record.epoch] = record.seq }` and `seed.epoch` higher -> after `load_addon()` the own record
  rolls to a new empty one with `epoch = seed.epoch` and "All" equals the seed, while `mine` keeps its counts; a seed
  that holds the record only up to an older seq -> the old record is kept under `"<myID>@<epoch>"`, not counted, and a
  new one starts; `absorbed` missing `myID` -> the own record counts in full; `resets[1415] = "1.60.2"` -> own cells of
  map 1415 under build `"1.60.1"` are left out of "All"; a missing or malformed `ns.SeedData` -> treated as an empty
  seed with epoch 0 and `CatchDB.HasSeed()` false; a generated seed of 3,000 places across 300 maps -> `Query` for a map
  fallback returns the right sums and the per-map index is built once (count calls through a test hook).
- [X] T023 [P] [US2] Extend `tests/catchhere_test.lua`: with a seed and no own catches the panel lists the seed's
  items; switching the source filter to "Only mine" shows the empty text.

### Implementation

- [X] T024 [US2] In `OneKeyFishing/CatchDB.lua`, read `ns.SeedData` at runtime (validated: tables where expected,
  else empty seed), apply the epoch check from data-model.md "State transitions" once in `ADDON_LOADED`, add the
  seed cells to "All", leave out own old-build cells of maps in `seed.resets`, build the per-map index of the seed
  lazily on first use; expose `CatchDB.HasSeed()` (false when the seed is missing, malformed or has no cells) and
  let `UI/CatchHere.lua` show "No bundled data in this version: only your own catches are shown." under source "All"
  when it is false. Make T022 and T023 pass.
- [X] T025 [US2] In `tools/check.mjs`, check `OneKeyFishing/SeedData.lua`: at most 1 MB; parses with `luaparse`;
  assigns `ns.SeedData` a table with `epoch` (number), `built`, `build` (strings), `absorbed`, `resets`, `cells`
  (tables); every `cells` key matches `^\d+:[0-4]:(\d\d|x)$`.

**Checkpoint**: US1 and US2 work together; the empty seed changes nothing.

---

## Phase 5: User Story 3 - The author refreshes the bundled data (Priority: P3)

**Goal**: `npm run harvest` per [contracts/harvest-command.md](contracts/harvest-command.md) (FR-021 to FR-024).

**Independent Test**: run the harvest on prepared files (two accounts, a friend's file, a broken file), check the
written seed and the report; run again: no change; run with `--reset`: the map's old numbers are gone.

### Tests first

- [X] T026 [P] [US3] Create `tests/harvest_test.mjs` (exported `tests` array) that builds in `os.tmpdir()` a fake game
  tree `<tmp>/Game/Interface/AddOns` and `<tmp>/Game/WTF/Account/{A,B}/SavedVariables/OneKeyFishing.lua` with
  `OneKeyFishingDB = { shared = { records = { ... } } }`, a friend's file and a broken file (not valid Lua), and calls
  the exported `harvest({ addonsDir, files, reset, outDir })` of `tools/harvest.mjs`. Failing tests: the sums equal the
  sum of all valid records; the broken file is listed as rejected and a cell with "`c + m <= t`" violated is skipped
  with a note, while the rest of that file is used; `epoch` grows by 1 and `absorbed` names every unit with the seq
  summed (`absorbed[id][epoch] = seq`); a second run with the same files gives the same `cells`; a record with a higher
  `seq` replaces the stored one for the same `id@epoch`; `--reset 1415` drops map 1415 cells of older builds and stores
  `resets`; a result over 1 MB writes nothing and reports the error; every written line is at most 120 characters and
  ASCII; keys are sorted.

### Implementation

- [X] T027 [US3] Create `tools/harvest.mjs`: CLI parsing (`[files...] [--reset <mapID>]`), `addonsDir()` from
  `tools/addon.mjs` (accounts under `path.resolve(addonsDir, "..", "..", "WTF", "Account")`), reading with `luaparse`
  and converting table constructors only (never executing), validation per contracts/harvest-command.md and
  data-model.md "Validation" (IDs "8 base32 characters", builds `digits.digits.digits`, keys `^\d+:[0-4]:(\d\d|x)$`, at
  most 20,000 distinct places per record; an odd cell or build is skipped with a note, not the record), merge into
  `seed/contributions.json` by `id@epoch` and `seq`, sums with `k`, writing `OneKeyFishing/SeedData.lua` per
  contracts/seed-data.md (sorted keys, wrapped at 120 characters, ASCII), the report and exit codes; export
  `harvest(options)` for the test. Make T026 pass.
- [X] T028 [P] [US3] Add `"harvest": "node tools/harvest.mjs"` to `package.json` scripts, `seed` to the `.pkgmeta`
  `ignore` list, and create `seed/contributions.json` as `{ "epoch": 0, "resets": {}, "contributions": {} }`.

- [X] T029 [US3] Add `--synthetic <places>` to `tools/harvest.mjs` (and a test in `tests/harvest_test.mjs`): writes a
  valid `OneKeyFishing/SeedData.lua` of that many random places (about 10 per map, 3 to 8 items each, random counts
  within the validation rules) without touching `seed/contributions.json`, and prints "synthetic seed: do not
  commit, restore with git checkout OneKeyFishing/SeedData.lua". Used for the V8 load test in game.

**Checkpoint**: the author can produce a seed with one command (SC-006).

---

## Phase 6: User Story 4 - Trustworthy auction prices (Priority: P4)

**Goal**: robust auction price and the "few lots" rule (FR-025 to FR-027, research R6).

**Independent Test**: scan items with a normal market, with one extreme lot, and with few pieces; compare the shown
prices and values (quickstart.md "In game: the feature" step 8).

### Tests first

- [X] T030 [P] [US4] Extend the `tests/wow.lua` auction stubs: `commodity_results[itemID]` (list of
  `{ unitPrice, quantity }`) behind `GetNumCommoditySearchResults`, `GetCommoditySearchResultInfo(itemID, i)`
  (`{ unitPrice = , quantity = }`), `GetCommoditySearchResultsQuantity` (sum, or `commodity_total[itemID]`),
  `HasFullCommoditySearchResults` (true); `item_results[itemID]` (list of `{ buyoutAmount, quantity }`) behind
  `GetNumItemSearchResults(itemKey)` and `GetItemSearchResultInfo(itemKey, i)`.
- [X] T031 [P] [US4] Create `tests/prices_test.lua` with failing tests: 100 pieces at 2 gold plus 1 at 1 copper ->
  price within 5% of 2 gold; plus 1 at 9,999 gold instead -> the same; results given in a shuffled order -> the same
  price (sorted locally); 3 pieces -> `quantity = 3`, `Prices.GetAuction` returns `fewLots = true`, `Prices.Get`
  returns the vendor price; an auction price below the vendor price -> `Prices.Get` returns the vendor price; a
  1.0.0 entry without `quantity` -> used as before, `fewLots = false`; item results use `buyoutAmount / quantity`
  and skip bid-only results.

### Implementation

- [X] T032 [US4] In `OneKeyFishing/Auction.lua`, on `COMMODITY_SEARCH_RESULTS_UPDATED` and `ITEM_SEARCH_RESULTS_UPDATED`
  collect the loaded results, sort by unit price, average the cheapest `max(1, ceil(total * 0.2))` pieces (`total` from
  `GetCommoditySearchResultsQuantity` when available, else the loaded sum) and store `prices[itemID] = { price,
  quantity, lots, time }` (`quantity`: the pieces loaded, `lots`: the result rows the price came from); mark the
  assumptions `-- VERIFY(V4): unitPrice/quantity per result, total from GetCommoditySearchResultsQuantity` and `--
  VERIFY(V5): buyoutAmount is for the whole auction`; keep the coverage (pieces loaded / total) for the debug report;
  update the file header comment. Make T031 pass with T033.
- [X] T033 [US4] In `OneKeyFishing/Prices.lua`, `Prices.Get` returns the vendor price when the auction entry has
  `quantity < 5` or `lots < 3`; add `Prices.GetAuction(itemID)` returning `price, fewLots`; update the header comment.
- [X] T034 [US4] Show the "few lots" mark: in `OneKeyFishing/UI/CatchHere.lua` rows and the top catches of
  `OneKeyFishing/UI/StatsFrame.lua` (a small "(few lots)" after the price and the auction price in the row tooltip);
  change the "Value" row tip text; add the texts ("few lots", "Auction price: %s (few lots)", the new value tip "Items
  caught, at the higher of vendor and auction price; with few lots listed, the vendor price.") to `Locales/enUS.lua` and
  all nine translations, removing the old tip text.

**Checkpoint**: all four stories work; SC-005 holds in the tests.

---

## Phase 7: Polish & Cross-Cutting Concerns (before launch)

- [X] T035 [P] In `OneKeyFishing/Debug.lua`, add a "Catch database" section from `ns.CatchDB.Describe()` (seed
  epoch, seed places, own places, current place key, pool detection result of the last fishing loot) and the last
  price scan coverage; no `myID`.
- [X] T036 [P] Update `CLAUDE.md` Architecture: `SeedData.lua`, `CatchDB.lua`, `UI/CatchHere.lua`, the tabs in
  StatsFrame, `ns.IsPoolLoot` and the `FISH_CAUGHT` pool argument, the price rule, `npm run harvest` and `seed/` under
  Commands; keep `npm run check` rule list current (VERIFY markers, seed check).
- [X] T037 [P] Update `README.md` (the new tab, what the bundled data is, the price rule, privacy: what is stored),
  `CHANGELOG.md` (`## [Unreleased]` entry), `docs/publishing.md` (run `npm run harvest` and commit the seed before a
  release; no open VERIFY markers), `docs/ROADMAP.md` (items 1 and 2 link to `docs/shared-db-plan.md` and
  this spec).
- [X] T038 [P] Create `docs/checklists/catch-database.md` from quickstart.md "In game: spike" and "In game: the
  feature", with a checkbox per step and the V-IDs each step closes, ready for launch day.
- [X] T039 Run `npm run check`, `npm test` and `npm run dev`; confirm the only open markers are V1-V7 and `spike`,
  each listed in verification.md; update the "Status" column of verification.md to "Built, waiting for launch".

**Checkpoint**: the feature is complete except for the in-game verification; it cannot be released yet.

---

## Phase 8: After launch (2026-11-04): close the verification debt

**Blocked until the game opens.** Each task is the author's in-game step plus the follow-up in code, on
`002-shared-db`. Part 1 is not released on its own: release 1.2.0 ships all four parts of the shared catch database
together (`docs/shared-db-plan.md` "Release 1.2.0"). T040 runs in the same game session as the spike steps of the
later parts.

- [ ] T040 Author: run `docs/checklists/catch-database.md` "Spike" steps and paste the `/okf spike` reports.
- [ ] T041 Record the answers in `docs/forever-api.md`; for each of V1-V7 either remove its markers (the
  assumption held) or change the code to the real behaviour (with tests) and then remove the markers; tick the items
  in `specs/002-local-catch-db/verification.md`.
- [ ] T042 Only when the spike steps of every part have run (the later parts add their own sections to
  `/okf spike`): remove `OneKeyFishing/Spike.lua`, its TOC line, the `spike` entry in `OneKeyFishing/Commands.lua`,
  and `tests/spike_test.lua` (`docs/shared-db-plan.md` "Release 1.2.0", step 3).
- [ ] T043 Author: run the "Feature" steps of `docs/checklists/catch-database.md` (closes V6, V8, V9; for V8 first
  `npm run harvest -- --synthetic 3000` and `npm run install-addon`, then `git checkout OneKeyFishing/SeedData.lua`);
  fix what fails and repeat.
- [ ] T044 Author: fish, then run `npm run harvest` (plus friends' files) for the first real seed; commit
  `OneKeyFishing/SeedData.lua` and `seed/contributions.json`.
- [ ] T045 Release 1.2.0 with the other parts (the one release task for all four parts; the last task of each
  later part points here), per `docs/shared-db-plan.md` "Release 1.2.0" and
  `docs/publishing.md` (`npm run build` must pass with no VERIFY markers).

---

## Dependencies & Execution Order

- **Phase 1** (T001-T007): no dependencies; T001 before T002 (shared regex wording), T005 before the tests that use
  the stubs.
- **Phase 2** (T008-T015): after T005; T008-T010 before T015; T012, T013, T014 before T015.
- **US1** (T016-T021): after Phase 2. T018 before T020-T021; T019 before T020.
- **US2** (T022-T025): after T018 (Query). Independent of the panel except T023 (needs T021).
- **US3** (T026-T029): after T013 (seed format); independent of US1/US2 code; T029 after T027.
- **US4** (T030-T034): after Phase 1 only (T030 extends T005); T034 needs T020/T021 for the panel mark.
- **Phase 7**: after the stories it documents. **Phase 8**: after 2026-11-04 and Phase 7; T042 and T045 after
  the other parts (`docs/shared-db-plan.md` "Release 1.2.0").

## Parallel Example: User Story 1

```text
T016 Query tests in tests/catchdb_test.lua
T017 Panel tests in tests/catchhere_test.lua
```

Then T018 (CatchDB.Query) and T019 (texts) in parallel; T020 and T021 after them.

## Parallel Example: across stories

After Phase 2, US3 (harvest, Node only) and US4 (prices) can be built alongside US1 and US2: they touch different
files (`tools/harvest.mjs`, `Auction.lua`, `Prices.lua`) until T034.

## Implementation Strategy

1. **MVP**: Phases 1-3: recording plus the panel on own data. Useful even with an empty seed.
2. **Add US2** (seed merge) and **US3** (harvest) together: the first seed proves both.
3. **Add US4** (prices).
4. **Phase 7** before launch, so launch day is only verification.
5. **Phase 8** after 2026-11-04, then release 1.2.0 together with the other parts.

## Notes

- Every task keeps `npm run check` and `npm test` green; commit after each task or logical group.
- A `VERIFY` marker is removed only after the author's in-game confirmation (Principle IV), never because a source
  "says so".
