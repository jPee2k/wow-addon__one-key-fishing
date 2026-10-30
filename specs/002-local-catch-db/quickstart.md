# Quickstart: validating the Local Catch Database

## Automated

```text
npm install
npm run check      # also: SeedData.lua parses, has the seed fields, is at most 1 MB; seed/ is in .pkgmeta ignore
npm test           # catchdb, prices, catchhere, harvest tests plus the existing ones
npm test -- catchdb
```

Expected: both pass. The tests cover the place key (FR-001 to FR-003), recording and the pool part (FR-004,
FR-007), counting once with the seed and the epoch reset (FR-019), the fallback and filters (FR-012 to FR-015), the
robust price (FR-025 to FR-027) and the harvest merge, validation, reset and size limit (FR-021 to FR-024).

## Harvest dry run

`tests/harvest_test.mjs` builds its fixtures in a temporary folder (a fake `WTF` tree with two accounts, a friend's
file and a broken file; a broken `.lua` file cannot live in `tests/`, where `npm run check` parses every Lua file)
and runs the harvest with an output folder in that temporary folder. Expected: the report lists the broken file as
rejected; the seed is written with `epoch + 1`; a second run with the same files gives the same sums.

Against real data: `npm run harvest` with `WOW_ADDONS_DIR` set; check the report and `git diff
OneKeyFishing/SeedData.lua`.

## In game: spike (after the game launch on 2026-11-04)

Each step closes items of [verification.md](verification.md). With `/okf spike` after `npm run install-addon` (or
`npm run link`) and a game restart:

1. Open water: start fishing, run `/okf spike` while the bobber is out. Note the map ID, map type, parent and the
   position.
2. A fishing pool: fish it until a catch, then `/okf spike`. Note the loot source GUIDs; compare with open water.
3. A city with water and a cave with water (if one exists): repeat step 1.
4. An instance with water (if reachable): repeat step 1.
5. Auction house: scan prices, then `/okf spike` for one fish (commodity) and one non-stacking item. Note the
   result counts, the total quantity and whether more results arrive.
6. Paste the report back; the facts go into `docs/forever-api.md`, the code is adjusted where needed and the
   `VERIFY` markers are removed.

## In game: the feature

1. Open `/okf stats`: two tabs at the bottom, "Statistics" shows today's numbers unchanged (SC-007).
2. "What can be caught here" at a spot covered by the seed, on a character with no catches: items, chances, counts
   appear (SC-001).
3. Fish 5 times there: the count grows by exactly the catches made (SC-002); the miss line grows with misses.
4. Walk to another part of the map: the tab follows; at a spot with few catches it says "whole map"; at a new map it
   says nothing has been caught yet.
5. Skill filter: own range by default, "All" adds other ranges; source filter "Only mine" shows only own catches.
6. Close the window on "What can be caught here", `/reload` and log out/in: it opens on that tab, filters at their
   defaults.
7. Switch the interface language: names change, numbers do not.
8. Auction scan: a fish with a normal market shows a price near the common listings; an item with fewer than 5
   pieces listed shows the "few lots" mark and the value rows use the vendor price.
9. Fish across a `/reload` mid-cast: the cast is counted once.
10. Watch the frame rate while opening the window and fishing: no stutter; login takes no noticeable extra time
    (SC-004).
11. `/okf debug`: the "Catch database" section shows the seed epoch, places, the current place key, and no ID.
