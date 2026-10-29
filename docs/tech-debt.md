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

Every item below was checked against the code; "flagged by" says how many of the three reviews found it. The four
high items (a refusal for one player counted once per queued part against the whole path; the one-time notice
marked shown before `StaticPopup_Show` was known to succeed; a throttle back-off of up to 60 s against 15 s
protocol timeouts; a cast under the build `"unknown"` bumping `seq` and so blocking the own record) are fixed with
tests on 2026-10-30. The medium items come next, the low ones when the code around them is touched anyway.

### Medium

1. **`SendRecords` and `Node:Send` check the budget differently** (`Share.lua`; flagged by 2). The loop checks
   `canSend(#data)`, `Node:Send` checks the text with 4 more bytes; when they disagree the session ends with
   `BYE limit` instead of the designed quiet stop, and the loop goes on: with no session left `Node:Send` skips its
   budget check and queues a smaller record after the BYE. Direction: build the text first, check once with its
   length, break when `Send` returns false. Test with an injected `canSend`.
2. **The damaged-own-record guard does not check the ID** (`CatchDB.lua`, `ADDON_LOADED`; flagged by 2). A saved
   own record without `id`, or with another one, passes the guard; `Store.Units` then errors on every HELLO and
   `/okf share` (`units[nil]`), or a roll freezes the record under the wrong key and `CleanUp` deletes it. Only a
   damaged saved file. Direction: `record.id ~= shared.myID` starts the record over like the other faults.
3. **Crossing `SUM`s between one client reached by two paths** (`Share.lua`, `Handlers.S`; flagged by 1). A
   guild member who is also a Battle.net friend may be known as `w:` on one side and `b:` on the other; each side's
   session peer is the other address, so both answer `BYE busy` and both drop. The round is lost (no 30 min pause:
   the BYE comes back on the session's own path), with some probability per round for such pairs. Direction: note
   the tag on every address of a node in `Handlers.H` (also when the HELLO is skipped as the same client) and
   compare tags, not addresses, in the busy check.
4. **Parts refresh the session before any check** (`Comm.lua`, `OnMessage`; `Node:Heard`; flagged by 1). Every
   part from the session peer refreshes `lastHeard`, parts do not count toward the per-sender message limit, and an
   overflowing part buffer only clears the buffer. A modified client can hold the single session slot for the whole
   session (everyone else gets `BYE busy`). Direction: count parts in the per-sender limit (the size reaches
   `Node:Receive` through the activity handler) or refresh `lastHeard` only for a message the session expects. Part
   3 (strangers) needs this before it ships.
5. **Relayed records are not checked again** (`Share.lua`, `SendRecords`; flagged by 1). `Store.CleanUp` at login
   checks only the shape of a stored record; a cell damaged in the saved file is relayed as it is, and the receiver
   ignores this client until logout. Direction: `CheckRecord` before a relayed record is encoded (at most 25 per
   session) and drop a damaged one from the store.
6. **A failed `SUM` burns the cooldowns** (`Share.lua`, `ConsiderSession`; flagged by 1). `lastStart` and
   `peer.lastSession` are set before the SUM is sent; when `Send` fails (budget edge, a path left out) no session
   runs, yet the 2 min gap and the 10/30 min peer cooldown apply. Direction: set them only when `Send` returned
   true (restore `previousSession` otherwise, as `BYE busy` does).

### Low

7. **`Store.Evict` fires a change with no keys** (`Share.lua`; flagged by 2). Over the place limit with nothing
   evictable (only frozen own records), `Changed({})` wipes the query cache and the node summary on every merged
   record. Direction: fire only when something was removed, as `CleanUp` does.
8. **`UnindexRecord` keeps emptied sets** (`CatchDB.lua`; flagged by 1). The place and prefix sets of a replaced or
   evicted record stay as empty tables (memory only, bounded by the distinct places ever held). Direction: drop a
   set when it is empty.
9. **`ns.ShowPopup` infers Escape behaviour from `onCancel`** (`Core.lua`; flagged by 1). `noCancelOnEscape` is
   derived from the presence of the handler; a future caller whose second button means "no" gets a surprise.
   Direction: an explicit argument when a second caller appears.
10. **The `greeting` message kind** (`Comm.lua`; flagged by 1). Since a refusal counts once per player (fixed high
    item), it only still saves a path from five odd friend names in one HELLO round; decide whether it stays.

### Checked, not a bug

- A HELLO with an equal hash counts the peer as exchanged (`Node:Confirmed`): `data-model.md` defines
  `lastExchange` as "the last session that moved or confirmed data", and the equal hash confirms every record.
  `contracts/share-api.md` says "peers with a finished session"; align that wording.
