# Technical debt

Known issues that are not fixed yet, with the reason they matter and a suggested direction. Each item says where
it was found and how serious it is. Remove an item when it is fixed (with a test), or move it to the spec of the
feature that takes it on.

Severity: **high** loses data or cuts off honest players; **medium** wrong state or wasted traffic; **low**
cleanup, no wrong behaviour.

## Open items

Grouped into fix batches: the items of one batch touch the same code and are fixed and tested in one commit. The
batches are ordered by severity. Batch D and items 6 to 9 come from a review of the whole `002-shared-db`
branch against `develop` on 2026-10-31; every one was confirmed by a test or a traced path.

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

### Review of the batch C fix, 2026-10-31 (low)

Found by four reviews of the fix of the channel leave's echo (`Exchange/Channel.lua`, `echoes`). They were not
introduced by it (the old time window had them too), and only the game can tell how the server orders the notices.

14. **A join of a name whose own leave is not answered yet** (`Join` right after `LeaveName` of the same name: a
    second name of ours, then a move to it). If the client drops the join while the leave is under way, the late
    `YOU_LEFT` is taken for the leave's answer, the join checks fail and a healthy name is locked. The tests assume
    the server answers the leave first and the join after it (as `late_join_test.lua` does). Direction: confirm the
    order in game (V41); if the join is lost, join again when the answer of the name being joined comes. The same
    check tells whether a leave during an unconfirmed join is answered at all (if not, its entry may cover a
    `/leave` of that name within its window).
15. **The owed answers do not survive a `/reload`** (`channelSession` keeps `rejoinAt`, not `echoes`). A leave cut off
    by a `/reload` within its 5 s whose answer comes after it is taken for a leave by hand. Direction: save `echoes`
    with the session, as `rejoinAt` is (`GetTime()` goes on across a `/reload`).
16. **An answer more than 5 s late, after the new join is confirmed, counts as a leave by hand** (the window is 15 s
    only while the join waits). A wider window would also swallow the player's `/leave` after a leave the server
    never answered. Direction: measure the answer's delay in game first.
17. **A name of ours joined by hand after a leave by hand is left at once** (`OnNotice`, `YOU_JOINED` of a name that
    is not `current`). After a `/leave` (`left`), a `/join OneKeyFishingShare2` by hand is taken for an old
    session's second channel and left; the `/reload` path already keeps such a channel (`not left`). Direction: the
    same `not left` guard there. Test: `YOU_LEFT` by hand, then `YOU_JOINED` of the second name: no leave.
18. **A join answered while a later leave of the name is owed confirms the next join too early** (`OnNotice`
    `YOU_JOINED`, and `Check` by the channel's number). The setting off and on twice: the answer to the first join
    (and the client still in it) confirms the second one, so the 15 s window of the second leave shrinks to 5 s and
    an answer later than that counts as a leave by hand. Only on a slow server. Direction: keep the joins as well as
    the leaves per name and match each notice to the oldest request of its kind (needs V41 first).
19. **A `YOU_CHANGED` of the joined channel resets the lock wait** (`OnJoined` clears `lockTimer`, `sawPassword`,
    `owner`): if the game sends one during the 10-20 s wait, the addon stays in a locked channel. Direction: reset
    only when the addon was joining. Test: `PASSWORD_CHANGED` by a stranger, `YOU_CHANGED`, then the wait: moved.

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
  (each of the addon's own channel leaves owes one `YOU_LEFT` of its name, used up when it comes) after them.
