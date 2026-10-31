# Research: Catch Data Exchange Through a Hidden Public Channel

Decisions taken for the plan, each with the reason and the alternatives that were rejected. The product decisions
were settled with the author in the spec's "Clarifications" and "Quiz on the gameplay" (2026-10-30). The channel
idea comes from `docs/shared-db-plan.md` (phase 5). API facts were read from the author's own client export (build
1.60.1.70685, `_forever_/BlizzardInterfaceCode`) and the public Forever dumps on 2026-10-30. They prove that a
function exists, not how it behaves, so behaviour is an assumption in [verification.md](verification.md) (V19-V29).

## R1. Built now, verified after launch; one switch for the channel

- **Decision**: as in parts 1 and 2: built before the game opens on 2026-11-04. Every behaviour only the game shows
  is marked `-- VERIFY(Vn)` (V19-V29, numbered after part 2's V10-V18). `npm run check` lists the markers and the
  release build refuses them. `/okf spike` gets a chat-channel section (R13), so one game session on launch day closes
  the questions of all parts.
  - Whether the channel ships at all (FR-026) hangs on one constant, `Channel.AVAILABLE`. When V19 fails it is set
    to `false`: nothing is joined, the setting is not shown, the notice and the page use the part 2 sentences, and
    `/okf share` drops the channel lines. The README and CHANGELOG lines about the channel are removed by hand.
  - The protections (R7-R11) do not depend on it and ship either way (Clarifications).
- **Rationale**: Principle IV; the author wants the work done before launch. One switch is the smallest change to
  make under release pressure.
- **Alternatives rejected**:
  - Deleting `Channel.lua`, its TOC line and its texts at release time: many edits in the last hour; the locale tests
    would have to follow.
  - A build-time flag: conditional code in the package is what the packager keywords did, and the project bans them.

## R2. Joining and hiding the channel

Facts (export = the author's client, build 70685; "Retail docs" = warcraft.wiki.gg):
- `JoinTemporaryChannel`, `JoinChannelByName`, `JoinPermanentChannel`, `LeaveChannelByName`: undocumented C globals,
  in no `C_` namespace. Retail docs give `type, name = JoinX(channelName [, password, frameID, hasVoice])`, and a nil
  first value means failure (Blizzard's own `/join` reads it that way, `SlashCommands.lua:920-944`). No protection is
  known; Total RP 3 joins from a timer.
- A temporary channel "will be left on logout" and does not save chat window settings; a permanent one is rejoined
  at every login (Retail docs). Channel names may not contain "-".
- `GetChannelName(nameOrLocalID)` returns the local number (0 when not in it); `C_ChatInfo.GetChannelInfoFromIdentifier`
  gives `{ name, localID, ..., channelType }` (`Custom` = 3).
- A chat window shows `CHAT_MSG_CHANNEL` and the channel notices only for channels in its own list
  (`ChatFrameOverrides.lua:338-365`). `ChatFrameMixin:RemoveChannel(name)` takes one out and updates the window's
  saved list (`ChatFrame.lua:179-190`). `ChatFrame_RemoveChannel` is only a deprecated alias, not loaded in Forever.
- `ChatFrameUtil.AddMessageEventFilter` runs for every `CHAT_MSG_*` event of a chat window: `CHANNEL`, both
  `NOTICE` events, `JOIN` and `LEAVE` included. It is skipped when the event's values are secret, and every
  `CHAT_MSG_CHANNEL*` event is secret in chat lockdown.
- Notice payload: arg1 the token, arg2 the player concerned, arg5 the actor, arg8 the local number, arg9 the channel
  name without its number (`ChannelFrame.lua:317-319, 1000-1005`).
- The Chat Channels window (`ChannelList.lua:102-179`) and Chat Settings > Channels (`ChatConfigFrame.lua:1704-1743`)
  build their lists straight from `GetChannelDisplayInfo` and `GetChannelList`, with no filter or data provider.
- `CHAT_MSG_ADDON` payload: prefix, text, chat type, sender, target, zoneChannelID, localID, name, instanceID; it is
  not secret.
- `SendAddonMessage`'s `target` "only applies for targeted channels". Retail docs: for `CHANNEL` it is the channel
  number. It is "disabled on Classic". Total RP 3 sends `SendAddonMessage(prefix, text, "CHANNEL",
  GetChannelName(name))`, and its TOC lists 16001 with channel broadcasts switched on for `WOW_PROJECT_CAMELOT`
  (Forever): its authors expect it to work there.

- **Decision**:
  - **Join**: `JoinTemporaryChannel(name)` with no password and no window, so it is left at logout, never saved with
    window settings and never rejoined by the client (FR-002 at the next login).
    - After a login, 30-60 s after `PLAYER_ENTERING_WORLD` (the client has placed the player's own channels by then;
      V22).
    - After a `/reload` the client is still in it: the addon finds it with `GetChannelName(name) > 0` and takes it
      as joined. A second one of our names found is left.
    - The join counts as done on the join notice for our name (`CHAT_MSG_CHANNEL_NOTICE`, token `YOU_CHANGED` on
      Retail; `YOU_JOINED` is handled too), or on `GetChannelName(name) > 0` at the next check.
  - **Hide in chat windows**: after each join, and on `UPDATE_CHAT_WINDOWS`, every chat window that
    `ContainsChannel(name)` gets `RemoveChannel(name)`. A window without the channel drops its lines and notices
    even when filters cannot run.
  - **Filters**: `ChatFrameUtil.AddMessageEventFilter` on `CHAT_MSG_CHANNEL`, `CHAT_MSG_CHANNEL_NOTICE`,
    `CHAT_MSG_CHANNEL_NOTICE_USER`, `CHAT_MSG_CHANNEL_JOIN` and `CHAT_MSG_CHANNEL_LEAVE` drop every line whose arg9
    is one of `Channel.NAMES` (compared without case). A second layer behind the window removal; a secret argument is
    left alone.
  - **The channel list**: no hook. The channel stays listed in the Chat Channels window and in Chat Settings under
    its own name, and the README says so. This is the fallback FR-003 allows, decided from the export: hiding a row
    would take a post-hook that hides pooled buttons and re-anchors the rest of Blizzard's list.
  - **Receive**: an `OKF1` `CHAT_MSG_ADDON` with chat type `CHANNEL` whose channel name (the `name` argument, else
    `target`; V19 shows which) is one of `Channel.NAMES`.
  - **Send**: the channel number from `GetChannelName(name)`, read when the message goes out.
- **Rationale**: FR-001 to FR-004; the window removal is what keeps the channel hidden in chat lockdown, where
  filters do not run.
- **Alternatives rejected**:
  - `JoinPermanentChannel`: rejoined at every login before the addon could wait, and saved in the window settings.
  - `JoinChannelByName`: the docs do not say whether it is kept.
  - A password known to every client: it would be in the open code.
  - Hooking the channel list: fragile, and it touches Blizzard's frame pools.
  - Filters alone: they do not run on secret values.

## R3. Chat channel slots and the player's limit

Facts: `Constants.ChatFrameConstants.MaxChatChannels` is 20 (the plan's "10" is outdated). Blizzard's own test is
`ChatFrameUtil.CanAddChannel()` = `C_ChatInfo.GetNumActiveChannels() < MaxChatChannels` (`ChatFrameUtil.lua:322-324`).
The refusal text is `ERR_TOO_MANY_CHAT_CHANNELS` ("You can only be in %d channels at a time."). The client makes it
natively (no Lua uses it), and whether it arrives as `CHAT_MSG_SYSTEM` or `UI_ERROR_MESSAGE` is not known. Total RP 3
compares `CHAT_MSG_SYSTEM` text with the raw `%d` string, which can never match.

- **Decision**:
  - Free slots = `MaxChatChannels - C_ChatInfo.GetNumActiveChannels()`; the addon joins only when 2 or more are
    free.
  - While in, the addon listens on both `CHAT_MSG_SYSTEM` and `UI_ERROR_MESSAGE` for
    `ERR_TOO_MANY_CHAT_CHANNELS:format(MaxChatChannels)`, the formatted text. When it comes and the addon is not
    joining itself, it leaves at once, prints the one line (`ns.Print`) and goes to `noslot`.
  - It joins again when 2 slots are free (checked on `CHANNEL_UI_UPDATE` and at every channel round), or at the next
    login (V23).
- **Rationale**: FR-005 and the quiz (Q3, Q3a). With one slot always left, the refusal is rare; when it comes, the
  player's next try works.
- **Alternatives rejected**:
  - Hooking the player's join to make room before it: a pre-hook of a Blizzard global taints.
  - Keeping two slots free without giving way: a player who fills them later meets a refusal they cannot explain.

## R4. Locks, kicks, bans and fallback channels

Facts:
- **Owner powers**: globals, none documented as protected: `SetChannelPassword(name, password)`,
  `ChannelKick` / `ChannelBan` / `ChannelUnban(channel, player)`, `SetChannelOwner`, moderation.
- **Who owns a channel**: when the owner leaves, ownership passes to the member with the highest seniority (character
  age, Retail docs). Who owns a new channel is not documented.
- **Joining a locked channel**: it gives `WRONG_PASSWORD` and the `CHANNEL_PASSWORD_REQUEST` event. Blizzard answers
  that event with a password popup (`StaticPopup_Show("CHAT_CHANNEL_PASSWORD", ...)`,
  `EventRouting.lua:41`, `EventImplementation.lua:82-84`).
- **Notice tokens**: `BANNED`, `PLAYER_BANNED`, `PLAYER_KICKED`, `PASSWORD_CHANGED` ("Password changed by %s"),
  `OWNER_CHANGED`, `MODERATION_ON/OFF`, `MUTED`, `WRONG_FACTION`, `TRIAL_RESTRICTED`.
- **Self-heal in practice**: Total RP 3 calls `SetChannelPassword(name, "")` when `OWNER_CHANGED` names the player.

- **Decision** (contracts/channel.md "Locks, kicks, bans"):
  - **Join refused**: `WRONG_PASSWORD` or `CHANNEL_PASSWORD_REQUEST`, `BANNED` or `WRONG_FACTION` mark the index
    locked for the session, and the next one is joined.
    - The password popup is hidden in the same frame (`StaticPopup_Hide("CHAT_CHANNEL_PASSWORD")`, only for one of
      our names; V21).
    - `TRIAL_RESTRICTED`, `INVALID_NAME` or a nil result from the join function mean the game refuses the channel
      itself: state `locked`, no fallback tried (all would fail alike).
  - **A lock while in**: `PASSWORD_CHANGED` or `MODERATION_ON` whose actor is not a player this client heard
    announce in the channel.
    - When this client is the owner, it undoes a password at once (`SetChannelPassword(name, "")`). It learns that it
      owns the channel from `OWNER_CHANGED`, or from the `CHANNEL_OWNER` notice that `DisplayChannelOwner(name)`
      asks for, only after a lock. Moderation cannot be undone: Forever's interface code has no call that turns it
      off (checked in the client export, build 70685), so a moderation lock always waits and moves.
    - Otherwise it waits 10-20 s (random). If a change by a player it heard announce follows (an addon owner undoing
      it), it stays. If not, it moves to the next index. Each client waits on its own random delay, so they do not
      all move in the same second.
    - A change by a player heard announcing never starts a move, so an addon owner's own clear moves nobody.
  - **Becoming the owner**: when `OWNER_CHANGED` names this client after it saw a lock on that channel, it clears
    the password (the self-heal; V24).
  - **Kicks and bans**: `PLAYER_KICKED` naming this player means joining again after 60 s; the third kick in a
    session counts as a ban. `PLAYER_BANNED` naming it, or `MUTED`, marks the index locked and moves on.
  - **Messages refused**: two refusals in a row on the channel path (`InvalidChannel`, `GeneralError`, or any
    other result but a success, a throttle or a lockdown) after a
    successful join mark the index locked and move on (a channel that cannot carry messages any more). The count starts
    again at each move (R6).
  - **Every index locked**: state `locked` until logout; the guild, group and friends go on.
  - **Names**: a fixed list of six (contracts/channel.md "Names").
- **Rationale**:
  - FR-005a and SC-011: everybody walks the same list, so clients that leave a locked channel meet again in the next
    one. The first addon clients there own it, so a griefer must take each name before them.
  - Invisible: the popup is hidden, the notices are filtered and dropped by the windows.
- **Residual risk** (spec Assumptions):
  - A griefer can take all six names ahead of time with one character (a character may be in 20 channels) and keep
    them locked while online. The channel exchange then stops; the guild, group, friends and the seed are not
    touched. When that character leaves, the locked channels, which no addon client could join, empty and vanish,
    and the next login finds them free.
  - A griefer who also runs the addon looks like an addon client. Its lock moves nobody inside, new clients go to the
    next name, and the network stays split until those inside log in again.
- **Alternatives rejected**:
  - Names derived from the date: just as predictable from the code, and everybody moves at the boundary.
  - Staying inside a locked channel: new clients never meet the old ones (FR-005a).
  - Moving on every `PASSWORD_CHANGED`: an addon owner's own clear would move everybody.
  - Reading the channel roster to find the owner: rosters of thousands of members, loaded on request only.

## R5. Announcements in the channel and whom to exchange with

- **Decision**: the rules of [contracts/protocol.md](contracts/protocol.md) "Announcements in the channel":
  - Rounds: a channel `HELLO` every 30-50 min (random), the first 30-90 s after the join.
  - The chance: a hearer starts a session with a stranger with `min(1, CHANNEL_TARGET / H)`. `H` is the number of
    channel `HELLO`s it heard in the last 40 minutes (about the number of clients in the channel, since each
    announces about once in 40 minutes), and `CHANNEL_TARGET` is 2.
  - Then the part 2 rules: one session at a time, 2 min between starts, 30 min with the same peer.
  - Near peers first: no channel session while a guild, group or friend peer heard in the last 15 min has a different
    hash and is about to get a session (its start is armed, its busy retry is due, or it waits for a session or a
    start to be over). A near peer that only waits for its cooldown, or that nothing will start a session with
    (refused busy twice, idle), does not block the channel. Otherwise an active guild would keep the channel shut,
    because every exchange makes their hashes differ again (changed while implementing: "could start now" held the
    channel back for a near peer nobody would start with). A channel start already armed gives way the same way when
    its delay ends.
  - The busy retry: a near peer that answered `BYE busy` is tried again once, 120-180 s later, instead of at its next
    `HELLO` 10-15 min later (FR-007).
  - The busy hearer: a near peer whose `HELLO` came while this client was in a session, or within the 2 min after its
    last start (so no session could start), is considered again when that session ends and the 2 min have passed,
    with the usual 2-20 s wait. Both directions are covered: the client that met a busy peer retries, and the busy
    client picks up the near peer it had to skip.
  - The peer bound: at most 300 peers whose only path is the channel; the one heard longest ago is forgotten, its
    tag with it (FR-009).
  - Measured (tests/channel_sim_test.lua, 2026-10-30, with these constants unchanged; logins spread over 10 minutes).
    A cold start (nobody holds anybody's record, every hash differs) runs one hour for the requests and the bytes; a
    warm start (every client holds every other one's record, one contribution changes at minute 30) runs 3 hours for
    the spread, then a lock:

    | Nodes | Cold: `SUM`s per channel `HELLO` (SC-002, at most 5) | Cold: busiest hour of one node, `BYE` aside (SC-003, at most 51,200 bytes) | Warm: the changed contribution at hour 3 (SC-001, at least 90%) | Met again in the fallback within 15 min (SC-011, at least 90%) | Run time |
    | --- | --- | --- | --- | --- | --- |
    | 60 (the default run) | 2.05 | 50,895 | 100% | 100% | 14 s |
    | 120 | 2.09 | 51,144 | 99% | 100% | 43 s |
    | 500 | 2.07 | 51,152 | 100% | 100% | 25 min |
    | 1,000 | 2.07 | 51,149 | stopped by the 30 min limit | not reached | 27 min for the cold hour |

    A first run with only a cold start showed why the two are split: at 500 clients a contribution made at minute 30
    reached 10% of them by hour 3 while the busiest client sent 51,217 bytes in an hour. Spreading every record to
    every client needs about N^2 records sent, and the budget lets a client send about 130 an hour, so a cold network
    of 500 needs far more than 3 hours whatever the protocol does. After a release the bundled data has absorbed what
    came before, so the real network starts close to the warm case. That run also sent `HELLO`s the game's Comm
    would have held back over the budget; the simulation now holds them back too (only `BYE` may pass it).
    SC-001 is met at its full size (500) and SC-002 at its (1,000); the warm run of 1,000 did not fit in the 30 minutes
    T051 allows.
- **Rationale**:
  - Requests: with `N` clients each announcing about once in 40 minutes, every client hears about `N` announcements
    in 40 minutes. Each hearer answers one with chance `2 / N`, so an announcement draws about 2 requests whatever
    `N` is (SC-002 allows 5). The announcer takes one and answers the other `BYE busy`.
  - Spread: every client then starts about 3 sessions an hour and answers about 3. A new contribution is wanted by
    every peer that lacks it, and goes early in a session (the most recently seen records go first), so the number of
    holders grows several times an hour. The simulation measures SC-001 with the real node code.
  - Budget: the 50 KB per hour budget of part 2 still caps everything; sessions between converged clients move only
    hashes.
  - Priority: guild and group exchange keep their part 2 timing (FR-007): a channel session ends within seconds to a
    minute, and the near peer that met it busy comes back within 3 minutes.
- **Alternatives rejected**:
  - Every hearer starts a session (part 2's rule): with a thousand clients, a thousand `SUM`s reach one announcer, and
    it answers each with `BYE busy`, a `BYE` going out even over the budget: a whisper storm.
  - Choosing hearers by a deterministic distance between node tags: subsets that never meet can split the network,
    and an attacker can pick tags.
  - The announcer picks its partners: it would need a reply from every hearer first.
  - Rarer announcements with every hearer answering: still a storm per announcement, and slow.

## R6. Transport changes in Comm

- **Decision**:
  - A `channel` path: `Comm.ChannelBroadcast(text)` queues `SendAddonMessage(PREFIX, text, "CHANNEL", number)` at the
    broadcast pace (2 s), only while `Channel.GetState()` is `in`. The number is read from `Channel.GetNumber()` when
    the message goes out, not when it is queued (a move to a fallback changes it).
  - Receiving: `CHAT_MSG_ADDON` with chat type `CHANNEL` is taken only when the channel argument names one of
    `Channel.NAMES` (R2 has the argument), with `via = "channel"`. From the channel only whole messages are taken: a
    part is dropped in Comm, any type but `H` in Share.
  - Parts of long messages are taken only from an address Share expects them from: the session's peer, or the session
    that just ended (`Comm.SetPartFilter`). The part buffers of all senders together are capped at 128 KB (FR-010).
  - A sender whose dropped parts pass `PART_FLOOD_LIMIT` within 10 minutes is reported to Share
    (`Comm.OnFlood`), which ignores it until logout (FR-010). Comm drops everything from that address from then on.
    The limit, 402, is more than an honest client's whole hourly budget (50 KB) can carry in parts: each part but a
    message's last is a full 255 bytes, and a long message has at least two. So what an honest peer still sends after
    its session ended here (a timeout, a `/reload`, a new session) never gets it ignored (changed while implementing:
    30 did, and a special case for recent sessions missed the `/reload`).
  - The channel path counts refusals per channel. Two in a row after a join mark that index locked, and Channel.lua
    joins the next (R4); each move starts the count again, so every index gets its two tries. The path is left out
    until logout only when every index is locked, not by part 2's rule of five refusals. The state then says "locked
    or refused by the game".
- **Rationale**: FR-001, FR-008, FR-010. Long messages exist only inside sessions (`DIFF`, `WANT`, `REC`), which go by
  whisper or Battle.net between two clients. So a part from anybody else is junk, dropped before any buffering or
  joining work. This closes the "flood of parts" left for part 3 in `docs/tech-debt.md`.
- **Alternatives rejected**:
  - A separate queue for the channel: the one paced queue and budget of part 2 is what keeps the client within policy.
  - Taking session messages over the channel: everybody would receive them.

## R7. Contribution weights

- **Decision**: in a view (spot or whole map), when `players >= 5` (FR-013):
  - The seed block and the own contribution keep their counts; every other ID gets `f = min(1, T / c)`.
  - `c` is the ID's catches in the scope. `T` is the cap with `T = (F + sum of min(c_j, T)) / 5`, and `F` is the
    seed block's and the own catches.
  - `T` is found by capping the largest contributions one by one: with `k` capped, `T = (F + S) / (5 - k)`, where `S`
    is the sum of the uncapped ones, until no uncapped one is above `T`. When five would be capped, they share the
    weight equally.
  - The scaled counts give `chance` and `pieces`; `catches` and `misses` stay raw, and so does `littleData` (a seed
    cell the harvest weighted carries its raw catches as `r`; its misses stay weighted).
  - `missRate` is weighted the same way by casts (`c + m`) instead of catches, so a contribution of few catches and
    many misses holds no more than a fifth of it either (FR-013; changed while implementing: the catch factors left
    such misses in full).
  - Sums keep each other ID's counts apart until the end (they were added straight into one total in part 2).
  - The harvest applies the same rule per seed cell where five or more contributions caught something (as in the
    views, a contribution of misses only is no player there), with every contribution capped (no own one
    there): catches and items by the catch factors, misses by the cast factors, and the catches weighted by casts as
    the cell's `x` when they differ from `c` (a view's miss rate is `m / (x + m)`). It rounds the scaled counts and
    keeps the cell rules: `c + m <= t`, items within the catches, pieces in
    `[catches, 20 x catches]`, positions within `1000 x casts`.
- **Rationale**: one contribution then holds at most a fifth of the weight, so it moves any chance by at most 20
  points (SC-006). The seed block counts as already limited, because the harvest limited it with full knowledge of
  every contribution. The own catch counts in full (Q5).
- **Alternatives rejected**:
  - Per-item medians across contributions: unstable at low counts, and needs per-contribution shares in the seed.
  - Client-side outlier trimming: thresholds per item, different results on different clients; the harvest's report
    does it once, with the author's judgment (R11).
  - Capping the own catch (Q5).

## R8. New items and items the client does not know

- **Decision**:
  - **Shown or not** (FR-014): an item is listed when it is in the seed anywhere, or in the own catch anywhere, or
    when at least 3 distinct other IDs report it on the map, in any range.
    - The seed's item set is built once per seed. The own set is built from `mine` and the records of the own ID at
      first use and grows with every catch.
    - The other IDs are counted from the index of other players' cells, by the map's five `<mapID>:<range>`
      prefixes.
  - **Unknown to the client** (FR-017a): `CatchDB.CheckRecord` no longer asks `C_Item.GetItemInfoInstant` (item IDs
    must only be integers from 1 to 2,147,483,647), and Share's `unknownItems` rule goes. A view item carries `known`,
    `reporters` and `inSeed`. CatchHere draws an unknown one as a row:
    - the question mark icon (file ID 134400, `INV_Misc_QuestionMark`), `L["Unknown item"]`, its chance and pieces,
      no price;
    - a tooltip with `L["The game has not shown this item yet."]`, `L["Reported by %d players on this map"]` or
      `L["In the bundled data"]`, and `L["Item ID: %d"]`. The number counts contributions (distinct IDs); the text
      says "players" as "N catches from K players" does since part 2, because one contribution is one account.
    - Drawing one asks the game once per item and session to load it (`C_Item.RequestLoadItemDataByID`). An
      `ITEM_DATA_LOAD_RESULT` with success redraws the tab, and the row becomes a normal one (V27).
- **Rationale**: Forever reveals some items only when someone finds them (the author's note), so a client that
  refuses records with unknown items loses real data. Three independent contributions make a made-up ID costly, and
  the weight limit keeps its chance small. The author chose the visible row with the ID (Q6, Q6a, Q6b).
- **Alternatives rejected**: part 2's refusal; hiding unknown items; one summary row for all of them (Q6a); counting
  the reports per range (an item reported in three ranges of one map is just as real).

## R9. Owner-bound versions

- **Decision**: a hash chain per own record (data-model.md "The version chain").
  - Links: `H(x)` = the first 80 bits of SHA-256(x) as 16 base32 characters. The top link (`CHAIN_LENGTH` = 4096) is
    `H(secret)`, and every lower one is `H` of the one above. A record at seq `i` carries link `i` as `proof`.
  - Checking: a newer version at seq `i` over a held one at `j` is accepted only when `H` applied `i - j` times to its
    proof gives the held proof. The held proof is the stored record's, or the seed's `proofs[id][epoch]` for a unit
    the seed absorbed in part. Only the owner knows the links above the newest one it published.
  - The limit: no record may hold more casting than `STEP_SECONDS` (180) per step of its own seq
    (`CatchDB.CheckRecord`, also for a record nobody held before). It needs no other version.
  - The secret: 130 bits, drawn as `SHA256` over `math.random` draws, `time()`, `GetTime()`,
    `debugprofilestop()` and the player's GUID. It lives in `shared.chain`, is replaced at every roll and never
    leaves the account.
  - The owner's cost: marks every 64 links, built in the background after a roll or a login (64 links per frame step),
    so a seq bump costs at most 63 links. A record rolls when its seq reaches the top.
  - The receiver's cost: the chain is walked `PROOF_STEPS` links per frame step (32 to start, from the spike's
    timing); a merge that is still walking keeps its place in the queue.
  - Old records: an own record without a proof (a dev install from part 2) gets a chain at its current seq at login;
    other records without a valid proof are cleaned up.
  - The harvest does the same checks with `node:crypto` on every version against the one stored in
    `seed/contributions.json`. A failing version is rejected and reported; the stored one stays. It writes the proof
    of every absorbed version into the seed's `proofs`. A unit with two versions in the input (or the input and the
    stored file) that are not on one chain, whichever seq is higher, is disputed: one of them is made up, maybe the one
    met first and stored. It is kept in `seed/contributions.json` (`disputed`), named in every report, and left out
    of the seed for good (no sums, not in `absorbed`, no proof; the owner's next epoch is a new unit), so clients keep
    and pass on their copies as for any unit the seed does not hold (changed while implementing: a made-up copy the author's client took first became the anchor,
    and clients deleted the owner's real copies).
  - `bit`: SHA-256 uses the game's `bit` library (`band`, `bor`, `bxor`, `bnot`, `rshift`, `lshift`).
    - The export calls it over 300 times (for example `Blizzard_Setting.lua:219` for `bxor`), and Ketho's Forever API
      list names it.
    - Whether its results are signed is not documented. So `ns.SHA256` takes every result modulo 2^32 and works
      the same either way.
    - `tests/wow.lua` replaces its "missing in 5.1" error for `bit` with a stub built on fengari's 5.3 operators.
      The stub compiles them from strings with `loadstring` (fengari's loader in the stub; its `load` refuses strings
      as Lua 5.1 does), because `npm run check` parses the tests as Lua 5.1 and would reject them as code. It gives
      signed results, or unsigned ones with a switch.
    - Test vectors pass in both modes, and the harvest test checks a chain made in Lua against Node's digest.
- **Rationale**: FR-015 and SC-007.
  - A forger cannot name a link above the owner's newest one, so it cannot make a version that looks newer than the
    owner's. The owner's next real version always chains to what a client holds, so it replaces any copy made up at
    an old seq.
  - A copy made up at a seq the owner already published holds at most `STEP_SECONDS` of casting per step of that seq,
    lives only until the owner's next version, and the weight limit caps its effect.
  - Why the limit is per version and not against the held version (changed while implementing, 2026-10-30). A check
    against the held version would block the owner. A client may hold a made-up copy at seq `i` (the owner had
    published link `i`), and the owner's real version `i + 1` does not contain the made-up cells or counts. "Must
    contain the held version" or "may grow by at most this much" then refuses the owner forever, against the first
    half of FR-015. A bound on each version alone can never do that.
  - The limit needs no timestamps. Records carry none, for privacy, and a limit against the time since a version
    arrived would refuse honest versions relayed slowly.
  - 180 s per step: the seq is bumped at most once per minute (`SEQ_INTERVAL`), on the first settled cast after it.
    So one step holds at most a minute plus two casts of casting (each about 30 s at most, V26), and flushes only
    shorten that.
  - 80 bits: a preimage costs about 2^80 hashes, far beyond anyone's reach.
- **Residual risk** (accepted): a unit a client has never held and the seed has not absorbed is taken from whoever
  brings it first. A forger who reaches that client before the owner's record wins it there until a release absorbs
  the unit; the seed's proof then deletes the forged copy at login (`Store.CleanUp`).
- **Alternatives rejected**:
  - Time-based limits only: the author chose owner-bound versions plus limits.
  - Limits against the held version (containment, growth per step): a made-up copy a client holds would block the
    owner's next real version.
  - Public-key signatures: there is no crypto API, and RSA or ECDSA in Lua 5.1 is slow and large.
  - Tying versions to the sender's name: records are relayed and anonymous.
  - An own hash built from modular arithmetic: invertible or unproven.
  - SHA-256 in plain arithmetic: about 10 times slower; it is the fallback if the game has no `bit` (V26).
  - Hashing every version on a fresh chain: nothing to compare against.

## R10. Eviction by new information

- **Decision**: data-model.md "Eviction by new information" (classes A-D by the seed's catches at the record's
  places and by `seen`, oldest first within a class). A record's place shares are computed once per stored table.
- **Rationale**: FR-016. With strangers the store fills with records about the busy spots the seed already knows
  well; those add least and go first. Records about rare places (low-level zones, little data) are the reason
  part 3 exists and go last. Players who stopped playing still fade out by `seen`.
- **Alternatives rejected**:
  - Oldest `seen` only (part 2): keeps redundant records of popular spots over rare ones.
  - Evicting single cells: it would cut a unit, which the protocol, the chain and the harvest treat as whole.

## R11. The block list and the outlier report

- **Decision**:
  - **Report**: the harvest flags a contribution (`id@epoch`) and prints `  outlier   <id>@<epoch> <reasons>` with the
    command to block it. The reasons:
    1. casting faster than 3 s per cast on average over at least 50 casts;
    2. at 3 or more cells where the others have at least 100 catches, item shares that differ by a total variation of
       0.5 or more over at least 50 catches of its own;
    3. items no other contribution and no earlier seed has, at cells where the others have at least 100 catches
       (listed; a lone item of a place nobody else fished is just new data);
    4. pieces per catch of an item 3 times the others' at a cell, with 20 catches or more on each side.
  - **Blocking**: `npm run harvest -- --block <id> "<note>"` / `--unblock <id>` keep `blocked` (ID -> note) in
    `seed/contributions.json`. Blocked IDs are left out of the sums and of `absorbed`; the seed carries `blocked`.
  - **Clients**: `CatchDB.IsBlocked`. `Store.Accept` refuses `"blocked"` without blaming the sender, `Store.CleanUp`
    deletes such records at login, `DIFF` entries of them are not wanted, and `Store.Units` leaves them out. An own
    blocked ID: the views still count it, it is not offered, and `/okf debug` says so (Q7).
- **Rationale**: FR-018 to FR-020. The author judges; the thresholds only point.
- **Alternatives rejected**:
  - Blocking automatically: honest heavy fishers would be caught.
  - Detection on each client: no judgment, and different results per client.
  - Blocking by name: records are anonymous.

## R12. The setting, the notice and the state

- **Decision**:
  - **Setting**: `settings.shareChannel`, on by default (Q1). A checkbox below "Use the shared catch database",
    greyed out while that is off (FR-021). `Channel.SetEnabled` leaves or joins at once; data received stays counted.
  - **Notice**: `shareNoticeChannel` next to `shareNotice`.
    - While `Channel.AVAILABLE`, the notice's first sentence names the channel. Closing the notice sets both flags.
    - The guild, group and friends exchange waits only for `shareNotice`; the channel also waits for
      `shareNoticeChannel`.
    - If the channel comes in a later release, the notice shows once more for players with `shareNotice` but without
      `shareNoticeChannel` (FR-022).
  - **Page**: the page's text gains the two sentences of contracts/channel.md, plus the channel's state below its
    setting.
  - **State lines**: `/okf share` gains the channel line and the channel count; `/okf debug` gains the channel and the
    protection lines.
  - **The give-way line**: printed with the addon's usual prefix (`ns.Print`).
- **Rationale**: FR-021 to FR-024 and the quiz answers (Q1, Q11, Q13).
- **Alternatives rejected**:
  - A second popup for the channel: two popups at the first login of one release.
  - Turning `shareNotice` from a flag into a number: a reshaped saved field needs a `DB_SCHEMA` bump and a migration
    for no gain.

## R13. Spike additions (`/okf spike`)

- **Decision**: a "Chat channel (V19-V27)" section with the test prefix `OKFSPIKE` and a test channel `OKFSpike`
  plus 4 random digits (no "-"), so the real channel is never created by a test. Events that come later (notices,
  echoes, item loads) are collected by the spike's handlers and shown on the next `/okf spike`, as the network section
  of part 2 does. Counts, numbers and patterns only: no names (the report is pasted into the conversation).
  1. Slots: `MaxChatChannels`, `C_ChatInfo.GetNumActiveChannels()`, and the formatted `ERR_TOO_MANY_CHAT_CHANNELS`
     text (for checklist step 5, which also notes the event it came as).
  2. Join: the two values `JoinTemporaryChannel` returned; the notice tokens and the events they came as; the
     channel's number; whether any chat window lists it (`GetChatWindowChannels`) before and after `RemoveChannel`.
  3. Send: the result of `SendAddonMessage("OKFSPIKE", "ping", "CHANNEL", number)`; for its echo, the chat type and
     the shapes of the `target` and `name` arguments.
  4. Owner: whether the roster flags (`C_ChatInfo.GetChannelRosterInfo`) or `IsDisplayChannelOwner` say the player
     owns the new channel; the notices after `SetChannelPassword(test, "x")` and `SetChannelPassword(test, "")`.
  5. Numbers: the channel numbers (`GetChannelList`) before the join and after the leave are the same (yes / no).
  6. Reach: echoes from other players in the test channel (count, sender shape). The author notes their layer and
     faction.
  7. Lock: after a second player set a password, the notices this client got, and on a fresh join whether
     `CHANNEL_PASSWORD_REQUEST` came and the popup was hidden (the author notes any flash).
  8. Hash: `bit` exists; the raw `bit.bnot(0)` and `bit.band(-1, 4294967295)` (signedness); `ns.SHA256("abc")`
     against the known digest; the milliseconds of 64 `ns.ProofStep` calls (`debugprofilestop`), which sets
     `PROOF_STEPS`.
  9. Items: how many item IDs of the bundled data `C_Item.GetItemInfoInstant` does not know, and how many
     `C_Item.DoesItemExistByID` says do not exist; the `ITEM_DATA_LOAD_RESULT` after `RequestLoadItemDataByID` on the
     first.
  The section leaves the test channel at the end.
- **Rationale**: answers V19-V27; one launch-day session with a second player closes them.

## R14. Modules and testing

- **Decision**:
  - **`Channel.lua` (new)**: names, the delayed temporary join, removal from chat windows, the filters, slots and
    giving way, locks, kicks and fallbacks, leaving by hand, the owner self-heal, the state and `CHANNEL_STATE`. It
    knows nothing about records.
  - **`Comm.lua`**: the channel path, the receive rules, the part filter, the buffer cap (R6).
  - **`Share.lua`**: channel rounds, the chance, near peers first, the busy retry, the peer bound (R5); the store's
    blocked rule, `CheckVersion` in `Accept`, the eviction classes; resumable merges; the state, texts and notice.
  - **`CatchDB.lua`**: the chain, `CheckRecord`, `CheckVersion`, `SeedProof`, `IsBlocked`; the views (R7, R8).
  - **`Data.lua`**: `ns.SHA256`, `ns.ProofStep`. **UI**: the setting (`Settings.lua`), the unknown row
    (`CatchHere.lua`).
  - **Tests** ([quickstart.md](quickstart.md)): new `proof_test`, `catchdb_weights_test`, `catchdb_items_test`,
    `channel_test`, `share_channel_test`, `channel_sim_test`; extended store, comm, CatchHere, settings, notice,
    spike and harvest tests.
  - **The simulation**: protocol nodes over a fake network with a fake channel and clock, sized by `OKF_SIM_NODES`
    (`tests/run.mjs` passes it as a global). The default size keeps `npm test` fast; 500 and 1,000 run before the
    release.
  - **`tests/wow.lua`**: the chat channel API and its notices, the faithful `bit`, item loading.
- **Rationale**: Principle VI (one new module for one new job), Principle V (everything that can run without the
  game is tested).
- **Alternatives rejected**:
  - The channel inside Comm: Comm is the transport of addon messages; joining and hiding a chat channel touches chat
    windows, filters and notices.
  - A separate file for SHA-256: `Data.lua` already holds the shared helpers (base32, rolling counts).
