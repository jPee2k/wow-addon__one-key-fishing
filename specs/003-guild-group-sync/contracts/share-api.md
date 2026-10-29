# Contract: `ns.Comm`, `ns.Share` and the `CatchDB` additions

Module functions used by the UI, the debug report, the slash command and the tests. Nothing here is called at file
load. TOC order: `SeedData.lua`, `CatchDB.lua`, `Comm.lua`, `Share.lua`, then the UI files; `Commands.lua` stays
last.

## `ns.Comm` (transport, `Comm.lua`)

| Function | Does / returns |
| --- | --- |
| `Comm.OnReceive(fn)` | `fn(address, via, text)` for every whole `OKF1` message (parts already joined); `via` is `"guild"`, `"group"`, `"whisper"` or `"bnet"` |
| `Comm.Broadcast(text)` | queues a `HELLO` to the guild and the home group, each only when the player is in one |
| `Comm.Send(address, text, kind)` | queues a message (split into parts when needed) to `w:<name>` or `b:<gameAccountID>`; kind `"bye"` goes out even over the hourly budget, kind `"greeting"` (a `HELLO` to a friend) does not count against its path when refused |
| `Comm.ForEachFriend(fn)` | calls `fn(address)` for each online character friend and each Battle.net friend playing Forever (research R3) |
| `Comm.OnOffline(fn)` | `fn(address)` when a send to it returned `TargetOffline` |
| `Comm.OnActivity(fn)` | `fn(address)` for every message or part that arrives (a long message is still on its way, so the session does not time out) |
| `Comm.IsSending(address)` | true while messages to the address wait in the queue |
| `Comm.Split(text)` | the message as it goes out: itself, or its parts (contracts/sync-protocol.md) |
| `Comm.GetPause()` | the pause reason (`"combat"`, `"instance"`, `"loading"`, `"restricted"`, `"lockdown"`, or `"unavailable"` once the game refused every path, until logout) or nil; a change fires `SHARE_PAUSE` (reason or nil) |
| `Comm.GetPaths()` | per path (`guild`, `group`, `whisper`, `bnet`): `{ failures, disabled }` (contracts/sync-protocol.md "Paths the game refuses") |
| `Comm.Refused()` | true while nothing went out since the login and every path tried with more than a greeting is left out: the state says unavailable (no pause; a later success clears it) |
| `Comm.GetTraffic()` | bytes sent in the last 60 minutes |
| `Comm.CanSend(bytes)` | false while paused, or when the messages still queued, a message of `bytes` (with its part headers) and one more full message would go over the hourly budget; a record is only sent when it fits whole |
| `Comm.BUDGET` | the hourly budget in bytes (Share derives its per-sender limits from it) |
| `Comm.Describe()` | lines for `/okf debug`: pause, traffic, queue length and bytes, result code counts, back-off, left-out paths |

Rules: with `settings.shareDB` off nothing is queued and every received message is dropped; the queue keeps the pace
and the budget of research R7 and reads every send result; the `CHAT_MSG_SYSTEM`
filter hides "No player named ..." for names whispered in the last 10 s (research R11). Names live only in the
queue and the filter's 10 s list.

## `ns.Share` (protocol and state, `Share.lua`)

| Function | Does / returns |
| --- | --- |
| `Share.NewNode(store, env)` | a protocol node over `store` (a `shared` table); `env` = `{ now, time, after, send(address, text, essential), broadcast, forEachFriend, canSend, absorbed, seedEpoch, encode, decode }` plus the optional `busy(address)`, `prepare()` (before the units are read for a peer), `clock()` (ms, for the longest merge step) and `random` (default `math.random`); the own ID is `store.myID`, records are checked by `CatchDB.CheckRecord`, and a store change fires `SHARED_DATA_CHANGED`; the game makes one node bound to `Comm`, `CatchDB` and `C_EncodingUtil`, the tests several bound to a fake network |
| `node:Receive(address, via, text)` | handles one whole message |
| `node:Hello()` | sends a `HELLO` round: the broadcast, then up to 20 friends, those already known as peers first, the rest in turn from a cursor (research R3) |
| `node:Pause(reason)` / `node:Resume()` | drops the running session / allows sessions again |
| `node:Status()` | the status table below |
| `Share.Store.Accept(store, record, now, absorbed)` | `"new"`, `"newer"`, `"same"` (only `seen` refreshed), `"older"` or `"refused", reason` (data-model.md rules); keeps a copy with only the part 1 fields |
| `Share.Store.CleanUp(store, absorbed)` / `Share.Store.Evict(store)` | delete the records under `id@epoch` the seed holds whole (`absorbed[id][epoch] >= seq`) or damaged ones / the oldest `seen` above 20,000 places, never one of the own ID; both return how many went (run at `ADDON_LOADED`, `Evict` also after a new record) |
| `Share.Store.Units(store, absorbed)` / `Share.Store.Get(store, unit)` / `Share.Store.ForSending(record)` | every unit held (`id@epoch` -> seq: the own record when it has cells of a game version, and the others, own rolled ones included, the seed does not hold whole) / a unit's record / the record without `seen` and builds without a game version |
| `node:OwnData(record)` | a record of the own ID as encoded for a peer, or `false` and why (no cells to send, a peer's check would refuse it, over 32 KB); encoded once per seq of each unit; a unit it refuses is left out of the summary, so hashes can still match |
| `Share.Hash(text)`, `Share.Base32(value, width)`, `Share.Buckets(units)`, `Share.BucketHashes(units)`, `Share.WholeHash(hashes)` | the hashes of research R5 |
| `Share.Encode(record)` / `Share.Decode(text)` | the `C_EncodingUtil` chain of research R4, each step in `pcall`; nil on failure |
| `Share.IsEnabled()` / `Share.SetEnabled(on)` | the setting (`settings.shareDB`); off drops the session and stops everything at once; both directions change the views (`SHARED_DATA_CHANGED`) |
| `Share.GetStatus()` | `{ state, reason, records, places, heard = { guild, group, friend, bnet }, exchanged, lastExchange, traffic, rejected, longestStep }`: `state` from data-model.md "State of the exchange" (`off`, `notice`, `unavailable`, `paused`, `alone`, `active`); `heard` = peers heard in the last hour per path; `exchanged` = peers with a finished session in the last hour; `longestStep` = the longest merge step in ms (SC-006) |
| `Share.StatusLine()` | the short localized line for the tab and the settings page: "Exchange: 3 players, 5 min ago", "Exchange paused: in combat" (one text per reason), "Exchange unavailable: the game refuses addon messages", "Shared catch database is off", "Nobody to exchange with right now", "Waiting for you to read the notice" |
| `Share.PrintStatus()` | `/okf share`: localized lines into the chat frame (FR-022): seed and its epoch, records held and places, peers heard per path, peers exchanged with, last exchange, traffic of the last hour, the state and its reason |
| `Share.Describe()` | English lines for `/okf debug` (FR-023): the same numbers, no names and no IDs |

Messages (both listed in `CLAUDE.md` "Messages"):

- `SHARED_DATA_CHANGED` (the changed keys, or none): records under `id@epoch` were added, replaced or removed
  (other players', or the own one a roll kept), or sharing was switched; `CatchDB` bumps its version on it.
- `SHARE_PAUSE` (reason or nil): `Comm`'s pause reason changed; the game node pauses or resumes on it.

The one-time popup: on `PLAYER_ENTERING_WORLD` while `shareNotice` is false, out of combat and after the loading
screen, `ns.ShowPopup` with "Got it" (accept) and "Settings" (cancel: opens the "Shared database" page); its
`OnHide` sets `shareNotice = true` and starts the exchange, so Escape counts as closing it.

## `ns.CatchDB` additions

| Function | Returns |
| --- | --- |
| `CatchDB.CheckRecord(record, myID)` | `true` or `false, reason`: research R6 (the part 1 cell rules, whole record rejected on any bad cell, `id` pattern and not `myID`, at most 1,000 places, `seq` not above the casts, items known to `C_Item.GetItemInfoInstant`) |
| `CatchDB.CountPlaces(record, limit)` | distinct places over all builds of a record (the unit of the place limits); with `limit`, counting stops one above it |
| `CatchDB.AbsorbedSeq(id, epoch, absorbed)` / `CatchDB.IsAbsorbed(id, epoch, seq, absorbed)` | the seq up to which the seed holds unit `id@epoch` (nil: none of it) / whether it holds this version whole |
| `CatchDB.FlushSeq()` | bumps the own record's seq when a change waits for its minute |
| `CatchDB.SeedInfo()` | the bundled seed's epoch and number of places (`/okf share`) |
| `CatchDB.Query(mapID, cell, filter)` | unchanged arguments; with sharing on, source `"all"` also sums other players' records; the view gains `players` (research R9); the cache key includes whether sharing is on |

## `/okf share` and `/okf debug`

`Commands.lua` gains `{ name = "share", description = "show the state of the shared catch database", run =
function() ns.Share.PrintStatus() end }` (English description, constitution Principle II). The debug report gains a
"Shared database" section built from `Share.Describe()` and `Comm.Describe()`.
