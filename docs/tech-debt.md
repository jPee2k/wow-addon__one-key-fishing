# Technical debt

Known issues that are not fixed yet, with the reason they matter and a suggested direction. Each item says where
it was found and how serious it is. Remove an item when it is fixed (with a test), or move it to the spec of the
feature that takes it on.

Severity: **high** loses data or cuts off honest players; **medium** wrong state or wasted traffic; **low**
cleanup, no wrong behaviour.

## Open items

Grouped into fix batches: the items of one batch touch the same code and are fixed and tested in one commit. The
batches are ordered by severity. Batches C and D and items 6 to 9 come from a review of the whole `002-shared-db`
branch against `develop` on 2026-10-31; every one was confirmed by a test or a traced path.

### Batch C: the echo of the channel leave (medium)

4. **The player's own leave of a fallback channel is taken for the echo of the addon's leave**
   (`Exchange/Channel.lua:375`, `YOU_LEFT` in `OnNotice`). The echo window (`leftAt`: 5 s, 15 s while joining) does
   not check which name was left. After a move (`Lock` by `MUTED`, a ban, a lock or two refusals), a `/leave` of the
   new channel within the window is ignored. Confirmed with two tests: after the join is confirmed the state stays
   `"in"` while the client is out, so every HELLO is dropped until logout; before it is confirmed the join check
   fails three times, the healthy channel is locked and a third one is joined, against spec 004 FR-005. The leave
   of the old name never needs the window (`index ~= current` already drops it). Direction: keep `leftIndex` next
   to `leftAt` in `Leave()` and apply the window only when `index == leftIndex`. Test: in
   `tests/exchange/channel/lock_test.lua`, `MUTED` and then `YOU_LEFT` of the fallback within 3 s gives `"left"`;
   the same before the confirmation gives `"left"` and no join of `OneKeyFishingShare3` after `advance(20)`.

### Batch D: the tag table of the exchange (low)

5. **`byTag` keeps every tag an address ever announced** (`Exchange/ShareProtocol.lua:51`; the only cleanup is in
   `Exchange/ShareNode.lua:143-144`, when a peer is forgotten). A remembered peer announcing a new tag leaves its
   old entry, so the table, whose values carry character names, is not bounded by the 300-peer limit (spec 004
   FR-009). Confirmed: 400 channel HELLOs from one address with new tags 61 s apart left `peers 1, byTag 400`;
   honest relogs leak the same way, slower. Direction: in `Handlers.H`, before `byTag[tag] = address`, drop the
   peer's previous tag when it still points to this address. Test: in `tests/exchange/share/channel_test.lua`, 50
   HELLOs with new tags from one address leave one `byTag` entry.

### Batch E: the catalog and its tabs (low)

Items 10 to 13 were found while building the catch catalog (`specs/005-catch-catalog`) on 2026-10-31.

6. **A click on an item before the index is built opens the search, not the item** (`UI/CatalogTab.lua:392-398`,
   `CatalogTab.Show`; reached from `UI/CatchHere.lua:134-137`). `Show(itemID)` chooses by
   `#Catalog.Places(arg, filter) > 0`, and `Places` returns `{}` while the index is still building (up to 10 s after
   the first loading screen), so the item's name goes into the search and nothing chooses the item later, against
   FR-024. Confirmed with a test: a row click before the first build shows the list with the search "Deviate Fish",
   still the list after the build. Direction: while `Catalog.State(filter)` is not `"ready"`, keep the item as
   pending and let `Tick` resolve it. Test: in `tests/ui/catalogtab_test.lua`, `StatsFrame.OpenCatalog(FISH)` before
   the first `advance(0)`, then `advance(0)` and a tick: the item view shows FISH.
7. **`Catalog.CatchesText` compares a nil player count** (`Catalog/Catalog.lua:438`): `players >= 2` raises an
   error for a view without `players`, while `ChanceText` uses `(players or 0)`. No caller passes nil today.
   Direction: the same guard in both. Test: `CatchesText(5, nil)` returns "5 catches".
8. **"Only mine" relies on a missing id for its counts line** (`UI/CatchHere.lua`, the counts line). The guard
   `source == "all"` before "N catches from K players" was removed; no player count under "Only mine" now holds only
   because `Views` builds the "mine" table without an id, so `Players(sum)` is 0. Direction: put the guard back.
   Test: a "mine" sum that carries an id still shows "N catches".
9. **`Catalog.State` repeats the prologue of `Catalog.Items`** (`Catalog/Catalog.lua:279`): two copies of the
   ready/building rule; if they drift, `CatalogTab.Tick` redraws on every tick or never. Direction: `Items` starts
   with `if Catalog.State(filter) ~= "ready" then return {}, "building" end`. Test: the tab tests stay green.
10. **The spot cache of the catalog only grows** (`Catalog/Catalog.lua`, `spots`). Each expanded zone keeps its rows
    under `<item>|<map>|<filter>` for the session, also after its map's views are replaced. A few hundred entries at
    most in a session, but nothing frees them. Direction: keep only the entries of the chosen item, or drop the
    table when the version moves. Test: expand zones of two items, choose the second, and count the cached keys.
11. **A spot's pin target is computed with its rows** (`Catalog.Spots`). A change of the game rule or of what a map
    allows (V30) shows only after the map's stamp moves. Direction: compute `pin` when the row is drawn. Test: a
    spot with a pin, then `game_rules[...] = true`, and the row's button must go on the next draw.
12. **The pin's toast follows "Show catch notifications"** (`ns.Toast` returns early with toasts off), so with
    toasts off the pin is set silently. Direction: a toast that ignores the setting for answers to a click. Test:
    toasts off, press a pin button, a message must still show.
13. **HasPoolData scans every stored record while there is no pool data** (`CatchDB.HasPoolData`): every
    `SHARED_DATA_CHANGED` clears the false answer, and the next tab draw walks up to 20,000 places again. Only while
    pools are not told apart (V3). Direction: check only the records the change names. Test: count the cells walked
    after a keyed change in `tests/catchdb/water_record_test.lua`.

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
  from the loot link) and batch B (the pool part of a cell must fit the cell) were fixed the same day.
