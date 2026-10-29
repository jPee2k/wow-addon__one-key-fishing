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
record) and the six medium ones (`SendRecords` and `Node:Send` checking the budget differently; the
damaged-own-record guard not checking the ID; relayed records not checked again before they are sent; a `SUM` that
could not be sent burning the cooldowns; crossing `SUM`s between one client known by two addresses both answered
`BYE busy`; a session held open by parts alone, now capped at 5 min; the flood of parts itself, a CPU cost only,
stays for part 3 with strangers). The low ones come when the code around them is touched anyway.

### Low

1. **`Store.Evict` fires a change with no keys** (`Share.lua`; flagged by 2). Over the place limit with nothing
   evictable (only frozen own records), `Changed({})` wipes the query cache and the node summary on every merged
   record. Direction: fire only when something was removed, as `CleanUp` does.
2. **`UnindexRecord` keeps emptied sets** (`CatchDB.lua`; flagged by 1). The place and prefix sets of a replaced or
   evicted record stay as empty tables (memory only, bounded by the distinct places ever held). Direction: drop a
   set when it is empty.
3. **`ns.ShowPopup` infers Escape behaviour from `onCancel`** (`Core.lua`; flagged by 1). `noCancelOnEscape` is
   derived from the presence of the handler; a future caller whose second button means "no" gets a surprise.
   Direction: an explicit argument when a second caller appears.
4. **The `greeting` message kind** (`Comm.lua`; flagged by 1). Since a refusal counts once per player (fixed high
   item), it only still saves a path from five odd friend names in one HELLO round; decide whether it stays.
5. **An empty session near the hourly budget** (`Share.lua`, `SendRecords` and `Advance`; the review of the fixes
   on 2026-10-30, behaviour older than the fixes). When the budget does not let even the first wanted record out,
   no record goes, yet the session ends with `BYE sent` / `done`, counts as moved and takes the cooldown; near the
   budget the same empty session (about 1 KB of `SUM`, `DIFF`, `WANT` and `BYE`) repeats every HELLO round until
   the budget frees. Direction: end with `BYE limit` when the first record did not fit, or let `CanStart` require
   room for one record.

### Checked, not a bug

- A HELLO with an equal hash counts the peer as exchanged (`Node:Confirmed`): `data-model.md` defines
  `lastExchange` as "the last session that moved or confirmed data", and the equal hash confirms every record.
  `contracts/share-api.md` says "peers with a finished session"; align that wording.
