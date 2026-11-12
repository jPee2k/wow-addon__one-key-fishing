# In-game checklist: the local catch database

**Feature**: "What can be caught here", the bundled catch database and the robust auction prices
(`specs/002-local-catch-db`, part 1 of the shared catch database).
**Closes**: V6, V8, V9 of `specs/002-local-catch-db/verification.md` (V1-V5 and V7 are closed by
[spike.md](spike.md), which runs first).
**Needs**: one character with Fishing; a build with a real seed for step 2 (after the first `npm run harvest`); the
auction house for step 7.

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`); restart the game
   completely (new files in the TOC).
2. Log in on a character that has learned Fishing, has a fishing pole and has the fishing keys bound.

## Steps

1. [x] **Tabs** (V6): `/okf stats` shows three tabs below the window, "Statistics", "What can be caught here" and
   "Catch catalog", in the game's tab look. "Statistics" shows the same numbers as before the update.
   In game 2026-11-06 (`002-shared-db`, enUS): as expected.
2. [ ] **A fresh character with the seed** (V9): with a seed that covers a spot, a character that never fished there
   sees items, chances and "N catches" at once.
   Partly 2026-11-07 (test seed from the Statistics tab): a level 1 character in Undercity without Fishing sees the
   seed in the catalog; the tab at a seeded spot is still to be checked (needs a character there).
3. [x] **Own catches** (V9): fish 5 times at one spot; the tab's count grows by exactly the catches, the miss line
   by the misses. In game 2026-11-07: 5 casts, 3 catches and 2 misses: 34 -> 37 catches,
   13% -> 16% nothing caught (5/39 -> 7/44).
4. [x] **Moving** (V9): walk to another part of the map; the tab follows. A spot with few catches says "Numbers for
   the whole map"; a new map says nothing has been caught there yet. In game 2026-11-07: the tab follows by itself (Mulgore, The
   Barrens: "Numbers for the whole map: few catches at this spot."; Dustwallow Marsh: "Nothing has been caught here
   yet."). Seen: "1 catches" (`docs/tech-debt.md`).
5. [x] **Filters** (V9): the skill filter starts at your range; "All skill levels" adds the other ranges; "Only mine"
   shows only your catches. After a `/reload` and after logging out and in, the window opens on the tab you left
   it on, with both filters back at their defaults. In game 2026-11-07, with a test seed made from the Statistics
   tab (range 75-149, not committed): as expected.
6. [x] **Language** (V9): switch the interface language in the settings; names and texts change, numbers do not.
   In game 2026-11-07 (enUS client, addon in Ukrainian): the texts change, item and zone names stay in the
   client's language, the numbers stay; no error.
7. [x] **Prices** (V9): after a scan, a fish with many listings shows a price near the common listings; an item
   with fewer than 5 pieces or fewer than 3 auctions listed shows "(few lots)" and its value uses the vendor price.
   In game 2026-11-07: as expected.
8. [x] **Across a reload** (V9): `/reload` while the bobber is out, then catch: the catch is counted once.
   In game 2026-11-07: counted once.
9. [x] **Load test** (V8): `npm run harvest -- --synthetic 3000`, `npm run install-addon`, restart the game. Login
   takes no noticeable extra time; opening "What can be caught here" and fishing show no stutter. Afterwards
   restore the real seed: `git checkout OneKeyFishing/CatchDB/SeedData.lua` and install again.
   In game 2026-11-06 (2881 places, 574 KB, linked): no extra time on `/reload`, no stutter on both tabs.
10. [x] **Debug report** (V9): `/okf debug` has a "Catch database" section with the seed epoch, the places and the
    current place key, and no anonymous ID. In game 2026-11-06: `seed epoch 0, 0 places` (no seed yet), the own
    places and the current place key `1434:2:27`; no anonymous ID.

## Results

- Date, build, client language: 2026-11-06 and 2026-11-07, game 1.60.1 (70790), enUS, `002-shared-db` linked;
  steps 5 and 8 with a test seed made from the Statistics tab, step 9 with a synthetic seed (neither committed).
- Problems found: "1 catches", fixed by spec 010 (confirmed 2026-11-08). Open: step 2 at a seeded spot with a character that has
  Fishing, then a real seed.

What happens next (the fixes, the markers, the first real harvest, the release) is in
[release-plan.md](../release-plan.md).
