# Technical debt

Known issues that are not fixed yet, with the reason they matter and a suggested direction. Each item says where
it was found and how serious it is. Remove an item when it is fixed (with a test), or move it to the spec of the
part that takes it on.

Severity: **high** loses data or cuts off honest players; **medium** wrong state or wasted traffic; **low**
cleanup, no wrong behaviour.

## Catch exchange (part 2, `specs/003-guild-group-sync`)

Found by the code review of 2026-10-29 on `002-shared-db`. None of these is covered by a test yet.

### 1. A harvest of an old received copy wipes the owner's newer data (high)

- **Where**: `tools/harvest.mjs` (absorbed), `OneKeyFishing/CatchDB.lua` (own record start-over),
  `OneKeyFishing/Share.lua` (`Store.CleanUp`).
- **Problem**: the harvest now also reads other players' records that a client received. The seed's `absorbed`
  map stores only the epoch, not the seq. If the author's saved data holds an old copy of player X's record (seq
  25) while X is already at seq 40, the seed absorbs X's epoch with the seq 25 data. After the release, X's client
  starts its record over and every peer deletes its seq 40 copy: the catches from seq 26 to 40 are lost from the
  shared database (they survive only in X's own `mine`).
- **Direction**: store the absorbed seq per ID (`absorbed[id] = { epoch, seq }`), and start over or delete only a
  record whose seq is not newer than the absorbed one; a newer record of an absorbed epoch keeps counting the
  difference, or moves to a new epoch. This changes the seed format (part 1) and the harvest.

### 2. `MESSAGE_LIMIT` is too small for honest traffic (high)

- **Where**: `OneKeyFishing/Share.lua` (`MESSAGE_LIMIT`, `Node:Receive`).
- **Problem**: a sender may send 600 weight units per hour, one unit per 240 bytes of each joined message. A record
  may be up to `MAX_RECORD_BYTES` (32 KB, about 135 units), and a group peer may hold a session every 10 minutes.
  A peer that sends one large record in each of its 6 sessions an hour goes over 600 and is ignored until logout,
  although `RECORD_LIMIT` was sized so that honest peers never reach it.
- **Direction**: derive the message limit from the session limits (sessions per hour x (`SESSION_BYTES` or one
  `MAX_RECORD_BYTES` record) plus the protocol messages), or count record bytes against the session's wants instead
  of a flat hourly limit.

### 3. The "unavailable" state is almost never reached (medium)

- **Where**: `OneKeyFishing/Comm.lua` (`Refused`).
- **Problem**: the exchange is "unavailable" only when all four paths (guild, group, whisper, Battle.net) were
  refused 5 times in a row. A path that is never used is never refused, and HELLOs to friends are greetings that do
  not count. A Trial or Veteran account in no guild and without Battle.net friends on Forever shows "Nobody to
  exchange with right now" for good instead of "Exchange unavailable: the game refuses addon messages".
- **Direction**: decide "unavailable" from the paths that were tried: every tried path left out and none ever
  succeeded.

### 4. The responder answers every SUM without a cooldown (medium)

- **Where**: `OneKeyFishing/Share.lua` (`Handlers.S`).
- **Problem**: cooldowns (`SESSION_GAP`, the per-peer cooldown, `pausedUntil`) are only checked on the initiator's
  side, in `CanStart`. A buggy or hostile peer that sends a SUM with a new session ID every few seconds gets a DIFF
  of several KB each time (each SUM counts as one message), so the 50 KB hourly budget is gone within minutes and no
  exchange with honest peers is possible for the rest of the hour.
- **Direction**: apply the per-peer cooldown on the responder's side too (answer `BYE busy` or ignore), and count a
  SUM that starts a session against a per-peer session limit.

### 5. `Comm.CanSend` does not count queued messages (medium)

- **Where**: `OneKeyFishing/Comm.lua` (`Comm.CanSend`, `Deliver`).
- **Problem**: the budget check sees only bytes already delivered. A session queues DIFF, WANT and records one after
  another; each check passes against the delivered total, and together they can go a few KB over the 50 KB hourly
  budget (SC-005).
- **Direction**: keep a running total of queued bytes, add it in `CanSend`, and subtract it as parts go out or are
  dropped.

### 6. Repeated pauses stack HELLO timers (low)

- **Where**: `OneKeyFishing/Share.lua` (`SyncPause`, `HelloSoon`).
- **Problem**: every pause that ends schedules a HELLO 5-30 s later when the last HELLO is older than 10 minutes;
  `lastHello` changes only when that timer fires. Short combat cycles therefore stack several timers and send
  several HELLO rounds (broadcasts and up to 20 friend whispers each). Peers drop the repeats, but the traffic
  counts against the budget.
- **Direction**: keep one pending HELLO timer (a flag or the time it is due) and do not schedule another while it
  waits.

### 7. An own record with only an "unknown" build goes out empty (low)

- **Where**: `OneKeyFishing/Share.lua` (`Store.Units`, `HasCells`, `Store.ForSending`, `Node:OwnData`).
- **Problem**: when the game gave no version, all own cells are under `builds["unknown"]`. `HasCells` counts them,
  so the record is offered, but `ForSending` drops that build and the record goes out with no builds at all. Peers
  store an empty record that only costs hashes and traffic.
- **Direction**: decide "has cells" on the record as it is sent (`ForSending`), and do not offer a record without
  sendable cells.

### 8. Two copies of the per-minute rolling hour (low)

- **Where**: `OneKeyFishing/Share.lua` (`Recent`), `OneKeyFishing/Comm.lua` (`AddTraffic`, `GetTraffic`).
- **Problem**: both bucket by `floor(t / 60)`, prune minutes older than an hour and sum the rest. A fix to one (for
  example the window edge) will not reach the other.
- **Direction**: one shared helper, for example `ns.MinuteCounter` in `Data.lua`, for the traffic budget and the
  per-sender limits.

### 9. Two counts of distinct places (low)

- **Where**: `OneKeyFishing/CatchDB.lua` (`CheckRecord`, `CountPlaces`); also `tools/harvest.mjs`.
- **Problem**: `CheckRecord` counts distinct places over all builds with its own loop, next to `CountPlaces`, which
  does the same and is used for eviction and the status. If one changes, the 1,000-place limit and the size limit
  disagree.
- **Direction**: let `CheckRecord` count with the same helper (it needs the early stop above the limit, so a
  helper with a limit argument).

### 10. Send results are hard-coded numbers (low)

- **Where**: `OneKeyFishing/Comm.lua` (`SUCCESS`, `NOT_IN_GROUP`, `ADDON_THROTTLE`, ...).
- **Problem**: the values match `Enum.SendAddonMessageResult` of the 1.60.1 export, but a patch that renumbers or
  adds values would make `TargetOffline` or `AddOnMessageLockdown` count as an ordinary refusal, which can leave a
  path out until logout or miss a lockdown back-off.
- **Direction**: read `Enum.SendAddonMessageResult.<Name>` at runtime and keep the numbers only as a fallback.

## Open design questions (catch exchange)

Limits of the exchange's design rather than bugs in its code: each needs a decision by the author before it is
changed. Found by the code review of 2026-10-29.

### 11. A forged high seq blocks a player's real updates (high)

- **Where**: `OneKeyFishing/Share.lua` (`Store.Accept`), `tools/harvest.mjs` (newest seq wins).
- **Problem**: records are anonymous and unsigned, and a higher seq always replaces a lower one. Anyone can send a
  well-formed record under another player's ID and epoch with a huge seq (up to `1e12`) and made-up cells. Every
  client that receives it keeps it and passes it on, and the owner's real updates are "older" everywhere from then
  on. The harvest keeps the forged version too. Only the owner's own client refuses it (own ID), and only the next
  epoch (after a release absorbed the ID) ends it.
- **Direction**: part 3 plans contribution weights and outlier checks. Cheaper bounds to consider before that: a seq
  can grow at most once per settled cast (part 1 bumps it only after a change), so `seq <= sum of c + m` over the
  record is a plausibility rule the client and the harvest could share.

### 12. The anonymous ID can be tied to a name, and positions are exact for one cast (high)

- **Where**: `OneKeyFishing/Share.lua` (`SendRecords` sends the own record first), `OneKeyFishing/CatchDB.lua`
  (`px`/`py` sums per cell), the notice and the "Shared database" page texts.
- **Problem**: a client sends its own record itself, by whisper or Battle.net, so the receiver sees the sender's
  name next to the record's ID. `HELLO` leaves the ID out, but the first `REC` of a session links them. The cells
  also carry `px`/`py`, the sums of the cast positions; for a cell fished once they are the exact position at
  1/1000 of the map. The texts promise "anonymously" and "No names, gear or exact positions".
- **Direction**: either change the texts to what is true (the ID is random, but players you exchange with can see it
  is yours), or relay the own record only through other peers, and leave `px`/`py` out of what is exchanged (they
  are needed only for the part 4 map pin) or send them only for cells with enough casts.

### 13. An own record over 1,000 places stops being shared (medium)

- **Where**: `OneKeyFishing/CatchDB.lua` (`MAX_RECORD_PLACES`), `OneKeyFishing/Share.lua` (`Node:OwnData`).
- **Problem**: a peer refuses a record with more than 1,000 distinct places or over 32 KB encoded, so a client does
  not offer its own record once it grows past that. A dedicated fisher reaches it within one seed epoch. The
  record then reaches nobody, so the author's harvest never absorbs it and it never starts over: that player's
  catches stay out of the network until a release absorbs the record from their own saved file. `/okf debug`
  shows "own record offered: no, too large for a peer"; nothing tells the player.
- **Direction**: raise `MAX_RECORD_PLACES` (the 32 KB encoded limit still bounds the size; the harvest allows
  20,000), split the own record into several records (one per map group), or start the own record over at a new
  epoch when it reaches the limit (the old epoch reaches the seed through the author's harvest).
