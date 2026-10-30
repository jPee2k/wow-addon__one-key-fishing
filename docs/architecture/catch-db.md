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

## Checking a received record

`CatchDB.CheckRecord(record)` checks a received record like the harvest's `checkRecord`, but rejects it whole.
Plus: an 8-character base32 ID, at most 1,000 places, `seq` not above the record's casts, items known to
`C_Item.GetItemInfoInstant`. The own ID is refused by Share's `Store.Accept`, not here ([exchange.md](exchange.md)).
