# Technical debt

Known issues that are not fixed yet, with the reason they matter and a suggested direction. Each item says where
it was found and how serious it is. Remove an item when it is fixed (with a test), or move it to the spec of the
feature that takes it on.

Severity: **high** loses data or cuts off honest players; **medium** wrong state or wasted traffic; **low**
cleanup, no wrong behaviour.

## Open items

None.

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
- 2026-10-31, a review of the whole branch against `develop` (five areas): one high, two medium and six low items,
  recorded as batches A to E. SHA-256, the codec, the merges and the session states held up. Batch A (item IDs
  from the loot link) and batch B (the pool part of a cell must fit the cell) were fixed the same day, and batch C
  (each of the addon's own channel leaves owes one `YOU_LEFT` of its name, used up when it comes) after them; batch D
  (a remembered peer's new tag replaces its old one in `byTag`, so the table stays within the peer bound) next.
- 2026-10-31, a triage of the open items: kept only the three confirmed in play. Dropped as cases that do not come
  up: a nil player count no caller passes, the "Only mine" guard that holds today, the repeated ready rule, the
  spot cache (a few hundred entries) and the pin rule changing mid-session; the pool-data scan (unmeasured; the
  step time is checked in game by V28 and V39); and the channel's notice-order cases of the batch C reviews (the
  order is V41, the delays are milliseconds, and nobody joins a fallback name or gets `YOU_CHANGED` by hand).
- 2026-11-01, batch E (the catalog): a `CatalogTab.Show` while the index is still building waits for it and
  `Tick` makes the choice once it is ready; the map pin's answers show with catch notifications off.
