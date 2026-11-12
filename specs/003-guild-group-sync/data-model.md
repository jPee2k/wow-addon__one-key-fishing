# Data Model: Catch Data Exchange in the Guild, the Group and with Friends

Builds on [the part 1 data model](../002-local-catch-db/data-model.md): the place key, the cell, `shared.mine`, the
contribution record and the seed keep their shape. This release adds other players' records next to the own one,
two account-wide fields, and state that lives only in memory for the session.

## Saved data (account-wide, `OneKeyFishingDB`)

`DB_SCHEMA` stays 1: only new fields, filled by `ApplyDefaults`; nothing is renamed, moved or reshaped.

```lua
OneKeyFishingDB.settings.shareDB = true   -- "Use the shared catch database" (FR-019); off = nothing sent or
                                          -- received, received records kept but not counted (FR-020)
OneKeyFishingDB.shareNotice = false       -- true once the one-time popup was closed (FR-021), any button or Escape
OneKeyFishingDB.shared = {
  myID = "k7f2q6xa",                      -- unchanged; never sent with a name, never in /okf debug or /okf share
  mine = { ... },                         -- unchanged: lifetime counts of this account ("Only mine")
  records = {
    ["k7f2q6xa"] = { id, epoch, seq, builds },             -- the own record, unchanged (part 1), keyed by myID
    ["m3p7x2zd@3"] = { id, epoch, seq, builds, seen = 1761234567 }, -- NEW: another account's record, keyed by
                                                                    -- "<id>@<epoch>"
  },
}
```

A received record has the same `{ id, epoch, seq, builds }` shape as the own one (part 1 data model, "Cell"), so
`npm run harvest` reads it unchanged (it already walks every entry of `shared.records`, checks it and keeps the
newest `seq` per `id@epoch`) and ignores the key and `seen`. Other records are keyed by `<id>@<epoch>`, the same
unit the harvest keeps: when an owner's record rolls (part 1 data model, "Rolling the own record"), a client holds
the old epoch next to the new one and drops it once its own seed holds it whole. The owner keeps its own rolled
records under the same keys (`"<myID>@<epoch>"`) and offers them like other players' records.

| Field | Meaning |
| --- | --- |
| `seen` | `time()` when this record version was last received or confirmed by a peer (a `HELLO` with the same whole hash, an equal bucket hash in a `SUM`, or its entry matched in a `DIFF`); drives eviction |

### Rules for other players' records

- **Accept** (research R6): the record passes `CatchDB.CheckRecord` (the part 1 cell validation, the same as the
  harvest's, plus: `id` is 8 base32 characters; at most 1,000 places; `seq` not above the record's casts, `c + m`
  over all cells, since the owner bumps it only after a settled cast; every item ID known to
  `C_Item.GetItemInfoInstant`). A failing record is rejected whole. A record refused only for an unknown item (a
  new item, a client not yet patched) is dropped without blaming its sender, and that version is not wanted again
  this session.
- **Replace**: a received record replaces the stored one with the same `id@epoch` only when its `seq` is higher.
  Otherwise it is a duplicate or older and is ignored (only `seen` is refreshed when it is the same version).
- **Absorbed**: `ns.SeedData.absorbed[id][epoch] = S` says the seed holds unit `id@epoch` up to seq `S`. A version
  with `seq <= S` is already counted in the seed: it is not accepted, and a stored one is deleted at login. A newer
  version is held by the seed only in part: it is accepted, kept and passed on (so the catches after `S` reach the
  next harvest instead of being lost), but not counted in the views, since the seed has its first part. This is
  what keeps network data from counting twice after a release (FR-014, SC-008) without losing it when the author's
  client had an older copy.
- **Own ID**: a record with `id == myID` is never accepted (FR-012); `Store.Accept` refuses it before the check.
- **Size limit**: the other records together hold at most 20,000 places (about 2 MB of saved data). Above that the
  record with the oldest `seen` is deleted first, until the total fits; no record of the own ID is deleted, neither
  the live one nor one kept by a roll (maybe the only copy left) (FR-013).
  Because `seen` is refreshed whenever a peer confirms the same version, records of players still in the network
  stay, and those of players who stopped playing go first. A version evicted this session is not wanted back
  (only a newer one), so eviction and the next session do not trade the same records while the network holds more. The info-based eviction order of
  `docs/history/shared-db-plan.md` (seed-heavy cells first, rare places last) is left for part 3, when strangers bring far
  more records (research R6).

## Views (changes to part 1 "Views")

| Filter | Data summed for a place key |
| --- | --- |
| Source "All", sharing on | seed cell + own record cells + every other stored record's cells (the reset rule of part 1 applies to each record) |
| Source "All", sharing off | seed cell + own record cells (as part 1) |
| Source "Only mine" | `mine` cell (unchanged) |

A view (contracts/catchdb-api.md of part 1) gains `players`: the number of contributions behind the numbers. Only a
summed cell with at least one catch counts (a cell of misses only adds no player). The seed counts as the cell's `k`
at a spot and the largest `k` of the summed cells for the whole map. Each record ID with such a cell counts once
(the own one included); an ID the seed absorbed (`absorbed[id]`, any epoch) may already be among that `k`, so those
IDs count only above it: `players = max(seed k, absorbed IDs) + IDs the seed never absorbed`. It is a lower bound:
the seed does not say which contributors overlap between cells, or whether an absorbed ID is among them. Nothing is
counted twice; at worst the count is low (research R9).

## Session memory (never saved)

```lua
node = {                   -- one per Share.NewNode; the game makes one at login (once the notice was closed)
  tag = "q2x7",            -- this client's random node tag, new at every login; not the anonymous ID
  peers = {                -- address -> peer; an address is "w:<name>" (whisper) or "b:<gameAccountID>" (Battle.net)
    ["w:Fisher-Forever"] = {
      via = "guild",       -- "guild" | "group" | "whisper" | "bnet": the path of its HELLO (a guild peer heard in
                           --   the group becomes "group"); /okf share counts "whisper" as friends
      node = "q2x7",       -- the peer's node tag (HELLO): one client on two paths is one peer, and the smaller tag
                           --   wins when both start a session at once (research R5)
      hash = "7f3k2a9",    -- the whole hash of its last HELLO
      heard = 4210.5,      -- GetTime() of its last HELLO taken
      synced = 4100.2,     -- GetTime() it was last confirmed: a finished session or a HELLO with the same hash
      lastSession = 4000,  -- GetTime() of the last session start with it (cooldowns); previousSession: the one
                           --   before, put back when no session followed (BYE busy, equal tags)
      answered = 3990,     -- GetTime() this client last answered its SUM with a DIFF (the responder's 8 min gap)
      pausedUntil = nil,   -- after a timeout or an offline report: no session before this; its next HELLO clears it
      starting = nil,      -- true while the 2-20 s wait before a SUM runs
      idle = nil,          -- { theirs, ours }: the two hashes of a session that moved nothing; none again until one
                           --   of them changes
      ignored = nil,       -- true when it flooded or sent bad data: ignored until logout
      messages = {}, records = {},   -- per-minute counts of the last hour, for the flood limits
    },
  },
  byTag = {},              -- node tag -> the address it was first heard from (one current tag per address)
  session = {              -- at most one at a time
    sid = "a7", peer = "w:Fisher-Forever", role = "initiator" | "responder",
    started = GetTime(), lastHeard = GetTime(),   -- 15 s timeout, 5 min in all
    buckets = {},          -- the differing bucket indices
    ourWants = {},         -- unit -> seq this side asked for; received: unit -> true once merged
    theirWants = nil,      -- the units the peer asked for (a list), once its WANT came
    -- flags of the steps done: gotReply, gotDiff, sentWant, gotSent, sentRecords; wantCount and recordsIn for the
    -- "no more records than wanted" limit
  },
  recent = nil,            -- the session that just finished: records still on their way are taken for 15 s
  merges = {},             -- received records waiting for their merge, one per frame step
  cursor = 1,              -- where the next HELLO round continues in the list of friends not yet known as peers
  lastStart = nil, lastHello = nil,   -- GetTime() of the last session start and the last HELLO round
  lastExchange = nil,      -- GetTime() of the last confirmation (a finished session or a HELLO with the same hash)
  rejected = 0, longestStep = 0,      -- senders ignored, the longest merge step in ms (/okf debug)
  unknownItems = {},       -- unit -> seq refused only for an item this client does not know: not wanted again
  cache = {}, ownData = {},           -- the summary (units, buckets, hashes) and the own records as encoded
}
-- In Comm.lua:
queue = {}                 -- the messages waiting for their slot (pace)
traffic = {}               -- bytes sent per minute for the last 60 minutes (50 KB per hour budget)
paths = {                  -- per path ("guild", "group", "whisper", "bnet"): refusals in a row and whether the path is
  whisper = { failures = 0, disabled = false },   -- left out until logout (5 refusals in a row, research R7)
}
buffers = {}               -- sender address -> the parts of its long messages (64 KB, 15 s)
notFound = {}              -- "No player named ..." line -> GetTime() of the whisper it would follow (10 s)
```

Character names and Battle.net account IDs exist only here (peers, `byTag`, the sessions, and `Comm`'s queue, part
buffers and 10 s list of names just whispered) and are gone at logout (FR-009). The protocol version is not a
field: it is the prefix (`OKF1`), and a client never sees messages of another version (FR-007).

## State of the exchange

`Share.GetStatus()` (contracts/share-api.md) derives one state, in this order:

```text
off       settings.shareDB is false
notice    the one-time popup has not been closed yet (no exchange before it, FR-021)
unavailable  the game refused every path 5 times in a row (for example a Trial or Veteran account): until logout;
          or, as a state only, nothing went out since the login and every path tried with more than a greeting
          was left out (a path never tried does not hide it; a later success clears it)
paused    combat (InCombatLockdown() or PLAYER_REGEN_DISABLED), a loading screen, IsInInstance(), an active add-on
          restriction (Chat, Encounter, ChallengeMode, PvPMatch, Map) or chat lockdown (InChatMessagingLockdown()),
          or the back-off after an AddOnMessageLockdown result; with the reason (combat, loading, instance,
          restricted, lockdown)
alone     nobody to exchange with: no guild, group or online friend with the addon heard in the last 30 minutes
active    exchanging or waiting for the next one
```

Transitions:

```text
login                -> notice (shareNotice false) | off | paused | alone
popup closed         -> shareNotice = true -> alone, first HELLO after 60-120 s (the setting changed on the
                        "Shared database" page first also closes the notice: the page says what is shared)
setting off          -> off: the running session is dropped without a message, nothing is sent or accepted
setting on           -> alone -> HELLO after 5-30 s; stored records count again at once
combat / instance /
loading / restriction-> paused: the running session is dropped (the peer times out); after the reason ends,
                        alone or active again, HELLO after 5-30 s if the last one is older than 10 minutes
AddOnMessageLockdown -> paused for 60 s, doubling up to 15 min while it repeats
throttle result      -> no pause: the message goes back to the front and the queue holds 2 s, then 4 s, at most
                        8 s (under the 15 s session and part timeouts)
5 refusals in a row  -> that path is left out until logout; when no path is left: unavailable until logout
```

## Bucket hashes

The records held (own plus others, without those the seed holds whole) are grouped into 32 buckets by the first character of the
ID (one bucket may hold several epochs of one ID). A bucket's hash is computed over its sorted `id.epoch.seq` lines
(research R5); the whole-database hash, sent in `HELLO`, is computed over the 32 bucket hashes. The summary (units,
buckets, the 32 bucket hashes and the whole hash) is cached and rebuilt whole on its next use after any change:
`SHARED_DATA_CHANGED` or a new seq of the own record. Units of the own ID that a peer would refuse are left out, so
the hashes can still match.
