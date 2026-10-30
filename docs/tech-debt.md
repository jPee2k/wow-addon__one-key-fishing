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
`BYE busy`; a session held open by parts alone, now capped at 5 min). The flood of parts itself is closed by part
3 (FR-010 of spec 004: parts only from the session's peer, a 128 KB cap over all senders, a flooder ignored until
logout; `tests/comm_channel_test.lua`). The low ones come when the code around them is touched anyway.

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

## Review of 2026-10-31 (part 3, spec 004, the `002-shared-db` working tree)

Three review-and-fix cycles at the `high` level, each of three rounds and a final review, then a narrow review of the
last harvest fix. Every blocker, critical, high and medium finding is fixed with a test. Among them:

- the harvest's weights;
- the part flood limit, now derived from the hourly budget;
- the channel state across `/reload`;
- the early channel `HELLO` after a rejoin;
- ignored peers past the peer bound;
- chain failures that blamed honest relays;
- the near-peer ordering around channel sessions;
- the miss rate weighted by casts (the seed's `x`);
- disputed units left out of the seed.

The lock by a player heard announcing is an accepted limit (spec.md edge cases, research R4), not debt. The low items
below were left on purpose; take them when the code around them is touched.

### Low

Channel.lua and its rounds in Share.lua:

1. **A refusal counted on the next channel** (`Comm.lua` `channelRefusals`). The count is not reset on a move caused
   by a notice (password, ban, mute), so one transient refusal on the new channel already moves on. Direction: reset
   it in `Channel.Lock` or on `CHANNEL_STATE`.
2. **Toggling the channel setting does not read the notice** (`Channel.SetEnabled`). `Share.SetEnabled` counts as
   reading it, the channel checkbox does not, so the state stays `notice`. Direction: call `NoticeRead` there too.
3. **A rejoin completed during a pause** gets no early channel `HELLO` (the `paused` to `in` edge is taken as a pause's
   end). Direction: let Channel.lua pass a join counter with `CHANNEL_STATE`.
4. **A `/leave` while the addon is still joining** is ignored, so the join check locks the name and joins the next
   fallback. Direction: handle `YOU_LEFT` while `joining` as a leave by hand.
5. **A `/reload` between `Lock` and the leave** restores `locked[i]` but takes the still-joined channel `i` as joined.
   Direction: leave a restored locked index in the reload scan.
6. **A join confirmed after `JOIN_CHECK` (5 s)** locks that name for the session (and across `/reload`). Direction:
   accept a late `YOU_JOINED` for an index locked by the join check alone.
7. **A channel joined again by hand after `/leave`** is taken as the addon's after a `/reload` (removed from the
   windows, state `left`). Direction: skip the scan's take-over while `left` is restored.
8. **`YOU_JOINED` for one of our names while `current` is nil** (setting off, before the login delay) leaves it at once,
   also when the player joined it on purpose. Direction: leave only the extra copies of a channel the addon is in.
9. **The kick rejoin timer firing exactly at `rejoinAt`** can read a hair under it and not rejoin until another
   trigger. Direction: a margin, as `Reconsider` has.

Share.lua:

10. **Non-`HELLO` messages from the channel** are dropped before `MESSAGE_LIMIT`, so such a flooder is never ignored
    (FR-010). Direction: count them before dropping.
11. **Whisper-only strangers** (a channel stranger's `SUM`, an `OnFlood` address) are never counted toward
    `MAX_CHANNEL_PEERS`. Direction: bound them with the channel peers.
12. **The peer bound forgets `inChannel`** of the announcer heard longest ago (over 300 announcers), so its undo of a
    lock reads as a lock. Direction: keep announcers' names in a small set outside the bound.
13. **The seed-chain walk races an early session.** An unchecked copy of a unit the seed holds in part may be offered
    before the walk reaches it, and the peer blames this client. Direction: do not offer such units until the walk is
    done.
14. **The near-peer queue has gaps:**
    - The skip conditions are written twice (`ConsiderSession` and the delayed start).
    - The same client on its other address counts as "somebody else".
    - A near peer refused only by the budget is not kept.
    - A start or busy retry that fires during a pause is lost.
    - Two pending busy retries share one `retrying` flag.
    - `NearWaiting` walks every peer.

    Direction: one helper, and keep a set of near peers waiting to start.
15. **`Store.Evict` picks linearly per deletion.** It is cheap for the one or two deletions of a merge, but slow when
    far over the limit at `ADDON_LOADED`. Direction: sort once when many go.
16. **`Store.Accept`'s unverified branch** (a whole chain walk in one call) is used only by tests. Direction: route the
    tests through the merge, or require `verified`.
17. **One real version kept out.** A made-up version can keep one real version (unit and seq) out of `node.chainRefused`
    while the same copy is held. This is close to the accepted residual risk of research R9.

Comm.lua:

18. **`dropped`** keeps a count table per sender below the flood limit until logout. Direction: prune empty ones.
19. **Dead state on the channel path:** `paths.channel.disabled` checks, the `skippedNear` clear in
    `BoundChannelPeers`, and `CapBuffers`, which one session at a time rarely reaches. Direction: remove or assert.
20. **`WithRealm`** in Data.lua duplicates the realm append in `Comm.ForEachFriend`. Direction: use `ns.WithRealm`.

CatchDB.lua:

21. **`Roll` builds missing marks in one frame** (up to 4096 SHA-256 steps) when a roll comes before the background
    build is done. Direction: roll from the marks that exist, or finish them in steps.
22. **The `capped >= shares` branch** of the weights cannot run (also in `tools/harvest.mjs`). Direction: remove it in
    both.
23. **The view's raw sums are not quite raw.** `BuildView` still sums `weighted.m`, which nothing reads, and the
    `Query` comment calls the seed's counts real sums although a weighted seed cell holds weighted ones (the
    little-data threshold reads them). Direction: drop `weighted.m`; give the seed raw totals if the threshold must be
    exact.

tools/harvest.mjs:

24. **A seed cell's `k` counts contributors with misses only**; the views count only those who caught something.
    Direction: `k = players`.
25. **`rawCasts` counts the seconds of an unknown build**, so the casting limit can reject an honest own record while
    `GetBuildInfo` fails (V7). Direction: count only valid builds.
26. **Extra cell fields reach `seed/contributions.json`.** Cells are kept as given; the client rebuilds them field by
    field. Direction: copy only `c`, `m`, `t`, `px`, `py`, `i` and `p`.
27. **The outlier report is quadratic** in the contributors per cell. Direction: per-cell totals minus the record's own.
28. **`scaleItems` drops an item whose weighted count rounds to 0**, so an item only a capped contributor caught leaves
    the seed. Direction: keep at least 1 when the original count is above 0.
29. **Error reports of a bad `--block`, `--unblock` or `--reset`** leave out the `Disputed` lines.
30. **`--block` takes a file path for its note.** A saved file whose name does not end in `.lua` is taken as the note,
    so its records are not harvested.
31. **Disputes behind an old stored version.** With a stored version without a proof (before part 3), two input
    versions that are not on one chain are never compared with each other.
