# Architecture: catch exchange

`Exchange/Comm.lua` and `Exchange/CommReceive.lua` (the transport, `ns.Comm`), `Exchange/Channel.lua` (the hidden public
channel) and `Exchange/Share.lua` (the protocol, other players' records and the state). The spec, model and contracts
are in `specs/003-guild-group-sync/` (`data-model.md`, `contracts/sync-protocol.md` for the wire format,
`contracts/share-api.md`) and, for the public channel and the protections against strangers, in
`specs/004-public-channel-sync/`; the in-game checklists are [catch-exchange.md](../checklists/catch-exchange.md) and
[public-channel.md](../checklists/public-channel.md).

The exchange is one module, `ns.Share`, in four files (TOC order, after `Comm.lua`, `CommReceive.lua` and
`Channel.lua`): `Share.lua` (the module table, the limits and timings, the store of other players' records, the bucket
hashes, the Base64/CBOR codec), `ShareNode.lua` (the protocol node: its summary, peers and sessions),
`ShareProtocol.lua` (the messages HELLO, SUM, DIFF, WANT, BYE, REC, the records sent and merged, the hello rounds, a
node's activity and status) and `ShareGame.lua` (the one node bound to Comm, its pauses and rounds, the setting, the
state). The files share their internals through `Share.private` (not an API); none of those names is ever reassigned,
the one reassigned counter (`dataVersion`) lives with its only reader in `ShareNode.lua`. The one-time popup is the
view's (`UI/ShareNotice.lua`).

## Exchange/Comm.lua and Exchange/CommReceive.lua

The transport of the catch exchange; it knows nothing about records. One module, `ns.Comm`, in two files sharing
`Comm.private` (not an API; the tests read the send paths there): `Comm.lua` sends (the queue, the pace, the budget,
the send results, the paths, the pause, the chat filter, the state for the debug report), `CommReceive.lua` takes
messages in (`OnReceive`, `OnActivity`, `SetPartFilter`, `OnFlood`; long messages put together from their parts
within the buffer limits, parts nobody asked for dropped, a flooding sender reported once).

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
- The channel path: `Comm.ChannelBroadcast` queues a `HELLO` with chat type `CHANNEL` only while
  Channel.lua is in its channel, at the broadcast pace; the channel's number is read when the message goes out. A
  `CHANNEL` message counts only from one of `Channel.NAMES` (the `name` argument, else `target`), as
  `via = "channel"`. Two refusals in a row (`InvalidChannel`, `GeneralError`, any result but a success, a
  throttle or a lockdown) call `Channel.OnRefused()` (the next channel); the channel path never counts toward
  "every path left out", since it carries `HELLO` only.
- Parts: never from the channel, and only from an address the part filter takes (`Comm.SetPartFilter`: Share's
  session peer); at most 128 KB of parts over all senders (the buffer that got its last part longest ago goes first).
  More refused parts from one sender in 10 minutes than an honest client's whole hourly budget carries (402) call
  `Comm.OnFlood` once and drop that sender until logout; what a peer still sends after its session ended here
  never reaches that.

## Exchange/Channel.lua

The hidden public channel; it knows nothing about records.

- Names: `OneKeyFishingShare`, then `OneKeyFishingShare2`..`6`, walked in this order by every client. The switch
  `Channel.AVAILABLE` takes the channel out of a release whose spike failed (V19).
- Joined with `JoinTemporaryChannel(name)` 30-60 s after a login (at once after the setting or after slots free
  up), only with both settings on, the notice that names the channel closed, no pause, and two free chat channel
  slots of the 20. After a `/reload` a joined channel is taken as it is.
- Hidden: taken out of every chat window that lists it (`RemoveChannel`, also on `UPDATE_CHAT_WINDOWS`), and five
  `ChatFrameUtil` filters drop every line whose channel is ours (secret values untouched). The password popup for
  our names is closed in the same frame.
- The player's channel limit: the game's limit text while in (not during its own join) makes it leave at once, print
  one line per session and wait until two slots are free (`CHANNEL_UI_UPDATE` or the next channel round).
- Locks: a refused join (`WRONG_PASSWORD`, the password request, `BANNED`, `WRONG_FACTION`, no confirmation by
  three checks 5 s apart) locks that name for the session and joins the next. A password or moderation set by a player
  not heard announcing (`Share.HeardInChannel`): the owner clears a password at once (it learns ownership from
  `OWNER_CHANGED` or the `CHANNEL_OWNER` answer to `DisplayChannelOwner`, asked only after a lock); otherwise, and
  for moderation, which has no undo call, it moves on after a random 10-20 s unless a heard player undoes it. Kicks
  rejoin after 60 s, the third counts as a ban; a ban or a mute moves on. `TRIAL_RESTRICTED`, `INVALID_NAME` or a
  nil join result: locked, no fallback. Each leave by the addon (`Leave`, a second name of ours once per join, the
  clean-up after a `/reload`) owes one `YOU_LEFT` of that name; one that comes within 5 s (15 s while a join of the
  same name waits) uses it up. Any other `YOU_LEFT` of the name joined (also before the join is confirmed) is a leave
  by hand: out until the next login. After a `/reload` a channel found locked that the client is still in is left,
  and one the player joined again by hand after a leave is left alone. Ticking the setting counts as reading the notice.
- `Channel.GetState()` (unavailable, off, notice, paused, left, noslot, locked, waiting, in) fires `CHANNEL_STATE`
  (state, index, joins) on each change; a new `joins` is a new join (Share's first channel round, Comm's refusal
  count), the same one after a pause is not. `Channel.Describe()` for `/okf debug`.

## Exchange/Share.lua: the store

`Share.Store` keeps received records in `shared.records` under `<id>@<epoch>` with `seen`:

- only the record fields of `specs/002-local-catch-db/data-model.md`; a higher `seq` replaces;
- the own ID and versions the seed holds whole are refused; a newer version of a unit it holds in part is kept and
  passed on;
- those held whole and damaged ones are deleted, and above 20,000 places the oldest `seen` goes (never one of the
  own ID), at `ADDON_LOADED` and after a merge; an evicted version is not wanted back this session;
- `SHARED_DATA_CHANGED` carries the changed keys so CatchDB updates its one index of other players' cells in place,
  and the store, so a protocol node's cached summary (versioned per store) and CatchDB (only the game's store) know
  whose data changed.
- A record needs a proof (`CatchDB.CheckRecord`), and a newer version of a held unit must continue its chain
  (`CatchDB.CheckVersion`, walked in steps of 32 links by the merge, or at once with `verified` unset). A record of
  an ID in the seed's `blocked` is refused without blame, deleted at login, not wanted and not offered; the own
  blocked record still counts locally. Eviction goes by class (half the places saturated in the seed, stale over 60
  days, the rest, mostly rare places), then by `seen`. The seed's chain proofs of units it holds in part are checked
  in the background after login.

## Exchange/ShareNode.lua and ShareProtocol.lua: the protocol

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
  (`node:OwnData`: checked and encoded once per version; never while the proof is not ready or the ID is blocked).
- The public channel (research R5 of `specs/004-public-channel-sync/`):
  - the game node sends a channel `HELLO` 30-90 s after joining, then every 30-50 min, and 5-30 s after a move to
    a fallback; from the channel only whole `HELLO`s are handled, sessions go by whisper;
  - a stranger's channel `HELLO` starts a session with the chance `min(1, 2 / H)`, `H` being the channel
    `HELLO`s heard in the last 40 min (about the number of clients), and not while a guild, group or friend peer
    heard in the last 15 min is about to get one (its start armed, its busy retry due, or waiting for a session or a
    start to end);
  - near peers (guild, group, friends) keep the timing above: one that answered `BYE busy` is tried once more 120-180 s
    later, and one skipped because a session ran (or a start was under 2 min ago) is considered again when that is over;
  - at most 300 peers known only from the channel; a channel peer has the 30 min cooldown, and a guild, group or
    friend `HELLO` from it upgrades its path;
  - the full refresh of every record's `seen` (a `HELLO` with the same hash) runs at most every 10 min.
- `tests/exchange/channel/sim_test.lua` runs many nodes through one fake channel (`OKF_SIM_NODES`); measured numbers in
  research R5 of `specs/004-public-channel-sync/`.

## Exchange/ShareGame.lua: setting and state

`Share.SetEnabled` (the setting), `Share.GetStatus()` / `StatusLine()` / `PrintStatus()` / `Describe()` (states
off, notice, unavailable, paused, alone, active); `Share.ChannelLine()` is the channel's line for `/okf share`
and the settings page, and `GetStatus` carries the channel fields (`channel`, `channelIndex`, `channelPeers`,
`population`, `blocked`, `ownBlocked`). The one-time notice names the channel: closing the popup sets
`shareNotice` and, while the release has the channel, `shareNoticeChannel`; a player who closed an earlier notice
that did not name the channel sees it once more. The popup itself is the view's (`UI/ShareNotice.lua`): Share says
whether one is owed (`Share.NoticeOwed()`), what closing it means (`Share.NoticeRead()`: the exchange starts) and
hides it by `Share.NOTICE_POPUP` when a setting on the page counts as reading it (`Share.CloseNotice()`).
