# Technical debt

Known issues that are not fixed yet, with the reason they matter and a suggested direction. Each item says where
it was found and how serious it is. Remove an item when it is fixed (with a test), or move it to the spec of the
part that takes it on.

Severity: **high** loses data or cuts off honest players; **medium** wrong state or wasted traffic; **low**
cleanup, no wrong behaviour.

## Open items

Found while building part 4 (the catch catalog, `specs/005-catch-catalog`) on 2026-10-31; all **low**.

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

- **Review of 2026-10-29** on `002-shared-db`: the thirteen items are fixed, each with a test; the part of item 11
  (a forged record) that a client cannot check on its own moved to `docs/shared-db-plan.md` ("Protection against
  spam and fakes"), which part 3 takes on.
- **Review of 2026-10-30** (part 2, three independent reviews): the four high and six medium items were fixed with
  tests the same day; the flood of parts is closed by part 3 (FR-010 of spec 004).
- **Review of 2026-10-31** (part 3, three review-and-fix cycles): every blocker, critical, high and medium finding
  was fixed with a test.
- **The low items of both reviews**, checked against the code on 2026-10-31. The real ones are fixed, each with a
  test that fails without its fix:
  - the channel: a join confirmed after 5 s, a `/leave` during the join, the `/reload` cases, the kick rejoin timer,
    refusals carried to the next channel, a rejoin during a pause, the channel's checkbox and the notice;
  - the exchange: the announcers the peer bound forgot, unchecked seed copies offered before the walk, the flood of
    other messages from the channel, the same client on its other address, starts lost in a pause, and the empty
    session near the budget;
  - the harvest: `k`, the raw catches of weighted cells (`r`), unknown builds in the casting limit, extra cell fields
    and `__proto__`, and `--block` with a saved file.

  The cheap cleanups went in with them. The rest were left out for these reasons:
  - not a defect: `ShowPopup`'s Escape rule; the `greeting` kind; the `Roll` that finishes missing marks in one
    frame; disputes behind a stored version without a proof; a near peer refused by the budget alone (nothing would
    start it sooner than its next HELLO); two busy retries sharing one flag (the second is never needed);
    `CapBuffers` (the only bound over all senders before the notice is closed); a capped contributor's rare item
    rounding to 0 in the seed (R7 rounds on purpose: keeping it at 1 would make its chance many times too high);
  - accepted limits, written down in specs/004-public-channel-sync: one real version kept out (data-model.md); copies
    of our names joined outside the addon, and whisper-only strangers outside the peer bound (spec.md edge cases);
  - speed or style with no wrong behaviour: eviction picks, `Store.Accept`'s unverified branch, `NearWaiting`, the
    `paths.channel` entry, the outlier report's speed, and error reports without the `Disputed` lines.
