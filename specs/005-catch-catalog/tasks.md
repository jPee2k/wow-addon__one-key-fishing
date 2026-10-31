---

description: "Task list for the Catch Catalog, Map Pins and Catch Chances in Tooltips"
---

# Tasks: Catch Catalog, Map Pins and Catch Chances in Tooltips

**Input**: Design documents from `specs/005-catch-catalog/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/api.md](contracts/api.md), [contracts/ui.md](contracts/ui.md),
[quickstart.md](quickstart.md), [verification.md](verification.md); the code of parts 1 to 3
(`specs/002-local-catch-db/`, `specs/003-guild-group-sync/`, `specs/004-public-channel-sync/`: CatchDB, the seed, the
harvest, Share, the tabs, the weights and the "Unknown item" rows).

**Tests**: Included. The constitution (Principle V) requires tests for logic that runs without the game. Tests come
first in each phase and must fail before the implementation.

**Organization**: Tasks are grouped by user story:

| Story | What the player gets | Priority |
| --- | --- | --- |
| US1 | Find where an item is caught (the catalog tab, the search, zones and spots with subzone names, the ways in) | P1 |
| US2 | Go to the spot (the map pin, the arrow, the replace question) | P2 |
| US3 | Chances where the player already looks (item and minimap tooltips, the setting) | P3 |
| US4 | Pools apart from open water (the "Water" filter) | P4 |

**Verification debt**: the game opens on 2026-11-04. Phases 1 to 7 are done before that, on the assumptions V30-V40
of [verification.md](verification.md); every line of code that relies on one of them carries
`-- VERIFY(Vn): <what>`. Phase 8 runs after launch, together with the debt of the other parts.

**Branch and release**: all shared-db work stays on `002-shared-db` (no branch per spec). Release 1.2.0 ships all four
parts together once the debt of all of them is closed (`docs/shared-db-plan.md` "Release 1.2.0").

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story the task belongs to
- Paths are relative to the repository root; addon files are under `OneKeyFishing/`.
- After every task, run `npm run check` and `npm test` (project rule).
- A new WoW API global goes into `.luacheckrc` `read_globals` in the same task that first uses it in addon code. The
  check also fails on unused globals, so a stub-only global waits for its first use.
- A new English text goes into `OneKeyFishing/Locales/enUS.lua` and all nine translations in the same task. Keys
  are literal (the list is in [contracts/ui.md](contracts/ui.md)), color codes stay outside the strings, and no
  `L[...]` lookup runs at file load. `npm test` checks completeness and placeholder order.
- Lua stays 5.1/5.3-neutral: no `utf8` library, no `//`, no `goto`, byte patterns only for UTF-8.
- Constants go at the top of their file with a comment, named as below: `MAX_AREAS = 8`, `STEP_MS = 3`,
  `MAPS_PER_STEP = 8`, `SYNC_MAPS = 4`, `NAME_REQUESTS_PER_STEP = 20`, `DEFAULT_INDEX_DELAY = 10`,
  `PIN_EPSILON = 0.0005`, `LITTLE_DATA = 50` (CatchDB's, reused through the views).
- A new file or a TOC change needs a game restart in the in-game checks, not just `/reload` (CLAUDE.md).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: test fakes for every new API, and the launch-day spike questions.

- [X] T001 In `tests/wow.lua`, add the map, area and item fakes. Each is driven by globals the tests set; document
  each global in the header comment and reset all of them in the existing per-test reset.
  - **Maps**: `map_types[mapID]` and `map_parents[mapID]` fill `mapType` (default 3, Zone) and `parentMapID`
    (default 0) of `C_Map.GetMapInfo`; `map_info_missing[mapID] = true` makes it return nil.
    `Enum.UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 }`.
  - **Waypoints**: `waypoint_maps[mapID] = true` makes `C_Map.CanSetUserWaypointOnMap(mapID)` true (default false).
    `C_Map.SetUserWaypoint(point)` records the point in `user_waypoint` and appends it to `waypoint_sets`, returning
    `waypoint_result` (default true; on false nothing is stored). `C_Map.HasUserWaypoint()` is
    `user_waypoint ~= nil`; `C_Map.GetUserWaypoint()` returns it; `C_Map.ClearUserWaypoint()` clears it.
    `UiMapPoint.CreateFromCoordinates(mapID, x, y, z)` returns `{ uiMapID = mapID, position = CreateVector2D(x, y),
    z = z }`. `CreateVector2D(x, y)` returns `{ x = x, y = y, GetXY = function(self) return self.x, self.y end }`.
  - **World positions**: `map_world[mapID] = { continent, left, top, width, height }` places a map in world space.
    `C_Map.GetWorldPosFromMapPos(mapID, pos)` returns `continent, CreateVector2D(left + pos.x * width,
    top + pos.y * height)`. `C_Map.GetMapPosFromWorldPos(continent, worldPos, overrideMapID)` returns
    `overrideMapID` and the inverse position on that map, or nothing when the continent differs or the map has no
    entry.
  - **Super tracking, rules, map**: `C_SuperTrack.SetSuperTrackedUserWaypoint(on)` sets `super_tracked`;
    `C_SuperTrack.IsSuperTrackingUserWaypoint()` returns it. `Enum.GameRule = { WorldMapTrackingPinDisabled = 1 }`
    (a stand-in value) and `C_GameRules.IsGameRuleActive(rule)` returns `game_rules[rule] == true`. The global
    `OpenWorldMap(mapID)` appends `mapID` to `world_maps_opened`.
  - **Areas**: `sub_zone` (default `""`) is returned by `GetSubZoneText()` (replace the fixed `""`).
    `area_names[areaID]` is returned by `C_Map.GetAreaInfo(areaID)`. `explored_areas` (a list of IDs) is returned by
    `C_MapExplorationInfo.GetExploredAreaIDsAtPosition(mapID, pos)`, and each call appends `{ mapID, pos.x, pos.y }`
    to `area_lookups`.
  - **Item names**: `item_names[itemID]` (default `"Item " .. itemID`) is returned by `C_Item.GetItemNameByID`,
    which returns nil for `unknown_items[itemID]`. `item_qualities[itemID]` (default 1) is returned by
    `C_Item.GetItemQualityByID`, nil for unknown items. `Enum.ItemQuality = { Poor = 0, Common = 1, Uncommon = 2,
    Rare = 3, Epic = 4 }` (keep any existing entries).
  - **Folding and order**: `CaseAccentInsensitiveParse` and `strcmputf8i` stay undefined unless the test sets
    `game_fold = true` before `load_addon()`. Then `CaseAccentInsensitiveParse(text)` returns `text:lower()` with
    both `"\195\137"` (capital E acute) and `"\195\169"` (e acute) replaced by `"e"`, folding case and accent as
    the game's function does. `strcmputf8i(a, b)` compares the two parsed strings and returns -1, 0
    or 1.
- [X] T002 In `tests/wow.lua`, add the UI fakes (same rules as T001).
  - **Scroll list**: `CreateFrame` with the templates `"WowScrollBoxList"`, `"MinimalScrollBar"` and
    `"SearchBoxTemplate"` returns a normal fake frame marked with `frame.template`. `CreateDataProvider(list)`
    returns an object with `Insert`, `Flush`, `GetSize`, `Enumerate` and the list in `provider.elements`.
    `CreateScrollBoxListLinearView()` returns a view with `SetElementInitializer(template, fn)` and
    `SetElementExtent(n)`, kept on the view. `ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)` stores the
    view on the box. `box:SetDataProvider(provider, retain)` stores it. Helper `scroll_rows(box)` creates one row
    frame per element, runs the initializer on it and returns the rows. With `no_scroll_templates = true` (before
    `load_addon()`), `CreateFrame` with those templates raises an error, so the fallback can be tested.
  - **Search box**: the frame of `"SearchBoxTemplate"` has `GetText` / `SetText` and an `Instructions` font string;
    helper `type_text(box, text)` sets the text and runs its `OnTextChanged` script with `userInput = true`.
  - **Tooltips**: `GameTooltip:AddDoubleLine(left, right)` appends `left .. " | " .. right` to `tooltip_lines`.
    `ItemRefTooltip` is a second tooltip with its own `itemref_lines`, with the same methods.
    `TooltipDataProcessor.AddTooltipPostCall(dataType, fn)` appends `fn` to `tooltip_post_calls[dataType]`;
    `Enum.TooltipDataType = { Item = 0 }`. Helper `show_item_tooltip(tooltip, itemID)` starts the tooltip over and
    runs every item post call with `(tooltip, { id = itemID })`.
  - **Clock**: `debugprofilestop` stays undefined by default. `profile_ms` (a number the test sets) makes it
    return that value, so a step budget can be tested; `profile_step` (when set) is added to `profile_ms` on each
    call.
- [X] T003 [P] In `OneKeyFishing/Spike.lua`, add a "Map pins and areas (V30-V36)" section to `BuildReport()`
  (research R13). It reads only and changes nothing in the game. Every call is guarded with `pcall` and a nil check.
  1. Pins: the current map (`C_Map.GetBestMapForUnit("player")`), its `mapType` and `parentMapID`;
     `CanSetUserWaypointOnMap` for the map and for its parent; `C_GameRules.IsGameRuleActive(
     Enum.GameRule.WorldMapTrackingPinDisabled)`; `GetCVar("showInGameNavigation")`; `C_Map.HasUserWaypoint()` and
     the map and position of `GetUserWaypoint()`; for a Micro map, the parent position that
     `GetWorldPosFromMapPos` / `GetMapPosFromWorldPos` give for the player's position.
  2. Areas: `GetExploredAreaIDsAtPosition` at the player's position, each ID with its `C_Map.GetAreaInfo` name,
     `GetSubZoneText()`, and the area `CatchDB.GetArea` keeps (until T021 exists: "not built yet").
  3. Items: for the first three item IDs of the bundled seed, `GetItemNameByID`, `GetItemQualityByID` and whether
     `GetItemInfoInstant` knows it, before and (on the next report) after one `RequestLoadItemDataByID` each.
  4. Folding: `CaseAccentInsensitiveParse ~= nil`, its result for `"Ab\195\137 \208\169"` (A, b, E acute, a space,
     Cyrillic Shcha), and `strcmputf8i("b", "A")`.
  5. UI: whether `CreateScrollBoxListLinearView`, `ScrollUtil.InitScrollBoxListWithScrollBar`, `CreateDataProvider`
     exist, whether `CreateFrame` succeeds with `WowScrollBoxList`, `MinimalScrollBar` and `SearchBoxTemplate`, and
     `C_Texture.GetAtlasInfo("Waypoint-MapPin-Untracked") ~= nil`.
- [X] T004 Extend `tests/spike_test.lua` for T003: the section is present with its five parts, sets no waypoint
  (`waypoint_sets` empty, `world_maps_opened` empty), and survives every new API call failing (each stub raising an
  error).

**Checkpoint**: the fakes and the spike section are in place; `npm test` passes.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the text folding, the per-map views with their change stamps, and the catalog's index; every story
builds on them.

**CRITICAL**: no user story work can begin until this phase is complete.

### Tests for the foundation

- [X] T005 [P] Create `tests/fold_test.lua` for `ns.FoldCase`, `ns.SearchKey` and `ns.CompareText`
  ([contracts/api.md](contracts/api.md) "Data.lua").
  - ASCII capitals are lowered; Latin-1 capitals U+00C0-U+00DE are lowered by +0x20, except U+00D7 (the
    multiplication sign).
  - Cyrillic U+0410-U+042F goes to U+0430-U+044F, and U+0400-U+040F to U+0450-U+045F.
  - Korean and Chinese text is unchanged, and so is an already lower string. The function is the same under the
    5.1 rules of the stub (no `utf8`).
  - With `game_fold = true`, `SearchKey("Truite \195\137")` uses `CaseAccentInsensitiveParse` ("truite e").
    `CompareText` uses `strcmputf8i` when present, else the folded byte order.
- [X] T006 [P] Create `tests/catchdb_views_test.lua` for `CatchDB.QueryMap`, `QueryCells`, `Maps` and `MapStamp`
  (data-model.md "Views", "Change stamps").
  - `QueryMap` equals the map view `Query` gives for a spot with few catches. Its scope is `"map"` with catches,
    `"none"` without.
  - `QueryCells` gives one view per cell with catches, carrying `cell`, `point` and `items[].ranges`:
    - `point` is `px / n / 1000` over cells with positions;
    - `point` is nil for cell `"x"`;
    - `ranges` is the lowest and highest range the item was caught in.
  - `Maps({ source = "all" })` lists the maps of the seed, the own record and, with sharing on, other records;
    `Maps({ source = "mine" })` lists only `mine`.
  - **Stamps:**
    - A settled cast on map A changes `MapStamp(A)` but not `MapStamp(B)`.
    - `SHARED_DATA_CHANGED` with a record's key changes the stamps of that record's maps, before and after the
      change.
    - Without keys it changes every stamp, and so does `Share.SetEnabled`.
  - **Cache:** a second `QueryMap` without a change returns the same table; a stamp change returns a new one.
  - **Own-cells index:** the sums with it equal the sums of a full walk, after catches on new and old keys.
- [X] T007 [P] Create `tests/catalog_test.lua` (the core; US1-US3 extend it).
  - **The index.**
    - Built 10 s after the first `PLAYER_ENTERING_WORLD` of the Lua session: a login (`enter_world(true, false)`,
      then `advance(10)`) or a `/reload` (`enter_world(false, true)` in a fresh state). A later loading screen
      (`enter_world(false, false)`) does not start it again.
    - With `profile_ms`/`profile_step` set, every step ends at `STEP_MS`; without a clock, at `MAPS_PER_STEP` maps.
      `Catalog.Items` returns `"building"` until the last step, then `"ready"`.
    - After a catch on one map: with up to `SYNC_MAPS` changed maps the next read (`Items` or `Places`) is
      complete at once; with more, the stale index answers, the read starts the rebuild in steps (only one runs at a
      time), and a read after the steps shows the new data.
    - `Catalog.GetVersion()` grows with every change of the items.
  - **The items.**
    - The seed's, the own catch's and other players' items (sharing on) are listed.
    - An item only others reported shows under part 3's three-contributions rule.
    - Sharing off drops other players' items.
    - An item listed in `unknown_items` is hidden, asked for in `item_load_requests` (at most
      `NAME_REQUESTS_PER_STEP` per step), and listed after `item_loaded(id, true)`.
    - A Poor item is hidden without search text and listed with a matching one.
    - A lower-case search finds item names in Latin with accents (`"Truite \195\137"` by `"truite \195\169"`),
      Cyrillic (`"\208\169\209\131\208\186\208\176"` by `"\209\137\209\131\208\186\208\176"`), Korean and Chinese
      (as typed) (SC-001).
    - The order is by `CompareText`, and every row has `zones`.
  - **The places.** `Catalog.Places` sorts reliable zones (50 catches or more) by chance, highest first, then the
    little-data ones by the item's catches; ties by map ID. Each has `name`, `chance`, `catches`, `players`,
    `littleData`, `ranges`.
  - **The names.**
    - `Catalog.ZoneName`: a zone; a Micro map whose parent is a zone ("Zone - Cave"); a Dungeon map the same way;
      "Unknown zone (%d)" without map info.
    - `Catalog.Find` and `Catalog.CommandArg`: an item link gives its ID, empty text nil, other text itself.
  - **The report.** `Catalog.Describe()` lists state, maps, items, stale, the build times and the name queue.
- [X] T008 [P] Create `tests/catalog_load_test.lua` (research R11, SC-003). It fills the largest database: 3,000 seed
  cells on 150 maps with 3 items each, 1,000 other records of 20 places (20,000 places), and 2,000 own cells in
  `mine` and the own record. Then:
  - the default index builds in steps of at most `MAPS_PER_STEP` maps;
  - one own catch afterwards changes exactly one map's stamp and recomputes one map;
  - `Catalog.Items` with a search over all names, `Catalog.Places` of the most common item, and `QueryCells` of the
    largest map each finish in one call;
  - the test prints the counts (maps, items, steps) to the test log.

### Implementation for the foundation

- [X] T009 In `OneKeyFishing/Data.lua`, add `ns.FoldCase`, `ns.SearchKey` and `ns.CompareText`
  ([contracts/api.md](contracts/api.md)). `FoldCase` lowers ASCII with `string.lower`, then folds by `gsub`:
  - Latin-1: `"\195[\128-\158]"`, skipping `"\195\151"`, by adding 32 to the second byte;
  - Cyrillic `"\208[\144-\159]"` to `"\208[\176-\191]"`;
  - Cyrillic `"\208[\160-\175]"` to `"\209[\128-\143]"`;
  - Cyrillic `"\208[\128-\143]"` to `"\209[\144-\159]"`.
  The comment says why: `string.lower` handles ASCII only. `SearchKey` uses `CaseAccentInsensitiveParse` when it
  is a function (`-- VERIFY(V36): CaseAccentInsensitiveParse folds case and accents of the client's language`).
  `CompareText` uses `strcmputf8i` the same way. Add both globals to `.luacheckrc`. Make T005 pass.
- [X] T010 In `OneKeyFishing/CatchDB.lua`, add the change stamps and the own-cells index (research R3).
  - **The stamps.**
    - `local stamps, globalStamp = {}, 0`.
    - `Settle` bumps `stamps[mapID]` of the cast's key.
    - The `SHARED_DATA_CHANGED` handler, with keys, bumps the map of every entry in `others.byRecord[key]` before
      `UnindexRecord` and after `IndexRecord`. When the index is not built yet, it bumps `globalStamp`.
    - Without keys, `ADDON_LOADED` and `SHARED_DATA_CHANGED` bump `globalStamp`.
    - `CatchDB.MapStamp(mapID)` returns `globalStamp .. ":" .. (stamps[mapID] or 0)`.
  - **The own-cells index.** `ownIndex` maps `"<mapID>:<range>"` to the own tables' keys: `mine` and every build of
    the own record and of the frozen own records.
    - It is built on first use and grown in `Settle`.
    - It is dropped where `frozen` is dropped and on a roll.
    - `SumMap` uses it instead of walking every own cell.
  Make the stamp and index parts of T006 pass.
- [X] T011 In `OneKeyFishing/CatchDB.lua`, add the views without the fallback (data-model.md "Views",
  [contracts/api.md](contracts/api.md)).
  - **New fields in the sums.** `NewSum` gains `px`, `py`, `n` and `ranges` (item ID -> `{ min, max }`).
    - `AddCell` takes the place key's range (the key is known in `SumSpot` and `SumMap`; an other player's entry
      has `entry.place`).
    - It adds `px`, `py` and `n = c + m` for cells with `px`.
    - It widens `ranges` for every item with catches.
  - **New fields in the views.** `BuildView` copies `point` (when `n > 0`), the `ranges` per item and `cell` into
    spot views.
  - **New functions:**
    - `CatchDB.QueryMap(mapID, filter)`: `BuildView` of `SumMap`, scope `"map"` or `"none"`;
    - `CatchDB.QueryCells(mapID, filter)`: one `BuildView` of `SumSpot` per cell that has catches under the
      filter, over the keys of the filter's ranges;
    - `CatchDB.Maps(filter)`: the map IDs of the seed index, the own-cells index and `others.byPrefix` (sharing
      on), or of `mine`.
    Each of the first two caches its result per map and filter key, with `MapStamp(mapID)`.
  - **Unchanged:** `Query` keeps its version-based cache.
  Make T006 pass.
- [X] T012 Create `OneKeyFishing/Catalog.lua` and add it to `OneKeyFishing/OneKeyFishing.toc` after `Share.lua`
  ([contracts/api.md](contracts/api.md) "ns.Catalog", data-model.md "Catalog").
  - **Indexes.**
    - `indexes[filterKey]` holds at most two entries: the default filter `all|all|all` and the latest other one.
    - The build walks `CatchDB.Maps(filter)`, compares `CatchDB.MapStamp`, calls `QueryMap` for changed maps and
      rebuilds `items` from the map views.
    - Steps run through `C_Timer.After(0)` and end at `STEP_MS` by `debugprofilestop`, or at `MAPS_PER_STEP`
      without it.
    - Every read (`Items`, `Places`, and later `Spots` and `TooltipLines`) first compares the stamps: up to
      `SYNC_MAPS` changed maps are recomputed at once, more start the step build unless one is running, and the
      read answers from the stale index meanwhile.
    - `GetVersion` and the timings are kept for `Describe`.
  - **When it builds.** The first `PLAYER_ENTERING_WORLD` of the Lua session (a login or a `/reload`; each starts
    with empty session memory) schedules the default index after `DEFAULT_INDEX_DELAY` seconds. Later loading
    screens do not.
  - **Names.**
    - `names[itemID]` holds `{ name, key = ns.SearchKey(name), quality, known }`.
    - Known means `GetItemInfoInstant` and `GetItemNameByID` both answer. Unknown items go into `queue`, sent
      `NAME_REQUESTS_PER_STEP` per step and once per session (`asked`).
    - `ITEM_DATA_LOAD_RESULT` and `GET_ITEM_INFO_RECEIVED` refresh the entry and bump the version.
    - `-- VERIFY(V35): item names load in batches of NAME_REQUESTS_PER_STEP without errors`.
  - **Functions:** `Catalog.Items(filter, search)`, `Places(itemID, filter)`, `ZoneName(mapID)` (cached per
    session), `Find(text)`, `CommandArg(rest)`, `GetVersion()`, `Describe()`.
  - **Rules for the list:**
    - an item shows only while it is known;
    - a Poor item only with a search;
    - part 3's item rule comes from the map views (a map view lists only the items it may show).
  - Add `C_Item.GetItemNameByID`, `C_Item.GetItemQualityByID` and `debugprofilestop` uses to `.luacheckrc` if not
    there.
  Make T007 and T008 pass.
- [X] T013 In `OneKeyFishing/Debug.lua`, add a "Catch catalog" section with the lines of `Catalog.Describe()`
  (English, like the other sections). In `tests/catalog_test.lua`, check through `ns.ShowReport()` (as
  `tests/catchdb_test.lua` does) that the report holds the section and no item name.

**Checkpoint**: the per-map views and the catalog index exist and pass their tests; nothing is visible yet.

---

## Phase 3: User Story 1 - Find where an item is caught (Priority: P1) MVP

**Goal**: the "Catch catalog" tab: the search, the item list, the item page with zones and spots named after their
subzone, and the ways in (the CatchHere click, `/okf catalog`).

**Independent Test**: with bundled data of several items in several zones, open the catalog, type part of an item's
name, choose it and check that zones are sorted by chance, expand into spots with subzone names and coordinates, and
match "What can be caught here" at that spot with the same filters (spec US1).

### Tests for User Story 1

- [X] T014 [P] [US1] Create `tests/catchdb_area_test.lua` (research R4, data-model.md "Cell").
  - **Reading the area.** With `player_map_position`, `explored_areas = { 10, 20 }`, `area_names` and
    `sub_zone = area_names[20]`, a cast keeps area 20. `area_lookups` shows the map and the position.
    - A `sub_zone` that differs from the area name only in letter case, Cyrillic included
      (`"\208\154\209\128\208\184\209\136\209\130\208\176\208\187\209\140"` against
      `"\208\186\209\128\208\184\209\136\209\130\208\176\208\187\209\140"`), still keeps area 20 (Principle II).
    - An empty `sub_zone`, no matching name, or no position keeps no area.
  - **Storing it.** A settled catch or miss adds 1 to `a[20]` in `mine` and the own record.
    - A ninth area of a cell is not added.
    - Cell `"x"` never gets `a`.
  - **`CheckRecord` refuses:**
    - `a` that is not a table;
    - more than 8 entries;
    - a key that is not a whole number from 1 to 2147483647;
    - a count that is not a count;
    - a sum above `c + m`.
    It accepts a cell without `a`.
  - **The spot's area.** A spot view's `area` is the area with the most casts, ties to the lower ID, with other
    players' parts scaled like their casts.
- [X] T015 [P] [US1] Extend `tests/share_store_test.lua`: a received record's `a` survives `CleanCell` unchanged; a
  record with a bad `a` is refused.
- [X] T016 [P] [US1] Extend `tests/harvest_test.mjs`:
  - `a` is cleaned, checked (the rules of T014), summed per area, kept to the 8 largest, and scaled by the cast
    factor where a cell is weighted (rounded, the sum capped at `c + m`);
  - it is written as `a = { [id] = n }` sorted by ID and accepted by `seedProblems`;
  - a seed cell with a bad `a` is a problem;
  - a 500-place record with two areas per place encodes under 28 KB (V18). The repository has no CBOR encoder, so
    the test carries a minimal one (maps, arrays, unsigned and negative integers, text strings: the subset a record
    uses), followed by `zlib.deflateRawSync` and Base64 (research R11). A comment says that the game's encoder may
    differ by a few bytes and that V18 confirms the size in game.
- [X] T017 [P] [US1] Extend `tests/catalog_test.lua` for `Catalog.Spots(itemID, mapID, filter)` and
  `Catalog.SpotName(spot)`.
  - **Spots:**
    - sorted like zones;
    - each with `cell`, `name`, `point`, `chance`, `catches`, `players`, `littleData`, `ranges`;
    - `pin` stays nil until US2.
  - **Names:**
    - "Crystal Lake (45, 72)" from `area_names` and the point rounded to whole percent;
    - "45, 72" without an area;
    - "No exact spot" for cell `"x"`.
- [X] T018 [P] [US1] Create `tests/catalogtab_test.lua` ([contracts/ui.md](contracts/ui.md) "The Catch catalog tab").
  - **The tab.** It is the third tab, and `statsTab = "catalog"` reopens it.
  - **The list.**
    - The status line reads "Counting the catch..." until the index is ready.
    - `type_text` narrows the list on every call, and clearing it brings back the full list.
    - The filter buttons read "Skill: All skill levels" and "Source: All".
    - There is no Water button without pool data.
  - **The item page.**
    - A row click opens it with the zone rows.
    - "Back" returns to the list with the search kept.
    - A zone row's "+" shows its spot rows, indented, and "-" hides them.
    - A zone row's hover shows "%d catches from %d players" from 2 players on, and "%d catches" below that.
    - A spot row's hover shows the subzone and the coordinates, then the same players line (FR-009).
    - "No data for this item under these filters." when a filter leaves it no zone.
  - **New data (FR-028).** A new catch, followed by the window tick, keeps the chosen item, the expanded zones and
    the search.
  - **Fallback.** With `no_scroll_templates = true` the page uses fixed rows with "and %d more" and still filters
    by the search.
  - **Empty states.**
    - An empty database shows the two empty lines.
    - "Only mine" without own catches shows its line.
- [X] T019 [P] [US1] Extend `tests/catchhere_test.lua`: a click on a known item row opens the statistics window on
  the catalog with that item chosen; an "Unknown item" row does nothing on click; the hint line includes
  "Click an item to see where else it is caught.".
- [X] T020 [P] [US1] Extend `tests/commands_test.lua`: `catalog` is listed in sorted order with its English
  description. `/okf catalog` opens the catalog list. `/okf catalog trout` fills the search, and when exactly one
  item matches it is chosen. `/okf catalog |cff..|Hitem:6291::|h[x]|h|r` chooses item 6291, or, when it is not in
  the index, puts its name in the search.

### Implementation for User Story 1

- [X] T021 [US1] In `OneKeyFishing/CatchDB.lua`, record the area of a cast (research R4).
  - **`CatchDB.GetArea(mapID, x, y)`.** It asks `C_MapExplorationInfo.GetExploredAreaIDsAtPosition(mapID,
    CreateVector2D(x, y))` and returns the ID whose `C_Map.GetAreaInfo` name, folded with `ns.FoldCase`, equals
    the folded `GetSubZoneText()`. The comment cites Principle II: matching against localized text tolerates case
    changes in non-ASCII text. It returns nil for an empty subzone text, no match or missing functions.
    `-- VERIFY(V34): the explored areas at the player's own position include the subzone, named as
    GetSubZoneText shows it`.
  - **Storing it.** `FISHING_CAST_START` stores `area` with the cast when it has a position. `Settle` adds 1 to
    `cell.a[area]`, creating `a`, unless the cell already has `MAX_AREAS` other areas.
  - **Checking it.** `CheckCell` checks `a`, quoting the rules: "absent or a table of at most 8 entries", "every key
    is a whole number from 1 to 2,147,483,647", "every count is a count, and their sum is at most `c + m`".
  - **Summing it.** The sums add `a` per area into the sum and into each other player's part; `BuildView` scales
    the parts by `castFactors` and sets `area` on spot views (the most casts, ties to the lower ID).
  - Add `C_MapExplorationInfo` and `CreateVector2D` to `.luacheckrc`.
  Make T014 pass.
- [X] T022 [US1] In `OneKeyFishing/Share.lua`, make `CleanCell` copy `a` (a fresh table of the same numbers). Make
  T015 pass.
- [X] T023 [US1] In `tools/harvest.mjs`, carry `a`:
  - `cleanCell` and `checkCell` copy and check it (the rules of T021);
  - the sums add it and keep the 8 largest;
  - `scaledCell` scales it by the cast factor, rounded, with the sum capped at `c + m`;
  - `seedText` writes it sorted by ID;
  - `seedProblems` checks it.
  Make T016 pass.
- [X] T024 [US1] In `OneKeyFishing/Catalog.lua`, add `Catalog.Spots(itemID, mapID, filter)`, from
  `CatchDB.QueryCells` cached with the map's stamp, sorted like `Places`; and `Catalog.SpotName(spot)`, with
  `L["%s (%s)"]`, `L["No exact spot"]` and the `%d, %d` coordinates. In `OneKeyFishing/Spike.lua`, replace "not
  built yet" in part 2 by `CatchDB.GetArea`. Make T017 pass.
- [X] T025 [US1] Create `OneKeyFishing/UI/CatalogTab.lua` and add it to `OneKeyFishing/OneKeyFishing.toc` after
  `UI\CatchHere.lua` ([contracts/ui.md](contracts/ui.md), research R8).
  - **Functions:** `CatalogTab.Create(parent)`, `Refresh()`, `Tick()` and `Show(arg)`.
  - **The list view.**
    - A search box (`SearchBoxTemplate`, its hint `L["Search by item name"]`), whose `OnTextChanged` refreshes.
    - The Skill and Source buttons, through `ns.OpenRadioMenu` with CatchHere's labels; Skill defaults to "all".
    - A `WowScrollBoxList` with a `MinimalScrollBar` through `ScrollUtil.InitScrollBoxListWithScrollBar` and a
      `CreateDataProvider` of `Catalog.Items`. A row shows `ns.ItemDisplay`, `L["Zones: %d"]` and the game's item
      tooltip.
    - The status line.
  - **The item page.**
    - `L["Back"]`, the icon and the name.
    - The headers `L["Place"]`, `L["Skill"]`, `L["Chance"]` and `L["Catches"]`.
    - Zone rows with "+"/"-", and spot rows indented.
    - The skill span formatted like CatchHere's `RangeLabel`, from the lowest to the highest range.
    - `L["Little data"]` in place of the chance.
    - The hover lines `L["%d catches from %d players"]` / `L["%d catches"]` on zone rows; on spot rows after the
      subzone and the coordinates (FR-009).
    - `Catalog.ZoneName`'s `L["Unknown zone (%d)"]`, with its nine translations.
  - **State.** Search, filters, the chosen item and the expanded zones stay in memory only. `Tick` redraws when
    `Catalog.GetVersion()` or the state changed, keeping the scroll position.
  - **Fallback.** Wrap the template creation in `pcall`; on failure use a fixed pool of rows with
    `L["and %d more"]`.
    `-- VERIFY(V37): the scroll list, the scroll bar and the search box render inside the statistics window`.
  - **Texts.** The empty states and all the texts above, with nine translations.
  Make T018 pass.
- [X] T026 [US1] In `OneKeyFishing/UI/StatsFrame.lua`, add the third page `{ key = "catalog", label =
  L["Catch catalog"], frame = ns.CatalogTab.Create(f), refresh = ns.CatalogTab.Refresh, tick = ns.CatalogTab.Tick }`
  and `StatsFrame.OpenCatalog(arg)`: it shows the window, calls `SelectTab("catalog")` and `CatalogTab.Show(arg)`.
  In `OneKeyFishing/Core.lua`, update the `statsTab` comment to `"stats" | "here" | "catalog"`. Add the text and its
  nine translations.
- [X] T027 [US1] In `OneKeyFishing/UI/CatchHere.lua`, make a known item row clickable: `OnMouseUp` with the left
  button calls `ns.StatsFrame.OpenCatalog(row.itemID)`; "Unknown item" rows stay unclickable. Add
  `L["Click an item to see where else it is caught."]` to the hint lines, with nine translations. Make T019 pass.
- [X] T028 [US1] In `OneKeyFishing/Commands.lua`, add `{ name = "catalog", description = "open the catch catalog
  (optionally with an item name or link)", run = function(rest) ns.StatsFrame.OpenCatalog(ns.Catalog.CommandArg(rest))
  end }` in sorted order. `CatalogTab.Show` with text fills the search and chooses the item when `Catalog.Find`
  returns exactly one. With an item ID that has no entry, it puts the item's name (or the ID) into the search. Make
  T020 pass.

**Checkpoint**: US1 works on its own: the catalog lists, finds and explains every item, with spots named in the
client's language; `npm test` passes.

---

## Phase 4: User Story 2 - Go to the spot (Priority: P2)

**Goal**: a spot's pin button sets the game's map pin, turns on the arrow, shows a toast and opens the map; the
player's own pin is replaced only after a question.

**Independent Test**: choose a spot and press its pin button; set a pin by hand and press another; check a spot in
an instance (spec US2).

### Tests for User Story 2

- [ ] T029 [P] [US2] Create `tests/catalog_pin_test.lua` (research R6, data-model.md "Pin target").
  - **`Catalog.PinTarget`:**
    - an allowed map gives `{ mapID, x, y }` at the spot's point;
    - a Micro map that refuses, with an allowed parent and a `map_world` entry for both, gives the parent and the
      converted point;
    - a point that converts outside 0..1 gives nil;
    - a Dungeon map with an allowed parent gives nil;
    - cell `"x"` (no point) gives nil;
    - `game_rules[Enum.GameRule.WorldMapTrackingPinDisabled] = true` gives nil;
    - with `Enum.GameRule.WorldMapTrackingPinDisabled = nil` (or no `Enum.GameRule`), an allowed map still gives a
      target (the rule check is skipped);
    - without `C_Map.SetUserWaypoint` it gives nil.
  - **`CatalogTab.Pin`:**
    - **No waypoint:** `waypoint_sets` gets the point, `super_tracked` is true, `ns.charDB.pin` holds it, the toast
      reads "Map pin: <name>", and `world_maps_opened` gets the map.
    - **The addon's own waypoint** (`user_waypoint` equal to `charDB.pin` within `PIN_EPSILON`) is replaced
      without a popup.
    - **Another waypoint:**
      - the popup "Replace your map pin with this place?" shows;
      - Cancel leaves `user_waypoint` and `charDB.pin` unchanged;
      - Replace sets the pin.
    - **In combat:** `in_combat = true` sets the pin but opens no map.
    - **Refused:** `waypoint_result = false` toasts "The game did not accept the map pin." and keeps no
      `charDB.pin`.
  - **The buttons.** `tests/catalogtab_test.lua` shows a pin button only on spot rows with a target; its hover text
    is "Set a map pin here".

### Implementation for User Story 2

- [ ] T030 [US2] In `OneKeyFishing/Catalog.lua`, add `Catalog.PinTarget(mapID, spot)` (research R6) and fill
  `spot.pin` in `Catalog.Spots`.
  - Mark the reads:
    - `-- VERIFY(V30): CanSetUserWaypointOnMap answers per map, open world true, instances false, and the game rule
      is not active`;
    - `-- VERIFY(V33): a Micro map converts to its parent zone through the world position`.
  - The rule check runs only when `C_GameRules.IsGameRuleActive` and `Enum.GameRule.WorldMapTrackingPinDisabled`
    both exist; a missing value skips it and is not a refusal.
  - Add `C_GameRules` and the map functions to `.luacheckrc`.
- [ ] T031 [US2] In `OneKeyFishing/UI/CatalogTab.lua`, add the pin button to spot rows with a target. It uses the
  atlas `Waypoint-MapPin-Untracked`, or a text button `L["Pin"]` when `C_Texture.GetAtlasInfo` lacks it, with the
  hover text `L["Set a map pin here"]`. Add `CatalogTab.Pin(target, placeName)`:
  - **Asking first.** When `C_Map.HasUserWaypoint()` and the waypoint differs from `ns.charDB.pin` (another map, or
    positions apart by more than `PIN_EPSILON`), it calls
    `ns.ShowPopup("ONEKEYFISHING_REPLACE_PIN", L["Replace your map pin with this place?"], apply, L["Replace"],
    L["Cancel"])`.
  - **Setting the pin.** It calls `C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(target.mapID, target.x,
    target.y))`. On true it calls `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`, saves `ns.charDB.pin =
    { mapID, x, y }`, toasts `L["Map pin: %s"]`, and calls `OpenWorldMap(target.mapID)` unless
    `InCombatLockdown()`.
  - **Refused.** On false it toasts `L["The game did not accept the map pin."]`.
  - Mark the calls:
    - `-- VERIFY(V31): super tracking the user waypoint shows the navigation arrow`;
    - `-- VERIFY(V32): OpenWorldMap from addon code opens the map without taint`.
  - **Comments.** In `OneKeyFishing/Core.lua`, add a comment line for `pin` to `CHAR_DB_DEFAULTS` (nil until the
    addon sets one). Leave `showInGameNavigation` alone and say so in a comment.
  - Add the texts with nine translations, and the new globals to `.luacheckrc`.
  Make T029 pass.

**Checkpoint**: US2 works on top of US1: a spot becomes a route on the map.

---

## Phase 5: User Story 3 - Chances where the player already looks (Priority: P3)

**Goal**: "Caught in" lines in item tooltips, the top catches of the current place in the minimap tooltip while
fishing, and one checkbox for both.

**Independent Test**: hover an item in the database and one outside it; the minimap button in fishing mode and
outside it; the checkbox off (spec US3).

### Tests for User Story 3

- [ ] T032 [P] [US3] Extend `tests/catalog_test.lua` for `Catalog.TooltipLines(itemID)` and `Catalog.MinimapLines()`
  ([contracts/ui.md](contracts/ui.md) "Item tooltips", "The minimap button tooltip").
  - **`TooltipLines`:**
    - up to three reliable zones by chance;
    - the right side is "18%", or "18% (14 players)" from 2 players on;
    - without a reliable zone, the little-data zones by the item's catches with "Little data";
    - nil for an item outside the default index, and nil before any index exists;
    - a Poor item still has lines;
    - a new catch of the item on a map is in the next `TooltipLines` without the catalog being opened (up to
      `SYNC_MAPS` changed maps at once; with more, after the steps the read started) (FR-028).
  - **`MinimapLines`:**
    - nil outside fishing mode and with `settings.tooltipChances = false`;
    - in fishing mode, the top three items of `CatchDB.Query` for the current place with the tab's defaults,
      skipping Poor and unknown items;
    - the footer "%d catches from %d players" / "%d catches";
    - "Little data" in place of the percentages under 50 catches on the whole map;
    - "Nothing has been caught here yet." without data.
- [ ] T033 [P] [US3] Create `tests/tooltips_test.lua`.
  - **The item tooltip.** `show_item_tooltip(GameTooltip, id)` adds "Caught in:" and the zone lines before the
    fishing gear line, and `show_item_tooltip(ItemRefTooltip, id)` adds them to `itemref_lines`. Neither adds them
    with the setting off or for an item without data.
  - **The minimap tooltip.** The minimap button's tooltip (`OnEnter` of the button) and the Addon Compartment
    entry's (`OneKeyFishing_OnAddonCompartmentEnter`) add "Likely catch here:" and the lines in fishing mode only
    (FR-018).
- [ ] T034 [P] [US3] Extend `tests/settings_test.lua`: the main page has the checkbox "Show catch chances in
  tooltips", on by default; turning it off sets `settings.tooltipChances = false` and fires `SETTINGS_CHANGED`.

### Implementation for User Story 3

- [ ] T035 [US3] In `OneKeyFishing/Catalog.lua`, add `Catalog.TooltipLines(itemID)` and `Catalog.MinimapLines()`
  ([contracts/api.md](contracts/api.md)). `TooltipLines` reads the default index as every read does (the stamps
  first, T012), answering stale while a step build runs; the fallback zones are ordered like `Places` (little-data
  zones by the item's catches). `MinimapLines` uses `CatchDB.Query` with
  `{ range = own range, source = "all", water = "all" }`. The texts: `L["%s (%d players)"]`, `L["Little data"]`,
  `L["%d catches from %d players"]`, `L["%d catches"]` and `L["Nothing has been caught here yet."]`. Make T032 pass.
- [ ] T036 [US3] In `OneKeyFishing/UI/ItemHooks.lua`, add the catch lines at the start of `OnItemTooltip`, before the
  equippable check:
  - for `GameTooltip` and `ItemRefTooltip`, with `ns.db.settings.tooltipChances`, `L["Caught in:"]` in
    `TOOLTIP_COLOR` and one `AddDoubleLine` per pair of `Catalog.TooltipLines`;
  - the gear line keeps its rules.
  Mark `-- VERIFY(V38): the item post call fires for bags, the auction house, chat links and the addon's rows`. Add
  `ItemRefTooltip` to `.luacheckrc`. Make the item part of T033 pass.
- [ ] T037 [US3] In `OneKeyFishing/UI/Minimap.lua`, after the session line of `ShowTooltip`, add a blank line,
  `L["Likely catch here:"]`, one `AddDoubleLine` per item of `Catalog.MinimapLines()` and the footer line, when it
  returns lines. Make the minimap part of T033 pass.
- [ ] T038 [US3] In `OneKeyFishing/Core.lua`, add `tooltipChances = true` to `DB_DEFAULTS.settings` with a comment. In
  `OneKeyFishing/UI/Settings.lua`, add `{ key = "tooltipChances", label = L["Show catch chances in tooltips"] }` to
  the feature toggles. Add the texts of T035-T038 with nine translations. Make T034 pass.

**Checkpoint**: US3 works with the foundation alone (tooltips need no tab): the database shows where players look.

---

## Phase 6: User Story 4 - Pools apart from open water (Priority: P4)

**Goal**: a "Water" filter in both tabs when the database holds pool catches.

**Independent Test**: with data that holds pool catches, both tabs show the filter, "Open water" and "Pools" split
the catches, and the miss line shows only under "Everywhere"; without pool data there is no filter (spec US4).

### Tests for User Story 4

- [ ] T039 [P] [US4] Create `tests/catchdb_water_test.lua` (research R5, data-model.md "Views").
  - **Sums under each filter** (`"pool"`, `"open"`, `"all"`, over cells with and without `p`):
    - catches, items and players under `"pool"` and `"open"` add up to `"all"` (SC-007);
    - `missRate` is nil under the two filters;
    - the 50-catch fallback counts the filtered catches;
    - a weighted seed cell uses its filtered `c`.
  - **Every view takes the filter:** `Query`, `QueryMap` and `QueryCells`; `Query`'s cache key includes the water.
  - **`HasPoolData`:**
    - false without any `p`;
    - true from a seed cell, an own pool catch (`FISH_CAUGHT` with `fromPool`) or a received record;
    - re-read after `SHARED_DATA_CHANGED` only while false.
- [ ] T040 [P] [US4] Extend `tests/catchhere_test.lua` and `tests/catalogtab_test.lua`.
  - **The button.** "Water: Everywhere" shows in both tabs once pool data exists, and offers "Everywhere", "Open
    water" and "Pools".
  - **"What can be caught here".** Under "Pools" the page shows the pool numbers without the miss line.
  - **The catalog.** Under "Open water" it builds the `all|all|open` index.

### Implementation for User Story 4

- [ ] T041 [US4] In `OneKeyFishing/CatchDB.lua`, add `filter.water` ("all" when missing) and `CatchDB.HasPoolData()`
  (research R5).
  - **Reading a cell.** `AddCell` reads the cell through the filter before adding it (the table in data-model.md
    "Views").
  - **Players and views.** Players count only parts with filtered catches. `BuildView` leaves `missRate` nil under
    a filter.
  - **Cache keys.** The cache keys of `Query`, `QueryMap` and `QueryCells` include the water.
  - **`HasPoolData`.** It scans the seed once, then the own tables and the stored records while false. `Settle`
    sets it on a pool catch, and the `SHARED_DATA_CHANGED` handler clears a false result.
  Make T039 pass.
- [ ] T042 [US4] In `OneKeyFishing/UI/CatchHere.lua` and `OneKeyFishing/UI/CatalogTab.lua`, add the Water button.
  - It shows only while `CatchDB.HasPoolData()`.
  - It uses `ns.OpenRadioMenu` with `L["Water: %s"]`, `L["Everywhere"]`, `L["Open water"]` and `L["Pools"]`.
  - It is in memory only (back to "all" on login).
  - CatchHere passes `water` to `Query` and leaves out the miss text when `missRate` is nil.
  - The catalog passes it to `Catalog.Items`.
  Add the texts with nine translations. Make T040 pass.

**Checkpoint**: US4 works on top of the foundation; without pool data (V3 failed) nothing changes for the player.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: documentation, the in-game checklist, the format contracts of part 1, and a last check of the whole.

- [ ] T043 [P] Update `README.md`:
  - the catalog tab and its search;
  - the map pin, with "the arrow depends on the game's navigation setting";
  - the "Caught in" tooltip lines and the minimap lines;
  - the "Show catch chances in tooltips" setting;
  - the Water filter (when the game tells pools apart);
  - `/okf catalog`.
- [ ] T044 [P] Add the part 4 entries to `CHANGELOG.md` under `[Unreleased]`.
- [ ] T045 [P] Update `CLAUDE.md`:
  - the module map: `Catalog.lua` after `Share.lua`, `UI/CatalogTab.lua`; the `UI/*.lua` row names the catalog
    tab;
  - the cross-module rules: the catalog reads `CatchDB.MapStamp` and sends no message;
  - the Forever API traps: `C_Map.OpenWorldMap` is restricted, so use the global `OpenWorldMap`; the waypoint
    sequence of `/mappin`; the subzone found through the explored areas at the player's own position;
  - and nothing else: no message was added.
- [ ] T046 [P] Update the architecture docs:
  - `docs/architecture/catch-db.md`: the area of a cast and `a`, the water filter, `QueryMap`/`QueryCells`/`Maps`,
    the stamps, the own-cells index.
  - `docs/architecture/ui.md`: the catalog tab, the pin, the tooltips, the minimap lines, the Water button, the
    CatchHere click.
  - `docs/architecture/core.md`: `ns.FoldCase`, `SearchKey`, `CompareText`, and the `catalog` command.
- [ ] T047 [P] Update `docs/forever-api.md` "From the client export" with the facts of research R4, R6 and R7:
  - the waypoint functions and their flags;
  - `UiMapPoint`;
  - the game rule;
  - the hidden navigation checkbox;
  - `OpenWorldMap` against `C_Map.OpenWorldMap` (`HasRestrictions`);
  - `GetExploredAreaIDsAtPosition` (explored areas only);
  - `CaseAccentInsensitiveParse`, `strcmputf8i`;
  - the scroll and search templates.
- [ ] T048 [P] Create `docs/checklists/catch-catalog.md` from [quickstart.md](quickstart.md) "In game: the feature".
  It has numbered steps with the expected result of each, and the V-number each step closes. The pin step also
  checks SC-002: from typing a name to the pin takes at most five actions. It notes that a fresh install needs a
  game restart, not `/reload`, and that steps 1 and 6 need a second client language.
- [ ] T049 [P] Update the format documents of part 1 for `a`:
  - `specs/002-local-catch-db/data-model.md` "Cell";
  - `specs/002-local-catch-db/contracts/seed-data.md` (the cell shape and its rules);
  - `specs/003-guild-group-sync/contracts/sync-protocol.md`, if it lists cell fields.
- [ ] T050 Run `npm run check` and `npm test`. Check every `L[...]` key of part 4 against
  [contracts/ui.md](contracts/ui.md), and every `VERIFY(V30..V40)` marker against
  [verification.md](verification.md) (each ID has at least one marker; V39 and V40 may live in the checklist only).
  Re-check the constitution table of [plan.md](plan.md) against the code, and add a dated line there, as part 3 did.
- [ ] T051 Note any open low-severity issue found while building in `docs/tech-debt.md`, each with the test that will
  close it (CLAUDE.md: remove an item once it is fixed with a test).

---

## Phase 8: After launch (debt, from 2026-11-04)

- [ ] T052 The author runs `/okf spike` (section "Map pins and areas") at the places of
  [quickstart.md](quickstart.md) "The spike", and the checklist `docs/checklists/catch-catalog.md` on two client
  languages.
- [ ] T053 Write the answers into `docs/forever-api.md` "Verified in game"; fix the code where an assumption was wrong
  (each V-row's "If it turns out wrong").
- [ ] T054 Remove the `VERIFY(V30..V40)` markers once the author confirms each behaviour, and tick V30-V40 in
  [verification.md](verification.md).
- [ ] T055 Release 1.2.0 with the other parts (`docs/shared-db-plan.md` "Release 1.2.0").

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: after Setup; blocks every story.
- **US1 (Phase 3)**: after Foundational.
- **US2 (Phase 4)**: after US1 (the pin button sits on US1's spot rows; `PinTarget` itself only needs the
  foundation).
- **US3 (Phase 5)**: after Foundational; independent of US1 and US2.
- **US4 (Phase 6)**: after Foundational. T040 extends `tests/catalogtab_test.lua` (created by T018) and T042
  touches `UI/CatalogTab.lua`, so both follow US1 when US1 is built first. Built before US1, they cover CatchHere
  only, and the catalog's Water button and its test come with T018 and T025.
- **Polish (Phase 7)**: after the stories it describes.
- **After launch (Phase 8)**: after 2026-11-04.

### Within each story

- Tests first, and they must fail.
- Data.lua (T009) before Catalog (T012), whose search keys use it.
- CatchDB stamps and the index (T010) before the views (T011), before Catalog (T012).
- CatchDB's area (T021) before Share (T022) and the spots (T024); the harvest (T023) is independent of the addon
  code but mirrors `CheckCell`.
- The page (T025) before StatsFrame (T026), CatchHere's click (T027) and the command (T028).

### Parallel opportunities

- Setup: T003 next to T001-T002.
- Foundational tests T005-T008 in parallel (different files).
- US1 tests T014-T020 in parallel; T022 (Share) and T023 (harvest) next to T024-T025 once T021 is done.
- After Foundational, US3 can be built next to US1 (different files except `Catalog.lua`, where T024, T030 and T035
  add functions in turn).
- Polish: T043-T049 in parallel.

## Parallel Example: Foundational

```text
Task: "Create tests/fold_test.lua"                 (T005)
Task: "Create tests/catchdb_views_test.lua"        (T006)
Task: "Create tests/catalog_test.lua"              (T007)
Task: "Create tests/catalog_load_test.lua"         (T008)
```

## Parallel Example: User Story 1

```text
Task: "Create tests/catchdb_area_test.lua"         (T014)
Task: "Extend tests/share_store_test.lua"          (T015)
Task: "Extend tests/harvest_test.mjs"              (T016)
Task: "Create tests/catalogtab_test.lua"           (T018)
Task: "Extend tests/commands_test.lua"             (T020)
```

## Implementation Strategy

### MVP first

1. Phase 1 and Phase 2.
2. Phase 3 (US1): the catalog itself. Stop and validate with `npm test -- catalog` and the independent test of US1.

US1 is the reason for part 4; US2 (the pin) makes it a route, US3 (tooltips) brings the data to players who never
open the window, US4 waits on part 1's pool check (V3).

### Incremental delivery

1. Setup + Foundational.
2. US1 (catalog), then US2 (pin); US3 (tooltips) in either order with them.
3. US4 (water filter).
4. Polish, hand-off.
5. After launch: spike, checklist, debt closed, release 1.2.0 with the other parts.

## Notes

- [P] tasks touch different files and depend on no unfinished task.
- Commit after each task or logical group, on `002-shared-db`, with English messages.
- The texts of each task go into `enUS.lua` and the nine translations in that task; the locale test fails otherwise.
- Stop at any checkpoint to validate a story on its own.
