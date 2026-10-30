# Architecture: catch database

SeedData.lua and CatchDB.lua: recording catches by place, the bundled seed and the views. The plan is in
[shared-db-plan.md](../shared-db-plan.md); the full model and contracts are in `specs/002-local-catch-db/`
(`data-model.md`, `contracts/catchdb-api.md`, `contracts/seed-data.md`, `contracts/harvest-command.md`); the
in-game checklist is [catch-database.md](../checklists/catch-database.md).

## Places and recording

- A place is `<mapID>:<range>:<cell>`: the map as `C_Map.GetBestMapForUnit` returns it,
  `min(4, floor(base rank / 75))`, and a 10x10 grid cell (`"x"` without a position).
- The place is read at every `FISHING_CAST_START` under Catch.lua's cast number (`ns.GetFishingCastID()`), and the
  cast that `FISH_CAUGHT` or `FISH_MISSED` names is settled.
- Every catch and miss goes into `OneKeyFishingDB.shared.mine` (lifetime, never reset) and the account's
  contribution record `shared.records[myID]` (split by game version, read by the harvest).
- `myID` is 8 random base32 characters and never appears in the debug report.

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
  that `k` (a lower bound, never an overcount).
- Indexes: the seed gets a per-map key index once, and all stored other records share one index by place key and
  by map (updated in place for the keys `SHARED_DATA_CHANGED` names, rebuilt without keys).
- Results are cached until `CatchDB.GetVersion()` changes, which `SHARED_DATA_CHANGED` bumps (so
  `Share.SetEnabled`, not a direct write of `settings.shareDB`, switches sharing).
- Weights (part 3): where five or more other contributions report a cell, none counts for more than a fifth of the
  others' part (water-filling over the raw counts); the seed and the own catch are not scaled. Chances and pieces
  are weighted by catches, `missRate` by casts (so many misses with few catches are capped too); `catches` stays raw.
- Items (part 3): an item neither in the seed nor in the own catch shows only once 3 other IDs reported it on the map
  (`reporters` and `inSeed` per item). Items the client does not know yet are kept and shown as "Unknown item"
  ([ui.md](ui.md)), which the tab reads when it draws the row.

## Checking a received record

`CatchDB.CheckRecord(record)` checks a received record like the harvest's `checkRecord`, but rejects it whole.
Plus: an 8-character base32 ID, at most 1,000 places, `seq` not above the record's casts, item IDs up to
2,147,483,647 (an item the client does not know is accepted, part 3), a `proof` of 16 base32 characters, and at most
`STEP_SECONDS` (180 s) of casting per step of `seq`. The own ID is refused by Share's `Store.Accept`, not here
([exchange.md](exchange.md)). `CatchDB.IsBlocked(id)` reads the seed's `blocked`.

## The version chain (part 3)

Each epoch of the own record has a chain of 4,096 links from a 26-character secret in `shared.chain` (never sent,
never shown): link 4,096 is `ns.ProofStep(secret)`, each lower link the step of the one above, and the record at seq
`i` carries link `i` as `proof`. Only the owner can name a link above the newest one it published, so nobody can
make up a newer version. Marks every 64 links are built in the background after a roll or a login
(`CatchDB.OwnProofReady()`); a roll starts a new chain, and the seq reaching the top rolls too.
`CatchDB.CheckVersion(held, incoming, steps, state)` steps the incoming proof down to the held seq (resumable) and
compares; the seed carries the `proofs` of the versions it absorbed.
