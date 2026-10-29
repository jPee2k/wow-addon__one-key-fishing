# Technical debt

Known issues that are not fixed yet, with the reason they matter and a suggested direction. Each item says where
it was found and how serious it is. Remove an item when it is fixed (with a test), or move it to the spec of the
part that takes it on.

Severity: **high** loses data or cuts off honest players; **medium** wrong state or wasted traffic; **low**
cleanup, no wrong behaviour.

The thirteen items of the code review of 2026-10-29 on `002-shared-db` are fixed, each with a test; the part of
item 11 (a forged record) that a client cannot check on its own moved to `docs/shared-db-plan.md` ("Protection
against spam and fakes"), which part 3 takes on.

## Review of 2026-10-30 (part 2, `ea3cc17..HEAD`, three independent reviews)

Every item below was checked against the code; "flagged by" says how many of the three reviews found it. Fixed
with tests on 2026-10-30: the four high items (a refusal for one player counted once per queued part against the
whole path; the one-time notice marked shown before `StaticPopup_Show` was known to succeed; a throttle back-off of
up to 60 s against 15 s protocol timeouts; a cast under the build `"unknown"` bumping `seq` and so blocking the own
record) and four medium ones (`SendRecords` and `Node:Send` checking the budget differently; the damaged-own-record
guard not checking the ID; relayed records not checked again before they are sent; a `SUM` that could not be sent
burning the cooldowns). The low ones come when the code around them is touched anyway.

### Medium

1. **Crossing `SUM`s between one client reached by two paths** (`Share.lua`, `Handlers.S`; flagged by 1). A
   guild member who is also a Battle.net friend may be known as `w:` on one side and `b:` on the other; each side's
   session peer is the other address, so both answer `BYE busy` and both drop. The round is lost (no 30 min pause:
   the BYE comes back on the session's own path), with some probability per round for such pairs. Direction: note
   the tag on every address of a node in `Handlers.H` (also when the HELLO is skipped as the same client) and
   compare tags, not addresses, in the busy check.
2. **Parts refresh the session before any check** (`Comm.lua`, `OnMessage`; `Node:Heard`; flagged by 1). Every
   part from the session peer refreshes `lastHeard`, parts do not count toward the per-sender message limit, and an
   overflowing part buffer only clears the buffer. A modified client can hold the single session slot for the whole
   session (everyone else gets `BYE busy`). Direction: count parts in the per-sender limit (the size reaches
   `Node:Receive` through the activity handler) or refresh `lastHeard` only for a message the session expects. Part
   3 (strangers) needs this before it ships.

### Low

3. **`Store.Evict` fires a change with no keys** (`Share.lua`; flagged by 2). Over the place limit with nothing
   evictable (only frozen own records), `Changed({})` wipes the query cache and the node summary on every merged
   record. Direction: fire only when something was removed, as `CleanUp` does.
4. **`UnindexRecord` keeps emptied sets** (`CatchDB.lua`; flagged by 1). The place and prefix sets of a replaced or
   evicted record stay as empty tables (memory only, bounded by the distinct places ever held). Direction: drop a
   set when it is empty.
5. **`ns.ShowPopup` infers Escape behaviour from `onCancel`** (`Core.lua`; flagged by 1). `noCancelOnEscape` is
   derived from the presence of the handler; a future caller whose second button means "no" gets a surprise.
   Direction: an explicit argument when a second caller appears.
6. **The `greeting` message kind** (`Comm.lua`; flagged by 1). Since a refusal counts once per player (fixed high
   item), it only still saves a path from five odd friend names in one HELLO round; decide whether it stays.

### Checked, not a bug

- A HELLO with an equal hash counts the peer as exchanged (`Node:Confirmed`): `data-model.md` defines
  `lastExchange` as "the last session that moved or confirmed data", and the equal hash confirms every record.
  `contracts/share-api.md` says "peers with a finished session"; align that wording.
