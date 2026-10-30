---

description: "Task list for the Catch Data Exchange in the Guild, the Group and with Friends"
---

# Tasks: Catch Data Exchange in the Guild, the Group and with Friends

**Input**: Design documents from `specs/003-guild-group-sync/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md),
[verification.md](verification.md); the part 1 code of `specs/002-local-catch-db/` (CatchDB, seed, harvest, tabs).

**Tests**: Included. The constitution (Principle V) requires tests for logic that runs without the game. Tests come
first in each phase and must fail before the implementation.

**Organization**: Tasks are grouped by user story:

| Story | What the player gets | Priority |
| --- | --- | --- |
| US1 | See the catches of the people I fish with | P1 |
| US2 | Know what is shared and switch it off | P2 |
| US3 | Check the state of the exchange | P3 |
| US4 | Network data reaches the next release | P4 |

**Verification debt**: the game opens on 2026-11-04.
- Phases 1 to 7 are done before that, on the assumptions V10-V18 of [verification.md](verification.md).
- Every line of code that relies on one of them carries `-- VERIFY(Vn): <what>`.
- Phase 8 runs after launch, together with the debt of the other parts.

**Branch and release**: all shared-db work stays on `002-shared-db` (no branch per spec). Release 1.2.0 ships all
four parts together, once the debt of all of them is closed (`docs/shared-db-plan.md` "Release 1.2.0"). Release
1.1.0 is the interface-language feature, released from `001-interface-language` on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story the task belongs to
- Paths are relative to the repository root; addon files are under `OneKeyFishing/`.
- After every task, run `npm run check` and `npm test` (project rule).
- A new WoW API global goes into `.luacheckrc` `read_globals` in the same task that first uses it. The check also
  fails on unused globals, so a stub-only global waits for its first use.
- A new English text goes into `OneKeyFishing/Locales/enUS.lua` and all nine translations in the same task. Keys
  are literal, color codes stay outside the strings, and no `L[...]` lookup runs at file load. `npm test` checks
  completeness and placeholder order.
- Lua stays 5.1/5.3-neutral: no `bit`, no `//`, no `goto`, no integer division assumptions.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: test fakes for every new API and the launch-day spike questions.

- [X] T001 In `tests/wow.lua`, add the fakes below. Each is driven by globals the tests set; document each global in
  the header comment and reset all of them in the existing per-test reset.

  **Addon messages**
  - `C_ChatInfo.RegisterAddonMessagePrefix(prefix)`: records the prefix in `addon_prefixes`, returns 0.
  - `C_ChatInfo.SendAddonMessage(prefix, text, chatType, target)`: appends
    `{ prefix, text, chatType, target, at = GetTime() }` to `addon_sent`. It returns
    `addon_send_result[chatType]` if set, else `addon_send_result.default`, else 0. It errors if `#text > 255` or
    `text` holds `"\0"`.
  - `C_ChatInfo.InChatMessagingLockdown()` returns `chat_lockdown` (default false).
  - `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()` returns `addon_chat_restricted` (default false).

  **Battle.net**
  - `C_BattleNet.SendGameData(gameAccountID, prefix, text)`: appends to `bn_sent`, returns
    `bn_send_result or 0`.
  - `BNGetNumFriends()` returns `#bn_friends`.
  - `C_BattleNet.GetFriendNumGameAccounts(i)` returns `#bn_friends[i]`.
  - `C_BattleNet.GetFriendGameAccountInfo(i, j)` returns `bn_friends[i][j]`, a table with `gameAccountID`,
    `clientProgram`, `wowProjectID`, `isOnline`.
  - Globals: `BNET_CLIENT_WOW = "WoW"`, `WOW_PROJECT_ID = 18`.

  **Friends, guild and group**
  - `C_FriendList.GetNumFriends()` returns `#friends`.
  - `C_FriendList.GetFriendInfoByIndex(i)` returns `friends[i]` (`{ name, connected }`).
  - `IsInGuild()` returns `in_guild`.
  - `IsInGroup()` returns `group_type ~= nil`; `IsInRaid()` returns `group_type == "raid"`.
  - `IsInInstance()` returns `in_instance, in_instance and "party" or "none"`.

  **Restrictions**
  - `C_RestrictedActions.IsAddOnRestrictionActive(t)` returns `restrictions[t] == true`.
  - `Enum.AddOnRestrictionType`: `{ Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4,
    Chat = 5 }`.
  - `Enum.SendAddonMessageResult`: the 13 values of research R2.

  **Encoding**
  - `C_EncodingUtil.SerializeCBOR` / `DeserializeCBOR`: a deterministic Lua serializer of nested tables of strings,
    numbers and booleans, with keys sorted.
  - `CompressString` / `DecompressString`: identity.
  - `EncodeBase64` / `DecodeBase64`: a real Lua Base64 with the standard alphabet. Decode returns nil on a bad
    character.
  - `Enum.CompressionMethod = { Deflate = 0, Zlib = 1, Gzip = 2 }`.

  **Chat filter**
  - `ChatFrameUtil.AddMessageEventFilter(event, fn)` records `fn` in `chat_filters[event]`.
  - Helper `filter_hides(event, text)` runs the filters and returns true when one returns true.

  **Receive helpers**
  - `receive_addon(prefix, text, channel, sender)` fires `CHAT_MSG_ADDON` with that payload.
  - `receive_bn(prefix, text, gameAccountID)` fires `BN_CHAT_MSG_ADDON` with `prefix, text, "WHISPER",
    gameAccountID`.
- [X] T002 [P] In `OneKeyFishing/Spike.lua`, add a "Network (V10-V15)" section to `BuildReport()` (research R12).
  Use the test prefix `OKFSPIKE`, registered on the first report. Collect echoes in a `CHAT_MSG_ADDON` /
  `BN_CHAT_MSG_ADDON` handler wrapped in the file's `Safe(...)`. Every call is guarded with `pcall` and a nil check,
  and the section prints no names.
  - The `RegisterAddonMessagePrefix` result.
  - The `SendAddonMessage` result for `GUILD` (when `IsInGuild()`), for `PARTY` / `RAID` (when grouped) and for
    `WHISPER` to `UnitName("player")`. For each echo received since the last report: its channel and the sender
    shape (`"Name-Realm"` when it contains `-`, else `"Name"`).
  - The result of a `WHISPER` to the made-up name `"Okfspikenobody"`. The report adds the line "check the chat for a
    'No player named' line".
  - Battle.net friends: the count of game accounts with `isOnline`, the count of those with
    `clientProgram == BNET_CLIENT_WOW`, and the count of those with `wowProjectID == WOW_PROJECT_ID`. Also the
    `C_BattleNet.SendGameData` result to the first matching game account, with "none" when there is no such
    account.
  - For each name in `Enum.AddOnRestrictionType`, `IsAddOnRestrictionActive`. Also `InChatMessagingLockdown()` and
    `AreOutgoingAddonChatMessagesRestricted()`.
  - A `C_EncodingUtil` round trip of `{ id = "abcdefgh", epoch = 1, seq = 2, builds = { ["1.60.1"] = {
    ["1415:3:47"] = { c = 3, m = 1, t = 40, px = 1500, py = 900, i = { [6291] = { 2, 3 } } } } } }` through the
    chain of research R4. Print equal / not equal (a deep compare), the encoded length, and whether the text matches
    `^[A-Za-z0-9+/=]*$`.
  - The values of `BNET_CLIENT_WOW` and `WOW_PROJECT_ID`.

  Every API global it uses goes into `.luacheckrc`. Extend `tests/spike_test.lua`: the report has the section, the
  round trip line says equal with the fakes, and a forced `SendAddonMessage` error shows the failure line, not a Lua
  error.

**Checkpoint**: the fakes exist; `/okf spike` asks every V10-V15 question.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the saved fields, record validation, the store of other players' records and the hashes that every
story builds on.

**CRITICAL**: no user story work can begin until this phase is complete.

- [X] T003 [P] In `OneKeyFishing/Core.lua`, add `settings.shareDB = true` and the top-level `shareNotice = false` to
  `DB_DEFAULTS`, each with a short comment (data-model.md). `DB_SCHEMA` stays 1. Change the shared records comment
  to "contribution ID (own) or `<id>@<epoch>` (others) -> record".

  Extend `ns.ShowPopup(key, text, onAccept, acceptText, cancelText)` with two optional arguments,
  `onCancel, onHide`, passed to the `StaticPopupDialogs` entry as `OnCancel` / `OnHide`.

  Extend `tests/core_test.lua`:
  - an old saved table gets `shareDB = true` and `shareNotice = false` without other changes;
  - `onCancel` runs on `cancel_popup()`;
  - `onHide` runs on both buttons.

  If the stub `StaticPopup_Hide` / `accept_popup` does not call `OnHide`, make it do so in `tests/wow.lua`.
- [X] T004 [P] Write the failing tests for `CatchDB.CheckRecord` in `tests/catchdb_test.lua` (research R6,
  contracts/share-api.md). `CheckRecord` accepts a valid record of two builds and three cells. It rejects, with a
  reason:
  - an `id` not matching `^[a-z2-7]{8}$` (the own ID is refused by `Share.Store.Accept`, T006);
  - a non-count `epoch` or `seq`, or a `seq` above the record's casts (`c + m` over all cells);
  - a build not `^%d+%.%d+%.%d+$`;
  - a place key not `^%d+:[0-4]:(%d%d|x)$`;
  - `c + m > t`;
  - an item with more catches than `c`, with pieces below its catches, or with pieces above `20 *` its catches;
  - only one of `px` / `py`, or `px > 1000 * (c + m)`;
  - a pool part with `p.c > c`;
  - more than 1,000 places over all builds;
  - an item ID for which `C_Item.GetItemInfoInstant` returns nil (set the stub to know only some IDs); then a third
    value `true` says the unknown item was the only fault.

  A record with one bad cell is rejected whole; unlike the harvest, cells are not skipped.
- [X] T005 Implement `CatchDB.CheckRecord(record)` in `OneKeyFishing/CatchDB.lua`. It returns `true` or
  `false, reason` (plus `true` when only an unknown item failed), with no side effects, and checks exactly the
  rules of T004. Use the existing `MAX_PIECES` and `ID_CHARS` constants and a new `MAX_RECORD_PLACES = 1000`.
  Comment that it mirrors `checkRecord` / `checkCell` in `tools/harvest.mjs`, but rejects the whole record.
- [X] T006 [P] Write the failing store tests in a new `tests/share_store_test.lua`, using `load_addon()` and
  `ns.Share.Store` (T007), against `ns.db.shared`:
  - **Accept:** a valid record is stored under `"<id>@<epoch>"` with `seen = time()`.
  - **Replace:** the same unit with a higher `seq` replaces it; an equal `seq` only refreshes `seen`; a lower `seq` is
    ignored.
  - **Other epoch:** a record of another epoch of the same ID is stored next to it.
  - **Own ID:** a record with `id == myID` is refused.
  - **Absorbed:** a version with `seq <= ns.SeedData.absorbed[id][epoch]` (the seed holds it whole) is refused. A
    stored one is deleted by `Store.CleanUp()`, which runs at login; a newer version (held in part) is kept.
  - **Eviction:** with other records holding more than 20,000 places together, `Store.Evict()` deletes the oldest
    `seen` first until they fit, and never the own record.
  - **Change message:** every change fires `SHARED_DATA_CHANGED` once, with the changed keys.
- [X] T007 Create `OneKeyFishing/Share.lua`, listed in `OneKeyFishing/OneKeyFishing.toc` after `CatchDB.lua`
  (leave room for `Comm.lua` before it, T013). Start it with a header comment on its job (contracts/share-api.md)
  and add `ns.Share = Share` and `Share.Store`, whose functions take the `shared` table:
  - `Accept(store, record, now, absorbed)`: returns `"new" | "newer" | "same" | "older"`, or `"refused"` with the
    reason (and `true` when only an unknown item failed), and runs the rules of data-model.md "Rules for other
    players' records": the own ID first, then `ns.CatchDB.CheckRecord` and the seed's `absorbed`.
  - `CleanUp(store, absorbed)` and `Evict(store)` (`MAX_OTHER_PLACES = 20000`).
  - `Units(store, absorbed)` returns every `id@epoch` held with its `seq`, the own record included when it has cells
    of a game version, and versions the seed holds whole left out.
  - `Get(store, unit)` returns the record for a unit.

  A change fires `ns.Fire("SHARED_DATA_CHANGED", keys)`. On `ADDON_LOADED`, after `CatchDB`'s own handler, run
  `CleanUp` and `Evict`. `Store.ForSending(record)` strips `seen` from a record before it is sent.
- [X] T008 Write the failing hash tests in `tests/share_store_test.lua` (after T006, same file):
  - `Share.Hash(text)` is a 32-bit value equal to a fixed expected number for a fixed input, computed by hand from
    the rule;
  - `ns.Base32(value, 7)` (Data.lua) gives 7 characters;
  - `Share.Buckets(units)` puts each unit in the bucket of the first character of its ID;
  - the bucket hashes and the whole hash do not depend on insertion order;
  - a change of one `seq` changes exactly one bucket hash and the whole hash.
- [X] T009 Implement the hashes in `OneKeyFishing/Share.lua` (research R5):
  - `Hash(text)`: `h = (h * 31 + byte) % 4294967291`, starting at 5381, plain arithmetic, no `bit`. Comment why: the
    hash must agree between the client and fengari.
  - `ns.Base32(value, width)` in `Data.lua`, with the base32 alphabet of the IDs (`ns.BASE32`).
  - `Buckets(units)` returns the 32 lists of sorted `id.epoch.seq` lines.
  - `BucketHashes(buckets)` (the 7-character texts `SUM` sends) and `WholeHash(hashTexts)`.
  - A node's summary (units, buckets, hashes) cached whole and rebuilt after `SHARED_DATA_CHANGED` or a change of
    the own record's `seq` (compare the last seen `seq`).

**Checkpoint**: other records can be checked, stored, evicted and hashed; nothing is sent yet.

---

## Phase 3: User Story 1 - See the catches of the people I fish with (Priority: P1) 🎯 MVP

**Goal**: clients in one guild, group or friends list find each other and exchange records in the background,
invisibly. "What can be caught here" counts the others' catches and says from how many players.

**Independent Test**: in `tests/share_protocol_test.lua`, three nodes reach each other over guild, group, whisper and
Battle.net paths, and end with the same records and counts. In game (quickstart.md, feature steps 2, 3 and 7), two
or three players see each other's catches, and nothing shows in chat.

### Tests for User Story 1

- [X] T010 [P] [US1] Write the failing transport tests in a new `tests/comm_test.lua`, using the T001 fakes and
  `advance` (contracts/sync-protocol.md, research R7, R8, R10, R11):
  - **Framing:** a 600-byte message to `w:Other-Realm` becomes parts `<type><sid>#<msg>.<part>.<total> <chunk>`,
    each at most 255 bytes. Fed back through `receive_addon` in reverse order, they reach `Comm.OnReceive`
    handlers once, whole. Parts never completed are dropped after 15 s. More than 64 KB of parts from one sender is
    dropped.
  - **Pace:** two broadcasts are 2 s apart in `addon_sent`; whispers go at most 2 per second.
  - **Budget:** after 50 KB in 60 minutes `Comm.CanSend()` is false. It turns true again as the minutes roll out.
  - **Throttle results:** result 3 or 8 re-queues the message and waits 2 s, then 4 s, then 8 s at most (under the
    15 s session and part timeouts; the cap was 60 s until the review of 2026-10-30).
  - **Lockdown result:** result 11 makes `Comm.GetPause()` return `"lockdown"` for 60 s, doubling to 15 min while it
    repeats.
  - **Offline result:** result 12 reports the address to the handler registered with `Comm.OnOffline`.
  - **Pause reasons:** `GetPause()` is `"combat"` with `in_combat`, `"instance"` with `in_instance`, `"loading"`
    between `LOADING_SCREEN_ENABLED` and `_DISABLED`, and `"restricted"` with `restrictions[5]` (`Chat`), the `Map`
    restriction or `chat_lockdown`; `addon_chat_restricted` (true on every normal realm) pauses nothing. While paused
    nothing is sent and incoming messages are dropped.
  - **Friends:** `Comm.ForEachFriend` lists only connected character friends, and Battle.net game accounts that are
    online, on `BNET_CLIENT_WOW` and on `WOW_PROJECT_ID`.
  - **Broadcast:** `Comm.Broadcast` goes to `GUILD` only when `in_guild`, and to `RAID` or `PARTY` by `group_type`.
  - **Chat filter:** `filter_hides("CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Other"))` is true within
    10 s of a whisper to `w:Other` and false after that.
  - **Validation:** a message with another prefix, or with a `"\0"`, is ignored.
  - **Refused paths** (contracts/sync-protocol.md "Paths the game refuses"): five results of 9 (`GeneralError`) in a
    row on `WHISPER` leave the `whisper` path out (`Comm.GetPaths().whisper.disabled`), and later sends to `w:`
    addresses are dropped. A success in between resets the count. Results 3, 8, 10, 11 and 12 never count, nor
    does a refused greeting (a `HELLO` to a friend). With all four paths left out, `GetPause()` is `"unavailable"`
    and stays so.
- [X] T011 [P] [US1] Write the failing protocol tests in `tests/share_protocol_test.lua`, with three or more nodes from
  `Share.NewNode(store, env)` on separate store tables and a fake network in the test. The network routes `send` /
  `broadcast` between nodes through `C_Timer.After(0.1, ...)` and lets a test cut a path or reorder deliveries
  (contracts/sync-protocol.md "A session").
  - **Convergence:** after `advance` past the `HELLO` and session delays, the three nodes, each starting with its
    own record and joined guild-only, group-only and by Battle.net, hold the same units with the same `seq`
    (SC-003).
  - **Relay:** a record of C that reaches B by two paths is stored once. C's record reaches B through A (FR-003).
  - **No redundant session:** equal databases start no session after `HELLO` (same hash). With a single differing
    bucket only its units are sent in `DIFF`.
  - **Busy:** a second hearer of the same `HELLO` gets `BYE busy` while A is in a session.
  - **Cooldowns:** no second session with the same peer within 10 min in a group, or within 30 min otherwise. A new
    session starts at least 2 min after the last one started.
  - **Session size:** more than 8 KB of wanted records is split over two sessions, and one record larger than 8 KB
    still goes.
  - **Timeout:** no reply for 15 s drops the session and pauses the peer for 30 min.
  - **Rejects:** a `REC` that was not wanted, or that fails `CheckRecord` (not only for an item this client does
    not know), makes the sender ignored until logout. More than 1 `HELLO` per 60 s, 1,160 message units per hour
    or 175 records per hour from one sender (`Share.MESSAGE_LIMIT`, `Share.RECORD_LIMIT`, derived from
    `Comm.BUDGET` and the session limits) is handled as contracts/sync-protocol.md says.
  - **Echo:** a node ignores its own `HELLO` echo (same node tag). `HELLO` never contains `myID`.
  - **Merge pace:** received records are merged at most one per frame step (`C_Timer.After(0, ...)`).
  - **Pause:** `node:Pause("combat")` mid-session sends nothing more; the peer side times out.
  - **Crossing `SUM`s:** two nodes that hear each other's `HELLO` and both send `SUM` end with one session, led by
    the node with the smaller tag, and converge. With forced equal tags, both drop their sessions and converge after
    the next `HELLO`.
  - **Friend rotation:** with 50 online friends (`friends` and `bn_friends`) of which 2 are known peers, a `HELLO`
    round greets the 2 known peers plus 18 others. The next rounds continue from the cursor, so all are greeted
    within 3 rounds.

  **Game node** (in `tests/share_game_test.lua`, through `load_addon()` with `shareNotice = true`, the T001 fakes
  and `advance`; these fail until T015):
  - the first `HELLO` goes to `GUILD` 60-120 s after login when `in_guild`;
  - after `group_type = "party"` and `GROUP_ROSTER_UPDATE`, a `HELLO` goes to `PARTY` within 30 s, and a second
    roster event within 2 min sends no extra one;
  - `SHARE_PAUSE` with `"combat"` stops sends, and `SHARE_PAUSE` with nil resumes them;
  - a session with a fake peer `w:Peer-Realm` (fed through `receive_addon`) leaves no string containing `"Peer"`
    anywhere in `OneKeyFishingDB` or `OneKeyFishingCharDB` (walk the tables, FR-009);
  - a full exchange with the fake peer, from its `HELLO` to its record counted in `CatchDB.Query`, finishes within
    5 simulated minutes of the group join (SC-001).
- [X] T012 [P] [US1] Write the failing view tests in `tests/catchdb_test.lua` (research R9, data-model.md "Views"):
  - With `settings.shareDB` true, source "All" sums the seed, the own record and every stored other record. With it
    false, the others are left out.
  - The part 1 reset rule applies to other records' builds too.
  - `players` counts each record ID with a summed cell of catches (own included) once, next to `k` of the seed cell
    at a spot, or the largest `k` of the summed seed cells for the whole map; an ID the seed absorbed counts only
    above that `k`.
  - The cached view changes after `SHARED_DATA_CHANGED` and after switching `shareDB`.

### Implementation for User Story 1

- [X] T013 [US1] Create `OneKeyFishing/Comm.lua`, listed in `OneKeyFishing/OneKeyFishing.toc` after `CatchDB.lua`
  and before `Share.lua`. Implement contracts/share-api.md "`ns.Comm`", until T010 passes.
  - **Setup:** prefix `"OKF1"`, registered at load. Constants in one block at the top:
    | Constant | Value |
    | --- | --- |
    | Message limit | 255 bytes |
    | Broadcast pace | 2 s |
    | Whisper pace | 0.5 s |
    | Budget | 50 KB per 60 min, counted per minute |
    | Throttle back-off | 2 s to 8 s |
    | Lockdown back-off | 60 s to 15 min |
    | Part timeout | 15 s |
    | Part buffer | 64 KB per sender |
    | Filter window | 10 s |
  - **Sending:** one queue, drained by `C_Timer.After` runs scheduled only while the queue is not empty.
  - **Receiving:** `CHAT_MSG_ADDON` and `BN_CHAT_MSG_ADDON`, joined into whole messages for `Comm.OnReceive`
    handlers.
  - **Pause rule** (research R8):
    - re-checked on `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `LOADING_SCREEN_ENABLED`,
      `LOADING_SCREEN_DISABLED`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_ENTERING_WORLD` and
      `ADDON_RESTRICTION_STATE_CHANGED` (on the next frame), and every 5 s while paused;
    - fires `ns.Fire("SHARE_PAUSE", reason)` when the reason changes (a new message, listed in CLAUDE.md, T036).
  - **Results:** every send result is read; the throttle and lockdown back-offs, `Comm.OnOffline` handlers, and the
    error counts kept for `Comm.Describe()`.
  - **Refused paths:** per-path refusal counts and `Comm.GetPaths()`. A path left out after 5 refusals in a row
    stays out until logout. With all paths out, the pause reason is `"unavailable"` (fired as `SHARE_PAUSE`) and is
    never lifted until logout.
  - **Friends:** `ForEachFriend`.
  - **Chat filter:** registered with `ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SYSTEM", ...)` when that exists.
    It compares the text with `ERR_CHAT_PLAYER_NOT_FOUND_S:format(name)` for names whispered in the last 10 s, and
    returns nothing while `issecretvalue` (when it exists) says the text is secret.
  - **Markers:** `-- VERIFY(V10)` at the send calls and the pace constants; `-- VERIFY(V11)` where the sender becomes
    an address; `-- VERIFY(V12)` at the filter and the `TargetOffline` handling; `-- VERIFY(V13)` at the Battle.net
    send and the friend test; `-- VERIFY(V14)` at the pause rule.
  - **Bookkeeping:** every new API global goes into `.luacheckrc`.
- [X] T014 [US1] Implement `Share.NewNode(store, env)` in `OneKeyFishing/Share.lua`, until T011 passes
  (contracts/sync-protocol.md, contracts/share-api.md).
  - **Peers:** the session memory of data-model.md, keyed by address. A node tag (4 base32 characters) is made per
    node.
  - **Messages:** `HELLO` / `SUM` / `DIFF` / `WANT` / `REC` / `BYE` in the exact forms of the contract.
  - **Sessions:** the initiator waits a random 2-20 s and re-checks; the responder takes one session at a time.
  - **Crossing `SUM`s:** the rule of contracts/sync-protocol.md "A session". The smaller node tag stays the
    initiator; on equal tags both drop their sessions.
  - **`HELLO` round:** `node:Hello()` broadcasts, then greets up to 20 friend addresses from `env.forEachFriend`:
    known peers first, then the others from a cursor that moves on each round (research R3).
  - **Cooldowns:** a new session at least 2 min after the last one started; with the same peer at most every 10 min
    for `via == "group"` and every 30 min otherwise.
  - **Limits:** 8 KB of encoded records per direction, at least one record, the own record first, then the newest
    `seen`; a record is at most 32 KB encoded.
  - **Timeouts and offline:** 15 s timeout; a 30 min pause for a peer that timed out or was reported offline.
  - **Sender limits:** per sender, the limits of the contract's "Limits on what is received". `ignored` lasts until
    logout.
  - **`seen` refresh:** for equal buckets and entries.
  - **Merge:** decoded records go through `env.decode`, then `Store.Accept`, one per `env.after(0, ...)` step.
  - **Unknown messages:** messages of an unknown type or form are ignored. Another protocol version never arrives:
    only `OKF1` is registered (FR-007).

  Randomness comes from `math.random`, and `env` supplies the clock and the scheduler, so tests are deterministic
  after `math.randomseed`.
- [X] T015 [US1] Bind the game node in `OneKeyFishing/Share.lua` (research R3), until the "Game node" tests of
  T011 pass.
  - **Setup:** on `PLAYER_LOGIN`, create one node over `ns.db.shared` with `env` bound to:
    - `GetTime`, `time` and `C_Timer.After`;
    - `Comm.Send`, `Comm.Broadcast`, `Comm.ForEachFriend`, `Comm.CanSend` and `Comm.IsSending`;
    - the seed's `absorbed` and epoch, `CatchDB.FlushSeq` (before the units are read for a peer) and
      `debugprofilestop` (the longest merge step); the own ID is `ns.db.shared.myID`, and the node checks records
      with `ns.CatchDB.CheckRecord` itself;
    - `encode` / `decode` = the `C_EncodingUtil` chain of research R4, each step in `pcall`, with
      `-- VERIFY(V15)`.
  - **`HELLO` rounds:** `node:Hello()` the first 60-120 s after login, then every 10-15 min (random).
  - **Extra `HELLO`:** 5-30 s after `GROUP_ROSTER_UPDATE` when the group got a member (at most once per 2 min).
  - **Pause:** on `SHARE_PAUSE` with a reason, `node:Pause`. When the pause ends, `node:Resume` and a `HELLO` after
    5-30 s if the last one is older than 10 min. `"unavailable"` never ends before logout.
  - **Gating:** the node stays paused (`"off"`) while `settings.shareDB` is false (T021 adds the notice gate).
  - **Markers:** `-- VERIFY(V16)` at the merge step.
- [X] T016 [US1] In `OneKeyFishing/CatchDB.lua`, make T012 pass:
  - `Sources("all", mapID)` adds the other players' records (`"<id>@<epoch>"`, not held in part by the seed)
    when sharing is on, through one index of their cells by place key and by map, with the reset rule per build.
  - Views gain `players` (research R9).
  - The cache key stays the map, cell, range and source: switching sharing goes through `Share.SetEnabled`, which
    fires `SHARED_DATA_CHANGED`.
  - `ns.On("SHARED_DATA_CHANGED", ...)` bumps `version` (and updates the index for the keys it names).

  Update the `catchdb-api.md` view shape in a comment above `Query`.
- [X] T017 [US1] In `OneKeyFishing/UI/CatchHere.lua`, show `L["%d catches from %d players"]` instead of
  `L["%d catches"]` when the source is "All" and `view.players` is at least 2; "Only mine" keeps `"%d catches"`.
  Add the text to `Locales/enUS.lua` and all nine translations. Extend `tests/catchhere_test.lua`: with one stored
  other record at the current spot the counts line reads "N catches from 2 players"; under "Only mine" it reads
  "N catches". With the window open, a record that arrives (`Share.Store.Accept` plus `SHARED_DATA_CHANGED`) shows
  in the counts on the next 1 s tick, without reopening (FR-018).

**Checkpoint**: in tests, several clients converge and the tab counts others' catches. US1 is usable in game once
V10-V15 hold.

---

## Phase 4: User Story 2 - Know what is shared and switch it off (Priority: P2)

**Goal**: a one-time popup explains the sharing. One setting on a "Shared database" page turns it on or off; off
means nothing sent, nothing received, and received data kept but not counted.

**Independent Test**: in the `tests/share_notice*_test.lua` files, `tests/share_game_test.lua` and
`tests/settings_test.lua`, the popup shows once, gates the
exchange, and the buttons work; the setting stops all sends and hides others' data, which comes back when it is
turned on. In game: quickstart.md, feature steps 1 and 6.

### Tests for User Story 2

- [X] T018 [P] [US2] Write the failing tests in `tests/share_notice_test.lua` (the popup),
  `tests/settings_test.lua` (its Settings button) and `tests/share_game_test.lua` (off and on again):
  - **Popup on first login:** with `shareNotice` false, after `PLAYER_ENTERING_WORLD` and the loading screen, out of
    combat, the popup is shown. Nothing is in `addon_sent` before it closes.
  - **Accept:** `accept_popup()` sets `shareNotice = true`, and a `HELLO` follows within 120 s.
  - **Settings button:** `cancel_popup()` also sets it and calls `ns.SettingsUI.OpenShare`.
  - **Once:** the popup is not shown again after a reload (`load_addon` with `shareNotice = true`).
  - **Combat:** in combat at login the popup waits for `PLAYER_REGEN_ENABLED`.
  - **Off:** `Share.SetEnabled(false)` drops a running session without a message. No message goes to
    `addon_sent` / `bn_sent` afterwards, and incoming `HELLO` and `REC` are ignored.
  - **Data while off:** `CatchDB.Query` leaves out stored others; the records stay in `ns.db.shared.records`.
  - **On again:** `SetEnabled(true)` counts them again at once and sends a `HELLO` within 30 s.
- [X] T019 [P] [US2] Write the failing settings test in a new `tests/settings_test.lua`, using `load_addon()` and
  `find_frame` / `click`:
  - a subcategory page "Shared database" is registered with a checkbox "Use the shared catch database" reflecting
    `settings.shareDB`;
  - clicking it calls `Share.SetEnabled` with the new value and fires `SETTINGS_CHANGED`;
  - the page shows the explanation text and a status line.

  Stub `Settings.RegisterCanvasLayoutSubcategory` in `tests/wow.lua` if needed.

### Implementation for User Story 2

- [X] T020 [US2] Implement `Share.IsEnabled()` / `Share.SetEnabled(on)` in `OneKeyFishing/Share.lua`. Setting the
  value means:
  - write `settings.shareDB`, and close the notice if it is still open (the page says what is shared);
  - when off, `node:Pause("off")` drops the session, and `Comm` ignores incoming messages and refuses sends while
    the setting is off (check it at the top of the queue and of the receive handler);
  - fire `SHARED_DATA_CHANGED` and `SETTINGS_CHANGED`;
  - when on, `node:Resume()` and a `HELLO` after 5-30 s.
- [X] T021 [US2] Implement the one-time popup in `OneKeyFishing/Share.lua` (contracts/share-api.md).
  - **When:** 2 s after `PLAYER_ENTERING_WORLD` or `LOADING_SCREEN_DISABLED` with `shareNotice` false and sharing
    on, out of combat (`PLAYER_REGEN_ENABLED` if needed); again after 30 s when the game had no free dialog frame.
  - **Popup:** `ns.ShowPopup("ONEKEYFISHING_SHARE_NOTICE", text, nil, L["Got it"], L["Settings"], onCancel =
    ns.SettingsUI.OpenShare, onHide = ...)`. `onHide` sets `shareNotice = true` and starts the `HELLO` rounds of
    T015 (not when the whole interface was hidden, Alt+Z).
  - **Gate:** the node does not start while `shareNotice` is false.
  - **Text:** three `L` keys joined by a space: `L["OneKeyFishing now shares your catches under a random ID with
    your guild, group and friends who use it."]`, `L["No character names are sent, but the players you exchange
    with can tell which ID is yours."]` and `L["Turn it off in Options -> AddOns -> OneKeyFishing -> Shared
    database."]`. Part 3 replaces only the first with one that also names the public channel (FR-021), so that
    change touches one key and its nine translations.

  Add the texts to `Locales/enUS.lua` and all nine translations.
- [X] T022 [US2] In `OneKeyFishing/UI/Settings.lua`, add `CreateSharePage()`, registered with
  `Settings.RegisterCanvasLayoutSubcategory(mainCategory, CreateSharePage(), L["Shared database"])`. It holds:
  - the checkbox `L["Use the shared catch database"]`, through the file's `CreateCheckbox`, calling
    `ns.Share.SetEnabled`;
  - the explanation, three keys joined by a space: `L["Your catches (items, counts, map cells, the average spot you
    fish from) are shared under a random ID."]`, `L["They go to addon users in your guild, group and friends list.
    No names or gear."]` and `L["The players you exchange with can tell which ID is yours."]`; then
    `L["Turned off: nothing is sent or received, and other players' data is not counted."]`;
  - a status line set from `ns.Share.StatusLine()` on `OnShow` and every 1 s while shown.

  Lay the page out top to bottom with room below the setting for part 3's public-channel setting (FR-019); part 3
  also extends the explanation text. Add `SettingsUI.OpenShare()` (opens that subcategory), and add the texts to
  `Locales/enUS.lua` and all nine translations.

**Checkpoint**: sharing is disclosed once and can be switched off and on in one place.

---

## Phase 5: User Story 3 - Check the state of the exchange (Priority: P3)

**Goal**: a quiet status line in the tab and on the settings page; `/okf share` with the full state; a
`/okf debug` section.

**Independent Test**: in `tests/share_game_test.lua`, `tests/commands_test.lua` and `tests/catchhere_test.lua`, the
status and texts match each state (alone, active, paused with each reason, off, notice). In game: quickstart.md, feature
steps 4, 5 and 8.

### Tests for User Story 3

- [X] T023 [P] [US3] Write the failing tests in `tests/share_game_test.lua` (and `tests/share_refused_test.lua`
  for `unavailable`) for `Share.GetStatus()` and
  `Share.StatusLine()` (contracts/share-api.md, data-model.md "State of the exchange"):
  - **States:** `off`, `notice`, `unavailable`, `paused` with each reason, `alone`, `active`, in that order of
    precedence.
  - **Counts:** `heard` per path for the last hour; `exchanged` = peers confirmed in the last hour (a finished
    session, or a `HELLO` with the same hash);
    `lastExchange`, `traffic`, `records` and `places`. Use `advance` to age entries past one hour.
  - **Status lines:**
    - "Exchange: 3 players, 5 min ago";
    - "Exchange paused: in combat" (one text per reason);
    - "Exchange unavailable: the game refuses addon messages";
    - "Shared catch database is off";
    - "Nobody to exchange with right now";
    - "Last exchange: %s ago" when a peer is heard but nobody was confirmed in the last hour.
- [X] T024 [P] [US3] Extend `tests/commands_test.lua`:
  - `/okf share` prints the localized lines of FR-022 into chat (`chat_contains`) on an English and on a German
    client;
  - `/okf` help lists `share` with the English description "show the state of the shared catch database";
  - `/okf debug` contains a "Shared database" section with the state, the counts and the traffic, and contains
    neither `myID` nor any peer name used in the test.
- [X] T025 [P] [US3] Extend `tests/catchhere_test.lua`: the tab shows `Share.StatusLine()` under the counts, and the
  line changes on the 1 s tick when the state changes, without reopening the window.

### Implementation for User Story 3

- [X] T026 [US3] Implement `Share.GetStatus()`, `Share.StatusLine()` and `Share.PrintStatus()` in
  `OneKeyFishing/Share.lua`.
  - **Status lines:** `L["Exchange: %d players, %s ago"]` (the time through the same short duration format Stats
    uses), `L["Exchange paused: in combat"]`, `L["Exchange paused: in an instance"]`,
    `L["Exchange paused: loading screen"]`, `L["Exchange paused: the game restricts addon messages here"]`,
    `L["Exchange paused: the game asked to slow down"]`,
    `L["Exchange unavailable: the game refuses addon messages"]`, `L["Shared catch database is off"]`,
    `L["Nobody to exchange with right now"]`, `L["Waiting for you to read the notice"]`,
    `L["Last exchange: %s ago"]` (nobody confirmed in the last hour) and
    `L["Exchange: waiting for the first exchange"]` (active, nothing confirmed yet).
  - **`PrintStatus()`:** prints the seed epoch and places, records held and their places, peers heard per path,
    peers exchanged with, the last exchange, the traffic of the last hour in KB, and the state line, through
    `ns.Print` with `L` texts.

  Add every text to `Locales/enUS.lua` and all nine translations.
- [X] T027 [US3] In `OneKeyFishing/Commands.lua`, add `{ name = "share", description = "show the state of the shared
  catch database", run = function() ns.Share.PrintStatus() end }` in name order.
- [X] T028 [US3] Add `Share.Describe()` in `OneKeyFishing/Share.lua` and `Comm.Describe()` in
  `OneKeyFishing/Comm.lua`. They return English lines with no names and no IDs: state and reason, records and
  places, peers heard per path and exchanged, last exchange age, traffic, queue length, result code counts, rejected
  senders count, back-off, the paths left out, and the longest merge step in ms (`debugprofilestop`, SC-006: under
  5 ms). In `OneKeyFishing/Debug.lua`, add
  a "Shared database" section from both.
- [X] T029 [US3] In `OneKeyFishing/UI/CatchHere.lua`, add a status text below the hint showing
  `ns.Share.StatusLine()`, refreshed on the existing 1 s tick when the line changed.

**Checkpoint**: the state of the exchange is visible in the tab, on the page, in `/okf share` and in bug reports.

---

## Phase 6: User Story 4 - Network data reaches the next release (Priority: P4)

**Goal**: the author's harvest bundles other players' records it received, each once, and clients that update
stop counting their network copies.

**Independent Test**: in `tests/harvest_test.mjs`, an author file with other players' records yields one seed with
each contribution once. In `tests/share_absorbed_test.lua`, after the seed absorbs those units, the counts do not
change and re-sent copies are refused. In game: quickstart.md, feature step 10.

### Tests for User Story 4

- [X] T030 [P] [US4] Extend `tests/harvest_test.mjs`.
  - **Setup:** a fake author file holds the own record under `myID` and three other records under `"<id>@<epoch>"`,
    each with `seen`. A second file holds one of the same units with a lower `seq`.
  - **Expect:**
    - the seed has the four contributions and the newer `seq` of the duplicate;
    - `absorbed` lists all four IDs with their epochs;
    - `seen` and the table keys do not matter;
    - the report counts the contributions;
    - a second run with the same files changes nothing.
- [X] T031 [P] [US4] Add `tests/share_absorbed_test.lua`: a node holding three other units has its counts noted. Then
  `ns.SeedData` is replaced with a seed containing the same sums and `absorbed` for those IDs, and the addon is
  reloaded. Expect:
  - the stored units are deleted;
  - `CatchDB.Query` gives the same catches as before (SC-008);
  - a peer that sends one of those units again sees it not wanted (not in `WANT`) and refused if pushed.

### Implementation for User Story 4

- [X] T032 [US4] Make T030 pass in `tools/harvest.mjs` if it does not already. The keys of `shared.records` and the
  field `seen` must not matter (`checkRecord` already rebuilds `{ id, epoch, seq, builds }`). The report line counts
  contributions by `id@epoch`. Make T031 pass in `OneKeyFishing/Share.lua` (`Store.CleanUp` at login, the absorbed
  check in `WANT`) if the Phase 2 code does not already.

**Checkpoint**: the network and the releases form one loop with nothing counted twice.

---

## Phase 7: Polish & Cross-Cutting Concerns (before launch)

- [X] T033 [P] Add a load test, `tests/share_load_test.lua`.
  - **Setup:** fill the store with synthetic other records totalling 20,000 places over 200 records.
  - **Expect:**
    - `ADDON_LOADED` cleanup and eviction finish;
    - a `CatchDB.Query` for a busy map and for an empty map returns;
    - a full session's merge runs one record per frame step.

  Print the times (`os.clock`) for information without failing on them (V16 is checked in game).
- [X] T034 [P] Update `README.md` with a "Shared catch database" section: what is shared, with whom (guild, group,
  friends; part 3 adds the public channel), that no names are sent, where to turn it off, `/okf share`, and that
  Trial and Veteran accounts cannot send addon data. Add an `## [Unreleased]` entry to `CHANGELOG.md`.
- [X] T035 [P] Re-check `docs/shared-db-plan.md` against the code. Its sections and the "part 2" decisions table
  were already brought in line with this design on 2026-10-29: "Transport", "Libraries", "Traffic budget", "Size
  and eviction" and "Sync protocol". Fix any value the implementation changed: the constants in `Comm.lua` and
  `Share.lua`, the message forms, and the limits. Update `docs/ROADMAP.md` item 1 so it links to this spec.
- [X] T036 [P] Update `CLAUDE.md`:
  - **Architecture:** new **Comm.lua** and **Share.lua** entries (job, node design, pause rule, budget); the CatchDB
    entry gains "All" with others' records and `players`; UI/Settings gains the "Shared database" page; UI/CatchHere
    gains the player count and the status line.
  - **Messages:** `SHARED_DATA_CHANGED` and `SHARE_PAUSE`.
  - **`/okf share`:** mention it with `/okf debug`.
  - **Known API facts:** the dump facts and the deprecated-globals rule are already there (2026-10-29); re-check
    them against a fresh `exportInterfaceFiles code` if the client was patched since.
- [X] T037 [P] Create `docs/checklists/catch-exchange.md` from quickstart.md "In game: spike" (N1-N7) and "In game:
  the feature" (1-12). Give each step a checkbox and the V-IDs it closes, and say that a second player is needed.
  Link it from `docs/checklists/catch-database.md` "After the checklist".
- [X] T038 Run `npm run check`, `npm test` and `npm run dev`. Confirm that the only open markers are V1-V7, `spike`
  (part 1), V10-V16 and V18, each listed in a verification.md. Set the "Status" column of
  `specs/003-guild-group-sync/verification.md` to "Built, waiting for launch".

**Checkpoint**: part 2 is complete except for the in-game verification; it ships with the other parts in 1.2.0.

---

## Phase 8: After launch (2026-11-04): close the verification debt

**Blocked until the game opens.** Each task is the author's in-game step plus the follow-up in code. A second
player or a second account is needed.

- [ ] T039 Author: run `docs/checklists/catch-exchange.md` "Spike" steps N1-N7 in the same game session as the spike
  steps of the other parts, and paste the `/okf spike` reports. This must happen before
  `specs/002-local-catch-db/tasks.md` T042 removes `Spike.lua`.
- [ ] T040 Record the answers in `CLAUDE.md` "Known API facts". For each of V10-V15, either remove its markers (the
  assumption held) or change the code to the real behaviour (with tests) and then remove the markers. Tick the items
  in `specs/003-guild-group-sync/verification.md`. If V14 shows addon chat restricted in the open world, stop and
  plan a way around it with the author before anything else.
- [ ] T041 Author: run the "Feature" steps of `docs/checklists/catch-exchange.md` with a second player (closes V16,
  V17, V18); fix what fails and repeat.
- [ ] T042 Mark part 2 ready for release 1.2.0: T039-T041 done, V10-V18 ticked in
  `specs/003-guild-group-sync/verification.md`, no `VERIFY(V1x)` marker left. The release itself is one task for
  all parts, `specs/002-local-catch-db/tasks.md` T045 (`docs/shared-db-plan.md` "Release 1.2.0"); its harvest also
  bundles the network records the author's client collected.

---

## Dependencies & Execution Order

- **Phase 1** (T001-T002): no dependencies; T001 before every test that uses the fakes.
- **Phase 2** (T003-T009): after T001.
  - T004 before T005.
  - T006 before T007, and T005 before T007.
  - T008 before T009, and T009 after T007 (same file).
  - T003 is independent.
- **US1** (T010-T017): after Phase 2.
  - T010 before T013.
  - T011 before T014, and T014 after T013 (the node is tested with a fake network, but T015 binds it to `Comm`).
  - T015 after T013 and T014; it makes the "Game node" tests of T011 pass.
  - T012 before T016, and T016 before T017.
- **US2** (T018-T022): after T015 (the gate and the setting act on the game node). T019 before T022.
- **US3** (T023-T029): after T015 and T020, for the states `off` and `notice`. T027 and T028 are independent of
  T029.
- **US4** (T030-T032): T030 only needs the part 1 harvest, so it can run at any time. T031 needs T007.
- **Phase 7**: after the stories it documents.
- **Phase 8**: after 2026-11-04 and Phase 7. T039 runs before `specs/002-local-catch-db/tasks.md` T042 (which
  removes `Spike.lua`). After T042 the release is `specs/002-local-catch-db/tasks.md` T045.

## Parallel Example: User Story 1

```text
T010 transport tests in tests/comm_test.lua
T011 protocol tests in tests/share_protocol_test.lua
T012 view tests in tests/catchdb_test.lua
```

Then T013 (`Comm.lua`) and T016 (`CatchDB.lua`) in parallel; T014 and T015 (`Share.lua`) after T013; T017 after
T016.

## Parallel Example: across stories

T030 (the harvest test, Node only) can be done at any time. The settings page (T022) and the commands entry (T027)
touch different files than the protocol, so they can run alongside the late US1 tasks once their tests exist.

## Implementation Strategy

1. **MVP**: Phases 1-3 build the exchange and the tab with others' catches. For US1 alone, tests set
   `shareNotice = true`.
2. **Add US2** (popup, setting) before anything reaches players: sharing is on by default, so disclosure is part of
   the minimum release.
3. **Add US3** (status, `/okf share`, debug) for players and bug reports.
4. **Add US4** (harvest loop), mostly tests.
5. **Phase 7** before launch, so launch day is only verification.
6. **Phase 8** after 2026-11-04, then release 1.2.0 with all four parts.

## Notes

- Every task keeps `npm run check` and `npm test` green; commit after each task or logical group, on `002-shared-db`.
- A `VERIFY` marker is removed only after the author's in-game confirmation (Principle IV), never because a source
  "says so".
- Names live only in memory (peers, the queue, the part buffers, the filter's 10 s list); never write them to saved
  variables, the debug report or `/okf share`.
