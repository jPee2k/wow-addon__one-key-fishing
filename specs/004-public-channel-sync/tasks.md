---

description: "Task list for the Catch Data Exchange Through a Hidden Public Channel"
---

# Tasks: Catch Data Exchange Through a Hidden Public Channel

**Input**: Design documents from `specs/004-public-channel-sync/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md),
[verification.md](verification.md); the code of parts 1 and 2 (`specs/002-local-catch-db/`,
`specs/003-guild-group-sync/`: CatchDB, the seed, the harvest, Comm, Share, the tabs).

**Tests**: Included. The constitution (Principle V) requires tests for logic that runs without the game. Tests come
first in each phase and must fail before the implementation.

**Organization**: Tasks are grouped by user story:

| Story | What the player gets | Priority |
| --- | --- | --- |
| US1 | Catches of players I have never met (the hidden channel) | P1 |
| US2 | Numbers no single player can skew (chain, weights, new and unknown items, eviction) | P2 |
| US3 | Turn the public channel off and see its state | P3 |
| US4 | The author blocks a bad contributor | P4 |

**Verification debt**: the game opens on 2026-11-04. Phases 1 to 7 are done before that, on the assumptions V19-V29
of [verification.md](verification.md); every line of code that relies on one of them carries
`-- VERIFY(Vn): <what>`. Phase 8 runs after launch, together with the debt of the other parts.

**Branch and release**: all shared-db work stays on `002-shared-db` (no branch per spec). Release 1.2.0 ships all four
parts together once the debt of all of them is closed (`docs/release-plan.md`). The channel ships
only if V19 holds; otherwise `Channel.AVAILABLE = false` (FR-026). The protections of US2 and US4 ship either way.

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
- Lua stays 5.1/5.3-neutral: no `//`, no `goto`, no integer division assumptions. `bit` is allowed only through the
  game's library (research R9), with every result taken modulo 2^32.
- Constants go at the top of their file with a comment, named as in the design documents (`CHAIN_LENGTH`,
  `STEP_SECONDS`, `PROOF_STEPS`, `CHANNEL_TARGET`, `MAX_CHANNEL_PEERS`, ...).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: test fakes for every new API, the simulation size, and the launch-day spike questions.

- [X] T001 In `tests/wow.lua`, add the chat channel fakes. Each is driven by globals the tests set; document each
  global in the header comment and reset all of them in the existing per-test reset.

  **Channels**
  - `channels_joined`: a list of `{ name, number }` the player is in; `channel_extra = 0`: other channels the
    player is in (the player's own), counted in the active total.
  - `JoinTemporaryChannel(name, password, frameID, hasVoice)`: appends `{ name, password, frameID }` to
    `channel_joins`. It returns `channel_join_result[name]` when set (a table of two values; `{}` means nil), else
    assigns the lowest free number from 1 to 20 (skipping `channel_extra` numbers 1..channel_extra), adds the channel
    to `channels_joined` and returns `0, name`.
  - `LeaveChannelByName(name)`: removes it from `channels_joined`, appends the name to `channel_leaves`.
  - `GetChannelName(nameOrNumber)`: `number, name, 0, false` when joined, else `0`.
  - `GetChannelList()`: triplets `number, name, false` for `channels_joined`, sorted by number.
  - `C_ChatInfo.GetNumActiveChannels()`: `#channels_joined + channel_extra`.
  - `C_ChatInfo.GetChannelInfoFromIdentifier(name)`: `{ name, localID = number, channelType = 3 }` or nil.
  - `Constants.ChatFrameConstants = { MaxChatChannels = 20, MaxChatWindows = 10 }`;
    `ERR_TOO_MANY_CHAT_CHANNELS = "You can only be in %d channels at a time."`.
  - `SetChannelPassword(name, password)`: appends `{ name, password }` to `channel_passwords`.
  - `NUM_CHAT_WINDOWS = 10` and `ChatFrame1` .. `ChatFrame10`, each with a `channelList` table and the methods
    `ContainsChannel(name)` and `RemoveChannel(name)` (removes it, appends `{ window, name }` to `window_removals`).
    Helper `chat_window_add(i, name)`.
  - `StaticPopup_Hide(key)`: keep the existing behaviour and append `key` to `popups_hidden`.

  **Notices and events**
  - Helper `channel_notice(event, token, channelName, player, actor)`: fires `event` (`"CHAT_MSG_CHANNEL_NOTICE"` or
    `"CHAT_MSG_CHANNEL_NOTICE_USER"`) with the payload `token, player or "", "", number .. ". " .. channelName,
    actor or "", "", 0, number, channelName` (number from `channels_joined`, else 0).
  - Helper `channel_text(channelName, text, sender)`: runs the `CHAT_MSG_CHANNEL` filters with
    `text, sender, "", number .. ". " .. channelName, sender, "", 0, number, channelName` and returns true when a
    filter discards it.
  - Extend `receive_addon(prefix, text, chatType, sender, target, localID, name)` to fire the full
    `CHAT_MSG_ADDON` payload `prefix, text, chatType, sender, target, 0, localID, name, 0`.
  - `filter_hides(event, ...)`: pass the whole argument list to the filters, not only the text.
  - `issecretvalue(value)`: returns `secret_values[value] == true` (default: nothing is secret).
- [X] T002 In `tests/wow.lua`, add the remaining fakes (same rules as T001).
  - **`bit`**: remove `bit` from `MISSING_51`. Define `bit = { band, bor, bxor, bnot, lshift, rshift }`.
    - Each function is compiled at runtime from a string with `loadstring(...)`, for example
      `loadstring("return function(a, b) return (a % 4294967296) & (b % 4294967296) end")()`. In the stub,
      `loadstring` is fengari's own loader (`load53`). The stub's `load` refuses strings on purpose (Lua 5.1 has no
      string `load`), so it must not be used here.
    - `npm run check` parses `tests/*.lua` as Lua 5.1 (`tools/check.mjs`) and would reject the operators written as
      code. In a string it never sees them, and fengari (Lua 5.3) compiles them.
    - Return signed 32-bit results as LuaBitOp does (a result `>= 2^31` minus 2^32). With the global
      `bit_unsigned = true`, return them unsigned instead (the game's signedness is not documented, research R9).
    - The comment says why the strings and the switch exist.
    Unit tests for the stub go into `tests/proof_test.lua` (T020).
  - **Item loading**: `C_Item.DoesItemExistByID(itemID)` returns `not unknown_items[itemID]`, and
    `C_Item.GetItemInfoInstant` returns nil for `unknown_items[itemID]` (keep `known_items`).
    `C_Item.RequestLoadItemDataByID(itemID)` appends to `item_load_requests`. Helper `item_loaded(itemID, success)`
    fires `ITEM_DATA_LOAD_RESULT` and, on success, clears `unknown_items[itemID]` first.
  - **Login**: helper `enter_world(isInitialLogin, isReloadingUi)` fires `PLAYER_ENTERING_WORLD` with both values.
  - **Proofs**: helper `prove(record, secret)` sets `record.proof` to link `record.seq` of a chain of length 4096
    built from `secret` with `ns.ProofStep` (data-model.md "The version chain"). It is used by the tests of other
    players' records once T026 exists; until then it errors with "ProofStep not loaded".
- [X] T003 [P] In `tests/lua.mjs`, add `setGlobalNumber(L, name, value)` next to `setGlobalString`. In
  `tests/run.mjs`, when the environment variable `OKF_SIM_NODES` is a positive integer, set the global `SIM_NODES`
  to it in every Lua state. Note the variable in the file's header comment and in `docs/development.md` (tests).
- [X] T004 [P] In `OneKeyFishing/Spike.lua`, add a "Chat channel (V19-V27)" section to `BuildReport()` (research R13).
  Use the test prefix `OKFSPIKE` and a test channel named `"OKFSpike" .. four random digits` (made once per session,
  no "-"). Collect the later events (channel notices and their event names, `OKFSPIKE` echoes from `CHAT_MSG_ADDON`
  with chat type `CHANNEL`, `CHANNEL_PASSWORD_REQUEST`, `ITEM_DATA_LOAD_RESULT`) in handlers wrapped in `Safe(...)`,
  and print them on the next report. Every call is guarded with `pcall` and a nil check; the section prints no
  names (sender shapes only: `"Name-Realm"` or `"Name"`).
  1. Slots: `Constants.ChatFrameConstants.MaxChatChannels`, `C_ChatInfo.GetNumActiveChannels()`, and
     `ERR_TOO_MANY_CHAT_CHANNELS:format(MaxChatChannels)`.
  2. Join: the two values of `JoinTemporaryChannel(test)`, then (on the next report) the channel number, the notice
     tokens seen with their events, and for each chat window whether `GetChatWindowChannels(i)` listed the test channel
     before and after `ChatFrameN:RemoveChannel(test)`.
  3. Send: the result of `C_ChatInfo.SendAddonMessage("OKFSPIKE", "ping", "CHANNEL", number)`, and for each echo the
     chat type and the shapes of the `target` and `name` arguments.
  4. Owner: the roster flags of the player (`C_ChatInfo.GetChannelRosterInfo`) or `IsDisplayChannelOwner()`, and the
     notices that followed `SetChannelPassword(test, "x")` and `SetChannelPassword(test, "")`.
  5. Numbers: the numbers of `GetChannelList()` before the join and after the leave are the same (yes / no).
  6. Reach: the number of echoes from other players, with sender shapes.
  7. Lock: whether `CHANNEL_PASSWORD_REQUEST` came for the test channel, and whether the popup was hidden.
  8. Hash: `bit ~= nil`; the raw `bit.bnot(0)` and `bit.band(-1, 4294967295)`; `ns.SHA256("abc")` equal to
     `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`; the milliseconds of 64 `ns.ProofStep`
     calls (`debugprofilestop`). Until T026 the hash lines say "not built yet".
  9. Items: the number of item IDs in the bundled seed's cells that `C_Item.GetItemInfoInstant` does not know, and
     that `C_Item.DoesItemExistByID` says do not exist; the result of `C_Item.RequestLoadItemDataByID` on the first.
  The section leaves the test channel at its end (`LeaveChannelByName(test)`). Mark the file's module comment
  `VERIFY(spike)` as for parts 1 and 2.
- [X] T005 Extend `tests/spike_test.lua` for T004: the section is present, names no player, joins and leaves the test
  channel, prints the send result and the hash lines, and survives every API call failing (each stub raising an
  error).

**Checkpoint**: the fakes and the spike section exist; nothing of the feature yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the new saved fields and the `Channel.lua` module every story talks to.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T006 In `OneKeyFishing/Core.lua`, add the defaults (`ApplyDefaults` fills them; `DB_SCHEMA` stays 1):
  `settings.shareChannel = true` with the comment `-- "Use the public channel" (Channel.lua); without effect while
  shareDB is off`, and `shareNoticeChannel = false` with `-- true once the notice that names the public channel was
  closed (Share.lua)`. Extend `tests/core_test.lua`: a fresh DB gets both; an existing `shareChannel = false` is kept.
- [X] T007 Create `OneKeyFishing/Channel.lua` (module comment as in Comm.lua: what it does, what it knows nothing
  about, the contract it follows: `specs/004-public-channel-sync/contracts/channel.md` and `api.md`). Add it to
  `OneKeyFishing/OneKeyFishing.toc` between `Comm.lua` and `Share.lua`. For now it holds:
  - `Channel.AVAILABLE = true` with `-- VERIFY(V19): addon messages in a custom channel work in Forever; false takes
    the channel out of the release (FR-026)`;
  - `Channel.NAMES = { "OneKeyFishingShare", "OneKeyFishingShare2", ..., "OneKeyFishingShare6" }`;
  - `Channel.IsEnabled()` (`ns.db.settings.shareChannel == true`);
  - `Channel.IsOurs(name)` (case-insensitive match against `Channel.NAMES`, false for a non-string or a secret
    value);
  - `Channel.FreeSlots()` (`MaxChatChannels - C_ChatInfo.GetNumActiveChannels()`);
  - `Channel.GetState()` returning `"unavailable"` while not `AVAILABLE`, `"off"` while `shareDB` or `shareChannel`
    is off, and `"waiting"` otherwise;
  - `Channel.GetNumber()` returning nil;
  - `Channel.Describe()` returning `{ "channel: " .. state }`.
  Create `tests/channel_test.lua` with tests for these. Add the new globals to `.luacheckrc`.

**Checkpoint**: Foundation ready; the stories can start (US2 and US4 do not depend on US1).

---

## Phase 3: User Story 1 - Catches of players I have never met (Priority: P1) 🎯 MVP

**Goal**: every client joins the hidden channel, announces itself there and exchanges with strangers it hears, about
two requests per announcement, invisibly, always leaving the player a channel slot, and moving to the same fallback
channel when one is locked.

**Independent Test**: quickstart.md "In game" steps 1-5 (two accounts with no guild, group or friends link see each
other's catches; the chat shows nothing; a lock moves both to `OneKeyFishingShare2`; the player's channel limit makes
the addon give way). Without the game: `npm test -- channel` and `npm test -- share_channel`.

### Tests for User Story 1 ⚠️

> Write these tests FIRST and make sure they FAIL before the implementation.

- [X] T008 [P] [US1] Extend `tests/channel_test.lua` (contracts/channel.md, data-model.md "State of the channel"):
  - **Join timing**: after `enter_world(true, false)` nothing joins before 30 s and the join happens by 60 s; after
    `enter_world(false, true)` with `OneKeyFishingShare` already in `channels_joined`, the state is `in` at once and
    nothing is joined again; a second one of our names found then is left.
  - **Gates**: no join while `shareNotice` or `shareNoticeChannel` is false (state `notice`), while `Comm.GetPause()`
    returns a reason (state `paused`, and a channel already joined stays), while `AVAILABLE` is false, or with fewer
    than 2 free slots (`channel_extra = 19`: state `noslot`).
  - **Hiding**: after the join notice (`YOU_CHANGED`, and separately `YOU_JOINED`) every chat window that lists the
    channel gets `RemoveChannel`; `UPDATE_CHAT_WINDOWS` repeats it; windows that do not list it are not touched.
  - **Filters**: for `CHAT_MSG_CHANNEL`, `CHAT_MSG_CHANNEL_NOTICE`, `CHAT_MSG_CHANNEL_NOTICE_USER`,
    `CHAT_MSG_CHANNEL_JOIN` and `CHAT_MSG_CHANNEL_LEAVE`, a line whose arg9 is any of `Channel.NAMES` (any case) is
    discarded, a line of another channel is not, and a secret arg9 is left alone.
  - **Locks on join**: `CHANNEL_PASSWORD_REQUEST` for our name hides `"CHAT_CHANNEL_PASSWORD"` (`popups_hidden`) and
    joins the next name; `WRONG_PASSWORD`, `BANNED` and `WRONG_FACTION` do the same; with all six locked the state is
    `locked` and nothing more is joined until logout; `TRIAL_RESTRICTED`, `INVALID_NAME` and a nil join result give
    `locked` at once without a fallback.
  - **Locks while in**: `PASSWORD_CHANGED` by an actor `Share.HeardInChannel` does not know:
    - when a `CHANNEL_OWNER` notice names this client as the owner, `SetChannelPassword(name, "")`
      at once and no move;
    - otherwise a move to the next name after the random 10-20 s wait;
    - no move when a `PASSWORD_CHANGED` by a heard actor comes within the wait.
    A `PASSWORD_CHANGED` by a heard actor alone starts nothing. `MODERATION_ON` behaves like `PASSWORD_CHANGED`,
    except that the owner cannot undo it.
    `OWNER_CHANGED` naming this player after a lock was seen clears the password; without a lock seen it does not.
  - **Kicks and bans**: `PLAYER_KICKED` naming this player rejoins after 60 s; the third kick counts as a ban (next
    name); `PLAYER_BANNED` naming it, or `MUTED`, moves to the next name. Notices naming another player change
    nothing.
  - **Left by hand**: `YOU_LEFT` for our channel when the addon did not leave itself gives `left` until the next
    login; the setting stays on.
  - **Settings**: `Channel.SetEnabled(false)` (or `Share.SetEnabled(false)`) leaves at once with state `off`;
    `SetEnabled(true)` joins at once, without the login delay. Other players' records received before
    `Channel.SetEnabled(false)` still count in `CatchDB.Query` after it (FR-012).
  - **Not fishing**: with fishing mode off (`ns.Mode` not active), the join happens and the state is `in` (FR-001,
    US1 scenario 10).
  - **Message**: `CHANNEL_STATE` fires with `state, index` on each change and not otherwise.
- [X] T009 [P] [US1] Extend `tests/channel_test.lua` with the slot rule of FR-005 and research R3. While in, the
  formatted `ERR_TOO_MANY_CHAT_CHANNELS` text on `CHAT_MSG_SYSTEM`, and separately on `UI_ERROR_MESSAGE`, makes the
  addon leave at once. It prints exactly one line containing the English text "OneKeyFishing left its hidden channel to
  free a chat channel slot. Try joining again." and goes to `noslot`. A second such text in the session prints
  nothing. The same text during the addon's own join does nothing. After two slots free up, `CHANNEL_UI_UPDATE`
  makes it join again.
- [X] T010 [P] [US1] Extend `tests/comm_test.lua` (research R6, contracts/api.md "ns.Comm additions"):
  - `Comm.ChannelBroadcast(text)` queues nothing unless `Channel.GetState()` is `in`. It sends with chat type
    `CHANNEL` and the number `Channel.GetNumber()` returns when the message goes out (change the number between
    queueing and sending), and keeps the 2 s broadcast pace shared with guild and group.
  - An `OKF1` `CHAT_MSG_ADDON` with chat type `CHANNEL` reaches `OnReceive` with `via = "channel"` only when its `name`
    argument (or, when that is empty, `target`) is one of `Channel.NAMES`; a part of a long message from the channel is
    dropped.
  - A part from an address the part filter (`Comm.SetPartFilter`) refuses is dropped before buffering; with the
    filter accepting, parts join as before. The part buffers of all senders together stay at or under 128 KB (the
    oldest sender's buffer goes first).
  - A sender with more than 30 dropped parts within 10 minutes (`PART_FLOOD_LIMIT`) is reported once through
    `Comm.OnFlood` (spy), and every later message from it is dropped (FR-010).
  - The channel path counts refusals per channel: two `InvalidChannel` / `GeneralError` results in a row after a join
    call `Channel.OnRefused` (spy) and start the count again. Five refusals spread over three indexes do not leave
    the path out; the channel path never makes the exchange `unavailable` on its own (it carries `HELLO` only).
- [X] T011 [P] [US1] Create `tests/share_channel_test.lua` (research R5, contracts/protocol.md "Announcements in the
  channel"):
  - From the channel only a whole `H` message is handled; `S`, `D`, `W`, `R`, `B` with `via = "channel"` are ignored.
  - With an injected `random`, a stranger's channel `HELLO` with another hash starts a session only when
    `random() < min(1, CHANNEL_TARGET / H)`. `CHANNEL_TARGET` is 2, and `H` is the channel `HELLO`s heard in the last
    40 minutes (check `H` = 1, 2, 10, 100).
  - **Near peers first**: no channel session while a guild, group or friend peer heard in the last 15 min has a
    different hash and `Node:CanStart` would start a session with it now. A near peer in its 30 min cooldown, paused
    or idle does not block a channel session.
  - **Part 2 timing kept** (FR-007, SC-009), both directions, each ending in a finished session with the group peer
    within 5 minutes of the group `HELLO`:
    - the group peer starts a session with this client while it runs a channel session, gets `BYE busy`, and comes
      back through the busy retry;
    - this client hears the group peer's `HELLO` while it runs a channel session, and starts the session with the
      group peer once the channel session ends.
  - **Busy retry**: a near peer that answers `BYE busy` is tried once more 120-180 s later; a channel peer is not.
  - **Cooldowns**: a channel peer keeps the 30 min cooldown (`OTHER_COOLDOWN`); a later guild `HELLO` from the same
    tag upgrades it to `via = "guild"`.
  - **Peer bound**: adding 301 channel-only peers forgets the one heard longest ago and its tag. A guild peer, a
    friend and the session's peer are never forgotten.
  - **Status and lookup**: `Share.GetStatus().heard.channel` counts channel peers heard in the last hour.
    `Share.HeardInChannel("Name")` and `("Name-Realm")` both match a channel peer `w:Name-Realm`.
  - **Rounds**: after `CHANNEL_STATE` `in`, the first channel `HELLO` comes 30-90 s later, then every 30-50 min, and
    5-30 s after a move to another index; none while not `in`.
- [X] T012 [P] [US1] Create `tests/channel_sim_test.lua`: `N = SIM_NODES or 60` protocol nodes (`Share.NewNode`) on
  one fake network with a fake clock and a fake channel that delivers each channel `HELLO` to every other node.
  - Each node has its own store and own record (a few cells, `prove`d once T026 exists; until then without proof).
  - Whispers deliver as in `tests/share_protocol_test.lua`; every node has its own byte counter per hour.
  - Run 3 simulated hours after a staggered login (each node joins 30-60 s after its own login, spread over the
    first 10 minutes). Assert:
    - at least 90% of the nodes hold a contribution created at minute 30 (SC-001, scaled);
    - the average number of `SUM`s received per channel `HELLO` sent is at most 5 (SC-002);
    - no node sends more than `Comm.BUDGET` bytes in any hour (SC-003).
  - Then lock the channel at hour 3: every node gets `PASSWORD_CHANGED` by an unknown actor. Assert that within 15
    simulated minutes at least 90% of the nodes are in index 2 and have exchanged there (SC-011).
  - Keep the default run under 30 s; print the measured numbers and the run time.
  - Every node really receives every channel `HELLO` (no sampling), so the chance code under test is the real one.
    That makes the full sizes of T051 slow; they run by hand, not in the default `npm test`.

### Implementation for User Story 1

- [X] T013 [US1] In `OneKeyFishing/Channel.lua`, build joining and hiding (research R2, contracts/channel.md
  "Joining", "Hiding"):
  - the state machine of data-model.md "State of the channel" with `CHANNEL_STATE` (`state, index`);
  - the join 30-60 s (`JOIN_DELAY_MIN`, `JOIN_DELAY_MAX`) after `PLAYER_ENTERING_WORLD` with `isInitialLogin`, or at
    once after `SetEnabled(true)` / two slots free; `JoinTemporaryChannel(name)` with no password and no window;
  - the `/reload` case (`isReloadingUi`: take a joined one of our names, leave a second one);
  - the gates (both settings, `shareNotice` and `shareNoticeChannel`, `Comm.GetPause()`, two free slots);
  - the join confirmed on `YOU_CHANGED` / `YOU_JOINED` for our name or `GetChannelName(name) > 0`;
  - `RemoveChannel(name)` on every chat window that `ContainsChannel(name)`, after each join and on
    `UPDATE_CHAT_WINDOWS`;
  - the five `ChatFrameUtil.AddMessageEventFilter` filters registered at file load (arg9 through
    `Channel.IsOurs`, nothing for a secret value);
  - `Channel.SetEnabled(on)` (sets `settings.shareChannel`, joins or leaves at once, fires `SETTINGS_CHANGED`
    `"shareChannel"`); leaving at once on `SETTINGS_CHANGED` `"shareDB"` off;
  - `Channel.GetNumber()` through `GetChannelName`.
  Markers: `VERIFY(V19)` at the join, `VERIFY(V21)` at the window removal and the filters, `VERIFY(V22)` at the
  login delay. Add the new globals to `.luacheckrc`.
- [X] T014 [US1] In `OneKeyFishing/Channel.lua`, build locks, kicks, bans and the self-heal (research R4,
  contracts/channel.md "Locks, kicks, bans"):
  - `locked` indexes per session; joining the next index;
  - `CHANNEL_PASSWORD_REQUEST` for our name (`StaticPopup_Hide("CHAT_CHANNEL_PASSWORD")`, then locked);
  - the join notices `WRONG_PASSWORD`, `BANNED`, `WRONG_FACTION`; and `TRIAL_RESTRICTED`, `INVALID_NAME` or a nil
    join result (state `locked`, no fallback);
  - `PASSWORD_CHANGED` and `MODERATION_ON` by an actor `Share.HeardInChannel` does not know:
    - a password, as the owner, undo at once (`SetChannelPassword(name, "")`); moderation has no undo call;
    - otherwise the 10-20 s wait (`LOCK_GRACE_MIN`, `LOCK_GRACE_MAX`), ended by a change from a heard actor;
  - `OWNER_CHANGED` naming the player after a lock was seen (clear the password);
  - `PLAYER_KICKED` (rejoin after 60 s, `KICK_REJOIN`; the third kick, `MAX_KICKS`, counts as a ban), `PLAYER_BANNED`
    and `MUTED` naming the player;
  - `Channel.OnRefused()` for Comm (two refusals in a row after a join, then the next index);
  - `YOU_LEFT` not caused by the addon (`left` until the next login).
  The owner is known from `OWNER_CHANGED` or from the `CHANNEL_OWNER` notice that `DisplayChannelOwner(name)` asks
  for, only when a lock was seen (the roster is not read: research R4). Players are matched by the
  name with or without the realm. Markers: `VERIFY(V24)` at the notice handling and the self-heal, `VERIFY(V21)` at
  the popup.
- [X] T015 [US1] In `OneKeyFishing/Channel.lua`, build giving the slot up (research R3): while in and not joining
  itself, listen on `CHAT_MSG_SYSTEM` and `UI_ERROR_MESSAGE` for `ERR_TOO_MANY_CHAT_CHANNELS:format(MaxChatChannels)`
  (also when it is secret: then nothing). Then leave at once, `ns.Print` the line once per session and go to
  `noslot`. Join again on `CHANNEL_UI_UPDATE` (and from Share's channel round) once `Channel.FreeSlots() >= 2`. Add the
  key `"OneKeyFishing left its hidden channel to free a chat channel slot. Try joining again."` to `enUS.lua` and the
  nine translations. Marker `VERIFY(V23)`.
- [X] T016 [US1] In `OneKeyFishing/Comm.lua`, add the channel path (research R6, contracts/api.md):
  - `paths.channel`; `Comm.ChannelBroadcast(text)` (broadcast pace, `chatType = "CHANNEL"`, the target read from
    `ns.Channel.GetNumber()` in `SendNow`, dropped when nil);
  - receiving in the `CHAT_MSG_ADDON` handler for chat type `CHANNEL` (the `name` argument, else `target`, through
    `ns.Channel.IsOurs`; `via = "channel"`; parts from the channel dropped);
  - `Comm.SetPartFilter(fn)`, checked before a part is buffered;
  - a total cap of 128 KB (`PART_BUFFER_TOTAL`) over all senders' buffers, the oldest sender's dropped first;
  - `Comm.OnFlood(fn)`: dropped parts counted per sender (per minute, last 10 minutes). Above `PART_FLOOD_LIMIT = 30`
    it calls `fn(address)` once and drops every later message from that address until logout;
  - for refusals on the channel path, `ns.Channel.OnRefused()` after the second in a row, then a fresh count. The
    channel path never counts toward the part 2 rule "every path left out" (it carries `HELLO` only).
  Update the module comment. Markers: `VERIFY(V19)` at the channel send and receive, `VERIFY(V25)` at the channel
  throttle results.
- [X] T017 [US1] In `OneKeyFishing/Share.lua`, extend the protocol node (research R5, contracts/protocol.md):
  - `env.channelBroadcast` and `node:ChannelHello()` (the `HELLO` text of `node:Hello()` through
    `env.channelBroadcast`);
  - in `Node:Receive`, drop every non-`H` message with `via = "channel"`;
  - in `Handlers.H` for `via = "channel"`: count the `HELLO` into `node.channelHeard` (per minute, last 40 min), then
    start only with `env.random() < math.min(1, CHANNEL_TARGET / heard)`, and not while a near peer (heard in the
    last 15 min, `NEAR_WINDOW`) has a different hash and `Node:CanStart` would start a session with it now (a near
    peer in its cooldown, paused or idle does not block);
  - a peer first heard in the channel gets `via = "channel"` (30 min cooldown); a guild, group or friend `HELLO`
    upgrades it;
  - in `Handlers.B`, a `busy` from a near peer schedules one retry after 120-180 s (`BUSY_RETRY_MIN`,
    `BUSY_RETRY_MAX`);
  - a near peer whose `HELLO` `ConsiderSession` skipped because a session was running is remembered
    (`node.skippedNear`), and `ConsiderSession` runs for it when the session finishes or is dropped;
  - the peer bound `MAX_CHANNEL_PEERS = 300` (forget the channel-only peer heard longest ago and its `byTag` entry;
    never a near peer or the session's);
  - `Node:Activity()` counts `heard.channel`;
  - `Share.HeardInChannel(name)`;
  - the game node registers `Comm.SetPartFilter` (the session's peer, or the session that just ended) and
    `Comm.OnFlood` (`Node:Ignore` of that peer until logout).
- [X] T018 [US1] In `OneKeyFishing/Share.lua`, the game node:
  - **Channel rounds**: on `CHANNEL_STATE` `in`, the first channel `HELLO` after 30-90 s (`CHANNEL_FIRST_MIN`,
    `CHANNEL_FIRST_MAX`), then every 30-50 min (`CHANNEL_ROUND_MIN`, `CHANNEL_ROUND_MAX`); after a change of index,
    one after 5-30 s. No round while not `in`. Each round also lets `Channel` re-check two free slots after a give-way.
  - **Notice**: closing the one-time popup also sets `shareNoticeChannel = true` while `ns.Channel.AVAILABLE`, and
    `Share.SetEnabled` closes both. `Channel` waits for both flags (the notice text is US3).
- [X] T019 [US1] Run `npm test -- channel_sim` at the default size. If SC-001, SC-002 or SC-011 fail, adjust only
  the constants of research R5 (`CHANNEL_TARGET`, the rounds) and write the values used and the measured numbers into
  research.md R5 and contracts/protocol.md.

> Done 2026-10-30. Each test file shares one login, so the channel tests are split by the state they need:
> T008 in `tests/channel_test.lua`, `channel_lock_test.lua` (locks, kicks, bans while in),
> `channel_join_lock_test.lua` (locks on join, all six locked), `channel_refused_test.lua` (a nil join result) and
> `channel_reload_test.lua`; T009 in `channel_slot_test.lua`; T010 in `comm_channel_test.lua`; T011 in
> `share_channel_test.lua` and `share_channel_game_test.lua` (the game node's rounds and `Share.HeardInChannel`).
> Found on the way: moderation has no undo call in Forever's interface code (contracts/channel.md); the channel path
> never counts toward "every path left out"; a near peer blocked by the 2 min gap after a start is remembered too;
> the busy retry runs once until the peer's next `HELLO`; the summary cache is versioned per store.
> The simulation (T012) runs a cold hour for SC-002 and SC-003 and a warm 3 hours for SC-001, then the lock: a cold
> network of 500 cannot spread every record in 3 hours under the budget (research R5, spec "While implementing").

**Checkpoint**: US1 works on its own: the channel is joined, hidden, kept, moved on a lock, and strangers exchange.

---

## Phase 4: User Story 2 - Numbers no single player can skew (Priority: P2)

**Goal**: owner-bound versions, weights, the three-contributions rule, unknown items kept and shown as "Unknown item"
rows, eviction by new information; the harvest applies the same rules.

**Independent Test**: `npm test -- proof`, `-- catchdb_weights`, `-- catchdb_items`, `-- share_store`, `-- catchhere`,
`-- harvest` (quickstart.md table); SC-006 and SC-007 hold.

### Tests for User Story 2 ⚠️

- [X] T020 [P] [US2] Create `tests/proof_test.lua` (research R9, data-model.md "The version chain"). Done as four files:
  `proof_test.lua` (the real SHA-256: vectors, signed and unsigned `bit`), `proof_chain_test.lua` (the chain and the
  checks, with the fast stand-in of tests/wow.lua: real SHA-256 costs about 12 ms per call in fengari),
  `proof_login_test.lua` and `proof_login_roll_test.lua` (the two login cases):
  - The `bit` stub against known LuaBitOp results (`bit.bnot(0) == -1`, `bit.band(-1, 4294967295) == -1`,
    `bit.rshift(-1, 28) == 15`).
  - `ns.SHA256` against the vectors for `""`, `"abc"` and
    `"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"`, plus a 200-byte input crossing a block border. The
    same vectors also pass with `bit_unsigned = true`: the digest does not depend on the library's signedness.
  - `ns.ProofStep` gives 16 base32 characters, the first 80 bits of the digest.
  - **Own chain**: a new own record gets `chain = { epoch, secret (26 base32), top = 4096, marks }`. The marks at
    every multiple of 64 are built 64 links per frame step; `CatchDB.OwnProofReady()` is false until then. Every
    seq bump sets `proof` to link `seq` using at most 63 `ProofStep` calls (count them). Seq 4096 rolls the record.
    An own record without a proof gets a chain at its current seq at login.
  - **`CatchDB.CheckVersion(held, incoming, steps)`**:
    - the owner's next version: `"ok"`;
    - a made-up proof one seq above: `"invalid"`;
    - a jump of 300 seqs with `steps = 32`: `"more"` ten times, then `"ok"`;
    - the owner's next real version after a made-up copy at the same seq, whatever the copy holds: `"ok"`;
    - a jump over more than `CHAIN_LENGTH` seqs: `"invalid"`;
  - **The casting limit** (`CatchDB.CheckRecord`): a record with more than `STEP_SECONDS` (180) of casting per step
    of its seq is refused; exactly 180 per step is accepted (limit changed while implementing: research R9);
    - against a seed proof (`CatchDB.SeedProof`): the same rules;
    - no held version and no seed proof: the first one is taken.
  - Secrets differ between two rolls.
- [X] T021 [P] [US2] Create `tests/catchdb_weights_test.lua` (research R7):
  - **SC-006**: 6 other contributions where an item has a 5% chance, plus a 7th with 10,000 catches all with that
    item. The shown chance rises by at most 20 points, and `view.catches` is the raw total.
  - The own catch (and the own rolled records) is never scaled, even when it is most of the spot.
  - With `players < 5` nothing is scaled.
  - `missRate` comes from the scaled sums; `littleData` from the raw catches.
  - The whole-map view applies the same rule over the map's contributions.
  - Five contributions that all hit the cap share the weight equally.
  - The seed block is not scaled.
- [X] T022 [P] [US2] Create `tests/catchdb_items_test.lua` (research R8):
  - An item in neither the seed nor the own catch, reported on a map by 1 and then 2 other IDs, is not listed; by a
    3rd ID it is, also when the IDs are in different ranges of the map. An item in the seed or in the own catch is
    always listed. Catches of an unlisted item still count in `view.catches`.
  - Each item carries `known` (false for `unknown_items`), `reporters` (distinct other IDs on the map) and `inSeed`.
  - `CatchDB.CheckRecord` accepts a record with an unknown item and returns no third value. It refuses item ID
    2147483648 and a `proof` that is not 16 base32 characters.
- [X] T023 [P] [US2] Extend `tests/share_store_test.lua`:
  - **Eviction** (data-model.md "Eviction by new information"): above 20,000 places the classes go in the order
    A, B, C, D. A: at least half the places are seed cells with `c >= 1000`. B: `seen` older than 60 days. D: more
    than half the places are seed cells with `c < 50`, or unknown to the seed. Within a class the oldest `seen` goes
    first; no record of the own ID ever goes.
  - **Accept**: `Share.Store.Accept` takes a record with an unknown item (no `unknownItem` value, the node no longer
    has `unknownItems`). Without `verified`, a newer version failing `CheckVersion` is `"refused", "invalid"`; with
    `verified = true` the check is not run again. Through a merge, a failing version makes the merge ignore the
    sender.
  - **Merges**: a merge whose chain needs several steps keeps its place in the queue, and each step stays within
    `PROOF_STEPS` links.
  - **CleanUp**: `Store.CleanUp` deletes other records without a valid proof, and stored versions that do not chain to
    the seed's proof of the same unit.
  - **Proof carried**: `Store.ForSending` and the stored copy keep `proof`.
  Once T026 exists, update every test that builds another player's record to `prove` it (grep for `builds =` in
  `tests/`). At least: `share_protocol_test.lua`, `share_game_test.lua`, `share_load_test.lua`,
  `share_absorbed_test.lua`, `share_refused_test.lua`, `share_notice_test.lua`, `share_notice_busy_test.lua`,
  `share_notice_off_test.lua`, `share_store_test.lua`, `share_channel_test.lua`, `channel_sim_test.lua`, and the
  `catchdb_*` and `catchhere_*` tests. After T028 none of them may pass a record without a proof.
- [X] T024 [P] [US2] Extend `tests/catchhere_test.lua`:
  - An unknown item listed by the view shows the question mark icon (file ID 134400), the text "Unknown item", its
    chance and pieces, and an empty price.
  - Its tooltip holds "The game has not shown this item yet.", then "Reported by 3 players on this map" (or "In the
    bundled data" for `inSeed`), then "Item ID: <id>".
  - `C_Item.RequestLoadItemDataByID` is asked once per item and session.
  - `item_loaded(id, true)` redraws the row with the item's name and icon.
  - The miss line uses `view.missRate`.
- [X] T025 [P] [US2] Extend `tests/harvest_test.mjs`:
  - A newer version is checked against the stored one with `node:crypto` SHA-256 (the chain, as T020), and every
    record against the casting limit. A failing one is rejected, reported, and the stored one stays.
  - The seed's `proofs` hold the proof of every absorbed version.
  - Cells with `k >= 5` apply the weight limit (one contribution at most a fifth), and the scaled counts keep
    `c + m <= t`, items within the catches, pieces within `[catches, 20 x catches]` and positions within
    `1000 x casts`.
  - `seedProblems` reports a malformed `proofs` entry.
  - A chain made in Lua (a fixture file written by `tests/proof_test.lua`'s helper, or a fixed vector list shared by
    both tests) verifies in Node.

### Implementation for User Story 2

- [X] T026 [US2] In `OneKeyFishing/Data.lua`, add `ns.SHA256(text)` (64 lowercase hex characters; the standard
  algorithm with the game's `bit` functions, every intermediate value taken modulo 2^32, no `bit` call at file load)
  and `ns.ProofStep(link)` (the first 80 bits of `SHA256(link)` as 16 characters of `ns.BASE32`). Marker
  `VERIFY(V26)` at the `bit` use. Add `bit` to `.luacheckrc`.
- [X] T027 [US2] In `OneKeyFishing/CatchDB.lua`, build the own chain (data-model.md "The version chain"):
  - the constants `CHAIN_LENGTH = 4096` and `MARK_STEP = 64`;
  - `shared.chain = { epoch, secret, top, marks }` made at every new own record. The secret: `ns.SHA256` over
    `math.random` draws, `time()`, `GetTime()`, `debugprofilestop()` and `UnitGUID("player")`, cut to 26 base32
    characters; never sent, never in a debug line;
  - the marks built in the background (64 links per `C_Timer.After(0)` step) after a roll or at login when missing;
  - `proof` set to link `seq` at every `BumpSeq`, from the next mark;
  - a roll when the seq reaches `top`;
  - the login fix for an own record without a proof (a chain whose top is above its current seq);
  - `CatchDB.OwnProofReady()`.
- [X] T028 [US2] In `OneKeyFishing/CatchDB.lua`, change the checks:
  - `CatchDB.CheckRecord`: `proof` of 16 base32 characters; item IDs from 1 to 2,147,483,647; no
    `C_Item.GetItemInfoInstant` call and no third value. Mirror the same rules in `tools/harvest.mjs` `checkRecord`.
  - Add `CatchDB.CheckVersion(held, incoming, steps, state)`: resumable, returns `"ok"`, `"invalid", reason` or
    `"more"` with its state. It checks the chain to the held proof (at most one chain long).
  - `CatchDB.CheckRecord` also refuses a record with more than `STEP_SECONDS = 180` of casting per step of its seq.
  - Add `CatchDB.SeedProof(id, epoch)` (from `ns.SeedData.proofs`, a malformed one counting as none).
- [X] T029 [US2] In `OneKeyFishing/Share.lua`, adapt the store and the merges:
  - `CleanRecord` and `Store.ForSending` keep `proof`;
  - remove `node.unknownItems`, the `unknownItem` returns of `Store.Accept` and their uses in `MergeOne`,
    `SendRecords` and `Wanted`;
  - `MergeOne` becomes resumable: decode and check, then `CheckVersion` in chunks of `PROOF_STEPS = 32` links per
    frame step against the stored record or `CatchDB.SeedProof`, then `Store.Accept(..., verified = true)`. An
    `"invalid"` result ignores the sender. The longest step is still measured per frame step;
  - `Store.Accept(store, record, now, absorbed, verified)`: without `verified` it runs `CheckVersion` to the end at
    once (tests, the cleanup);
  - `Store.CleanUp` deletes other records without a valid proof, and versions that do not chain to the seed's proof;
  - `Node:OwnData` returns `false, "proof not ready"` while `CatchDB.OwnProofReady()` is false.
  Marker `VERIFY(V26)` at `PROOF_STEPS`.
- [X] T030 [US2] In `OneKeyFishing/Share.lua`, replace the order of `Store.Evict` with the classes of data-model.md
  "Eviction by new information". The constants are `SATURATED_CATCHES = 1000`, `RARE_CATCHES = 50` (part 1's
  `LITTLE_DATA`) and `STALE_SECONDS = 60 * 86400`. Classes come from the seed's catches at the record's places and
  are cached per stored table (weak keys, as `OtherPlaces`); the own ID never goes.
- [X] T031 [US2] In `OneKeyFishing/CatchDB.lua`, add weights to the views (research R7):
  - `SumSpot` and `SumMap` keep each other ID's counts in its own partial sum;
  - when `Players(sum) >= 5`, every other ID's counts are scaled by `min(1, T / c)`, with the cap `T` found by
    capping the largest contributions one by one (five capped share equally); the seed block and the own counts are
    not scaled;
  - the view gains `missRate`, and `chance` and `pieces` come from the scaled sums; `catches`, `misses` and
    `littleData` stay raw.
  Update the view comment of `CatchDB.Query`.
- [X] T032 [US2] In `OneKeyFishing/CatchDB.lua`, add the item rules of research R8:
  - the seed's item set (built once per seed) and the own item set (from `mine` and the records of the own ID,
    grown by every catch in `Settle`);
  - an item is listed only when one of them has it or 3 distinct other IDs report it on the map's five
    `<mapID>:<range>` prefixes;
  - each view item gains `known` (`C_Item.GetItemInfoInstant(itemID) ~= nil`), `reporters` and `inSeed`.
  Marker `VERIFY(V27)` at `known`.
- [X] T033 [US2] In `OneKeyFishing/UI/CatchHere.lua`, draw unknown items (research R8):
  - the icon 134400, the text `L["Unknown item"]`, chance and pieces, an empty price;
  - a tooltip on `OnEnter` with `L["The game has not shown this item yet."]`, then
    `L["Reported by %d players on this map"]` or `L["In the bundled data"]`, then `L["Item ID: %d"]`;
  - one `C_Item.RequestLoadItemDataByID` per item and session;
  - a redraw on `ITEM_DATA_LOAD_RESULT` with success for a shown row;
  - the miss line from `view.missRate`.
  Add the five keys to `enUS.lua` and the nine translations. Markers `VERIFY(V27)` at the icon and the load request.
- [X] T034 [US2] In `tools/harvest.mjs`:
  - check every newer version against the one stored in `seed/contributions.json` (`node:crypto` SHA-256: chain,
    the casting limit), keeping the stored one and reporting `  rejected  <id>@<epoch>: <reason>`;
  - keep `proof` in the stored records;
  - write `proofs` (`{ [id] = { [epoch] = proof } }` for every absorbed version) into the seed, and its lines in
    `seedText`;
  - scale every contribution of a cell with `k >= 5` by the weight limit before summing, rounding and keeping the cell
    rules;
  - make `seedProblems` check `proofs`.
  Update `specs/002-local-catch-db/contracts/seed-data.md` with the field.

**Checkpoint**: US2 works on its own (and ships even without the channel).

---

## Phase 5: User Story 3 - Turn the public channel off and see its state (Priority: P3)

**Goal**: the setting, the notice that names the channel (shown again if the channel comes later), and the channel's
state in the page, `/okf share` and `/okf debug`.

**Independent Test**: quickstart.md "In game" steps 6-8; `npm test -- settings`, `-- share_notice`, `-- share_game`.

### Tests for User Story 3 ⚠️

- [X] T035 [P] [US3] Extend `tests/settings_test.lua`:
  - The "Shared database" page has a "Use the public channel" checkbox below the first one, greyed out
    (`IsEnabled() == false`) while "Use the shared catch database" is off, and clickable again when it is on.
    Clicking it calls `Channel.SetEnabled`.
  - The page text holds "With the public channel on, they also go to every other addon user, through a hidden chat
    channel." and "Anyone who joins that channel by its name can see which characters in it use the addon."
  - The channel's state line ("Public channel: ...") updates with the page's status timer.
  - With `Channel.AVAILABLE = false` none of these exist.
- [X] T036 [P] [US3] Extend `tests/share_notice_test.lua`:
  - While `Channel.AVAILABLE`, the notice starts with "OneKeyFishing now shares your catches under a random ID with
    other players who use it." and "It reaches your guild, group and friends, and anyone else through a hidden chat
    channel." (two keys, so each fits a line), and
    closing it sets `shareNotice` and `shareNoticeChannel`.
  - With `AVAILABLE = false` it is the part 2 sentence, and only `shareNotice` is set.
  - With `shareNotice = true` and `shareNoticeChannel = false` the notice shows again at login while the guild
    exchange keeps running, and the channel joins only after it is closed.
- [X] T037 [P] [US3] Extend `tests/share_game_test.lua`:
  - `/okf share` prints the line for each channel state (in use; in use (fallback channel 3); off; no free chat
    channel slot; locked or refused by the game; you left it, back at the next login; waiting). The states `notice` and
    `paused` print "Public channel: waiting"; with `AVAILABLE` false no channel line is printed.
  - It prints "Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d, channel %d", and the
    part 2 line when `AVAILABLE` is false.
  - `/okf debug` holds the `Channel.Describe()` lines, the population estimate and the channel peers kept, and
    never a name, the anonymous ID or the chain's secret.

### Implementation for User Story 3

- [X] T038 [US3] In `OneKeyFishing/UI/Settings.lua`, extend `CreateSharePage()`:
  - the "Use the public channel" checkbox below the first one (`Channel.IsEnabled` / `Channel.SetEnabled`), greyed
    out with its label while `ns.Share.IsEnabled()` is false (re-read on `SETTINGS_CHANGED`);
  - the two sentences added to `about`;
  - a channel state line under the checkbox, updated with `status`;
  - none of it built while `ns.Channel.AVAILABLE` is false.
  Add the keys `"Use the public channel"` and the two sentences to `enUS.lua` and the nine translations.
- [X] T039 [US3] In `OneKeyFishing/Share.lua`, change the notice: while `ns.Channel.AVAILABLE`, the first sentence
  is the new key (contracts/channel.md "Texts"); closing sets both flags. `ShowNotice` also runs when
  `shareNotice` is true but `shareNoticeChannel` is false and `AVAILABLE` (FR-022). Add the key to `enUS.lua` and the
  nine translations, and update the comment above the sentences.
- [X] T040 [US3] In `OneKeyFishing/Share.lua`, `OneKeyFishing/Channel.lua` and `OneKeyFishing/Debug.lua`, add the
  state:
  - `Share.GetStatus()` gains `channel`, `channelIndex`, `channelPeers`, `blocked`, `ownBlocked` (contracts/api.md);
  - `Share.PrintStatus()` gains the channel line (one text per state; `notice` and `paused` use "waiting", as
    contracts/channel.md "Texts" says) and the heard line with the channel count while `AVAILABLE`; the settings
    page's channel line (T038) uses the same mapping;
  - `Share.Describe()` gains the population estimate (`H`), the channel peers kept, and the chain state (`seq` of
    `top`, marks ready);
  - `Channel.Describe()` gives state, index, free slots, locked indexes, kicks and whether the self-heal ran;
  - the debug report's "Shared database" section adds the `Channel.Describe()` lines.
  Add the seven `Public channel: ...` keys and the heard line with the channel to `enUS.lua` and the nine
  translations.

> Done 2026-10-30. Release-specific cases have their own logins: `tests/settings_nochannel_test.lua`,
> `share_notice_nochannel_test.lua` and `share_notice_channel_test.lua` (the notice shown again after part 2). The
> notice's long first sentence is two keys, so each fits a line of the code (contracts/channel.md "Texts").

**Checkpoint**: US3 works on its own: the player can turn the channel off, and every state is explained.

---

## Phase 6: User Story 4 - The author blocks a bad contributor (Priority: P4)

**Goal**: the harvest reports outliers; the author blocks IDs; the seed carries `blocked`; every client drops,
refuses and stops passing on their contributions.

**Independent Test**: quickstart.md "In game" step 11 and `npm test -- harvest`, `-- share_store`.

### Tests for User Story 4 ⚠️

- [X] T041 [P] [US4] Extend `tests/harvest_test.mjs` (research R11):
  - **Report**: an `  outlier   <id>@<epoch>` line for each of the four reasons (casting faster than 3 s per cast
    over 50+ casts; item shares differing by a total variation of 0.5+ at 3+ cells where the others have 100+ catches
    and it has 50+; items no other contribution and no earlier seed has; pieces per catch 3 times the others' with
    20+ catches each), with the block command; an honest heavy fisher is not flagged.
  - **Blocking**: `--block <id> "note"` and `--unblock <id>` change `blocked` in `seed/contributions.json`. A blocked
    ID is left out of the sums and of `absorbed`, and the seed's `blocked` names it.
  - `seedProblems` reports a malformed `blocked`.
- [X] T042 [P] [US4] Extend `tests/share_store_test.lua`:
  - A record of an ID in `ns.SeedData.blocked` is refused as `"blocked"` without ignoring the sender, deleted by
    `Store.CleanUp`, skipped in a `DIFF` (not wanted) and left out of `Store.Units`.
  - An own blocked ID still counts in the views, is not offered (`Node:OwnData` is
    `false, "blocked by the bundled data"`), and `Share.Describe()` says so.
  - An ID no longer blocked is accepted again.

### Implementation for User Story 4

- [X] T043 [US4] In `tools/harvest.mjs`:
  - the `blocked` map (ID -> note) in `seed/contributions.json`;
  - the `--block <id> [note]` and `--unblock <id>` options (checked against the ID pattern);
  - blocked IDs left out of `sumContributions` and `absorbed`;
  - `blocked` written into the seed (`seedText`) and checked by `seedProblems`;
  - the outlier report of research R11 (thresholds as named constants) after the sums.
  Update the file's usage comment, `specs/002-local-catch-db/contracts/harvest-command.md` and `seed-data.md`.
- [X] T044 [US4] In `OneKeyFishing/CatchDB.lua` and `OneKeyFishing/Share.lua`:
  - `CatchDB.IsBlocked(id)`;
  - `Store.Accept` refuses `"blocked"` (no blame in `MergeOne`);
  - `Store.CleanUp` deletes blocked records;
  - `Node:Wanted` and `Store.Units` skip them;
  - `Node:OwnData` returns `false, "blocked by the bundled data"` for an own blocked ID;
  - `GetStatus` fills `blocked` and `ownBlocked`.

**Checkpoint**: all four stories work; the feature is complete without the game.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T045 [P] `README.md`, section "Shared catch database":
  - the public channel, what it does, and the "Use the public channel" setting;
  - that the channel shows in the Chat Channels window and Chat Settings as `OneKeyFishingShare` but in no chat
    window;
  - that anyone who joins it can see which characters use the addon;
  - the one line when a chat channel slot is freed;
  - "Unknown item" rows.
- [X] T046 [P] `CHANGELOG.md` `[Unreleased]`: the public channel, the protections (weights, owner-bound versions,
  new and unknown items, the block list), the new setting.
- [X] T047 [P] `CLAUDE.md`:
  - the module map (`Channel.lua`: the hidden public channel);
  - the message `CHANNEL_STATE` (state, index);
  - a cross-module rule: the channel is switched by `Channel.SetEnabled`, never by a write of
    `settings.shareChannel`;
  - the Forever traps found:
    - 20 chat channels;
    - the password popup on joining a locked channel;
    - channel lists without a filter;
    - filters skipped on secret values;
    - `ChatFrame_RemoveChannel` deprecated, use the window's `RemoveChannel`.
- [X] T048 [P] Update the area documents (constitution, Development Workflow):
  - `docs/architecture/exchange.md`: Channel.lua, the channel path, rounds and chance, the store's new rules;
  - `docs/architecture/catch-db.md`: the chain, weights, items, unknown items;
  - `docs/architecture/ui.md`: the "Unknown item" row and tooltip in CatchHere, and the channel setting and its
    state line on the "Shared database" page;
  - `docs/architecture/core.md`: `ns.SHA256` and `ns.ProofStep` in Data.lua, the new defaults in Core.lua.
- [X] T049 [P] `docs/history/shared-db-plan.md`:
  - part 3 decisions (link this spec);
  - "10 channel slots" corrected to 20;
  - the "Protection against spam and fakes" rows that part 3 closes (forged versions, weights, items, `blocked`);
  - "What the player sees" (the channel lists show the channel).
  Also `docs/tech-debt.md`: the "flood of parts" left for part 3 is closed by FR-010.
- [X] T050 [P] `docs/checklists/public-channel.md`: the in-game checklist of quickstart.md "In game" with report blanks
  (as `docs/checklists/catch-exchange.md`). Add the spike section's export facts (not behaviour) to
  `docs/forever-api.md` under "From the client export": `MaxChatChannels`, the password popup routing, the channel
  lists, `bit` in Blizzard code.
- [X] T051 Run `OKF_SIM_NODES=500 npm test -- channel_sim` and `OKF_SIM_NODES=1000 npm test -- channel_sim`, each with
  a time limit of 30 minutes (stop it and note the size reached if it runs longer). Write the measured numbers
  (spread, requests per announcement, highest hourly bytes, lock recovery) and the run times into quickstart.md under
  the simulation paragraph.
- [X] T052 Final pass: `npm run check` and `npm test` pass. The open `VERIFY` markers of part 3 in the code are V19 and
  V21-V27, plus the earlier parts' markers, each with an entry in verification.md; V20, V28 and V29 have no code
  marker and are closed by the spike and the checklist only. Re-check the plan's Constitution Check against the
  code.

After implementation (2026-10-30 to 2026-10-31): three review-and-fix cycles at the `high` level. Every blocker,
critical, high and medium finding is fixed with a test; the low ones are listed in `docs/tech-debt.md` ("Review of
2026-10-31").

---

## Phase 8: After launch (verification debt, from 2026-11-04)

- [ ] T053 The author runs `/okf spike` in the open world with a second player (another layer and the other faction
  if possible) and pastes the report. Record every answer in `docs/forever-api.md`, and set `PROOF_STEPS` from the
  timing of step 8.
- [ ] T054 Adjust the code where an answer differs from the assumption (the `CHAT_MSG_ADDON` channel argument, the
  join notice token, the limit event, the owner check). If V19 fails, set `Channel.AVAILABLE = false` and remove the
  channel lines from `README.md` and `CHANGELOG.md`; the protections stay.
- [ ] T055 The author runs `docs/checklists/public-channel.md` with three accounts, including a week of normal play
  (SC-004, SC-005). Fix and re-run until it passes; tick V19-V29 in verification.md and remove their markers.
- [ ] T056 Release with the other parts, following `docs/release-plan.md`; `npm run build` must pass
  with no `VERIFY` marker left.

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: after Setup; blocks every story.
- **US1 (Phase 3)**: after Foundational.
- **US2 (Phase 4)**: after Foundational; independent of US1. The simulation (T012) proves its records once T026
  exists.
- **US3 (Phase 5)**: after Foundational; the setting and the notice gate work without US1, the state lines show more
  once US1 exists.
- **US4 (Phase 6)**: after Foundational; T044 builds on the store changes of T029 when US2 is done first (else it
  touches the part 2 store directly).
- **Polish (Phase 7)**: after the stories it describes.
- **After launch (Phase 8)**: after 2026-11-04.

### Within each story

- Tests first, and they must fail.
- `Channel.lua` (T013-T015) before Comm (T016), before Share (T017-T018).
- Data.lua (T026) before the chain (T027), before the checks (T028), before the store (T029).
- The views (T031-T032) before the tab (T033).
- The harvest (T034, T043) independent of the addon code, but it mirrors `CheckRecord` / `CheckVersion`.

### Parallel opportunities

- Setup: T003 and T004 next to T001-T002.
- Every story's test tasks marked [P] (different test files).
- After Foundational, US1, US2 and US4 can be built side by side by different people (different files, except
  `Share.lua`: T017-T018, T029-T030 and T044 touch it in turn).
- Polish: T045-T050 in parallel.

## Parallel Example: User Story 2

```text
Task: "Create tests/proof_test.lua"                 (T020)
Task: "Create tests/catchdb_weights_test.lua"       (T021)
Task: "Create tests/catchdb_items_test.lua"         (T022)
Task: "Extend tests/catchhere_test.lua"             (T024)
Task: "Extend tests/harvest_test.mjs"               (T025)
```

## Parallel Example: User Story 1

```text
Task: "Extend tests/channel_test.lua"               (T008, T009)
Task: "Extend tests/comm_test.lua"                  (T010)
Task: "Create tests/share_channel_test.lua"         (T011)
Task: "Create tests/channel_sim_test.lua"           (T012)
```

## Implementation Strategy

### MVP first

1. Phase 1 and Phase 2.
2. Phase 3 (US1): the channel itself. Stop and validate with `npm test -- channel` and the simulation.

US1 is the reason for part 3, but it only ships if V19 holds after launch. US2 and US4 ship either way, so building US2
right after Foundational (before US1) is equally valid; both orders end in the same code.

### Incremental delivery

1. Setup + Foundational.
2. US1 (channel) and US2 (protections), in either order; each passes its tests on its own.
3. US3 (setting, notice, state).
4. US4 (block list).
5. Polish, the full-size simulation, hand-off.
6. After launch: spike, checklist, debt closed, release 1.2.0 with the other parts.
