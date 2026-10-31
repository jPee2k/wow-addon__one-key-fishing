# Data Model: Catch Data Exchange Through a Hidden Public Channel

Builds on [the part 1 data model](../002-local-catch-db/data-model.md) and [the part 2 data
model](../003-guild-group-sync/data-model.md). The place key, the cell, `shared.mine`, the store of other players'
records and the session of part 2 keep their shape. Part 3 adds a version proof to every record, the owner's chain
behind it, two fields to the seed, two account-wide settings, the channel's session state, and new rules for the
views and for eviction.

## Saved data (account-wide, `OneKeyFishingDB`)

`DB_SCHEMA` stays 1: only new fields, filled by `ApplyDefaults` or created at runtime; nothing is renamed, moved or
reshaped. Nothing of parts 1-3 has been released yet, so the dev installs that hold part 2 records without a proof are
handled at login (below) and need no migration.

```lua
OneKeyFishingDB.settings.shareChannel = true -- NEW: "Use the public channel" (FR-021); without effect while shareDB
                                             -- is off
OneKeyFishingDB.shareNoticeChannel = false   -- NEW: true once the notice that names the public channel was closed
                                             -- (FR-022); shareNotice (part 2) stays as it is
OneKeyFishingDB.shared = {
  myID = "k7f2q6xa", mine = { ... },         -- unchanged
  chain = {                                  -- NEW: the own record's version chain (research R9); never sent, never in
    epoch = 3,                               --   /okf debug or /okf share; the epoch of the live own record
    secret = "q7...",                        --   26 base32 characters (130 random bits), new with every epoch
    top = 4096,                              --   CHAIN_LENGTH: the highest seq this chain can prove
    marks = { [4096] = "...", [4032] = "...", ... },   -- every 64th link (16 base32 each), built in the
  },                                         --   background after a roll or a login, so a proof costs <= 63 steps
  records = {
    ["k7f2q6xa"] = { id, epoch, seq, proof, builds },             -- the own record: + proof (the link of its seq)
    ["m3p7x2zd@3"] = { id, epoch, seq, proof, builds, seen },     -- another player's: + proof
  },
}
```

| Field | Meaning |
| --- | --- |
| `proof` | 16 base32 characters (80 bits): link `seq` of the owner's chain. Link `top` is a hash of the secret; every lower link is the hash of the one above it (`x[i-1] = H(x[i])`), so only the owner can name a link above the newest one it published |
| `chain.marks` | links at the multiples of 64, from `top` down; the proof of a seq is at most 63 steps below the next mark |

### The version chain

- `H(x)` = the first 80 bits of SHA-256 of the 16 characters, written as 16 base32 characters (research R9). The top
  link is `H(secret)`.
- A new own record (a roll, or the first record of an account) gets a new secret and `chain.epoch` = its epoch. The
  marks are built in the background (64 links per frame step), and the record's `proof` is set to link `seq` at every
  seq bump (`CatchDB`), at most 63 steps from the next mark.
- A record whose seq reaches `top` rolls (as at 500 places, part 1 "Rolling the own record"); the old one keeps its
  last proof and never changes again.
- At login, an own record without a proof (a dev install from part 2) gets a chain for its epoch that starts at its
  current seq (no peer ever held a proof of it). Other players' records without a valid proof are deleted by
  `Store.CleanUp`, like damaged ones.
- The proof is part of the record: it is sent, checked, stored and read by the harvest. `seen` stays local.

### Rules for other players' records (changes to part 2)

- **Check** (`CatchDB.CheckRecord`): as in part 2, plus `proof` is 16 base32 characters; item IDs must be positive
  integers up to 2,147,483,647; the casting of all cells together (`t`) is at most `STEP_SECONDS` (180) times the
  seq (research R9). An item this client does not know is no longer a fault (FR-017a): the record is kept,
  counted and passed on.
- **Blocked**: a record of an ID in the seed's `blocked` list is refused without blaming the sender, deleted at login
  and after a seed update (`Store.CleanUp`), never wanted, never offered (FR-020).
- **Newer version** (`CatchDB.CheckVersion(held, incoming)`, research R9). Against the version held (the stored
  record, or the seed's `proofs[id][epoch]` for a unit the seed absorbed in part):
  1. the chain: `H` applied `incoming.seq - held.seq` times to `incoming.proof` gives `held.proof`, and the jump is
     at most one chain (`CHAIN_LENGTH`);
  2. no seed proof and no stored version: the first version heard is taken (nothing to check it against).
  Nothing else is compared with the held version: it may be a made-up copy, and the owner's next version must
  replace it whatever it holds (research R9). The casting limit of the check above bounds every version alone.
  A version that fails is refused. Its sender is ignored until logout, as for any invalid record, only when the
  version held is the seed's proof: a stored one may be a made-up copy taken first (the residual risk of research
  R9), and then the sender relaying the owner's real version is no forger. That version (unit and seq) is not wanted
  again this session while the same copy is held (`node.chainRefused`), so sessions do not fetch and refuse it over
  and over; another seq still is, since the forgery may be the version and not the copy. The chain is
  walked in chunks of `PROOF_STEPS` links per frame step (research R9), so a long jump never costs one frame more
  than the 5 ms goal.
- **Same seq, other proof or content**: `"same"`, as in part 2 (only `seen` refreshed); the first copy stays.
- **Size limit**: 20,000 places of other records, as in part 2, with the eviction order below.

### Eviction by new information (FR-016)

Above 20,000 places, records are deleted in this order until the total fits; never one of the own ID:

```text
class A  most of its places (at least half) are places the seed knows from 1,000 or more catches
class B  not confirmed by any peer for over 60 days (seen older than 60 * 86400 s)
class C  every other record
class D  more than half of its places are places where the seed has under 50 catches (part 1's "little data")
```

A record belongs to the first class it fits, D excepted: D wins over B and C (a rare-places record that went quiet
still goes last); A and D cannot both apply. A place without a seed cell counts as one with under 50 catches.
Within a class the oldest `seen` goes first, then the key. A stored record never changes, so its class shares are
computed once per stored table (a weak cache, as `OtherPlaces` is). A version evicted this session is not wanted back
(part 2 rule).

## Seed (`SeedData.lua`, written by the harvest)

Two new fields; the rest of `specs/002-local-catch-db/contracts/seed-data.md` is unchanged. `npm run check` checks
their shape.

```lua
ns.SeedData = {
  ...,
  proofs = {                 -- NEW: contribution ID -> { [epoch] = proof }: the proof of the version absorbed
    ["k7f2q6xa"] = { [2] = "a2c...", [3] = "7kq..." },   --   (the seq in `absorbed`); a newer version must chain to it
  },
  blocked = {                -- NEW: contribution IDs the author blocked (FR-019); their data is not in the sums
    ["zz7qkp2m"] = true,
  },
  cells = { ... },           -- the sums now apply the weight limit per cell (research R7); k is still the number of
}                            --   contributors
```

`seed/contributions.json` (the harvest's store) keeps each record with its `proof`, and gains `blocked`: ID -> the
author's note (FR-019).

## Views (changes to parts 1 and 2 "Views")

`CatchDB.Query(mapID, cell, filter)` keeps its arguments, its scopes and its cache key.

- **Contributions**: the seed cell(s) are one block; the own record and the own records a roll kept are one
  contribution (the own ID); every other ID is one contribution (its epochs together). `players` is unchanged
  (part 2 research R9).
- **Weights** (FR-013, research R7): when `players >= 5`, every other ID's counts are scaled by `f = min(1, T / c)`,
  where `c` is its catches in the scope and `T` the cap that makes each capped share at most one fifth of the
  weighted total (seed block and own counts unscaled). The view's `catches` and `misses` stay the raw sums;
  `chance` and `pieces` come from the scaled sums. The new `missRate` is weighted the same way by casts (`c + m`
  instead of `c`; a weighted seed cell gives its catches weighted by casts as `x`), so a contribution of few catches
  and many misses holds at most a fifth of it. `littleData` uses the raw catches (a seed cell the harvest weighted
  gives them as `r`).
- **Items shown** (FR-014): an item is listed when the seed has it anywhere, or the own catch (`mine`, or a record
  of the own ID) has it anywhere, or at least 3 distinct other IDs report it on the map (any range). The catches of an
  item left out still count in the totals.
- **Unknown items** (FR-017a): each item gets `reporters` (the distinct other IDs that report it on the map) and
  `inSeed`. Whether the client knows the item is read when the row is drawn (`C_Item.GetItemInfoInstant`), not kept in
  the view, so the cache needs no change when the game learns the item; the tab draws an unknown one as an "Unknown
  item" row.

```lua
view = { scope, littleData, catches, misses, missRate, players,
         items = { { itemID, catches, chance, pieces, known, reporters, inSeed } } }
```

## Session memory (never saved)

```lua
-- Channel.lua
channel = {
  state = "in",              -- see "State of the channel" below
  index = 1,                 -- 1 = the main channel, 2..6 = fallback channels (research R4)
  number = 5,                -- the chat channel number the game gave it (for SendAddonMessage)
  locked = { [1] = true },   -- indexes found locked or banned this session: not tried again until logout
  kicks = 0,                 -- kicks this session; the third counts as a ban
  rejoinAt = nil,            -- GetTime() before which a kicked client does not join again (60 s after the kick)
  joinAt = 4100,             -- GetTime() of the delayed join after the login
  joining = false,           -- the addon's own join is under way (a limit refusal now is not the player's)
  echoes = {},               -- index -> GetTime() of each of the addon's own leaves of that name whose YOU_LEFT has
                             -- not come, oldest first. A YOU_LEFT of the name uses up the oldest one within 5 s (15 s
                             -- while a join of the same name waits) and is not "left by hand"; older ones are dropped.
                             -- Any other YOU_LEFT of the name joined is the player's; one of another name is ignored
  joins = 0,                 -- joins started this session (CHANNEL_STATE's third value)
  sawPassword = false,       -- a password set by a player not heard announcing on this channel (the owner clears it;
                             -- moderation has no undo, so it only starts the wait)
  lockTimer = nil,           -- the 10-20 s wait before moving on after such a lock
}
-- What lasts until the next login survives a /reload: PLAYER_LOGOUT (a /reload fires it too) writes
-- OneKeyFishingCharDB.channelSession = { left, refused, gaveWay, wayLinePrinted, kicks, rejoinAt, locked, lockWait,
-- sawPassword }; the next PLAYER_ENTERING_WORLD reads it back on a /reload (a lock waited on starts its wait again)
-- and deletes it either way, so a real login starts afresh.
-- Comm.lua (additions to part 2)
channelRefusals = 0          -- refusals in a row on the channel path; the second calls Channel.OnRefused, then 0
dropped = {}                 -- address -> per-minute count of parts dropped by the part filter (last 10 minutes)
flooded = {}                 -- addresses reported through Comm.OnFlood: every message from them is dropped
-- Share.lua, the node (additions to part 2)
node.ignored = {}            -- addresses ignored until logout: kept when the peer bound forgets the peer itself
node.chainRefused = {}       -- "<unit>.<seq>" of a version that failed to continue the stored copy -> that copy (weak
                             -- values): that version is not wanted again while the copy is held
node.channelHeard = {}       -- per-minute count of channel HELLOs heard: the population estimate (research R5)
peer.busyRetried = true      -- a near peer's one busy retry is scheduled (cleared by its next HELLO)
peer.retrying = true         -- that retry is still due (cleared when it fires): the channel waits for it
node.skippedNear = {}        -- near peers whose HELLO came during a session or within 2 min of the last start, or
                             -- whose start met a session or a start with somebody else in its start delay:
                             -- considered again when that (and a pause) is over
node.channelCount = 0        -- peers whose only path is the channel (bounded to 300)
peer.via = "channel"         -- a peer first heard in the channel; a later guild, group or friend HELLO upgrades it
merge.verify = { held, record, state }  -- a received record whose chain is still being walked (research R9)
```

At most `MAX_CHANNEL_PEERS` (300) peers whose only path is the channel are kept; above it the one heard longest ago
is forgotten (its tag too), never a guild, group or friend peer and never the session's peer (FR-009). Names live
only here and in Comm's queue, part buffers and 10 s filter list, as in part 2.

## State of the channel

`Channel.GetState()` derives one state, in this order:

```text
unavailable  the release ships without the channel (Channel.AVAILABLE false, FR-026)
off          "Use the shared catch database" or "Use the public channel" is off
notice       the notice that names the channel has not been closed yet
paused       the exchange is paused (part 2 reasons); the addon stays in the channel but sends and takes nothing
left         the player left the channel by hand: out until the next login
noslot       fewer than two chat channel slots free, or the slot was given up for the player
locked       every channel (main and fallbacks) was found locked or banned this session, or the game refused to join
waiting      the delayed join after the login has not happened yet
in           in the channel (index 1) or a fallback channel (index 2..6)
```

Transitions:

```text
login (all on)        -> waiting -> 30-60 s later (research R2): join index 1, or the first index not locked
/reload               -> the state saved at the logout is back (left, locked, kicks, a slot given up); already in
                         one of our names (GetChannelName > 0): in, windows cleaned again
joined                -> in: removed from every chat window that lists it; CHANNEL_STATE fires
setting off / shareDB off -> leave at once (leaving = true) -> off
setting on            -> join at once (no login delay)
wrong password (the popup hidden) / banned / wrong faction on join -> mark locked, join the next index;
                         none left -> locked until logout
trial restricted / invalid name / the join returns nil -> locked (no fallback)
lock while in (password or moderation by a player not heard announcing) -> as owner: undo it; otherwise wait
                         10-20 s: undone by a player heard announcing -> stay; else leave, mark locked, next index
became owner after a lock was seen -> clear the password (V24)
kicked                -> join again after 60 s; the third kick counts as a ban
banned or muted while in, or 2 channel refusals in a row -> leave, mark locked, next index
player leaves by hand -> left until logout (the setting is not changed)
player hits the channel limit while in -> leave at once, print the one line (FR-005) -> noslot
two slots free again  -> join (checked on CHANNEL_UI_UPDATE and at every channel HELLO round)
```
