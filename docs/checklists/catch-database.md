# In-game checklist: Local Catch Database (part 1)

What to check in the game for the catch database (`specs/002-local-catch-db`), on and after the game launch on
2026-11-04. The feature was built before the game could be played, on the assumptions V1-V9 of
`specs/002-local-catch-db/verification.md`; each step below says which ones it closes. Tick each box, note
anything that looks wrong, and paste the `/okf spike` reports back: the answers go into `CLAUDE.md` "Known API
facts", and the `VERIFY` markers in the code are removed only after that.

## Setup

1. Install the build into the game (or link the working folder once with `npm run link`):

   ```bash
   npm run install-addon
   ```

2. Restart the game completely. New files were added to the TOC, so `/reload` is not enough.
3. Log in on a character that has learned Fishing, has a fishing pole and has the fishing keys bound.

## Part 1: Spike (game facts)

`/okf spike` opens a window with a report; copy it (Ctrl+A, Ctrl+C) and keep each one.

- [ ] **Open water** (V1, V2, V7): start fishing in fishing mode and run `/okf spike` while the bobber is out.
  Expected: a map ID, map type 3 (zone), a position with two numbers between 0 and 1, the game version
  `1.60.x`. Report: ____
- [ ] **Fishing pool** (V3): fish a pool until you catch something, then `/okf spike`. Expected: the loot source
  is a `GameObject` whose object ID is not 35591. Then catch once in open water and run it again: object ID
  35591 or no source. Reports: ____
- [ ] **City with water** (V1, V2): fish in a capital and run `/okf spike`. Note the map ID and type (a city may
  have its own map) and whether there is a position. Report: ____
- [ ] **Cave with water**, if you know one (V2): the same. Report: ____
- [ ] **Instance with water**, if one is reachable (V1): the same; the position is expected to be `nil`.
  Report: ____
- [ ] **Auction house** (V4, V5): open the auction house, scan prices (`/okf scan` or the button), then run
  `/okf spike`. Expected for a fish: results with prices in ascending order, a total quantity at least the
  loaded quantity. For an item that does not stack (if one was scanned): `buyoutAmount` and `quantity`.
  Report: ____

## Part 2: The feature

- [ ] **Tabs** (V6): `/okf stats` shows two tabs below the window, "Statistics" and "What can be caught here", in
  the game's tab look. "Statistics" shows the same numbers as before the update.
- [ ] **A fresh character with the seed** (V9): with a seed that covers a spot (after the first real harvest), a
  character that never fished there sees items, chances and "N catches" at once.
- [ ] **Own catches** (V9): fish 5 times at one spot; the tab's count grows by exactly the catches, the miss line
  by the misses.
- [ ] **Moving** (V9): walk to another part of the map; the tab follows. A spot with few catches says "Numbers
  for the whole map"; a new map says nothing has been caught there yet.
- [ ] **Filters** (V9): the skill filter starts at your range; "All skill levels" adds the other ranges; "Only
  mine" shows only your catches. After a `/reload` and after logging out and in, the window opens on the tab
  you left it on, with both filters back at their defaults.
- [ ] **Language** (V9): switch the interface language in the settings; names and texts change, numbers do not.
- [ ] **Prices** (V9): after a scan, a fish with many listings shows a price near the common listings; an item
  with fewer than 5 pieces or fewer than 3 auctions listed shows "(few lots)" and its value uses the vendor price.
- [ ] **Across a reload** (V9): `/reload` while the bobber is out, then catch: the catch is counted once.
- [ ] **Load test** (V8): `npm run harvest -- --synthetic 3000`, `npm run install-addon`, restart the game. Login
  takes no noticeable extra time; opening "What can be caught here" and fishing show no stutter. Afterwards
  restore the real seed: `git checkout OneKeyFishing/SeedData.lua` and install again.
- [ ] **Debug report**: `/okf debug` has a "Catch database" section with the seed epoch, the places and the current
  place key, and no anonymous ID.

## After the checklist

1. Record the answers in `CLAUDE.md` "Known API facts"; fix the code where an assumption was wrong (with tests).
2. Remove the `VERIFY` markers that are closed and tick V1-V9 in `specs/002-local-catch-db/verification.md`.
3. Run the spike part of `docs/checklists/catch-exchange.md` (the catch exchange, part 2) in the same session,
   then remove `OneKeyFishing/Spike.lua`, its TOC line, the `spike` entry in `OneKeyFishing/Commands.lua` and
   `tests/spike_test.lua`.
4. Fish, run `npm run harvest` for the first real seed, commit it, and release (`docs/publishing.md`).
