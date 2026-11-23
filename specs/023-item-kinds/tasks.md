---

description: "Task list for spec 023: new item kinds (Trophies, Quest) and the trophy collection"
---

# Tasks: New Item Kinds (Trophies, Quest) and the Trophy Collection

**Input**: Design documents from `specs/023-item-kinds/` (spec, plan, research, data-model, contracts, quickstart)

**Tests**: included: the project's rule (CLAUDE.md, Principle V) asks for a test with every logic change that can run
without the game. Tests run in fengari (Lua 5.3); the addon stays free of 5.1/5.3 differences.

**Paths**: addon files under `OneKeyFishing/`, tests under `tests/<area>/`, documents in the repository root.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1 kinds, US2 collection, US3 first-trophy notice

---

## Phase 1: Setup

- [X] T001 Read `docs/architecture/catalog.md` ("Item kinds"), `docs/architecture/catch-db.md` (own data, Settle),
  `docs/architecture/game-data.md` and `specs/014-catch-filters/` to confirm the present kind rules before editing;
  no file change

---

## Phase 2: Foundational (blocks every story)

- [X] T002 Add the four enUS keys `"Trophies"`, `"Quest"`, `"%s (%d/%d)"`, `"New trophy: %s (%d/%d)"` in
  `OneKeyFishing/Locales/enUS.lua` and their translations in `deDE.lua`, `esES.lua`, `esMX.lua`, `frFR.lua`,
  `koKR.lua`, `ptBR.lua`, `ukUA.lua`, `zhCN.lua`, `zhTW.lua` (same folder); color codes stay outside the strings

**Checkpoint**: `npm run check` passes (every key in every language).

---

## Phase 3: User Story 1 - Trophies and quest items have their own kinds (P1) MVP

**Goal**: seven kinds in the order Fish, Containers, Trophies, Potions & drinks, Reagents & herbs, Quest, Other.

**Independent test**: a list holding a cooking fish, a weighed fish and a quest item shows three headers in that order;
hiding Trophies removes only the weighed fish.

### Tests for User Story 1

- [X] T003 [P] [US1] In `tests/catalog/kinds_test.lua` (its list of every listed item; `tests/gamedata/shape_test.lua`
  already checks every value is a known kind) pin the lists: each of 6292, 6294, 6295, 6309, 6310, 6311,
  6363, 6364, 13876-13880, 13882-13887, 13901-13917 is `"trophies"` (36 IDs); each of 1467, 6717, 6718, 16967, 16968,
  16969, 16970, 19803, 19804, 19805, 19806, 19807 is `"quest"` (12 IDs); `byClass["12"] == "quest"`; every kind
  value in `byItem` is one of the seven kinds
- [X] T004 [P] [US1] In `tests/catalog/kinds_test.lua`: `Catalog.KINDS` equals
  `{ "fish", "containers", "trophies", "potions", "reagents", "quest", "other" }`; an unlisted item of class 12 is
  `"quest"`; `Group` puts headers in that order; `ShownKinds()` returns `7, 7` by default; a saved
  `hiddenKinds = { containers = true }` (a five-kind era choice) still hides containers and shows trophies and quest
  (FR-005)
- [X] T005 [US1] After T006 and T007, run `npm test` and fix exactly the existing tests that fail because they assume
  five kinds or a trophy / quest item as `"fish"` (expected among `tests/catalog/index_test.lua`,
  `tests/catchdb/bonus_views_test.lua`, `tests/catchdb/water_test.lua`, `tests/catch/auction_price_test.lua`,
  `tests/core/report_seed_kinds_test.lua`, `tests/ui/catalog_kinds_test.lua`, `tests/ui/here_kinds_test.lua`,
  `tests/ui/here_bonus_test.lua`; the button text becomes "Kinds: n of 7"); change no test that still passes

### Implementation for User Story 1

- [X] T006 [US1] In `OneKeyFishing/GameData/ItemKinds.lua`: change the listed trophies (6292, 6294, 6295, 6309, 6310,
  6311, 6363, 13876, 13877, 13878, 13879, 13882, 13883, 13885, 13886, 13901, 13907, 13908, 13909, 13910, 13914,
  13915) from `"fish"` to `"trophies"`; add 6364, 13880, 13884, 13887, 13902, 13903, 13904, 13905, 13906, 13911,
  13912, 13913, 13916, 13917 as `"trophies"` with their names in comments (class 15 / 0); change 1467, 16967,
  16968, 16969, 16970, 19805, 19806, 19807 to `"quest"`; add 6718, 19803, 19804 as `"quest"` and move 6717 (Gaffer Jack) from `"other"`; add
  `["12"] = "quest"` to `byClass`; update the header comment's kind list
- [X] T007 [US1] In `OneKeyFishing/Catalog/Catalog.lua`: `Catalog.KINDS = { "fish", "containers", "trophies",
  "potions", "reagents", "quest", "other" }`; `Catalog.KindText` returns `L["Trophies"]` and `L["Quest"]` for the new
  kinds (looked up when drawn)
- [X] T008 [US1] Check `OneKeyFishing/UI/CatchHere.lua` and `OneKeyFishing/UI/CatalogTab.lua` for any width or count
  tied to five kinds (the kind menu builds from `Catalog.KINDS`); adjust only if a test of T005 shows it

**Checkpoint**: `npm test` passes; US1 works alone.

---

## Phase 4: User Story 2 - The trophy collection in the catalog (P2)

**Goal**: "Trophies (n/36)" on the catalog's Trophies header and a check mark on each trophy the account caught.

**Independent test**: with two trophies in the own data, the header reads "Trophies (2/36)", those rows carry the
mark, a trophy known only from others' data does not.

### Tests for User Story 2

- [X] T009 [P] [US2] New `tests/catalog/trophies_test.lua`: `Catalog.TrophyIDs()` returns the 36 IDs ascending and the
  same table twice; `Catalog.TrophyCount()` counts trophies in `shared.mine` and in an own record of another game
  version (`<id>@<epoch>` and a build other than the current), not those only in another player's record or in the
  seed; a non-trophy item in the own data does not count; hiding Trophies or a search does not change the count
- [X] T010 [P] [US2] New `tests/catchdb/own_item_test.lua`:
  `CatchDB.IsOwnItem(itemID)` is true for an item of `shared.mine` and of an own record, false for another player's
  item and a seed item, and true right after a settled catch of a new item
- [X] T011 [P] [US2] New `tests/ui/catalog_trophies_test.lua` (its own seed and own catch): the catalog list's Trophies header text is
  `"Trophies (n/36)"`; a caught trophy's row shows the check mark texture, an uncaught one and a non-trophy row do not
  (a reused row frame clears the mark)

### Implementation for User Story 2

- [X] T012 [US2] In `OneKeyFishing/CatchDB/Index.lua`: public `CatchDB.IsOwnItem(itemID)` reading `OwnItems()`
  (builds on first use); document it in the file's header comment
- [X] T013 [US2] In `OneKeyFishing/Catalog/Catalog.lua`: `Catalog.TrophyIDs()` (the IDs whose
  `GameData.ItemKinds.byItem` value is `"trophies"`, sorted ascending, built once) and `Catalog.TrophyCount()`
  returning `caught, total` with `ns.CatchDB.IsOwnItem`
- [X] T014 [US2] In `OneKeyFishing/UI/CatalogTab.lua` `InitItemRow`: the `trophies` header reads
  `L["%s (%d/%d)"]:format(Catalog.KindText("trophies"), Catalog.TrophyCount())`; a check mark texture (atlas
  `common-icon-checkmark`, 12 px, anchored to the icon's bottom right) made once per row, shown only for an item row
  whose `Catalog.ItemKind(itemID) == "trophies"` and `CatchDB.IsOwnItem(itemID)`, hidden on header rows and other
  items; the count follows a new catch at the window's next refresh (the catalog already redraws on
  `CatchDB.MapStamp` changes)

**Checkpoint**: US2 works with US1; `npm test` passes.

---

## Phase 5: User Story 3 - A notice for a new trophy (P2)

**Goal**: a gold toast "New trophy: <item> (n/36)" and the rare sound on the account's first catch of a trophy; the
ordinary catch toast for a repeat.

**Independent test**: first catch of a trophy: the loud toast (also with catch notifications off), the ordinary toast
without it, the rare sound once; second catch: the ordinary toast only.

### Tests for User Story 3

- [X] T015 [P] [US3] New `tests/catchdb/first_caught_test.lua`: a settled catch of an item not in the own data fires
  `ITEM_FIRST_CAUGHT(itemID, castID)` once, after `CatchDB.IsOwnItem(itemID)` became true, also when no view has built
  the own-items set before (fresh login state); a second catch, a miss, and an item already in an own record of an
  older version fire nothing; two new items in one loot fire twice, ascending by item ID; a cast without a place fires
  nothing
- [X] T016 [P] [US3] New `tests/ui/trophy_toast_test.lua`: a first trophy shows the toast
  `"New trophy: <link> (n/36)"` with the count after the catch, also with `settings.toasts = false`; the ordinary
  "Caught:" toast of that cast leaves the trophy out and is not shown when nothing is left; a repeated trophy shows the
  ordinary toast only; two new trophies in one loot give two toasts with n+1 and n+2; a first non-trophy item gives no
  trophy toast
- [X] T017 [P] [US3] In `tests/fishing/sound_events_test.lua`: `ITEM_FIRST_CAUGHT` of a trophy schedules the rare
  sound once; with a green item in the same loot the rare sound still plays once; nothing in a fight, outside
  fishing mode or with the sounds off; a first non-trophy item plays nothing extra

### Implementation for User Story 3

- [X] T018 [US3] In `OneKeyFishing/CatchDB/CatchDB.lua` `Settle`: call `P.OwnItems()` before the cast is written;
  after the write, for each caught item not in the set (ascending by item ID), add it and collect it; after `BumpMap` /
  `Changed`, fire `ns.Fire("ITEM_FIRST_CAUGHT", itemID, castID)` for each collected item (pass the cast's ID into
  `Settle` from `CatchDB/Events.lua`); keep the existing `BumpAll()` for a new item; only catches fire, never misses
- [X] T019 [US3] In `OneKeyFishing/UI/Toast.lua`: on `ITEM_FIRST_CAUGHT(itemID, castID)` with
  `ns.Catalog.ItemKind(itemID) == "trophies"`, remember `itemID` for `castID`; in the `FISH_CAUGHT(items, castID)`
  handler, for each remembered item show `ns.Toast(L["New trophy: %s (%d/%d)"]:format(item.link, caught, total), 1,
  0.82, 0, true)` (caught and total from `Catalog.TrophyCount()`, which already counts every new trophy of the cast; the n of a
  toast is `caught` minus the number of the cast's new trophies after it in loot order, so two give n+1, n+2), leave those items out of
  the ordinary "Caught:" toast, show none when nothing is left, then forget the cast
- [X] T020 [US3] In `OneKeyFishing/Fishing/Sound.lua`: a per-cast guard so the rare sound plays at most once per cast
  (the existing `IsRare` path sets it); on `ITEM_FIRST_CAUGHT(itemID, castID)` with
  `ns.GameData.ItemKinds.byItem[itemID] == "trophies"` and `Allowed()`, schedule the rare sound the same way unless
  the cast's guard is set (the message comes after Sound's own `FISH_CAUGHT`); Sound reads only `GameData`, never `Catalog` or `CatchDB`

**Checkpoint**: all three stories work; `npm test` passes.

---

## Phase 6: Polish & Cross-Cutting

- [X] T021 [P] `CLAUDE.md`: add `ITEM_FIRST_CAUGHT` (itemID, castID: an item new to the account's own catch, fired by
  CatchDB's Settle inside FISH_CAUGHT) to the message list; mention `CatchDB.IsOwnItem` where the own data is described
  if needed
- [X] T022 [P] `docs/architecture/catalog.md` ("Item kinds": seven kinds, `TrophyIDs`, `TrophyCount`, the header and
  the mark), `docs/architecture/catch-db.md` (`IsOwnItem`, the set built before the write, the message),
  `docs/architecture/game-data.md` (the new kinds and class 12), `docs/architecture/ui.md` (the trophy toast, the
  mark), `docs/architecture/fishing-mode.md` (the rare sound for a first trophy)
- [X] T023 [P] `CHANGELOG.md` under `[Unreleased]` and `OneKeyFishing/README.md` (the kinds Trophies and Quest and
  their order, the collection in the catalog, the new trophy notice)
- [X] T024 [P] `docs/ROADMAP.md`: remove the "New item kinds (spec 023)" entry from "Planned" once done
- [X] T025 Run `npm run check` and `npm test`; fix what they report
- [X] T026 Write the in-game look as `docs/checklists/item-kinds.md` (with its row in that folder's `README.md`; no `VERIFY` markers
  in this spec)

---

## Dependencies & Execution Order

- Phase 1 -> Phase 2 (T002 texts) -> US1 (T003-T008).
- US2 (T009-T014) needs US1 (the "trophies" kind). US3 (T015-T020) needs US1 and T013 (`TrophyCount` for the toast);
  T018 needs T012 (`IsOwnItem` shares the set).
- Within a story: tests first (they fail), then the implementation.
- Polish after the stories.

### Parallel opportunities

- T003, T004 (different test files; T005 runs after T006 and T007); T009, T010, T011; T015, T016, T017; T021-T024.
- T006 and T007 touch different files but T007's tests need T006: run T006 first or together.

### Parallel example: User Story 3

```text
T015 tests/catchdb/first_caught_test.lua
T016 tests/ui/trophy_toast_test.lua
T017 tests/fishing/sound_events_test.lua
```

## Implementation Strategy

- **MVP**: Phases 1-3 (the two kinds): releasable alone.
- Then US2 (the collection), then US3 (the notice), each checked with `npm test`.
- One commit per finished phase only when the author asks (no automatic commit).
