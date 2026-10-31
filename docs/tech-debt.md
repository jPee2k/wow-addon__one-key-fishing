# Technical debt

Known issues that are not fixed yet, with the reason they matter and a suggested direction. Each item says where
it was found and how serious it is. Remove an item when it is fixed (with a test), or move it to the spec of the
feature that takes it on.

Severity: **high** loses data or cuts off honest players; **medium** wrong state or wasted traffic; **low**
cleanup, no wrong behaviour.

## Open items

Found while building the catch catalog (`specs/005-catch-catalog`) on 2026-10-31; all **low**.

1. **The spot cache of the catalog only grows** (`Catalog.lua`, `spots`). Each expanded zone keeps its rows under
   `<item>|<map>|<filter>` for the session, also after its map's views are replaced. A few hundred entries at most in
   a session, but nothing frees them. Direction: keep only the entries of the chosen item, or drop the table when
   the version moves. Test: expand zones of two items, choose the second, and count the cached keys.
2. **A spot's pin target is computed with its rows** (`Catalog.Spots`). A change of the game rule or of what a map
   allows (V30) shows only after the map's stamp moves. Direction: compute `pin` when the row is drawn. Test: a spot
   with a pin, then `game_rules[...] = true`, and the row's button must go on the next draw.
3. **The pin's toast follows "Show catch notifications"** (`ns.Toast` returns early with toasts off), so with toasts
   off the pin is set silently. Direction: a toast that ignores the setting for answers to a click. Test: toasts off,
   press a pin button, a message must still show.
4. **HasPoolData scans every stored record while there is no pool data** (`CatchDB.HasPoolData`): every
   `SHARED_DATA_CHANGED` clears the false answer, and the next tab draw walks up to 20,000 places again. Only while
   pools are not told apart (V3). Direction: check only the records the change names. Test: count the cells walked
   after a keyed change in `tests/catchdb_water_record_test.lua`.

## History

Every review of the shared catch database was closed with tests the same or the next day; the details are in the
commit history of `002-shared-db` (commits "Fix ..." between 2026-10-29 and 2026-10-31).

- 2026-10-29, the local catch database: thirteen items fixed; the forged-record part moved to the design and was
  closed by the public channel's version chain.
- 2026-10-30, the catch exchange (three independent reviews): four high and six medium items fixed; the flood of
  message parts was closed by the public channel.
- 2026-10-31, the public channel (three review-and-fix cycles): every blocker, high and medium finding fixed.
- 2026-10-31, the low items of all reviews: the real ones fixed (channel, exchange and harvest), the rest recorded
  as accepted limits in `specs/004-public-channel-sync` (spec edge cases, data-model.md) or left as style.
