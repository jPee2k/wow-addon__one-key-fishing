# Contract: `ns.Comm`, `ns.Share` and the `CatchDB` additions

Module functions used by the UI, the debug report, the slash command and the tests. Nothing here is called at file
load. TOC order: `SeedData.lua`, `CatchDB.lua`, `Comm.lua`, `Share.lua`, then the UI files; `Commands.lua` stays
last.

## `ns.Comm` (transport, `Comm.lua`)

| Function | Does / returns |
| --- | --- |
| `Comm.OnReceive(fn)` | `fn(address, via, text)` for every whole `OKF1` message (parts already joined); `via` is `"guild"`, `"group"`, `"whisper"` or `"bnet"` |
| `Comm.Broadcast(text)` | queues a `HELLO` to the guild and the home group, each only when the player is in one |
| `Comm.Send(address, text)` | queues a message (split into parts when needed) to `w:<name>` or `b:<gameAccountID>` |
| `Comm.ForEachFriend(fn)` | calls `fn(address)` for each online character friend and each Battle.net friend playing Forever (research R3) |
| `Comm.OnOffline(fn)` | `fn(address)` when a send to it returned `TargetOffline` |
| `Comm.GetPause()` | the pause reason (`"combat"`, `"instance"`, `"loading"`, `"restricted"`, `"lockdown"`, or `"unavailable"` once the game refused every path, until logout) or nil; a change fires `SHARE_PAUSE` (reason or nil) |
| `Comm.GetPaths()` | per path (`guild`, `group`, `whisper`, `bnet`): `{ failures, disabled }` (contracts/sync-protocol.md "Paths the game refuses") |
| `Comm.GetTraffic()` | bytes sent in the last 60 minutes |
| `Comm.CanSend()` | false while paused or over the hourly budget |
| `Comm.Describe()` | lines for `/okf debug`: pause, traffic, queue length, result code counts, back-off, left-out paths |

Rules: with `settings.shareDB` off nothing is queued and every received message is dropped; the queue keeps the pace
and the budget of research R7 and reads every send result; the `CHAT_MSG_SYSTEM`
filter hides "No player named ..." for names whispered in the last 10 s (research R11). Names live only in the
queue and the filter's 10 s list.

## `ns.Share` (protocol and state, `Share.lua`)

| Function | Does / returns |
| --- | --- |
| `Share.NewNode(store, env)` | a protocol node over `store` (a `shared` table); `env` = `{ now, after, send, broadcast, forEachFriend, canSend, myID, absorbed, check, encode, decode, onChange }`; the game makes one node bound to `Comm`, `CatchDB` and `C_EncodingUtil`, the tests several bound to a fake network |
| `node:Receive(address, via, text)` | handles one whole message |
| `node:Hello()` | sends a `HELLO` round: the broadcast, then up to 20 friends, those already known as peers first, the rest in turn from a cursor (research R3) |
| `node:Pause(reason)` / `node:Resume()` | drops the running session / allows sessions again |
| `node:Status()` | the status table below |
| `Share.IsEnabled()` / `Share.SetEnabled(on)` | the setting (`settings.shareDB`); off drops the session and stops everything at once; both directions change the views (`SHARED_DATA_CHANGED`) |
| `Share.GetStatus()` | `{ state, reason, records, places, heard = { guild, group, friend, bnet }, exchanged, lastExchange, traffic, rejected, longestStep }`: `state` from data-model.md "State of the exchange" (`off`, `notice`, `unavailable`, `paused`, `alone`, `active`); `heard` = peers heard in the last hour per path; `exchanged` = peers with a finished session in the last hour; `longestStep` = the longest merge step in ms (SC-006) |
| `Share.StatusLine()` | the short localized line for the tab and the settings page: "Exchange: 3 players, 5 min ago", "Exchange paused: in combat" (one text per reason), "Exchange unavailable: the game refuses addon messages", "Shared catch database is off", "Nobody to exchange with right now", "Waiting for you to read the notice" |
| `Share.PrintStatus()` | `/okf share`: localized lines into the chat frame (FR-022): seed and its epoch, records held and places, peers heard per path, peers exchanged with, last exchange, traffic of the last hour, the state and its reason |
| `Share.Describe()` | English lines for `/okf debug` (FR-023): the same numbers, no names and no IDs |

Messages (both listed in `CLAUDE.md` "Messages"):

- `SHARED_DATA_CHANGED` (no arguments): other players' records were added, replaced or removed, or sharing was
  switched; `CatchDB` bumps its version on it.
- `SHARE_PAUSE` (reason or nil): `Comm`'s pause reason changed; the game node pauses or resumes on it.

The one-time popup: on `PLAYER_ENTERING_WORLD` while `shareNotice` is false, out of combat and after the loading
screen, `ns.ShowPopup` with "Got it" (accept) and "Settings" (cancel: opens the "Shared database" page); its
`OnHide` sets `shareNotice = true` and starts the exchange, so Escape counts as closing it.

## `ns.CatchDB` additions

| Function | Returns |
| --- | --- |
| `CatchDB.CheckRecord(record)` | `true` or `false, reason`: research R6 (the part 1 cell rules, whole record rejected on any bad cell, `id` pattern and not `myID`, at most 1,000 places, items known to `C_Item.GetItemInfoInstant`) |
| `CatchDB.Query(mapID, cell, filter)` | unchanged arguments; with sharing on, source `"all"` also sums other players' records; the view gains `players` (research R9); the cache key includes whether sharing is on |

## `/okf share` and `/okf debug`

`Commands.lua` gains `{ name = "share", description = "show the state of the shared catch database", run =
function() ns.Share.PrintStatus() end }` (English description, constitution Principle II). The debug report gains a
"Shared database" section built from `Share.Describe()` and `Comm.Describe()`.
