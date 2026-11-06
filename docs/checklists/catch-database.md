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

1. [ ] **Tabs** (V6): `/okf stats` shows three tabs below the window, "Statistics", "What can be caught here" and
   "Catch catalog", in the game's tab look. "Statistics" shows the same numbers as before the update.
2. [ ] **A fresh character with the seed** (V9): with a seed that covers a spot, a character that never fished there
   sees items, chances and "N catches" at once.
3. [ ] **Own catches** (V9): fish 5 times at one spot; the tab's count grows by exactly the catches, the miss line
   by the misses.
4. [ ] **Moving** (V9): walk to another part of the map; the tab follows. A spot with few catches says "Numbers for
   the whole map"; a new map says nothing has been caught there yet.
5. [ ] **Filters** (V9): the skill filter starts at your range; "All skill levels" adds the other ranges; "Only mine"
   shows only your catches. After a `/reload` and after logging out and in, the window opens on the tab you left
   it on, with both filters back at their defaults.
6. [ ] **Language** (V9): switch the interface language in the settings; names and texts change, numbers do not.
7. [ ] **Prices** (V9): after a scan, a fish with many listings shows a price near the common listings; an item
   with fewer than 5 pieces or fewer than 3 auctions listed shows "(few lots)" and its value uses the vendor price.
8. [ ] **Across a reload** (V9): `/reload` while the bobber is out, then catch: the catch is counted once.
9. [ ] **Load test** (V8): `npm run harvest -- --synthetic 3000`, `npm run install-addon`, restart the game. Login
   takes no noticeable extra time; opening "What can be caught here" and fishing show no stutter. Afterwards
   restore the real seed: `git checkout OneKeyFishing/CatchDB/SeedData.lua` and install again.
10. [ ] **Debug report** (V9): `/okf debug` has a "Catch database" section with the seed epoch, the places and the
    current place key, and no anonymous ID.

## Results

- Date, build, client language:
- Problems found:

What happens next (the fixes, the markers, the first real harvest, the release) is in
[release-plan.md](../release-plan.md).
