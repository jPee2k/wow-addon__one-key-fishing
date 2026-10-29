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
  myID = "k7f2q9xa",                      -- unchanged; never sent with a name, never in /okf debug or /okf share
  mine = { ... },                         -- unchanged: lifetime counts of this account ("Only mine")
  records = {
    ["k7f2q9xa"] = { id, epoch, seq, builds },             -- the own record, unchanged (part 1), keyed by myID
    ["m3p7x2zd@3"] = { id, epoch, seq, builds, seen = 1761234567 }, -- NEW: another account's record, keyed by
                                                                    -- "<id>@<epoch>"
  },
}
```

A received record has the same `{ id, epoch, seq, builds }` shape as the own one (part 1 data model, "Cell"), so
`npm run harvest` reads it unchanged (it already walks every entry of `shared.records`, checks it and keeps the
newest `seq` per `id@epoch`) and ignores the key and `seen`. Other records are keyed by `<id>@<epoch>`, the same
unit the harvest keeps: when an owner starts over after a release absorbed their record, a client with an older seed
still holds the old epoch (its seed does not contain it yet) next to the new one, and drops it once its own seed
absorbs it.

| Field | Meaning |
| --- | --- |
| `seen` | `time()` when this record version was last received or confirmed by a peer in a session (its entry matched in a `DIFF`); drives eviction |

### Rules for other players' records

- **Accept** (research R6): the record passes `CatchDB.CheckRecord` (the part 1 cell validation, the same as the
  harvest's, plus: `id` is 8 base32 characters and not `myID`; at most 1,000 places; every item ID known to
  `C_Item.GetItemInfoInstant`). A failing record is rejected whole.
- **Replace**: a received record replaces the stored one with the same `id@epoch` only when its `seq` is higher.
  Otherwise it is a duplicate or older and is ignored (only `seen` is refreshed when it is the same version).
- **Absorbed**: a record whose `epoch` is not newer than `ns.SeedData.absorbed[id]` is already counted in the seed:
  it is not accepted, and a stored one is deleted at login (as the own record starts over in part 1). This is what
  keeps network data from counting twice after a release (FR-014, SC-008).
- **Own ID**: a record with `id == myID` is never accepted (FR-012).
- **Size limit**: the other records together hold at most 20,000 places (about 2 MB of saved data). Above that the
  record with the oldest `seen` is deleted first, until the total fits; the own record is never deleted (FR-013).
  Because `seen` is refreshed whenever a peer confirms the same version, records of players still in the network
  stay, and those of players who stopped playing go first. A version evicted this session is not wanted back
  (only a newer one), so eviction and the next session do not trade the same records while the network holds more. The info-based eviction order of
  `docs/shared-db-plan.md` (seed-heavy cells first, rare places last) is left for part 3, when strangers bring far
  more records (research R6).

## Views (changes to part 1 "Views")

| Filter | Data summed for a place key |
| --- | --- |
| Source "All", sharing on | seed cell + own record cells + every other stored record's cells (the reset rule of part 1 applies to each record) |
| Source "All", sharing off | seed cell + own record cells (as part 1) |
| Source "Only mine" | `mine` cell (unchanged) |

A view (contracts/catchdb-api.md of part 1) gains `players`: the number of contributions behind the numbers. For the
records it is exact (the records with at least one summed cell, the own one included); for the seed part it is the
cell's `k` at a spot and the largest `k` of the summed cells for the whole map (a lower bound: the seed does not say
which contributors overlap between cells). Nothing is counted twice; at worst the count is low (research R9).

## Session memory (never saved)

```lua
peers = {                  -- address -> peer; an address is "w:<name>" (whisper) or "b:<gameAccountID>" (Battle.net)
  ["w:Fisher-Forever"] = {
    via = "guild",         -- "guild" | "group" | "friend" | "bnet": how it was found (for /okf share counts only)
    node = "q2x7",         -- the peer's random node tag of this login (HELLO): one client on two paths is one peer,
                           --   and the smaller tag wins when both start a session at once (research R5)
    epoch = 3, count = 12, hash = "7f3k2a9",           -- from its last HELLO
    heard = 1761234567,    -- last HELLO
    synced = 1761234000,   -- last finished session with it (cooldown, "players in the last hour")
    pausedUntil = nil,     -- after a timeout or "busy": no session before this time
    ignored = nil,         -- reason, when it flooded or sent bad data: ignored until logout
    hellos = {}, records = {},                -- receive times in the last hour, for the flood limits
  },
}
session = {                -- at most one at a time
  sid = "a7", peer = "w:Fisher-Forever", role = "initiator" | "responder",
  step = "sum" | "diff" | "want" | "records" | "done", started = GetTime(), lastHeard = GetTime(),
  sent = 0,                -- payload bytes sent in this session (8 KB limit)
  theirWants = {}, ourWants = {},
}
traffic = {}               -- bytes sent per minute for the last 60 minutes (50 KB per hour budget)
paths = {                  -- per path ("guild", "group", "whisper", "bnet"): refusals in a row and whether the path is
  whisper = { failures = 0, disabled = false },   -- left out until logout (5 refusals in a row, research R7)
}
friendCursor = 1           -- where the next HELLO round continues in the list of friends not yet known as peers
node = "q2x7"              -- this client's random tag, new at every login; not the anonymous ID
lastExchange = nil         -- time() of the last session that moved or confirmed data
```

Character names and Battle.net account IDs exist only here (and in `Comm`'s send queue and its 10 s list of names
just whispered) and are gone at logout (FR-009). The protocol version is not a field: it is the prefix (`OKF1`), and
a client never sees messages of another version (FR-007).

## State of the exchange

`Share.GetStatus()` (contracts/share-api.md) derives one state, in this order:

```text
off       settings.shareDB is false
notice    the one-time popup has not been closed yet (no exchange before it, FR-021)
unavailable  the game refused every path 5 times in a row (for example a Trial or Veteran account): until logout
paused    InCombatLockdown(), IsInInstance(), a loading screen, an active add-on restriction, or a back-off after
          the game reported a limit or a lockdown; with the reason
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
game limit / lockdown-> paused for 60 s, doubling up to 15 min while it repeats
5 refusals in a row  -> that path is left out until logout; when no path is left: unavailable until logout
```

## Bucket hashes

The records held (own plus others, without absorbed ones) are grouped into 32 buckets by the first character of the
ID (one bucket may hold several epochs of one ID). A bucket's hash is computed over its sorted `id.epoch.seq` lines
(research R5); the whole-database hash, sent in `HELLO`, is computed over the 32 bucket hashes. Hashes are cached per bucket and recomputed only for a bucket that
changed.
