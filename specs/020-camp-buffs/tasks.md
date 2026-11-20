---

description: "Task list for spec 020, Fishing Camp Buffs"
---

# Tasks: Fishing Camp Buffs

**Input**: Design documents from `specs/020-camp-buffs/`

**Prerequisites**:
- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/module-api.md](contracts/module-api.md), [quickstart.md](quickstart.md), [verification.md](verification.md)

**Tests**: required (constitution Principle V). Each test is written first and seen failing before its code.

**Organization**: grouped by the user stories of spec.md (US1 to US8), in the order of work of plan.md. Work on
`020-camp-buffs`; commit only when the author asks, and not before T037 to T039 are done: the new module,
message and saved fields reach `CLAUDE.md` and the architecture pages there (the definition of done).

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it; a test written before its code is the only allowed red.
- Addon Lua: ASCII outside `Locales/`, 120-character lines, Lua 5.1/5.3 neutral (no `//`, no `math.type`; a number
  formatted with `%d` is made whole with `math.floor` first).
- No Cyrillic in Markdown. Files with LF line endings.
- A new visible text: a literal English key in `Locales/enUS.lua` and its translation in each of the nine other
  locale files (`deDE`, `esES`, `esMX`, `frFR`, `ukUA`, `koKR`, `ptBR`, `zhTW`, `zhCN`) in the same task. The English
  keys are the table "Wording for the feature" of `docs/fishing-investigation.md`, verbatim. The Ukrainian texts are
  the ones of `static/reports/camp-bonus-wording-ukUA.md`, verbatim (a local file outside git, every text in it
  accepted by the author on 2026-11-19). The other languages use the client's own names of the Fishing Rack, the
  Fishing Hut and the auras "Uncommon Fishing" / "Rare Fishing" where known, and the words each file already uses
  for "catch", "cast" and "buff". Color codes outside the strings; no `L[...]` lookup while the files load. A key in
  `Locales/enUS.lua` that no code uses fails `npm run check`: a key goes in with the code that shows it.
- A global in `.luacheckrc` that no file uses fails `npm run check`: a global goes in with the code that reads it.
- Game data by ID only: the auras 1280341 and 1280342 and the item IDs live in `GameData/CampBonuses.lua`; no other
  file writes them as literals (tests may). `GameData/*.lua` is data only: no function, no call, no `L`.
- Layers: `Fishing/Camp.lua` and `Catch/Stats.lua` are layer 1 (no `ns.CatchDB`, `ns.Catalog`, `ns.Share`, no
  frame); the tag and the filter are in `CatchDB/` and `Catalog/` (layer 2); frames only in `UI/`.
- The aura is read only by `C_UnitAuras.GetPlayerAuraBySpellID`, never while auras are restricted
  (`InCombatLockdown()` or `C_Secrets.ShouldAurasBeSecret()`), and the `UNIT_AURA` payload is never read.
- `FISH_CAUGHT` and `FISH_MISSED` keep their arguments: the mask is asked from `ns.Camp.CastMask(castID)`.
- A bonus part is inclusive and disjoint, keyed by `tostring(mask)` (data-model.md): no total of a cell changes
  because of `q`, and no code writes `q` under a number key.
- No view is built by fetching another view (research R7): a scope's bonus sums are filled in the pass that sums it.
- No game action anywhere in this feature (FR-008): `Fishing/Camp.lua` calls no cast, item-use, equip or secure
  function and creates no frame.
- The assumptions carry exactly `-- VERIFY(V60): <what>` to `-- VERIFY(V67): <what>` above the code that rests on
  them, as named in the tasks. A further assumption only the game can confirm: stop and ask the author.
- The aura stubs live in `tests/wow.lua` (T003); a test sets the auras and the restriction before the event it
  fires. The stubs' serializer and compressor do not shrink anything: no test asserts an encoded size.
- A test file names its subject, never a module of its area (`tests/tools/test_names_test.mjs`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US8)

---

## Phase 1: Setup (baseline)

**Purpose**: the baseline; no addon behaviour.

- [X] T001 Run `npm run check` and `npm test` from the repository root on `020-camp-buffs`; note the test count and
  that no `VERIFY` marker is open, for the hand-over.
- [X] T002 [P] Read `tools/check.mjs` and `tools/addon.mjs` for the rules the new files meet: the list of game data
  files or their data-only check, the files allowed to call `CreateFrame`, the layer table, the unused-global and
  unused-key rules, the test-name rule. Note for T005 and T009 what, if anything, has to be listed there. No file
  changes.
- [X] T003 [P] `tests/wow.lua`: stubs for the aura API. A table `wow.auras` (spell ID -> `{ expirationTime, duration
  }`) and a switch `wow.aurasRestricted`; `C_UnitAuras.GetPlayerAuraBySpellID(id)` returns nil while restricted, else
  a table `{ spellId = id, expirationTime = ..., duration = ... }` or nil; `C_Secrets.ShouldAurasBeSecret()` returns
  the switch; `InCombatLockdown()` keeps its present stub. The present `C_Item.GetItemIconByID` stub gains an optional
  per-ID table (`wow.item_icons[id]`), its default unchanged. A helper `run_item_post_calls(tooltip, itemID)` runs the
  item post calls on a tooltip without resetting it (unlike `show_item_tooltip`), for the tests that open a tooltip
  through `ns.ShowItemTooltip` and then let the game's hook run. `GameTooltip` gains a working `HookScript("OnHide",
  fn)` / `GetScript`, `IsShown`, and a `Hide` that runs the `OnHide` hooks. Follow the file's own style for stubs and
  resets between tests. No test changes its result.

---

## Phase 2: Foundational (the game data)

**Purpose**: the list every story reads. Blocks US1, US2, US3, US5, US6, US8.

- [X] T004 `tests/gamedata/camp_bonuses_test.lua` (new, fails first): `ns.GameData.CampBonuses` is a list of two
  entries in rank order; entry 1 is `key = "rack"`, `bit = 1`, `aura = 1280341`, `item = 279965` with the twelve
  items 6643, 6644, 6645, 6646, 6647, 8366, 13881, 13891, 21162, 21163, 21164, 21243 set to true; entry 2 is `key =
  "hut"`, `bit = 2`, `aura = 1280342`, `item = 279966` with an empty `items`; keys and bits are distinct, each bit
  a power of two.
- [X] T005 `OneKeyFishing/GameData/CampBonuses.lua` (new, data only, header comment like the other game data files
  with the source: the client's game data and the in-game session of 2026-11-19 in
  `docs/fishing-investigation.md`): the list of data-model.md. `-- VERIFY(V60): the Hut's aura behaves like the
  Rack's` above the Hut's entry; `-- VERIFY(V61): Bloated fish come only under a camp buff` above the Rack's
  `items`. `OneKeyFishing/OneKeyFishing.toc`: `GameData\CampBonuses.lua` after `GameData\Lures.lua`. What T002
  noted for a new game data file. T004 passes.

**Checkpoint**: the list loads; nothing reads it yet.

---

## Phase 3: User Story 4 - Small chances are readable (Priority: P2, independent, done first)

**Goal**: every shown percentage follows the new rule. Done first because it stands alone and US2's numbers need it.

**Independent Test**: `tests/core/percent_test.lua`; in game, a rare item reads with a fraction.

- [X] T006 [US4] `tests/core/percent_test.lua` (new, fails first): `ns.Percent` gives `37%` for 0.374, `10%` for
  0.0996 and for 0.0995, `9.9%` for 0.0994, `3.4%` for 0.0344, `1.0%` for 0.00996, `0.99%` for 0.00994, `0.47%` for
  0.00468, `0.01%` for 0.00006, `<0.01%` for 0.00004 and for 1e-9, `0%` for 0, `100%` for 1 (FR-029's edges).
- [X] T007 [US4] `OneKeyFishing/Core/Data.lua`, `ns.Percent(value)`: with `p = value * 100`: `p >= 9.95` a whole
  number (`math.floor(p + 0.5)` with `%d`); `p >= 0.995` `("%.1f%%")`; `p >= 0.005` `("%.2f%%")`; `p > 0` the
  literal `<0.01%`; else `0%` (research R9). Update its comment. T006 passes. Run the whole suite: fix every test
  that compared a text built by hand against the old rounding (search `tests/` for `%%` and `Percent`); a test that
  calls `ns.Percent` itself needs no change.

**Checkpoint**: US4 done.

---

## Phase 4: User Story 1 - Catches under a camp bonus are recorded apart (Priority: P1) MVP

**Goal**: `ns.Camp` knows the buffs; a cast with a mask is written into its part.

**Independent Test**: the tests below; in game, `/okf debug` after fishing with a Rack (the debug lines come in
T036).

- [X] T008 [US1] `tests/fishing/camp_state_test.lua` (new, fails first), over the stubs of T003 and the events the
  module listens to:
  - no aura: `Camp.IsActive("rack")` is false after `PLAYER_ENTERING_WORLD`; `Camp.Mask()` is 0;
  - the Rack's aura with `expirationTime = GetTime() + 600`: active, `TimeLeft("rack")` about 600, `Mask()` 1;
  - both auras: `Mask()` 3; only the Hut's: 2; `Camp.HasBit(3, "rack")` and `HasBit(3, "hut")` true, `HasBit(2,
    "rack")` false; `Camp.KnownBonus(6643)` is `"rack"`, `KnownBonus(6291)` nil;
  - restricted from the start (no read yet): `IsActive` nil, `Mask()` nil;
  - active, then restricted with the aura stub now empty: still active (no read); after the clock passes
    `expires`: not active, `Mask()` 0;
  - `PLAYER_REGEN_ENABLED` with the restriction lifted and the aura gone: not active;
  - `UNIT_AURA` whose first argument is `"target"` reads nothing; `"player"` reads; a second argument that is a
    secret value is never touched (pass one the stub would raise on);
  - an `expirationTime` that is a secret value (the stub's `secret_values`, read through `issecretvalue`) counts as a
    failed read: the state stays as it was;
  - the source text of `OneKeyFishing/Fishing/Camp.lua` holds none of `CastSpell`, `UseItem`, `UseContainerItem`,
    `SecureActionButton`, `CreateFrame` (FR-008).
- [X] T009 [US1] `OneKeyFishing/Fishing/Camp.lua` (new): `ns.Camp` with `Read`, `IsActive`, `TimeLeft`, `Mask`,
  `HasBit`, `KnownBonus` (contracts). State per key `{ known, expires, first }` (data-model.md "State of a bonus");
  a read per research R2 on `PLAYER_ENTERING_WORLD`, `UNIT_AURA` (only when its first argument is `"player"`; the
  second is not touched), `PLAYER_REGEN_ENABLED`. `-- VERIFY(V64): expirationTime is on GetTime()'s clock` where
  `expires` is kept; `-- VERIFY(V62): both auras can be held at once` above `Mask`; `-- VERIFY(V65): UNIT_AURA
  fires when the aura comes and goes out of combat` at the registration. File header comment in the style of
  `Fishing/Skill.lua`. `OneKeyFishing/OneKeyFishing.toc`: `Fishing\Camp.lua` after `Fishing\Skill.lua`, before
  `Catch\Stats.lua`. `.luacheckrc`: `C_UnitAuras` and `C_Secrets` in `read_globals`. What T002 noted for a new
  module. T008 passes.
- [X] T010 [US1] `tests/fishing/camp_cast_test.lua` (new, fails first), driving `FISHING_CAST_START` through the
  addon's own cast path as `tests/catch/caught_test.lua` does:
  - the Rack active at the start and at the settle: `Camp.CastMask(castID)` is 1; asked a second time for the same
    cast (two modules ask): 1 again;
  - no buff: 0; both: 3;
  - the buff ends between the start and the settle (the clock passes `expires`): 0;
  - the buff is granted after the start: 0;
  - the state unknown at the start (restricted, never read): 0, also when it is known at the settle;
  - a cast ID that never started: 0;
  - **a miss after a quick recast**: cast N starts under the Rack and stops, cast N+1 starts, then `CastMask(N)`
    is still 1 (`Catch/Catch.lua` settles a miss a second after the stop);
  - after `CastMask(N+1)` the mask of N is gone (`CastMask(N)` is 0); after ten more cast starts without a settle
    no mask older than eight casts is kept.
- [X] T011 [US1] `OneKeyFishing/Fishing/Camp.lua`: on `FISHING_CAST_START` read (when allowed), keep `Mask()` (or
  `false`) under `ns.GetFishingCastID()` and drop masks more than eight casts old; `Camp.CastMask(castID)` per
  research R3 and data-model.md "The mask of a cast" (drop the masks of casts before `castID`, keep `castID`'s);
  remember the answer as `lastMask`. `-- VERIFY(V63): the bonus is decided by the aura during the cast` above
  `CastMask`. T010 passes.
- [X] T012 [US1] `tests/catchdb/bonus_recording_test.lua` (new, fails first), in the style of
  `tests/catchdb/recording_test.lua`:
  - a catch with the Rack active: the place's cell in `shared.mine` and in the own record has `c` one higher, the
    item in `i`, and `q["1"] = { c = 1, m = 0, i = { [itemID] = { 1, pieces } } }`; `q[1]` (the number key) is nil;
  - a miss with the Rack active: `m` one higher and `q["1"].m` one higher;
  - a miss with the Rack active whose `FISH_MISSED` comes after the next cast started: still in `q["1"]`;
  - a catch without a buff: no `q` on a fresh cell; an existing `q` unchanged;
  - both buffs: only `q["3"]` grows;
  - a cast whose mask is 0 by the rule of T010 (the buff ended in it): totals only;
  - two catches of the same item under the Rack: `q["1"].i[itemID]` is `{ 2, pieces }`.
- [X] T013 [US1] `OneKeyFishing/CatchDB/Events.lua`: in the `FISH_CAUGHT` and `FISH_MISSED` handlers set
  `cast.mask = ns.Camp.CastMask(castID)` on the taken cast before `Settle`. `OneKeyFishing/CatchDB/CatchDB.lua`,
  `Settle`: when `(cast.mask or 0) > 0`, for each target cell add to `cell.q[tostring(cast.mask)]` (created as `{
  c = 0, m = 0, i = {} }`): `c` and the items through `AddItems`, or `m`; set `P.bonusData = nil` when a part is
  created (the cache `HasBonusData` fills in T030; until then the field is only written). Update the comment above
  `Settle`. T012 passes.
- [X] T014 [US1] `tests/catchdb/bonus_check_test.lua` (new, fails first), in the style of the present record check
  tests: a record whose cell has a valid `q` passes; each of these is refused with the reason of data-model.md:
  `q` not a table; nine parts; a key that is the number 1, or the strings `"0"`, `"256"`, `"01"`, `"1.5"`, `"x"`;
  a part that is not a table; a part's `c` or `m` not a count; a part's `c` above the cell's `c`; two parts whose
  `c` sum above the cell's `c`; parts' `m` summing above the cell's `m`; a part item that is not in the cell's
  `i`; a part item with more catches than the cell's item; the rest (cell minus parts) breaking an item rule. A
  part under `"4"` and one under `"255"` pass. A cell without `q` passes as before. The own record written by the
  steps of T012 (a catch, a miss, both buffs) passes `CatchDB.CheckRecord`.
- [X] T015 [US1] `OneKeyFishing/CatchDB/Checks.lua`, `CheckCell`: the rules of data-model.md "Validation" after the
  pool part's (a local `MAX_BONUS_PARTS = 8`; sum the parts' items into one table and reuse `CheckItems(cell.i,
  cell.c - sum, summedItems)` for the rest, as the open-water check does). T014 passes.

**Checkpoint**: US1 done: casts under a buff are in their parts; nothing visible changed.

---

## Phase 5: User Story 8 - The split reaches other players (Priority: P1)

**Goal**: the parts survive the exchange and the harvest; 1.4.0 clients stay unharmed.

**Independent Test**: the tests below; in game, checklist step 8 and the size reading (V67).

- [X] T016 [US8] `tests/exchange/share/bonus_clean_test.lua` (new, fails first), in the style of the present exchange
  store tests: a received record whose cells carry `q` is stored with equal parts in fresh tables (changing the
  sender's table afterwards changes nothing stored); it is offered on with its parts (the encoded and decoded
  record holds them, under their string keys); a field beside `c`, `m`, `i` inside a part is dropped. No size is
  asserted (the rules above).
- [X] T017 [US8] `OneKeyFishing/Exchange/Share.lua`, `CleanCell`: copy `q` (per key `{ c = part.c, m = part.m, i =
  CleanItems(part.i) }`). `-- VERIFY(V67): a record with bonus parts stays under the size a peer takes` above the
  copy. T016 passes.
- [X] T018 [P] [US8] `tests/exchange/share/bonus_old_client_test.lua` (new; a guard, it passes once T015 is in):
  a copy of 1.4.0's `CleanCell` field list inside the test (the fields `c, m, t, px, py, i, p, a`, with a comment
  naming 1.4.0) applied to a cell with `q` gives a cell without `q`, with the same `c`, `m`, `i`, that passes
  `CatchDB.CheckRecord` in its record with the record's `seq` unchanged (FR-011): the rule "parts are inclusive".
- [X] T019 [US8] `tests/tools/harvest_test.mjs` (extended, fails first): a contribution whose cells carry parts:
  - the cleaned cell keeps them; a part above the totals, or under a key like `"0"`, `"01"` or `"x"`, makes its
    cell skipped like any bad cell (a number key cannot be written in a saved file the parser tells apart);
  - two contributions' parts of one mask are summed per place;
  - **scaling**: a cell with parts `"1"` and `"3"` scaled by factors that round awkwardly (for example 0.37 for
    catches and 0.61 for misses, with odd counts) still passes `checkCell`; its `c` equals the scaled parts' `c`
    plus the scaled rest's; an item whose catches all lie in parts before scaling has all its catches in parts
    after it; the parts' misses use the miss factor;
  - **a seed part's own numbers**: with three contributors of whom two fished under the Rack, the summed part
    `"1"` has `k = 2`, and `r` / `x` by the cell's rules over the part's own contributions;
  - **`p` beside `q`**: one contribution's cell with `p` and another's with `q` at one place, unscaled (weights
    of 1): the seed cell has `q` and no `p`; the same when scaled;
    - **one cell with both** `p` and `q`, scaled by awkward factors: the result has `q`, no `p`, and passes
    `checkCell`;
  - the written seed text holds `q = { ["1"] = { c = ..., m = ..., i = { ... } } }` (with `k`, `r`, `x` when
    present) and reads back equal.
- [X] T020 [US8] `tools/harvest.mjs`: `cleanCell`, `checkCell`, `sumContributions`, `cellLines` carry `q` by the rules
  of T015; `scaleCell` per research R15 (each part and the rest scaled apart, the totals built as their sum);
  `sumContributions` writes each part's own `k`, `r`, `x` and drops `p` from a summed cell that has `q`; a
  contribution's cell with both `p` and `q` loses `p` before it is scaled or checked. T019 passes. Do not run `npm run
  harvest` (the seed is a release step).

**Checkpoint**: US8's data path done; the views come with US2.

---

## Phase 6: User Story 2 - Bonus catches carry a tag and an honest chance (Priority: P1)

**Goal**: `filter.bonus` in the sums, `item.bonus` on tagged items, the tag's icon in both tabs and its words in
the tooltips.

**Independent Test**: the tests below; in game, checklist step 2.

- [X] T021 [US2] `tests/catchdb/bonus_views_test.lua` (new, fails first), in the style of
  `tests/catchdb/water_test.lua`, with own, seed and another player's cells that carry parts:
  - `bonus = "rack"`: catches, misses, items and the miss rate come from the parts with bit 1 (`"1"` and `"3"`);
  - `bonus = "hut"`: `"2"` and `"3"`; `bonus = "none"`: the cell minus all parts, a cast of mask 3 subtracted once;
  - `bonus = "all"` and a missing `bonus`: the numbers of a filter without the field;
  - a cell without `q` counts for `"all"` and `"none"`, never for a key;
  - `littleData` follows the filtered catches (49 under the Rack: little data; 50: not);
  - a part under `"4"` (unknown bit) counts for no known key and is left out of `"none"`;
  - `CatchDB.FilterKey` differs between the four values and is equal for a missing `bonus` and `"all"`;
  - with `bonus ~= "all"` a `water` value other than `"all"` changes nothing;
  - `CatchDB.BonusKeys()` is `{ "rack", "hut" }`.
- [X] T022 [US2] `OneKeyFishing/CatchDB/Views.lua`: a `ThroughBonus(cell, bonus)` beside `ThroughWater` (research
  R6, R15): a key sums the parts with its bit into `{ c, m, i, a = cell.a }`, and for a seed cell `k` = the largest
  `k` of those parts (else `cell.k`), `r` = their summed `r` (where a part has none, its `c`), `x` = their summed
  `x` (where none, `c`); `"none"` subtracts all parts and keeps `k = cell.k`, without `r` and `x`. `AddCell`
  applies it (and skips the water reduction when a bonus filter is set); `sum.bonus` set where `sum.water` is; the
  miss rate is shown under a bonus filter (it stays nil only under a water filter); `FilterKey` gains `|bonus`;
  `CatchDB.BonusKeys()`. Update the comments. T021 passes; extend T021 first with a seed cell whose parts carry
  `k` and `r`: the view under `"rack"` has the parts' players and the raw catches against the threshold.
- [X] T023 [US2] `tests/catchdb/bonus_tag_test.lua` (new, fails first):
  - a known item (6643) in a scope with 50 catches under the Rack: `item.bonus = { key = "rack", chance = its
    catches under the Rack / catches under the Rack, littleData = false, catches = 50, players = those with a
    catch under the Rack }`;
  - the same with 49: `littleData = true`;
  - a known item whose catches are all outside every part (old data): `{ key = "rack", littleData = true, catches
    = 0, players = 0 }`, no chance;
  - **the scope stays the view's own**: through `CatchDB.Query` at a spot with 60 catches of which 10 are under
    the Rack, on a map with 200 under the Rack elsewhere: the tagged item's `bonus.catches` is 10 and `littleData`
    true (the spot's, not the map's);
  - an item not on the list with all its catches under the Hut's parts, in the seed's cells: `key = "hut"`;
  - **an item caught only under `"3"`**, in the seed: `"hut"` in an "all" view (the higher rank), `"rack"` in a
    view under `"rack"`, `"hut"` in a view under `"hut"`;
  - the same item only in the own catch (one player): no tag; in the own catch and two other records: tagged;
    in two other records only: no tag (FR-017's three players); under the source `"mine"`: no data tag, a known
    item still tagged;
  - an item with one catch outside every part: no `item.bonus`;
  - an item caught under `"1"` and under `"2"`, never outside a part: no `item.bonus` in an "all" view;
  - every untagged item's `chance`, `catches` and `pieces` equal those of the same data without any `q` (SC-008);
  - a view with `bonus = "rack"`: an item known for the Rack, or tagged "rack" from the data, carries the five
    fields with the view's own numbers; other items none;
  - a view with `bonus = "hut"`: a known Rack item listed there carries `{ key = "rack", plain = true }`;
  - a view with `bonus = "none"`: a known item with catches there carries `{ key = "rack", plain = true }`; no item
    is tagged from the data there;
  - building any of these views calls no other query (count the calls of `CatchDB.Query`, `QueryMap` and
    `QueryCells` made from inside a build: none).
- [X] T024 [US2] `OneKeyFishing/CatchDB/Views.lua`: per research R7, in the pass that sums a scope: the sub-sum per
  bonus key under `"all"`, `rawAll` under a key or `"none"`, and who holds each item under each bonus; after the
  view is built set `item.bonus` by data-model.md "A view item's bonus" (the four shapes); a known item (through
  `ns.GameData.CampBonuses`) gets its tag in every view. No change for a scope without parts and no known item.
  T023 passes, and the present view tests still do.
- [X] T025 [US2] `tests/catalog/bonus_test.lua` (new, fails first): with an index over maps whose views carry
  `item.bonus`:
  - a zone place's `chance`, `littleData`, `catches`, `players` are the bonus's and `place.bonus` is the
    `item.bonus` table; the same for a row of `Catalog.Places` and for a spot row of `Catalog.Spots`; a list row
    carries the best place's `bonus` table and `players`;
  - a known item without data under its bonus: the place, the spot and the row are "Little data" (`littleData`
    true), their `catches` and `players` are 0, never nil, and every text built from them is `L["Little data"]`
    or the catches text, never empty;
  - the order by chance uses the bonus chance;
  - `Catalog.ChanceText(0.0047, false, 3)` is `(L["%s (%d players)"]):format("0.47%", 3)`;
    `ChanceText(0.0047, false, 3, true)` is `(L["%s (%d players)"]):format((L["%s with the bonus"]):format("0.47%"),
    3)`, "0.47% with the bonus (3 players)" in English; `ChanceText(nil, true)` and `ChanceText(nil, false)` are
    `L["Little data"]`;
  - `Catalog.BonusTag("rack")` / `("hut")`, `Catalog.BonusTip`, `Catalog.BonusLabel` for `"all"`, `"none"`,
    `"rack"`, `"hut"` give the agreed texts; with `wow.item_icons[279965] = 777`, `Catalog.BonusIcon("rack")` is 777;
  - `Catalog.TooltipLines(itemID)` returns the lines, a tagged place's `right` in the bonus form, and second the
    best place's `bonus` table; nil as the second value for an untagged item;
  - `Catalog.DefaultFilter().bonus` is `"all"`; under the filter `"rack"` a known item's place has the view's own
    numbers and `place.bonus.key = "rack"`; under `"none"` a known item's place keeps the ordinary numbers and
    `place.bonus.plain` is true;
  - `Catalog.MinimapLines()` gives a tagged item's right text in the bonus form.
- [X] T026 [US2] `OneKeyFishing/Catalog/Catalog.lua`: the contract's changes (the filter field in `DEFAULT_FILTER`,
  `DefaultFilter`, `IndexFor`; `RebuildItems`, `Places`, `Spots` and the rows; `ChanceText`'s fourth argument
  (`withBonus`) and its nil chance; `BonusTag`, `BonusTip`, `BonusLabel`, `BonusIcon` with `-- VERIFY(V66): the camp
  features' item icons are known to every client` above it; `TooltipLines`' second value; `MinimapLines`). The texts:
  the keys `Fishing Rack bonus`, `Fishing Hut bonus`, `Bonus catch: comes only with the buff of a Fishing Rack
  (Uncommon Fishing).`, `Bonus catch: comes only with the buff of a Fishing Hut (Rare Fishing).`, `%s with the bonus`,
  `All catches`, `No camp bonus`, `Fishing Rack`, `Fishing Hut` in `Locales/enUS.lua` with the nine translations
  (`C_Item` is already a declared global; if `GetItemIconByID` needs a stub, T003 added it). T025 passes.
- [X] T027 [US2] `tests/ui/here_bonus_test.lua` and `tests/ui/catalog_bonus_test.lua` (new, fail first; only the
  tag steps in this task, the button's in T029):
  - **the icon**: a tagged item's row in "What can be caught here", in the catalog's list, zone rows and spot rows
    shows the tag's icon at the right end of the name column and, in the chance cell, the number of
    `item.bonus.chance` (`ns.Percent(item.bonus.chance)`, not `item.chance`) without the "with the bonus" words; the
    name's width is the column's minus the icon's; an untagged row has no icon and its full name width;
  - a known item without bonus data: the icon, "Little data" in the chance cell (also in the catalog list's right
    column sorted by chance) and `0` in a zone row's Catches cell;
  - **item rows** ("What can be caught here", the catalog's list): hovering a tagged row, the tooltip has, after
    the item's own lines, `Catalog.BonusTag`, `Catalog.BonusTip` and the chance in the bonus form with its players;
    with `settings.tooltipChances` off they are still there; a `plain` tag shows the first two lines only;
  - **the "Unknown item" row** of "What can be caught here", tagged: its own lines, then the same bonus lines;
  - **zone and spot rows** of the catalog: the place tooltip has its name, its catches line from the bonus's
    numbers, then the bonus lines; hovering such a row of a known item without bonus data raises no error and
    reads "0 catches";
    - **not doubled**: after hovering a tagged item row, `run_item_post_calls(GameTooltip, itemID)` (T003) adds no
    second `Catalog.BonusTip` line; after `GameTooltip:Hide()` (its `OnHide`), a new `SetOwner` with a bag button
    and the same call add it; a `ns.ShowItemTooltip` of that item without a bonus (another owner or the same)
    leaves nothing kept, so the call adds it.
  `tests/ui/tooltips_test.lua` (extended): an item tooltip outside the addon's rows of a tagged item has one more
  line under "Caught in:" with `Catalog.BonusTip`; an untagged item has none; with `tooltipChances` off neither.
- [X] T028 [US2] `OneKeyFishing/UI/Widgets.lua`: `ns.AddBonusLines(tooltip, bonus)`, `ns.ShowItemTooltip(owner,
  itemID, withPrice, bonus)` setting what it keeps after `SetOwner` and before `SetItemByID` on every call (nil
  without a bonus), a `GameTooltip:HookScript("OnHide")` clearing it, and `ns.TooltipHasBonus(tooltip,
  itemID)` (contract). `OneKeyFishing/UI/CatchHere.lua`: the icon texture on a row (research R19; 14 pixels, at the
  right end of the name column, hidden on untagged and header rows); the row keeps its `bonus` and hands it to
  `ns.ShowItemTooltip`; the "Unknown item" branch calls `ns.AddBonusLines` after its lines; a tagged row's chance cell
  through `Catalog.ChanceText(item.bonus.chance, item.bonus.littleData)` unless the tag is `plain`, an untagged
  one's as today. `OneKeyFishing/UI/CatalogTab.lua`: the same icon on the list rows and the
  zone and spot rows; a list row hands its bonus to `ns.ShowItemTooltip`; `ShowPlaceTooltip` calls
  `ns.AddBonusLines` after its catches line; `RightColumn` writes "Little data" for an item whose chance is nil and
  `littleData` true (not ""). `OneKeyFishing/UI/ItemHooks.lua`: the extra line from `TooltipLines`' second value,
  skipped when `ns.TooltipHasBonus(tooltip, itemID)`. T027 passes.

**Checkpoint**: US2 done: a Bloated fish reads as a bonus catch with its own chance.

---

## Phase 7: User Story 3 - A filter by camp bonus (Priority: P2)

**Goal**: the "Camp bonus" button in the Water button's place in both tabs.

**Independent Test**: the tests below; in game, checklist step 3.

- [X] T029 [US3] `tests/catchdb/bonus_views_test.lua` (extended, fails first): `CatchDB.HasBonusData()` is false
  without any part; true with a part in the seed, in the own counts or in a held record; `HasBonusData("hut")`
  only with a part whose mask has bit 2; it turns true after the own first cast under a buff and after a received
  record (`SHARED_DATA_CHANGED`), and **false again** after the record with the only part is removed; a held record
  with parts counts only while sharing is on; a part under `"4"` alone (unknown bit) counts for nothing. The two UI
  tests of T027 (extended, fail first): no button without bonus data; with Rack data the button shows with the
  text of `L["Camp bonus"]` and its menu offers "All catches", "No camp bonus", "Fishing Rack", no "Fishing Hut";
  a choice filters the list and sets the button's text to the value's label; the Hut value appears with Hut data;
  a chosen value that is no longer offered falls back to "All catches"; when the last bonus data leave, the button
  hides and the filter is "All catches"; with pool data and bonus data only the bonus button shows and the query's
  `water` is `"all"`; with pool data alone the Water button shows as before; the button's tooltip is the two
  agreed lines; every login starts at "All catches"; with "Fishing Rack" chosen, a skill range, a hidden kind, a
  search text and each sort order still narrow and order the same filtered list (FR-028); the chosen value stays
  when a camp aura comes or goes (`UNIT_AURA` with the stub changed: US3 scenario 6); "No camp bonus" at a place
  whose every catch was under a buff shows the tab's usual empty message (the edge case).
- [X] T030 [US3] `OneKeyFishing/CatchDB/Views.lua`: `CatchDB.HasBonusData(key)` cached in `P.bonusData` (a table: per
  key and for "any"). `OneKeyFishing/CatchDB/Events.lua`: set `P.bonusData = nil` at `ADDON_LOADED` and on **every**
  `SHARED_DATA_CHANGED` (not only when it holds a "no", unlike `P.poolData`). `OneKeyFishing/UI/ CatchHere.lua`: the
  bonus state (memory only), `CatchHere.OpenBonusMenu(owner, current, choose)`, `CatchHere.SetBonus`, the button
  anchored where the Water button is, shown by `HasBonusData()`, the Water button shown only when pools and no bonus
  data; the query's filter gets `bonus`. `UI/CatalogTab.lua`: the same for its own filter (`CatalogTab.SetBonus`).
  `HasBonusData` counts held records only while sharing is on and only parts with a known bit. The texts `Camp bonus`,
  `Show the catches made with a camp bonus: the fishing buff from a Fishing Rack or a Fishing Hut placed by a
  campfire.`, `"No camp bonus" also holds older catches for which the bonus is not known.` with nine translations.
  Menus build no title, divider or spacer in combat (CLAUDE.md, Forever API). T029 passes.

**Checkpoint**: US3 done.

---

## Phase 8: User Story 5 - A notice before the camp bonus ends (Priority: P3)

- [X] T031 [US5] `tests/fishing/camp_notice_test.lua` (new, fails first), with the test clock and the
  `C_Timer.After` stub. In every case the aura is first shown at grant (3600 s left) unless the step says otherwise:
  - fishing mode on: at 300 s left one `CAMP_BONUS_WARNING` with `L["The Fishing Rack bonus ends in 5 minutes."]`,
    at the end one with `L["The Fishing Rack bonus has ended."]`; the Hut's texts for the Hut; never a second one
    of either for the same buff;
  - fishing mode off at the 300 s crossing, turned on at 200 s left: no five-minute notice then or later, the end
    notice at the end (US5 scenario 6);
  - fishing mode off at the end, turned on after it: none; `settings.campBonusWarning` off at a crossing, turned
    on after it: none for that crossing;
  - the aura first seen with 200 s left (a login late in the hour), mode on: only the end notice;
  - a renewed buff (a later `expirationTime` read before the old end): no end notice for the old one, the
    five-minute notice again for the new;
    - **a fight over the 300 s crossing**: restricted from 320 s to 200 s left, mode kept on (`exitOnCombat` off):
    no five-minute notice at all (found 100 s late), the end notice at the end;
  - **the 30 s window**: the fight ends 20 s after the crossing: the five-minute notice then; 40 s after: none;
  - the five-minute timer comes due with the clock one frame short of the threshold: the notice still comes (the
    timer is armed a second past it);
  - **a fight over the end**: restricted when the end timer comes due: no notice then; at the fight's end with
    `exitOnCombat` off and the aura gone: the end notice once; with the aura renewed during the fight (a later
    `expirationTime` at the read): no end notice;
  - with `exitOnCombat` on (the default) the mode leaves at the fight's end before the read: no notice, and none
    when the mode is turned on again (FR-033);
  - a death out of a fight (the aura gone on a `UNIT_AURA` read): the end notice once.
  `tests/core/migrations_test.lua` (extended): the default of `campBonusWarning` is true.
  `tests/ui/toast_bonus_test.lua` (new; `tests/ui/` has no toast test yet): the toast shows the message's text
  with `settings.toasts` off.
- [X] T032 [US5] `OneKeyFishing/Fishing/Camp.lua`: the timers and the crossings of research R10 (`first`, `seen`,
  `warned`, `ended` per key, set when a crossing is found whether or not a notice is shown); the four texts, read when
  a notice fires, with nine translations. `OneKeyFishing/Core/Core.lua`: the default `campBonusWarning = true`.
  `OneKeyFishing/UI/Toast.lua`: `ns.On("CAMP_BONUS_WARNING", ...)` showing the text always, in the color the skill
  notice uses when it is not loud. `OneKeyFishing/UI/Settings.lua`: the row `{ key = "campBonusWarning", label =
  L["Warn when a camp bonus is ending"] }` after `skillCapWarning`, with nine translations (no hint: the rows have
  none). T031 passes.

---

## Phase 9: User Story 6 - Camp bonus rows in the statistics (Priority: P3)

- [X] T033 [US6] `tests/catch/stats_bonus_test.lua` (new, fails first): a catch and a miss under the Rack add 2 to
  `bonusCasts` of the session, the current zone and the total; a miss whose `FISH_MISSED` comes after the next
  cast started still counts; a catch under the Rack that holds item 6643 adds 1 to `bonusCatches`, a catch that
  holds two known items also 1, a catch of an ordinary fish 0; a catch of 6643 with mask 0 adds nothing; a saved
  bucket without the two fields reads 0 and counts on without an error; a session reset zeroes them.
  `tests/fishing/camp_cast_test.lua` (extended): `Camp.IsBonusCatch(1, { { itemID = 6643, quantity = 1 } })` true,
  with mask 2 false, with mask 0 false, with an ordinary item false. `tests/ui/stats_window_test.lua` (extended):
  the rows `L["Casts with a camp bonus"]` and `L["Bonus catches"]` are the last two rows of the "Results" block and
  show in the three columns when the total has a bonus cast ("Bonus catches" then also with 0); both are hidden
  otherwise, their place kept; the window is 736 high and the "Top catches" header sits two lines lower than
  today (FR-035).
- [X] T034 [US6] `OneKeyFishing/Fishing/Camp.lua`: `Camp.IsBonusCatch(mask, items)` (the list of `FISH_CAUGHT`).
  `OneKeyFishing/Catch/Stats.lua`: `NewBucket` with the two fields; the handlers take the cast ID (`FISH_CAUGHT`'s
  second and `FISH_MISSED`'s first argument) and add through a helper that reads a missing field as 0.
  `OneKeyFishing/UI/StatsFrame.lua`: the two rows as the last entries of the "Results" block of `ROWS` (the window
  is laid out once with fixed offsets: the rows always keep their place, their label, hover frame and cells are
  hidden while the total has no bonus cast); `HEIGHT` from 700 to 736 so the zone lines keep their room above the
  buttons; `UI/CatalogTab.lua`'s `WINDOW_HEIGHT = 660` is already stale and only sizes a fallback list capped by
  `MAX_ROWS`: leave it. The two
  texts with nine translations. T033 passes.

---

## Phase 10: User Story 7 - The Rack's lure is applied like any other (Priority: P3)

- [X] T035 [P] [US7] `tests/fishing/lures_test.lua` (extended, fails first): with 291005 and 6530 in the bags the
  offered lure is 291005; with 291005 and 6532 it is 6532; at Fishing 49 it is passed over, at 50 offered; the
  orders of `GameData.Lures` are 1 to 7 without a gap; with Camper's Lure on the pole (the weapon enchant stub
  set) the key offers no lure until it runs out, as for any lure. `OneKeyFishing/GameData/Lures.lua`: a comment
  line `-- Camper's Lure: from a placed Fishing Rack; +60 for 5 minutes, seen in game 2026-11-19` above the entry
  `[291005] = { bonus = 60, order = 4, skill = 50 },`, the three below it to orders 5, 6, 7 (every line within 120
  characters); the header comment no longer says no other lure exists. The test passes.

---

## Phase 11: Polish & Cross-Cutting

- [X] T036 `tests/core/report_sections_test.lua` (extended, fails first) then `OneKeyFishing/Fishing/Camp.lua`
  `Camp.Describe()`, `OneKeyFishing/CatchDB/Views.lua` `CatchDB.DescribeBonusParts(placeKey)` and
  `OneKeyFishing/Core/Debug.lua`: a section `-- Camp bonus --` with a line per bonus (`rack: aura 1280341, active,
  1234 s left` / `not active` / `unknown`), `aura reads restricted: true|false`, `last cast mask: N`, `setting
  campBonusWarning`; in the catch database section, after the current place, `bonus parts here: 1 = 12 catches / 3
  misses, ...` or `none` (FR-038). English, not localized.
- [X] T037 [P] Documents of the architecture:
  - `CLAUDE.md`: `CampBonuses` in the `GameData/*.lua` row; a row for `Fishing/Camp.lua` (after `Fishing/Skill.lua`)
    with its job and `fishing-mode.md`; the message `CAMP_BONUS_WARNING (text: a camp bonus ends in 5 minutes or
    has ended, Fishing/Camp.lua; the toast shows it even with catch notifications off)`; cross-module rules: the
    cast's bonus mask is asked from `Camp.CastMask(castID)`, never sent in a message; a bonus part of a cell is
    inclusive, disjoint and keyed by the mask as a string; a view never fetches another view; `020` in the list of
    features with a `verification.md`.
  - `docs/architecture/fishing-mode.md` (`Camp`: the state, the reads, the cast rule and why a mask outlives the
    next cast's start, the notices), `catch-db.md` (the cell's `q`, its checks, `filter.bonus`, `item.bonus`,
    `HasBonusData`), `exchange.md` (`CleanCell` and what a 1.4.0 client does with the part), `catalog.md` (the
    bonus numbers of a place, the texts, the icon), `game-data.md` (`CampBonuses`, Camper's Lure),
    `catch-and-stats.md` (the two bucket fields), `ui.md` (the button, the tag's icon, the tooltip lines, the
    rows, the setting), `core.md` (the saved fields, `ns.Percent`'s rule, the debug section).
  - `specs/002-local-catch-db/data-model.md`: the cell's shape gains `q` with a pointer to this spec.
  - `docs/fishing-investigation.md`, "What it means for the catch database": what spec 020 built (the parts by
    mask, not option B's one part per condition) in three lines, with the link.
  - `docs/development.md` if it lists the test files or the game data files.
- [X] T038 [P] `docs/checklists/camp-buffs.md` following `docs/checklists/README.md` "How a checklist is built":
  header (closes V60 to V67; needs a character with Fishing 140 and a Fishing Rack, a campfire, a party member,
  a mob for a fight, French or German as a second language, a second player on the new version and one on 1.4.0
  for step 8, a character that never fished under a buff for the size reading, Fishing 300 and a Fishing Hut for
  step 9), setup (two new files in the TOC: a game restart), the nine steps of quickstart.md "In game" with blanks
  for the values and the debug lines, each naming its FR, SC or V: among them the tag's icon after a fresh login
  (V66), the bytes per place of the own record with and without parts (V67), the end notice out of a fight and,
  with "Leave fishing mode when attacked" off, after one (V65). A step
  notes whether a tagged row's bonus lines survive the first hover of an item the client was still loading (the
  game rebuilds such a tooltip, as it does today with the price line). Steps already seen on 2026-11-19 are not repeated
  (cite the investigation document instead). Its row in the table of `docs/checklists/README.md`.
- [X] T039 `CHANGELOG.md`: `## [Unreleased]` above the newest release. `### Added`: catches made with a camp bonus
  (the fishing buff of a Fishing Rack or a Fishing Hut) are recorded apart and shared; bonus catches are marked with
  the camp feature's icon and show their chance with the bonus in "What can be caught here", the catalog and item
  tooltips; a "Camp bonus" filter in both tabs; a notice 5 minutes before a camp bonus ends and when it ends, with its
  setting; "Casts with a camp bonus" and "Bonus catches" in the statistics; Camper's Lure is applied like the other
  lures. `### Changed`: small chances are shown with a fraction ("0.47%") instead of "0%". `OneKeyFishing/README.md`:
  a section on the camp bonus (what it is in two lines, the icon and its tooltip, the filter and what "No camp bonus"
  holds, the notices and the setting and that a buff lost in a fight gives none with "Leave fishing mode when
  attacked" on, the statistics rows), the percentages, Camper's Lure in the lures list, the settings list.
- [X] T040 Run `npm run check` and `npm test`; compare with T001 (the new tests added; the open markers are V60 to
  V67 and no other); set the spec's status to "Implemented (in-game checklist `docs/checklists/camp-buffs.md`
  open)"; `docs/release-plan.md`: the open markers of this feature and that V67 is read before the release; hand
  the checklist to the author. The version stays 1.4.0 here: the bump to 1.5.0 and the harvest are release steps
  of `docs/publishing.md`, and `npm run build` refuses while a marker is open (the author closes them or releases
  with `--force`).

---

## Phase 12: Follow-up after the first in-game try (2026-11-20)

**Goal**: decisions 21 to 31 of the spec (FR-041 to FR-048): the filter buttons in two rows in both tabs, the Camp
bonus button that names its value, the value "Bonus catches only", "Per catch" without ".0", the hints and the
exchange line at the top of "What can be caught here" over a scrolling list, the catalog's status line under the
search box. No data change: `CatchDB` and the saved data stay as they are; no new `VERIFY` marker.

**Independent Test**: the tests below; in game, checklist steps 3 and 10 to 13 of
`docs/checklists/camp-buffs.md`.

- [X] T041 `tests/core/count_format_test.lua` (new, fails first): `ns.FormatCount(1)` is "1", 1.04 "1", 1.25 "1.3",
  1.5 "1.5", 12.96 "13", and with the decimal separator stubbed to a comma 1.5 is "1,5" and 2 is "2".
  `tests/ui/here_page_test.lua` and `here_kinds_test.lua` (extended): the "Per catch" cell of one piece reads "1".
  `OneKeyFishing/Core/Data.lua`: `ns.FormatCount(value)` beside `ns.Percent` (tenths rounded; a whole result through
  `%d` of a `math.floor`ed value, another through `ns.FormatDecimal(value, 1)`); `UI/CatchHere.lua` writes the
  column with it (FR-046). The tests pass.
- [X] T042 `tests/wow.lua`: the helper `list_rows(list)` (the rows a list of `ns.CreateList` shows: the scroll list's
  rows as the game makes them, or the fallback's shown rows; kind headers included). `tests/ui/here_page_test.lua`,
  `here_kinds_test.lua`, `here_seed_test.lua`, `catalog_kinds_saved_test.lua` read the rows of "What can be caught
  here" through it; the "and N more" case of `here_kinds_test.lua` becomes "the list scrolls: every item and header
  is listed, no 'and N more'" (fails first). `OneKeyFishing/UI/Widgets.lua`: `ns.CreateList(parent, top,
  initialize)` moved from `UI/CatalogTab.lua` unchanged (the scroll list, or the fixed rows with "and N more" without
  the templates, V37); `UI/CatchHere.lua`: the list through it in place of the 16 fixed rows, the row initializer
  drawing an item row or a kind header as before, `page.more` gone (FR-047). The catalog's fallback tests still see
  "and N more". The tests pass.
- [X] T043 `tests/ui/here_bonus_test.lua` (a layout case), `tests/ui/catalog_sort_test.lua` and
  `catalog_kinds_test.lua` (extended, fail first): in "What can be caught here" the hints and the exchange line above
  the counts, the counts above row A, row A above row B, the Water and the Camp bonus buttons at one slot, Kinds
  right of the Camp bonus button (at the slot without pool or bonus data), no `page.more`; in the catalog the search
  box at -32, the status line at -56, row A at -88, the slot at -114, Sort right of Kinds, the list at -146.
  `OneKeyFishing/UI/CatchHere.lua`: the y offsets as constants at the top (the place, the scope line, the hints up to
  three lines with their room kept, the exchange line, the counts, row A, row B, the column headers, the list); the
  place's line 540 wide (Kinds left its top right corner); `CatchHere.CreateWaterButton(parent, x, y, current,
  choose)`, `CatchHere.CreateBonusButton(parent, x, y, current, choose)` and `CatchHere.UpdateFilterSlot(waterButton,
  bonusButton, water, bonus, nextButton)` for both tabs (the shown slot button, both texts, the next button placed
  after it). `OneKeyFishing/UI/CatalogTab.lua`: the status line under the search box (where the zones begin on an
  item's page), row A Skill and Source, row B the slot, Kinds and Sort, the list below (FR-041, FR-047, FR-048). The
  tests pass.
- [X] T044 `tests/ui/here_bonus_test.lua`, `tests/ui/catalog_bonus_test.lua` (extended, fail first): the button reads
  `L["Camp bonus: All"]` at first and the short text of each chosen value; the menu keeps the full labels.
  `OneKeyFishing/Catalog/Catalog.lua`: `Catalog.BonusButtonText(value)` with the five whole texts `Camp bonus: All`,
  `Camp bonus: No bonus`, `Camp bonus: Bonus only`, `Camp bonus: Rack`, `Camp bonus: Hut`, nine translations each
  (the French and German ones short enough for row B); `CatchHere.BonusButtonText` removed, `UpdateFilterSlot` sets
  the text (FR-042). The tests pass.
- [X] T045 `tests/ui/here_bonus_test.lua`, `tests/ui/catalog_bonus_test.lua` (extended, fail first): the menu offers
  "Bonus catches only" after "No camp bonus"; under it "What can be caught here" lists only the tagged rows (the
  Bloated fish and the item tagged from the data, no ordinary fish), with the counts line of "All catches" and the
  chance with the bonus; a place with catches but no tagged item says `L["No bonus catch has been recorded here
  yet."]` and has no rows; the catalog lists only the tagged items (a known item without data among them), an item's
  page shows all its zones, `Catalog.Describe()` names no index of its own, and with bonus data but no tagged item
  the status line says `L["No bonus catch has been recorded yet."]`. `OneKeyFishing/UI/CatchHere.lua`:
  `OpenBonusMenu` with `"bonusOnly"`, `OfferedBonus` keeping it while `HasBonusData()`, `CatchHere.QueryBonus` and
  `CatchHere.BonusItems`, the empty text in `page.message`. `OneKeyFishing/Catalog/Catalog.lua`: `IndexFilter`
  (`"bonusOnly"` reads the index of `"all"`), `Catalog.Items` drops the untagged rows, `BonusLabel("bonusOnly")`.
  `OneKeyFishing/UI/CatalogTab.lua`: the empty text in `StatusText`. The three texts with nine translations; `CatchDB`
  untouched (FR-043 to FR-045). The tests pass.
- [X] T046 [P] Documents: `spec.md` (decisions 21 to 31, FR-023 and FR-024 adjusted, FR-041 to FR-048, User Story 3
  scenarios 2 and 7 to 11, two edge cases), `plan.md` (the follow-up section), `research.md` (R8 updated, R18's keys,
  R20 "Bonus catches only", R21 the layout), `data-model.md` (the value `"bonusOnly"`, UI and catalog only),
  `contracts/module-api.md`, `quickstart.md`, this phase; `docs/architecture/ui.md` (the two rows, the button's text,
  the value, the top block and the shared list), `catalog.md` (`IndexFilter`, `Catalog.Items` under `"bonusOnly"`,
  `BonusButtonText`), `core.md` (`ns.FormatCount`); `docs/checklists/camp-buffs.md` (the steps of the follow-up);
  `CHANGELOG.md` under `[Unreleased]` (Added: "Bonus catches only"; Changed: the button's text, the two rows, the
  scrolling list with the hints at the top, the catalog's status line, "Per catch"); `OneKeyFishing/README.md` ("What
  can be caught here", "Catch catalog", "Camp bonus").
- [X] T047 Run `npm run check` and `npm test`; no new `VERIFY` marker; hand the new checklist steps to the author.

---

## Dependencies & Execution Order

- Phase 1 -> Phase 2 -> the stories. T002 and T003 are independent of T001.
- US4 (T006, T007) needs nothing and comes first: US2's texts use the new format.
- US1 (T008 to T015) needs Phase 2 and T003.
- US8 (T016 to T020) needs US1's check (T015); T018 only T015; the harvest tasks (T019, T020) only the rules of
  T015, in another language and file.
- US2 (T021 to T028) needs US1 (the parts) and US4; T024 needs T022; T026 needs T024; T028 needs T026.
- US3 (T029, T030) needs T022 and the UI of T028 (the same two files).
- US5 (T031, T032) needs T009. US6 (T033, T034) needs T011. US7 (T035) needs nothing.
- Phase 11 after every story; T037 and T038 in parallel; T039, T040 last.
- Phase 12 after the first try in game: T041 on its own, T042 before T043 (the same rows), T044 before T045
  (the same button and tests); T046 after the code, T047 last.

Files touched by several tasks (no [P] between them): `Fishing/Camp.lua` (T009, T011, T032, T034, T036),
`CatchDB/Views.lua` (T022, T024, T030, T036), `CatchDB/Events.lua` (T013, T030), `UI/CatchHere.lua` and
`UI/CatalogTab.lua` (T028, T030), the locale files (T026, T030, T032, T034), `OneKeyFishing.toc` (T005, T009),
`tests/catchdb/bonus_views_test.lua` (T021, T029), the two UI bonus tests (T027, T029),
`tests/fishing/camp_cast_test.lua` (T010, T033), `tests/fishing/camp_state_test.lua` (T008, T036),
`tests/catchdb/bonus_views_test.lua` (T021, T022's extension, T029), `tests/wow.lua` (T003 only).

## Parallel Example: after US1

```
US8: T016 -> T017, with T018 [P] and T019 -> T020 beside it
US2: T021 -> T022 -> T023 -> T024 -> T025 -> T026 -> T027 -> T028
US5: T031 -> T032        US7: T035 [P] at any time
```

US8 touches `Exchange/Share.lua` and the harvest, US2 the views, the catalog and the UI, US5 `Camp` and the toast:
they do not meet, except in the locale files (US2 and US5: one after the other).

## Implementation Strategy

1. **First to try in game**: Phases 1 to 5 (the game data, the percentages, US1 and US8): casts under a buff are
   recorded, checked and shared, with nothing new on screen but the percentages. It is not a release by itself:
   the documents, the changelog, the manual and the checklist (T037 to T039) belong to the release (the definition
   of done), so a release cut here would need them brought forward.
2. **Then**: US2 (the tag and the chance) and US3 (the filter): the data become visible.
3. **Then**: US5, US6, US7 (the notices, the statistics rows, the lure), each on its own.
4. **Last**: the debug section, the documents, the checklist, the changelog and the manual, the final check.

Nineteen new visible texts in all (T026: 9, T030: 3, T032: 5, T034: 2), each with nine translations; the
follow-up adds eight (T044: 5, T045: 3).

## Notes

- Two new files in the TOC: the game needs a restart, not only `/reload`.
- One new message (`CAMP_BONUS_WARNING`), no command, no `DB_SCHEMA` bump, no change of the exchange's messages.
- The Fishing Hut's part of every task is built on V60 and cannot be tried until the author has Fishing 300.
- Commit only when the author asks (`020-camp-buffs` branch).
