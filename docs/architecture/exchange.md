# Architecture: catch exchange

Comm.lua (the transport) and Share.lua (the protocol, other players' records and the state). The spec, model and
contracts are in `specs/003-guild-group-sync/` (`data-model.md`, `contracts/sync-protocol.md` for the wire format,
`contracts/share-api.md`); the in-game checklist is [catch-exchange.md](../checklists/catch-exchange.md).

## Comm.lua

The transport of the catch exchange; it knows nothing about records.

- Prefix `OKF1` (the digit is the protocol version). `C_ChatInfo.SendAddonMessage` to `GUILD`, `PARTY`/`RAID`
  (home group) and `WHISPER`; `C_BattleNet.SendGameData` to Battle.net friends playing Forever. Addresses
  `w:<name>` and `b:<gameAccountID>`.
- Messages over 255 bytes go in parts `<type><sid>#<msg>.<part>.<total> <chunk>` (joined in any order, 64 KB per
  sender, dropped 15 s after the last part).
- One queue: broadcasts 2 s apart, whispers 0.5 s, 50 KB per hour (`Comm.BUDGET`; `CanSend` counts the queued
  bytes too; above it only `BYE`).
- Every send result is read:
  - throttle: back-off 2-8 s, under the protocol's 15 s timeouts;
  - `AddOnMessageLockdown`: pause 60 s-15 min;
  - `TargetOffline`: `Comm.OnOffline`;
  - any other refusal of a whisper or Battle.net message also drops the rest to that player and reports them
    offline, so it counts once per player;
  - 5 refusals in a row leave a path out until logout; all paths out = "unavailable";
  - `Comm.Refused()`: nothing went out since the login and every path tried with more than a greeting is out,
    which the state shows as unavailable too.
- The result codes are read from `Enum.SendAddonMessageResult` (the 1.60.1 numbers only as a fallback).
- Pause rule (`Comm.GetPause()`, fires `SHARE_PAUSE`): combat, loading screen, instance,
  `Chat`/`Encounter`/`ChallengeMode`/`PvPMatch`/`Map` restrictions (read on the frame after
  `ADDON_RESTRICTION_STATE_CHANGED`, which fires before a restriction is active), chat lockdown
  (`InChatMessagingLockdown`; not `AreOutgoingAddonChatMessagesRestricted`, which is about chat messages by addons
  and true on a normal realm), the lockdown back-off. While paused nothing is sent or received.
- A `CHAT_MSG_SYSTEM` filter (`ChatFrameUtil.AddMessageEventFilter`) hides "No player named" for names whispered
  in the last 10 s.
- Names live only in the queue, the part buffers and that list.

## Share.lua: the store

`Share.Store` keeps received records in `shared.records` under `<id>@<epoch>` with `seen`:

- only the part 1 fields; a higher `seq` replaces;
- the own ID and versions the seed holds whole are refused; a newer version of a unit it holds in part is kept and
  passed on;
- those held whole and damaged ones are deleted, and above 20,000 places the oldest `seen` goes (never one of the
  own ID), at `ADDON_LOADED` and after a merge; an evicted version is not wanted back this session;
- `SHARED_DATA_CHANGED` carries the changed keys so CatchDB updates its one index of other players' cells in place.

## Share.lua: the protocol

- `Share.NewNode(store, env)` is a protocol node with its clock, scheduler and transport injected. The tests run
  several over a fake network; the game makes one bound to Comm on `PLAYER_LOGIN`, once the one-time popup was
  closed (`OneKeyFishingDB.shareNotice`).
- Message names are logical: on the wire each message starts with its first letter, the session messages with the
  session ID right after it (`S<sid> ...`); format in `specs/003-guild-group-sync/contracts/sync-protocol.md`.
- `HELLO` (on the wire `H <node tag> <epoch> <count> <hash>`) goes to guild and group and to up to 20 friends per
  round (known peers first, the rest from a cursor): 60-120 s after login, then every 10-15 min, and 5-30 s after
  the group grew. One extra HELLO waits at a time.
- The hearer of a differing hash starts a session after 2-20 s:
  - `SUM`: 32 bucket hashes by the ID's first base32 character, polynomial hash mod 4294967291 in plain
    arithmetic;
  - `DIFF`, `WANT`;
  - `REC`: `C_EncodingUtil` CBOR + Deflate + Base64;
  - `BYE`.
- One session at a time: others get `BYE busy`, and so does a peer whose last `SUM` was answered with a `DIFF`
  less than 8 min ago.
- 8 KB and 25 records per direction (own record first, only records a peer would accept, each checked again
  before it goes); 15 s timeout and 5 min in all; cooldowns 2 min / 10 min (group) / 30 min.
- Crossing `SUM`s: the smaller node tag leads, also when the two know each other by different addresses (a `SUM`
  is matched to the session by the tag).
- Received records are decoded, checked and stored one per `C_Timer.After(0)` step.
- A sender of broken, unwanted or too much data is ignored until logout (not for an item this client does not
  know; the hourly limits are twice what an honest client can send to one peer, derived from `Comm.BUDGET` and the
  session limits).
- A session that moved nothing is not repeated with that peer until one of the two hashes changes.
- The records of the own ID (the live one and those a roll kept) are offered only when a peer would take them
  (`node:OwnData`: checked and encoded once per version).

## Share.lua: setting and state

`Share.SetEnabled` (the setting), `Share.GetStatus()` / `StatusLine()` / `PrintStatus()` / `Describe()` (states
off, notice, unavailable, paused, alone, active).
