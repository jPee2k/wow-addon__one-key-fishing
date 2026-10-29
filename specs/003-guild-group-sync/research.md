# Research: Catch Data Exchange in the Guild, the Group and with Friends

Decisions taken for the plan, each with the reason and the alternatives that were rejected. The product decisions
(who, when, one setting, the popup, the tab) were settled with the author in the spec's "Clarifications" and are
recorded in `docs/shared-db-plan.md` ("Part 2 (spec 003): exchange in the guild and the group"). The protocol idea (HELLO, then
bucket hashes, then only the missing records) comes from the plan's "Sync protocol"; this file fixes how it is built
in WoW Forever. API facts below were read from the Forever 1.60.1.70532 dumps (Gethe `wow-ui-source@forever`,
Ketho `BlizzardInterfaceResources@forever`) on 2026-10-29; they prove that a function exists, not how it behaves,
so behaviour is an assumption in [verification.md](verification.md) (V10-V17).

Checked again on 2026-10-29 against the author's live client, build 1.60.1.70685 (newer than the 70532 dump).
The author ran `exportInterfaceFiles code` from the character screen. Everything this plan calls exists there with
the signatures and enum values used here:

- `C_ChatInfo`: `SendAddonMessage`, `RegisterAddonMessagePrefix`, `InChatMessagingLockdown`,
  `AreOutgoingAddonChatMessagesRestricted`.
- `C_BattleNet`: `SendGameData(gameAccountID, prefix, data)`, `GetFriendNumGameAccounts`,
  `GetFriendGameAccountInfo`. `BNGetNumFriends()` is used by the Forever ("Camelot") friends frame.
- `C_FriendList.GetFriendInfoByIndex`.
- `C_RestrictedActions.IsAddOnRestrictionActive`.
- `Enum.SendAddonMessageResult` 0-12 and `Enum.AddOnRestrictionType` 0-5 (`Chat` = 5).
- The six `C_EncodingUtil` functions; `CompressString` defaults to Deflate.
- `ChatFrameUtil.AddMessageEventFilter` (in `Blizzard_ChatFrameBase`). `ChatFrame_AddMessageEventFilter` is only an
  alias in `Blizzard_DeprecatedChatInfo`.

The export lives in the game folder (`_forever_/BlizzardInterfaceCode`); grep it for signatures before relying on
an API.

## R1. Built now, verified after launch

- **Decision**: as in part 1 (`specs/002-local-catch-db/research.md` R1): the exchange is built before the game opens
  on 2026-11-04, every behaviour only the game shows is marked `-- VERIFY(Vn)` (V10-V17, numbered after part 1's
  V1-V9 because the markers share the code), `npm run check` lists them and the release build refuses them. The
  temporary `/okf spike` (`Spike.lua`) gets a network section (R12), so one game session on launch day closes the
  part 1 and the part 2 questions. A second player (a friend or a second account) is needed for the exchange steps.
- **Rationale**: Principle IV; the author wants the work to go ahead now (memory of 2026-10-29).
- **Alternatives rejected**: waiting for launch; a spike release of its own.

## R2. Transport: addon messages, Battle.net game data, no channel

- **Decision**: every message goes through `C_ChatInfo.SendAddonMessage(prefix, text, chatType, target)` for
  `GUILD`, `PARTY`, `RAID` and `WHISPER`, and through `C_BattleNet.SendGameData(gameAccountID, prefix, text)` for
  Battle.net friends. Prefix `OKF1` (the digit is the protocol version), registered with
  `C_ChatInfo.RegisterAddonMessagePrefix` at load. Received through `CHAT_MSG_ADDON` (prefix, text, channel,
  sender, ...) and `BN_CHAT_MSG_ADDON` (prefix, text, channel, senderID = gameAccountID).
  - Broadcasts (`HELLO` only) go to `GUILD` when `IsInGuild()` and to `RAID` or `PARTY` when
    `IsInGroup(LE_PARTY_CATEGORY_HOME)` (`IsInRaid()` picks which). The instance group category is never used:
    the exchange pauses in instances (R8).
  - Sessions go by `WHISPER` to the sender name `CHAT_MSG_ADDON` gave (used as it is, `Name-Realm`), or by
    `SendGameData` to the Battle.net game account.
  - Both functions return `Enum.SendAddonMessageResult` (Success 0, InvalidPrefix 1, InvalidMessage 2,
    AddonMessageThrottle 3, InvalidChatType 4, NotInGroup 5, TargetRequired 6, InvalidChannel 7, ChannelThrottle 8,
    GeneralError 9, NotInGuild 10, AddOnMessageLockdown 11, TargetOffline 12); every result is read (R7).
- **Rationale**: these are the only in-game paths between players (Principle I: no traffic outside the game). The
  deprecated globals `BNSendGameData` and `ChatFrame_AddMessageEventFilter` exist in Forever only behind the
  `loadDeprecationFallbacks` CVar and drop the result code, so the namespaced functions are used.
- **Alternatives rejected**: the hidden public channel (`CHANNEL`): part 3, after the spike confirms it;
  whispering Battle.net friends by character name (a friend on another Forever mode may not be reachable by name,
  and the name is not needed when the game account ID is).

## R3. Finding peers

- **Decision**: a client announces itself with `HELLO` and learns peers from the `HELLO`s it hears; the sender of a
  `HELLO` becomes a peer, addressed `w:<sender>` or `b:<gameAccountID>`.
  - Guild and group: `HELLO` broadcast 60-120 s after the login (once the notice is closed), then every 10-15 min
    (random), and 5-30 s after the player joins a group or a new member joins it (`GROUP_ROSTER_UPDATE`, at most
    once per 2 min).
  - Character friends: `C_FriendList.GetNumFriends` / `GetFriendInfoByIndex(i)`; a `HELLO` by `WHISPER` to each
    friend with `connected = true`, with the regular round.
  - Battle.net friends: `BNGetNumFriends`, `C_BattleNet.GetFriendNumGameAccounts(i)` and
    `C_BattleNet.GetFriendGameAccountInfo(i, j)`; a `HELLO` by `SendGameData` to each game account with `isOnline`,
    `clientProgram == BNET_CLIENT_WOW` and `wowProjectID == WOW_PROJECT_ID` (how the Forever friends frame itself
    tells "the same game").
  - Friends per round: at most 20 `HELLO`s by whisper and Battle.net together. Friends already known as peers this
    session come first (they run the addon, so the `HELLO` keeps the exchange going); the rest follow in turn from a
    cursor that moves on each round, so with up to about 40 friends online each is greeted within two rounds (about
    30 minutes, SC-002). Battle.net friends are mutual, so either side's rotation finds the other.
  - A friend without the addon never registered the prefix, so the message is dropped by the game without a trace.
  - `HELLO` carries a random 4-character node tag made at every login, so one client heard by two paths (a guild
    member who is also a Battle.net friend) is one peer for the session limits, and the client ignores its own
    broadcasts echoing back.
  - `HELLO` never carries the anonymous ID: the receiver sees the sender's name, so an ID in `HELLO` would tie the
    two together.
- **Rationale**: a whisper needs a name, so discovery has to come first; guild and group have broadcast types,
  friends do not, so they are greeted one by one. Peers live in memory only (FR-009).
- **Alternatives rejected**: greeting every guild member by whisper (the roster can be hundreds: needless traffic);
  greeting every online friend each round (a long friends list would spend the budget on friends without the
  addon); a persistent peer list (it would store names).

## R4. Encoding: the game's own `C_EncodingUtil`, no libraries

- **Decision**: a record travels as `C_EncodingUtil.SerializeCBOR(record)`, then
  `C_EncodingUtil.CompressString(cbor, Enum.CompressionMethod.Deflate)`, then
  `C_EncodingUtil.EncodeBase64(...)`; the receiver reverses it with `DecodeBase64`, `DecompressString`,
  `DeserializeCBOR`, each in `pcall`, and then validates the table (R6). All ten functions are in the Forever dump
  (`EncodingUtilDocumentation.lua`). Base64 has no NUL byte and no framing character, so it is safe in addon
  messages. `tests/wow.lua` gets fakes: a deterministic Lua serializer for the CBOR pair, identity for the
  compression pair and a real Lua Base64, so the protocol is tested end to end in fengari; the real encoding is
  checked by the spike (V15).
- **Rationale**: native code is fast (no per-frame cost of a Lua compressor: LibDeflate compresses 132 KB in 68-189
  ms in Lua 5.1), adds nothing to the package, and needs no `Libs/` exceptions in `npm run check` (Principle VI).
- **Alternatives rejected**:
  - AceComm-3.0 + ChatThrottleLib + LibSerialize + LibDeflate (the plan's first idea): four vendored libraries;
    AceComm has no Battle.net path; ChatThrottleLib drops a message on `AddOnMessageLockdown` (a lost part leaves
    AceComm's spool incomplete); LibDeflate's header holds packager keywords and LibSerialize a non-ASCII name,
    both forbidden by `npm run check`; ChatThrottleLib needs `securecallfunction`, `hooksecurefunc` and
    `GetFramerate` fakes.
  - An own text format for records: more code to write and test than the native pair, kept as the fallback if V15
    fails.

## R5. Sync protocol and hashes

- **Decision**: the plan's anti-entropy session, with the details fixed in
  [contracts/sync-protocol.md](contracts/sync-protocol.md): `HELLO` (node tag, seed epoch, record count,
  whole-database hash), then by whisper `SUM` (32 bucket hashes), `DIFF` (the `id.epoch.seq` entries of the buckets
  that differ), `WANT` (the `id@epoch` units wanted), `REC` (records), `BYE` (end or refusal). Only the hearer of a
  `HELLO` starts a session; the responder takes one session at a time and answers others `BYE busy`.
  - Version: only the prefix (`OKF1`) carries it. A client registers just its own prefix, so messages of another
    version never reach it (FR-007); a breaking change takes a new digit. No version field is needed in `HELLO`.
  - Two clients that hear each other may send `SUM` to each other at the same moment. A client that receives a
    `SUM` from the peer it is waiting on compares node tags: the smaller tag keeps the initiator role and drops the
    other's `SUM` without an answer; the larger one drops its own session and answers as the responder. Equal tags
    (one chance in about a million): both drop and try again after the next `HELLO`. Without this rule both would
    answer `BYE busy` and could miss each other on every round.
  - Hash: a 32-bit polynomial hash over the sorted `id.epoch.seq` lines of a bucket, computed with plain arithmetic
    modulo the prime 4294967291 (no `bit` library: the client has one, fengari does not, and the hash must be the
    same in both). The whole-database hash is the same hash over the 32 bucket hashes. Cached per bucket.
  - Seed epochs: no epoch gate. A unit the receiver's seed already absorbed is simply not wanted (R6), so clients
    with different releases still exchange everything both count.
- **Rationale**: when two databases are equal the session ends after `HELLO` (no session at all) or `SUM` + `BYE`;
  otherwise only the differing buckets and the missing records move.
- **Alternatives rejected**: sending every record on every meeting (traffic); per-map record pages with their own
  `seq` (smaller resends for very active fishers, but a bigger inventory and a reshaped record; left for part 3 if
  traffic demands it); the plan's "same or compatible epoch (E or E±1)" rule (not needed with the absorbed check).

## R6. Accepting and keeping a record

- **Decision**: `CatchDB.CheckRecord(record)` mirrors the harvest's `checkRecord` (part 1 data model, "Validation"):
  the cell rules (`c + m <= t`, item catches within the catches, pieces at most 20 per catch, positions in range,
  pool part within the totals), the place key pattern and a game version per build. Unlike the harvest it rejects
  the whole record on any bad cell (a peer's data is not cleaned up, it is refused), and also checks: `id` is 8
  base32 characters and is not `myID`; at most 1,000 places; every item ID resolves with
  `C_Item.GetItemInfoInstant` (an unknown item is a made-up item). Then `Share` keeps it per `id@epoch` when its
  `seq` is newer, unless the seed absorbed that epoch (data-model.md). A sender whose record fails is ignored until
  logout.
- **Size limit**: other records together hold at most 20,000 places (about 2 MB). Above it the record with the
  oldest `seen` goes first; `seen` is refreshed whenever a peer confirms the same version, so records still alive in
  the network stay and those of players who stopped playing go. The own record is never deleted (FR-013).
- **Rationale**: FR-011 to FR-013; the same rules as the harvest, so data a client accepts is data the next seed
  accepts. Among guild, group and friends the limit is rarely reached, so the simple order is enough.
- **Alternatives rejected**: contribution weights and outlier checks (part 3, when strangers take part); asking the
  item cache (`GetItemInfo` needs a server round trip and does not exist in Forever); the plan's eviction by new
  information (cells the seed already knows well first, rare places last): it needs per-cell comparisons with the
  seed and pays off only with strangers' data, so it moves to part 3.

## R7. Traffic budget and back-off

- **Decision**: constants in one place (`Comm.lua`), starting values from the plan:

  | What | Limit |
  | --- | --- |
  | Message size | 255 bytes, header included (R10) |
  | Pace | broadcasts (`GUILD`, `PARTY`, `RAID`) at most 1 message per 2 s; whispers and Battle.net at most 2 per s |
  | Sessions | one at a time; a new one at least 2 min after the last one started; with the same peer at most once per 10 min in a group, once per 30 min otherwise |
  | Session size | 8 KB of encoded records per direction, but always at least one record (a record encodes to at most 32 KB) |
  | Total sent | 50 KB per hour per client (SC-005), headers included; above it only `BYE` is sent |
  | Timeout | 15 s without a message from the peer: the session is dropped, the peer paused for 30 min |

  `AddonMessageThrottle` and `ChannelThrottle` put the message back and pause sending for 2 s, doubling up to 60 s;
  `AddOnMessageLockdown` pauses the exchange (R8) for 60 s, doubling up to 15 min; `TargetOffline` ends the session
  with that peer silently; `NotInGuild` and `NotInGroup` drop the message (the player just left); any other failure
  drops the message and counts against its path. Five refusals in a row on one path (`guild`, `group`, `whisper`,
  `bnet`) leave that path out until logout; a success resets the count. When every path is left out, the exchange
  is unavailable until logout and the status says so (a Trial or Veteran account cannot send addon data; a path
  that does not work in Forever, V10, V13).
- **Rationale**: the game allows 10 messages per prefix with 1 more per second, whispers outside instances
  unthrottled (Retail rules, V10); the pace stays far below that and far below what could disconnect a client.
- **Alternatives rejected**: ChatThrottleLib (R4); no pacing at all (a session could hit the throttle at once).

## R8. When the exchange pauses

- **Decision**: the exchange sends nothing and drops incoming messages while any of these holds:
  `InCombatLockdown()`; `IsInInstance()`; a loading screen (`LOADING_SCREEN_ENABLED` to `..._DISABLED`);
  `C_RestrictedActions.IsAddOnRestrictionActive(t)` for `Chat`, `Encounter`, `ChallengeMode` or `PvPMatch`
  (`Enum.AddOnRestrictionType`); `C_ChatInfo.InChatMessagingLockdown()`;
  `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()`; a lockdown back-off (R7). It re-checks on
  `PLAYER_REGEN_ENABLED`, `LOADING_SCREEN_DISABLED`, `ZONE_CHANGED_NEW_AREA` and `ADDON_RESTRICTION_STATE_CHANGED`,
  and every 5 s while paused. A session running when a pause starts is dropped without a message (the peer times
  out); nothing was merged half-way, because a record is merged only whole.
- **Rationale**: FR-002 and the Midnight-level restrictions Forever has; incoming data is not worth handling in
  combat either.
- **Alternatives rejected**: queueing outgoing messages through a pause (stale sessions; the peer times out anyway).

## R9. "N catches from K players"

- **Decision**: `CatchDB.Query` adds `players` to a view, counting each contribution at most once: for the records,
  the exact number of records with at least one summed cell (own included); for the seed, the cell's `k` at a spot
  and the largest `k` of the summed cells for the whole map (a lower bound, FR-016). The tab shows "60 catches from 3 players" in place of "60 catches" (and keeps "60 catches" under
  "Only mine").
- **Rationale**: the seed stores contributors per cell only; summing `k` over cells would count one player many
  times. The largest `k` is a lower bound and never counts anybody twice (FR-016).
- **Alternatives rejected**: a per-map contributor count in the seed (a new seed field and harvest output for a
  soft number).

## R10. Messages and framing

- **Decision**: every message is `<type><sid>` plus fields, ASCII only; a payload longer than one message is split
  into parts `<type><sid>#<msg>.<part>.<total> <chunk>` (format in the protocol contract), reassembled by part number
  (Battle.net delivery is unordered), at most 64 KB buffered per peer, an incomplete message dropped after 15 s.
- **Rationale**: one framing for both transports; no control bytes, so nothing clashes with other addons' parsing
  or with the NUL ban.

## R11. Hiding the exchange from chat

- **Decision**: addon messages never reach the chat frame (V10). The only visible trace could be the system line
  `ERR_CHAT_PLAYER_NOT_FOUND_S` ("No player named '%s' is currently playing.") after a whisper to a player who just
  went offline. A `CHAT_MSG_SYSTEM` filter registered with `ChatFrameUtil.AddMessageEventFilter` hides that line
  for names whispered in the last 10 s (V12). `CHAT_MSG_SYSTEM` is secret during chat lockdown, but the exchange is
  paused then (R8), so the filter does nothing. Friends are greeted only while `connected`.
- **Rationale**: FR-004.

## R12. Spike additions (`/okf spike`)

- **Decision**: a "Network" section in the spike report, using a test prefix `OKFSPIKE`:
  1. `RegisterAddonMessagePrefix` result; `SendAddonMessage` results to `GUILD`, `PARTY` (when grouped) and a
     `WHISPER` to the player themself, and whether each echo arrives in `CHAT_MSG_ADDON` with the sender's form
     (`Name-Realm` or `Name`, shown as a pattern, not the name).
  2. A `WHISPER` to a made-up name: the result code and whether a system line appears (the author notes it).
  3. Battle.net: the number of friends whose game account has `clientProgram`, `wowProjectID` and `isOnline` set
     the way R3 expects (counts only, no names), and the `SendGameData` result to the first such friend.
  4. The restriction state: `IsAddOnRestrictionActive` for each `Enum.AddOnRestrictionType`,
     `InChatMessagingLockdown()`, `AreOutgoingAddonChatMessagesRestricted()`, in the open world and, if possible,
     in an instance.
  5. A round trip of a sample record through the `C_EncodingUtil` chain (R4): equal after decoding, the encoded
     length, and whether the text holds only Base64 characters.
  6. `BNET_CLIENT_WOW` and `WOW_PROJECT_ID` values.
- **Rationale**: answers V10-V15; counts and patterns instead of names, because the report is pasted into the
  conversation.

## R13. Modules and testing

- **Decision**:
  - `Comm.lua` (new): the transport: prefix, framing, send queue with pace, budget, result codes and back-off,
    receiving from both events, the chat filter, the pause rule (R8). Knows nothing about records.
  - `Share.lua` (new): the protocol node: peers, `HELLO` rounds, sessions, buckets and hashes, encoding, storing
    others' records (accept, replace, absorbed cleanup, eviction), the state, `/okf share` text, the `/okf debug`
    section, the one-time popup. The node is created by `Share.NewNode(store, env)` with its clock, scheduler and
    send function injected; the game creates one node bound to `Comm`, the tests create several bound to a fake
    network, so "three clients converge" (SC-003) runs in one fengari state.
  - `CatchDB.lua`: `CheckRecord`; the "All" view takes in other records when sharing is on; `players` in views.
  - `UI/Settings.lua`: the "Shared database" subcategory page. `UI/CatchHere.lua`: the player count and the status
    line. `Commands.lua`: `share`. `Debug.lua`: the section. `Core.lua`: defaults, `ns.ShowPopup` gains an
    `onCancel` and an `onHide`.
  - Tests: `share_test.lua` (protocol, convergence of three nodes over several paths, duplicates, absorbed units,
    own ID, limits, eviction, crossing `SUM`s, pauses, setting off; and the game node through `load_addon`: the
    `HELLO` triggers, the friend rotation, the pause messages, no names in saved data), `comm_test.lua` (framing,
    reassembly out of order, pace, budget, back-off, result codes, refused paths, chat filter), extended `catchdb_test.lua` (CheckRecord, views with others, players) and
    `catchhere_test.lua`; `tests/wow.lua` gains the addon message, Battle.net, friends, restriction and
    `C_EncodingUtil` fakes; `harvest_test.mjs` gains an author file holding other players' records (US4).
- **Rationale**: Principle VI (one job per module) and Principle V (the protocol is logic that can run without the
  game).
- **Alternatives rejected**: two addon instances in one fengari state (the addon uses globals: saved variables,
  frames, slash commands); one big `Share.lua` with the transport inside (untestable without the game globals).
