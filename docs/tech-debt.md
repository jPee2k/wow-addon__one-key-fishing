# Technical debt

Known issues that are not fixed yet, with the reason they matter and a suggested direction. Each item says where
it was found and how serious it is. Remove an item when it is fixed (with a test), or move it to the spec of the
feature that takes it on.

Severity: **high** loses data or cuts off honest players; **medium** wrong state or wasted traffic; **low**
cleanup, no wrong behaviour.

## Fix batches

The open items grouped into fixes that can be taken in one go (one spec or one patch each, `/speckit-specify` with
the batch as its description). Each batch says where it is built, what it closes and what the game still has to
show. Batches 3 and 4 were fixed by spec 009, batch 1 by spec 010, batches 2 and 6 with the pole item of batch 5 by
spec 011, and batches 5, 7, 8, 9 and 10 by spec 012, on `002-shared-db` (release 1.2.0).

### Batch 11: one player counted per address after a relog (any time; no game needed)

Seen in game; the fix and its test run without the game.

- "A partner who relogs counts twice for an hour" (low)

## Open items

### A partner who relogs counts twice for an hour (low)

- **Found**: in game, 2026-11-12 (build 2f96652): in the last hour A exchanged with three partners (two in A's
  group who are also Battle.net friends, and a guildmate who is a Battle.net friend), but `/okf debug` said
  "heard in the last hour: guild 0, group 2, friend 0, bnet 2; exchanged with 4". Earlier the same evening, with
  the same people, the counts were right (each client once, under the path heard first). In that hour one partner
  logged in again from another computer.
- **Cause**: `Node:Activity` (`Exchange/ShareProtocol.lua`) counts addresses heard and synced in the last hour, and
  `Handlers.H` joins two addresses of one client only by its node tag, which is new at every login or `/reload`.
  After a partner reloads, the new tag is heard first from the group address (the HELLO round broadcasts before it
  greets friends), so the group address becomes a peer, while the Battle.net address keeps its old `heard` (and
  `synced`) and counts until an hour has passed; its HELLOs with the new tag are taken as the same client and do not
  refresh it. A scratch test showed group 1 and bnet 1 for one client right after the new tag and 20 minutes later.
  Only the counts are wrong ("Exchange: N players", `/okf share`); sessions and cooldowns already read the tag.
- **Direction**: count clients, not addresses: in `Activity`, take each non-channel peer's tag and count a tag
  once (under the path heard last), and drop an address whose tag another address took over. Test: a client heard
  by Battle.net, then by the group with a new tag, counts once in `heard` and `exchanged`.

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
- 2026-11-06, spec 008 (architecture alignment), three review-and-fix rounds of the working tree. Fixed with tests:
  - the login check of the own record follows `CatchDB.OwnRecord`;
  - the indicator redraws on a skill change;
  - the catch database's range constants stay literals, held equal to the ranks by a test;
  - the CVars of fishing mode come from one table;
  - the GameData check finds calls, also without brackets;
  - the cave fallback of the map pin uses only the point's own map.

  Also cleaned: dead locals, a dead branch, a dead stub, stale names in docs and comments. Two low items stay
  above. Dropped as cases that do not come up:
  - a fifth Fishing rank (Forever has none above 300);
  - a record whose `id` differs from its key;
  - an own record damaged during a session;
  - the per-row pin lookups of a spot list (cached with the rows);
  - the lure `order` field, held 1..n by the shape test.
- 2026-11-07, spec 009: batches 3 and 4 fixed with tests (the map pin no longer opens the map; no equip call in
  the combat lockdown; the attack line; the combat state handler compares the number the driver sends); R14 and
  V45 confirmed in game the same day.
- 2026-11-07, spec 010: batch 1 and "1 catches" fixed with tests (names as the game gives them, the public channel
  off, the proof step budget, the hidden "No player named" line as the offline signal, the singular texts; the
  spike trimmed); V11 (friends list, other realm), V12 and V26 wait for the game.
- 2026-11-08, spec 011: batch 2, batch 6 and the pole item of batch 5 fixed with tests (a cave's continent map
  becomes the zone under the point; the subzone found by its name among the game's area names, walked over frames;
  the loot source of a catch is unknown, no pool part written; a secret name in a fight counts as missing and the
  skill check waits for the fight's end; the best pole within the Fishing skill). The `/run` checks before the code
  confirmed the zone under the cave and the area names (`docs/forever-api.md`).
- 2026-11-12, spec 012: every open item fixed with tests (batch 10: the bobber's secret GUID in an instance answers
  "unknown", no error and no "No bobber", a secret loot source is skipped; batch 9: the no-bundled-data hint drops
  "only your own catches" with another player's record, "Exchange: 1 player"; batch 5: a refused lure comes back
  after a Fishing skill-up; batch 7: the minimap tooltip carries its colours as codes in the text; batch 8: the
  private-table check parses the file). The dungeon is re-checked in game.
