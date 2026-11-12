# Architecture: catch database

The `CatchDB/` folder: recording catches by place, the bundled seed and the views. The model and contracts
are in `specs/002-local-catch-db/` (`data-model.md`, `contracts/catchdb-api.md`, `contracts/seed-data.md`,
`contracts/harvest-command.md`), the later additions in `specs/004-public-channel-sync/` (weights, the version
chain) and `specs/005-catch-catalog/` (views across maps, areas, the water filter); the design is recorded in
[history/shared-db-plan.md](../history/shared-db-plan.md). The in-game checklist is
[catch-database.md](../checklists/catch-database.md); the catalog built on the views is [catalog.md](catalog.md).

One module, `ns.CatchDB`, in six files (TOC order): `SeedData.lua` (the seed, generated), `CatchDB.lua` (the
module table, constants and change stamps, place keys, the seed accessors, the own record (`CatchDB.OwnRecord`, also
for the exchange), its version chain, roll and settle), `Checks.lua` (the checks of other players' records, pure
functions), `Index.lua` (the indexes the views read: the seed's keys, the cells of others' records, the frozen own
records, the own places and items), `Views.lua` (sums, weights, the queries, `Describe`) and `Events.lua` (the game's
events: `ADDON_LOADED`, casts and catches, the index upkeep on `SHARED_DATA_CHANGED`, logout). The files share their
internals through `CatchDB.private` (not an API): a name a later file re-binds into a local is never reassigned; the
reassigned state (`version`, `ownItems`, `ownIndex`, `poolData`, `others`, `frozen`) lives on that table as
`P.<name>`.

## Places and recording

- A place is `<mapID>:<range>:<cell>`: the map as `C_Map.GetBestMapForUnit` returns it,
  `min(4, floor(base rank / 75))`, and a 10x10 grid cell (`"x"` without a position).
- A continent is never a place (spec 011): where the game reports a map of type Continent or above (a cave, such
  as the one before Wailing Caverns, gives Kalimdor 1414), `CatchDB.GetCurrentPlace` takes the zone under the
  player's point (`C_Map.GetMapInfoAtPosition`, The Barrens 1413) and reads the cell and position on it. Without a
  zone there, or without a position on it, there is no place and the cast is not recorded.
- The place is read at every `FISHING_CAST_START` under Catch.lua's cast number (`ns.GetFishingCastID()`), and the
  cast that `FISH_CAUGHT` or `FISH_MISSED` names is settled.
- Every catch and miss goes into `OneKeyFishingDB.shared.mine` (lifetime, never reset) and the account's
  contribution record `shared.records[myID]` (split by game version, read by the harvest).
- `myID` is 8 random base32 characters and never appears in the debug report.
- The subzone (`specs/011-catch-place-fixes` research R3): at `FISHING_CAST_START`, with a position,
  `CatchDB.LookupArea(done)` gives the lowest area ID whose `C_Map.GetAreaInfo` name equals `GetSubZoneText()`,
  both folded with `ns.FoldCase` (Principle II). The answer (an ID, or none) is cached per subzone text for the
  session; the first cast in a subzone walks the IDs 1 to 20000 (`P.MAX_AREA_ID`) in steps of 2000
  (`P.AREA_CHUNK`, one per frame through `C_Timer.After(0)`), and the cast gets its area when the walk ends (a
  lookup for another subzone during a walk gets none). Settling the cast adds 1 to the cell's `a[areaID]` (at most
  8 areas; a ninth is not added; never for cell `"x"`). Only the ID is stored; every client names it in its own
  language.

## The seed

- `ns.SeedData` is the seed written by `npm run harvest` ([development.md](../development.md)).
- Its `absorbed[id][epoch] = seq` names every unit it holds and up to which seq (`CatchDB.AbsorbedSeq`,
  `IsAbsorbed`).

## Rolling the own record

The own record rolls (`specs/002-local-catch-db/data-model.md`, "Rolling the own record") when the seed names it
or before a 501st place:

- a new record starts at the next epoch;
- the old one stays under `"<myID>@<epoch>"` (unless empty or held whole by the seed), counts like the live one
  (not when the seed holds it in part) and goes to peers until a seed holds it whole, so nothing counts twice and
  nothing is lost.

## Queries

- `CatchDB.Query(mapID, cell, filter)` sums the seed and the own record (or `mine`) for a spot, or for the whole
  map when the spot has fewer than 50 catches.
- With `settings.shareDB` on, source "all" also sums every other player's record
  (`shared.records["<id>@<epoch>"]`, the reset rule per build; not one the seed holds in part).
- A view has `players`: records with a summed cell plus the seed's largest `k`, an ID the seed absorbed only above
  that `k` (a lower bound, never an overcount); and `others`: another player's record has a catch in the sum
  (spec 012: the no-bundled-data hint of "What can be caught here").
- Indexes: the seed gets a per-map key index once, and all stored other records share one index by place key and
  by map (updated in place for the keys `SHARED_DATA_CHANGED` names, rebuilt without keys).
- Results are cached until `CatchDB.GetVersion()` changes, which `SHARED_DATA_CHANGED` bumps (so
  `Share.SetEnabled`, not a direct write of `settings.shareDB`, switches sharing).
- Weights: where five or more other contributions report a cell, none counts for more than a fifth of the
  others' part (water-filling over the raw counts); the seed and the own catch are not scaled. Chances and pieces
  are weighted by catches, `missRate` by casts (so many misses with few catches are capped too); `catches` stays raw
  (a seed cell the harvest weighted gives its raw catches as `r`).
- Items: an item neither in the seed nor in the own catch shows only once 3 other IDs reported it on the map
  (`reporters` and `inSeed` per item). Items the client does not know yet are kept and shown as "Unknown item"
  ([ui.md](ui.md)), which the tab reads when it draws the row.

## Views across maps

For the catch catalog ([catalog.md](catalog.md), `specs/005-catch-catalog`):

- `CatchDB.QueryMap(mapID, filter)`: the whole map's view without the spot fallback (scope `"map"` or `"none"`);
  `CatchDB.QueryCells(mapID, filter)`: one spot view per cell with catches (`cell`, `point` = the average catch
  position, `area` = the subzone with the most casts, other players' parts scaled by their cast factors, ties to the
  lower ID); `CatchDB.Maps(filter)`: the map IDs with data under the source. Every view's items carry `ranges`
  (`{ min, max }`, the skill ranges the item was caught in).
- Change stamps: `CatchDB.MapStamp(mapID)` is `"<global>:<map>"`. A settled cast moves its map;
  `SHARED_DATA_CHANGED` with keys moves the maps of the named records' entries before and after the change; without
  keys (sharing switched, a store rebuilt), a change to an own record, login, and an item new to the own catch move
  the global part. `CatchDB.GetStampVersion()` grows with any move, so a reader skips the comparison while nothing
  moved. QueryMap and QueryCells keep their views until their map's stamp moves; Query keeps its version cache.
- The own-cells index: the keys of `mine`, the own record and the frozen own records by `"<mapID>:<range>"`, built
  on first use and grown by `Settle`, so a map's sum no longer walks every own cell. Dropped on a roll, at login and
  on a `SHARED_DATA_CHANGED` without keys or naming an own record (data written past `Settle` needs one).
- The water filter: `filter.water` (`"all"` by default, `"open"`, `"pool"`) reads each cell through its pool part
  `p`: pools `p.c` and `p.i`, open water the rest, both without misses, so `missRate` is nil under them; players
  and the 50-catch rule count the filtered catches. `CatchDB.HasPoolData()` is true once any held cell has a pool
  part (a false answer is read again after `SHARED_DATA_CHANGED`). Since spec 011 no own catch writes a pool part:
  in Forever a pool catch has the bobber as its loot source, so the source of a catch is not known (V3). A pool part
  from an older build is still accepted and read, so the filter shows only with such data.

## Checking a received record

`CatchDB.CheckRecord(record)` checks a received record like the harvest's `checkRecord`, but rejects it whole.
Plus: an 8-character base32 ID, at most 1,000 places, `seq` not above the record's casts, item IDs up to
2,147,483,647 (an item the client does not know is accepted), a `proof` of 16 base32 characters, at most
`STEP_SECONDS` (180 s) of casting per step of `seq`, and a cell's `a` absent or at most 8 area IDs from 1
to 2,147,483,647 with counts summing to at most `c + m`, and the open water of a pool part
(`i - p.i` out of `c - p.c`) holding the same item rules. Share's `CleanCell` copies `a`; the harvest checks, sums
(the 8 largest), scales and writes it the same way. The own ID is refused by Share's `Store.Accept`, not here
([exchange.md](exchange.md)). `CatchDB.IsBlocked(id)` reads the seed's `blocked`.

## The version chain

Each epoch of the own record has a chain of 4,096 links from a 26-character secret in `shared.chain` (never sent,
never shown): link 4,096 is `ns.ProofStep(secret)`, each lower link the step of the one above, and the record at seq
`i` carries link `i` as `proof`. Only the owner can name a link above the newest one it published, so nobody can
make up a newer version. Marks every 64 links are built in the background after a roll or a login
(`CatchDB.private.OwnProofReady()`, read by the tests); a roll starts a new chain, and the seq reaching the top rolls
too. `CatchDB.CheckVersion(held, incoming, steps, state)` steps the incoming proof down to the held seq (resumable) and
compares; the seed carries the `proofs` of the versions it absorbed.
