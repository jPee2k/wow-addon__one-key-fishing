---

description: "Task list for spec 016, the public channel returns"
---

# Tasks: The Public Channel Returns

**Input**: Design documents from `specs/016-public-channel-return/`

**Prerequisites**:
- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/module-api.md](contracts/module-api.md), [quickstart.md](quickstart.md)

**Tests**: required. Spec FR-011 and constitution Principle V ask for a test that fails without its change; a test
that pins today's behaviour (the password order, the owner notices) is written to fail if that behaviour breaks.
Each new test is run before its change and its failure is seen (except the pinning tests, which pass at once).

**Organization**: grouped by the user stories of spec.md (US1 to US4). Work on `016-public-channel-return`; commit
only when the author asks.

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it; a test written before its change is the only allowed red.
- Addon Lua: ASCII, 120-character lines, Lua 5.1/5.3 neutral. No Cyrillic in Markdown. LF line endings.
- No new addon file, no TOC change, no new visible text (research R7): no locale file changes.
- Line numbers below are hints from the code before this spec; find each place by the quoted text (they shift after
  the first edit of a file).
- `--force` for releases with open markers (`tools/`, `.github/workflows/release.yml`, `tests/tools/verify_force_test.mjs`)
  is already in the working tree and is not part of these tasks.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US4)

---

## Phase 1: Setup

- [X] T001 Run `npm run check` and `npm test` from the repository root. Note the marker count (1: V51) and the test
  count (870) for the hand-over.

---

## Phase 2: Foundational (the switch, as shipped)

**Purpose**: the channel ships on, and every test runs it as shipped (research R4, contract S1, T1). Every story
depends on this phase.

- [X] T002 In `OneKeyFishing/Exchange/Channel.lua` set `Channel.AVAILABLE = true` (`Channel.AVAILABLE = false`,
  about line 14) and replace the comment above it ("V19 failed in game (2026-11-06) ...", two lines) with: V19 failed on 2026-11-06 (spec 010 switched the channel off) and passes again since
  2026-11-16 (`docs/forever-api.md`); `false` is the kill switch: no join, a leftover channel left once at login
  (spec 004 FR-026, spec 016). Update the file's header comment (lines 1-5) to say the channel ships (spec 016).
- [X] T003 In `tests/wow.lua`: in the header comment (line 78) replace the `channel_on` line with
  `channel_off = true (before loading) switches the channel off (the kill switch; it ships on, spec 016)`; in the
  loader (lines 2004-2006) replace the `channel_on` block with `if ... "Channel.lua" and rawget(_G, "channel_off")
  then ns.Channel.AVAILABLE = false end`, comment "a release without the channel (spec 010); it ships on (spec
  016)"; in `NIL_GAME_DATA` (line 2203) replace `channel_on = true` with `channel_off = true`.
- [X] T004 [P] Remove the line `channel_on = true` (and a comment that says the channel ships off, where the test's
  header has one) from every test that sets it: `tests/exchange/channel/` `ban_test.lua`, `join_lock_test.lua`,
  `join_twice_test.lua`, `joining_test.lua`, `late_join_test.lua`, `lock_test.lua`, `move_leave_joining_test.lua`,
  `move_leave_test.lua`, `not_allowed_test.lua`, `own_leave_test.lua`, `refused_test.lua`, `rejoin_leave_test.lua`,
  `reload_cut_test.lua`, `reload_left_test.lua`, `reload_lock_test.lua`, `reload_rejoined_test.lua`,
  `reload_test.lua`, `sim_test.lua`, `slot_test.lua`; `tests/exchange/comm/channel_path_test.lua`;
  `tests/exchange/share/channel_game_test.lua`, `channel_sessions_test.lua`; `tests/ui/notice_channel_test.lua`,
  `notice_channelbox_test.lua`, `notice_test.lua`, `shared_page_test.lua`. Confirm with `grep -rn channel_on tests`
  that nothing is left.
- [X] T005 [P] Add `channel_off = true` at the top of `tests/exchange/channel/off_test.lua` (before `load_addon`)
  and fix its header to "with the public channel switched off (the kill switch, spec 010)". In
  `tests/ui/notice_nochannel_test.lua` and `tests/ui/shared_page_nochannel_test.lua` set `channel_off = true` before
  loading instead of the `load_addon(function() ns.Channel.AVAILABLE = false end)` hook (keep the hook only if the
  file needs it for something else); headers say "the kill switch".
- [X] T006 Run `npm test`: every test passes with the channel on by default. For each test that fails, first decide
  what the failure means before touching it:
  - it checks the switched-off release on purpose (a "without the channel" case): give it `channel_off = true`;
  - it shows a real change a player would see with the channel on (for example the notice owed again where a test
    sets `shareNotice = true` without `shareNoticeChannel`, so the channel waits in the `notice` state, or a join,
    a line or a status that was not there before): that is a finding, not a test edit. If spec 004 or this spec
    asks for that behaviour (the notice once more is spec US1 scenario 2), the test's setup was outdated: give it
    `shareNoticeChannel = true` or what the case needs, with a comment why. If no spec asks for it, it is a bug:
    fix it in the addon now, the failing test being the test that fails without the fix, and list it for the
    review (T025);
  - it only assumed the channel was off without testing it (an exact count of sends or joins, a debug line): adjust
    the expectation, and note each such edit for the hand-over.

**Checkpoint**: the channel is on, and the suite runs it as players get it.

---

## Phase 3: User Story 1 - Strangers share catches through the hidden channel (Priority: P1) MVP

**Goal**: the notice, the setting, `/okf share` and `/okf debug` show the channel again; the exchange runs through it
(research R6: no code to build).

**Independent Test**: the existing tests `tests/ui/notice_channel_test.lua`, `tests/ui/shared_page_test.lua`,
`tests/exchange/share/channel_game_test.lua` and `tests/exchange/channel/sim_test.lua` pass without `channel_on`.

- [X] T007 [US1] Confirm `tests/ui/notice_channel_test.lua` passes without `channel_on`: it covers spec US1
  scenario 2 (the notice closed in 1.2.0, `OneKeyFishingDB = { shareNotice = true }` with `shareNoticeChannel`
  not set, shows once more, naming the channel, and `shareNoticeChannel` is saved when it closes). No new test.
- [X] T008 [US1] New `specs/016-public-channel-return/verification.md` (header and table as in
  `specs/004-public-channel-sync/verification.md`) with one row, **V53**: "`CHAT_MSG_ADDON` for a message in a
  custom channel names that channel in argument 8 (`name`) or argument 5 (`target`), so `CommReceive.lua` can tell
  the addon's channel from another"; evidence: Retail docs, and on 2026-11-16 the `/run` listener printed only
  prefix, text, chat type `CHANNEL` and sender; if wrong: every channel message is dropped and the channel exchanges
  nothing (checklist step 2 shows it), the check then reads the channel number in `target`; how to verify: the
  `/run` lines of `docs/forever-api.md` with the listener printing `select(5, ...)` and `select(8, ...)`, or
  `docs/checklists/public-channel.md` step 2; status "Built, waiting for the check". In
  `OneKeyFishing/Exchange/CommReceive.lua` line 175 replace the comment with
  `-- VERIFY(V53): a channel message names its channel in the name argument (or in target), as on Retail`.

---

## Phase 4: User Story 2 - The channel leaves the player's chat alone (Priority: P1)

**Goal**: hiding, numbers, slots and leaves behave as spec 004 built them; what only the game confirms carries a
marker again (research R5).

**Independent Test**: the existing tests `slot_test.lua`, `late_join_test.lua`, `own_leave_test.lua`,
`reload_left_test.lua`, `rejoin_leave_test.lua` pass without `channel_on`; so do `joining_test.lua` (a join counts on
`YOU_CHANGED` alone, FR-004) and `join_twice_test.lua` and `reload_rejoined_test.lua` (a channel of the addon's names
it did not join is left, one the player joined by hand is kept, FR-003); `npm run check` lists the new markers.

- [X] T009 [US2] In `OneKeyFishing/Exchange/Channel.lua` turn the "(not shipped, V19)" comments of this story into
  markers, each one line `-- VERIFY(Vn): <what>` above the code it marks (`npm run check` reads `VERIFY(<id>):`):
  line 159 (`RemoveFromWindows` and the filters) → `VERIFY(V21): removing the channel from every chat window and the
  CHAT_MSG_CHANNEL* filters hide all its lines`; lines 199-201 (`LeaveName`) → `VERIFY(V41): one YOU_LEFT per leave
  of addon code, answered before a later join of the name`; lines 461-462 (`OnLimit`) → `VERIFY(V23): the refused
  join at the 20-channel limit comes as this text on CHAT_MSG_SYSTEM or UI_ERROR_MESSAGE`; line 515 (the login join)
  → `VERIFY(V22): joined 30-60 s after the login, General, Trade and the player's channels keep their numbers`.
  Keep each existing explanation sentence beside its marker.

---

## Phase 5: User Story 3 - A locked or hostile channel does not disturb the player (Priority: P2)

**Goal**: the password and owner notices seen on 2026-11-16 are pinned by tests; kicks and bans carry a marker.

**Independent Test**: `password_order_test.lua` and `owner_notices_test.lua` pass; `ban_test.lua`, `lock_test.lua`,
`join_lock_test.lua` pass without `channel_on`.

- [X] T010 [P] [US3] New `tests/exchange/channel/password_order_test.lua` (contract S6, FR-005): header comment naming
  `Channel.lua` and the order seen in game. `OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }`,
  `load_addon()`, `advance(61)` (the join of index 1). Fire `CHANNEL_PASSWORD_REQUEST` with `"OneKeyFishingShare"`
  (`fire("CHANNEL_PASSWORD_REQUEST", "OneKeyFishingShare")`, as `join_lock_test.lua` does), then
  `channel_notice("CHAT_MSG_CHANNEL_NOTICE", "WRONG_PASSWORD", "OneKeyFishingShare")`. Check: the password popup was
  hidden once (`popups_hidden` of `tests/wow.lua` gains exactly one `"CHAT_CHANNEL_PASSWORD"`), index 1 is locked, exactly one join of `OneKeyFishingShare2` followed; `channel_leaves` gains one entry
  (`OneKeyFishingShare`, the leave `Lock` sends) after the password request and none after the `WRONG_PASSWORD`. Then `channel_notice(... "YOU_CHANGED", "OneKeyFishingShare2")`
  and `Channel.GetState()` gives `"in", 2`.
- [X] T011 [P] [US3] New `tests/exchange/channel/owner_notices_test.lua` (contract S6, FR-006, FR-007): join the
  main channel; a stranger "Some Stranger" sets a password
  (`channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "PASSWORD_CHANGED", MAIN, "Some Stranger")`); then
  `SET_MODERATOR` with the player's first name only (`ns.PlayerName():match("^%S+")`) changes nothing: no password
  cleared (`#channel_passwords` unchanged), `Channel.Describe()[1]` still says `owner false`; then `OWNER_CHANGED`
  with the player's full name (`ns.PlayerName()`): the password is cleared once (`channel_passwords` gains one
  `{ name = MAIN, password = "" }`), `owner true`, self-heals 1. Use the argument order of `channel_notice`
  (`event, token, channelName, player, actor`).
- [X] T012 [US3] In `OneKeyFishing/Exchange/Channel.lua`: line 378 (`OnNotice`) → replace "(research R4; not
  shipped, V19)" with "seen in game 2026-11-16: YOU_CHANGED, PASSWORD_CHANGED, WRONG_PASSWORD, OWNER_CHANGED
  (argument 2 "First Last"); SET_MODERATOR (first name only) is not read" and add above the kick and ban branches
  `-- VERIFY(V24): PLAYER_KICKED, PLAYER_BANNED and MUTED name the player in argument 2, as on Retail`; line 452
  (the popup) → `-- VERIFY(V21): hiding the password prompt in the same frame leaves no visible flash and no blocked
  action`.

---

## Phase 6: User Story 4 - A refusal by the server switches the channel off quietly (Priority: P2)

**Goal**: two `NOT_ALLOWED_IN_CHANNEL` notices stop the channel for the session, with no fallback walk (research R1,
data model, contract S2-S5, C4).

**Independent Test**: `not_allowed_test.lua`, `server_refusal_reload_test.lua` and
`server_refusal_old_record_test.lua` fail before T015-T016 and pass after; `server_refusal_login_test.lua` passes
before and after (it pins the retry at a real login); `channel_path_test.lua` sees send refusals call `OnRefused()`
and notices `OnRefused("server")`; `join_lock_test.lua` and `lock_test.lua` still move to the next fallback on a
lock (FR-010).

- [X] T013 [US4] Change `tests/exchange/channel/not_allowed_test.lua`: the first test keeps "one notice alone changes
  nothing" and the successful send in between; after the second notice expect `Channel.GetState()` == `"locked"`,
  the main channel left once, and after `advance(3600)` no join of any `OneKeyFishingShare2..6`
  (`channel_joins` holds only the main one); `ns.Channel.Describe()[1]` contains `refused server`; then `fire("PLAYER_LOGOUT")` and
  `OneKeyFishingCharDB.channelSession.refused == "server"`. Update the header to spec 016 US4. Run it: it fails
  (today the addon moves to index 2).
- [X] T014 [P] [US4] Three new files, each its own load sequence as in `tests/exchange/channel/reload_lock_test.lua`
  (`OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }`, a seeded `OneKeyFishingCharDB.channelSession`,
  `load_files(TOC_FILES)`, `fire("ADDON_LOADED", "OneKeyFishing")`, `fire("PLAYER_LOGIN")`, then `enter_world(...)`),
  since a login or a `/reload` reloads the module's locals (contract S4, FR-009):
  - `tests/exchange/channel/server_refusal_reload_test.lua`: `channelSession = { refused = "server" }`,
    `enter_world(false, true)`: `Channel.GetState()` is `"locked"`, `Channel.Describe()[1]` contains
    `refused server`, and after `advance(3600)` `#channel_joins == 0`.
  - `tests/exchange/channel/server_refusal_login_test.lua`: the same record, `enter_world(true, false)` (a real
    login): after `advance(61)` the last of `channel_joins` is `OneKeyFishingShare`, and `Describe` says
    `refused false`.
  - `tests/exchange/channel/server_refusal_old_record_test.lua`: `channelSession = { refused = true }` (written by
    1.2.0), `enter_world(false, true)`: `"locked"`, `refused game`.
  Run them: the reload and old-record files fail before T015 (`refused` is restored as a boolean today).
- [X] T015 [US4] In `OneKeyFishing/Exchange/Channel.lua`: `refused` holds `false | "game" | "server"` (comment it at
  line 44 with the data model's table). `Join` (nil result) and the `TRIAL_RESTRICTED` / `INVALID_NAME` branch set
  `"game"`. `Channel.OnRefused(reason)` (line 311): `if reason == "server" then Leave(); refused = "server";
  Notify() else Lock(current) end`; its comment says why (research R1: the server refuses every custom channel
  alike, a walk would join all six for nothing). `PLAYER_LOGOUT` stores `refused = refused`; `Restore` reads
  `refused = (saved.refused == true or saved.refused == "game") and "game" or (saved.refused == "server" and
  "server") or false`. `Describe` adds `, refused %s` with `tostring(refused)`. The `NOT_ALLOWED_IN_CHANNEL` branch
  comment (line 412): "seen in game on 2026-11-06, gone on 2026-11-16; two in a row stop the channel for the session
  (Comm.ChannelRefused, spec 016)".
- [X] T016 [US4] In `OneKeyFishing/Exchange/Comm.lua` `Comm.ChannelRefused(notice)` (line 256): when the notices
  reach `CHANNEL_REFUSALS`, reset both counts and call `ns.Channel.OnRefused("server")`; when the send refusals
  reach it, reset both and call `ns.Channel.OnRefused()`. Update its comment (contract C4). Line 312: replace
  "(not shipped, V19)" with `-- VERIFY(V25): addon messages to a channel throttle as on Retail and report
  ChannelThrottle` (ten in one frame passed on 2026-11-16).
- [X] T017 [US4] Extend `tests/exchange/comm/channel_path_test.lua` (contract C4, FR-010). The file replaces
  `ns.Channel.OnRefused` with a stand-in (`ns.Channel.OnRefused = function() refusals = refusals + 1 end`, near the
  top): make it record each call's argument too (`reasons`, a list; `refusals` stays the count the existing tests
  read). New test, appended after the existing ones: first reset both counts, since the test "two channel refusals
  in a row ..." leaves `channelRefusals` at 1 after its five refusals: fire a new join,
  `ns.Fire("CHANNEL_STATE", "in", 1, 99)` (`Comm.lua`'s `CHANNEL_STATE` handler zeroes both counts when `joins`
  changes). Then two refused channel sends (`addon_send_result.CHANNEL = 7`, as the test "two channel refusals in a
  row move to the next channel" does) give one call with no reason (`reasons[#reasons] == nil` and the count +1);
  then two `ns.Comm.ChannelRefused(true)` give one call with `"server"`; and one send refusal followed by one notice
  gives no call (the two counts stay separate). The move to the next fallback after `OnRefused()` is the real
  `Channel.lua`'s and stays covered by `join_lock_test.lua` and `lock_test.lua`. Run T013, T014, T017: all pass.

---

## Phase 7: Polish & documents (FR-012, FR-014)

- [X] T018 [P] `OneKeyFishing/README.md` "Shared catch database" and the settings list: bring back the public
  channel from the lines removed in `984eed2` (`git show 984eed2 -- OneKeyFishing/README.md`): the intro ("and
  through a hidden chat channel to every other addon user ... Two settings turn it off"), "With whom" (every other
  addon user the game lets you meet in the public channel; remove "The addon joins no chat channel ..."), the
  bullet **The public channel** (as removed, plus: if the game refuses addon data in chat channels again, the addon
  stops using the channel until the next login and `/okf share` says so), **Use the public channel** in "Turning it
  off" with the popup note, the `/okf share` line ("and whether the public channel is in use or why not"), and the
  **Shared database** settings entry. Keep "each release bundles the shared data gathered so far". Check every
  setting name and status text against `Locales/enUS.lua`.
- [X] T019 [P] `CHANGELOG.md` `[Unreleased]` → `### Added`: "The public channel is back: addon users who share no
  guild, group or friends list exchange catch data through a hidden chat channel again (WoW Forever carries addon
  data in chat channels again). **Use the public channel** on the Shared database page turns it off." (keep the
  file's line style).
- [X] T020 [P] `CLAUDE.md` (all its edits of this spec): "Hard rules" lists 016 among the features with a
  `verification.md`; module table row of `Exchange/` → "the hidden public channel (`Channel.AVAILABLE`, the
  kill switch; on since spec 016)"; Forever API bullet → drop "The addon's channel is still off in code; spec 016
  switches it on for 1.3.0" and say "the addon's channel uses them (spec 016); two refusals stop it for the session".
- [X] T021 [P] `docs/architecture/exchange.md` "Exchange/Channel.lua": replace the "Off since spec 010" paragraph
  (and the note added on 2026-11-16) with: the channel ships (spec 016); `AVAILABLE = false` is the kill switch;
  the tests switch it off with `channel_off`; a server refusal (`NOT_ALLOWED_IN_CHANNEL` twice) stops it for the
  session (`refused = "server"`), a refused send moves to the next fallback. Fix the Names bullet ("takes the channel
  out of a release whose spike failed") and the Comm paragraph at line 59 for the split of the two counts.
- [X] T022 [P] `docs/architecture/ui.md`: the paragraphs about a release without the channel (search
  `AVAILABLE`) say it is the kill switch's case, not the shipped one.
- [X] T023 [P] `docs/checklists/catch-exchange.md` step 1: replace "and the addon joins no chat channel (the public
  channel is off, spec 010)" with "and the only chat channel the addon joins is the hidden public channel
  ([public-channel.md](public-channel.md))". In `docs/checklists/public-channel.md` step 3 ("Not fishing"), add:
  "`/okf debug` shows `refused false`; after a refusal by the server it shows `refused server`, the state is locked
  and no fallback is joined until the next login (spec 016 US4)".
- [X] T024 [P] `specs/004-public-channel-sync/verification.md`: in the rows V21-V25 and V41, add to the 2026-11-16
  note "markers back in `Exchange/Channel.lua` / `Comm.lua` (spec 016)" where T009, T012, T016 placed one.
  `docs/release-plan.md` 1.3.0 section: add "the channel's markers (V21-V25, V41, and V53 of
  `specs/016-public-channel-return/verification.md`) block `npm run build` until the checklist runs or the author
  accepts them or releases with `--force`".
- [X] T025 Review (FR-012, plan note 7): read `OneKeyFishing/Exchange/Channel.lua`, the channel path of
  `OneKeyFishing/Exchange/Comm.lua` and the channel part of `OneKeyFishing/Exchange/CommReceive.lua` against
  `docs/forever-api.md` "Verified in game" (2026-11-06 and 2026-11-16 entries): every notice token, argument position,
  name shape ("First Last") and event the code reads. A real hole (like V53) is fixed with a test that fails without
  it, or marked `VERIFY` with a row in `specs/016-public-channel-return/verification.md` when only the game can tell;
  a low item goes to `docs/tech-debt.md`. Report what was found.
- [X] T026 Run `npm run check` (lists V51 and the new markers V21-V25, V41, V53) and `npm test`; `grep -rn "not shipped"
  OneKeyFishing/Exchange` finds nothing; `grep -rn "channel_on" tests` finds nothing. Report to the author: test
  count, marker list, and the in-game checklist `docs/checklists/public-channel.md` to run on this build (step 2
  with a non-Battle.net-friend, step 4 with a third account).

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 (T002 → T003 → T004/T005 in parallel → T006) → user stories.
- US1 (T007-T008), US2 (T009), US3 (T010-T012) and US4 (T013-T017) depend on Phase 2 only. T009, T012 and T015 edit
  `Channel.lua`: run them one after another (US2, US3, US4 order). T016 after T015 (it calls `OnRefused("server")`).
- Within US4: T013 and T014 first (seen failing), then T015, T016, then T017.
- Polish (T018-T024) after the stories; T025 (review) after them; T026 last.

## Parallel Example

```text
After T003:  T004 (remove channel_on)  ||  T005 (channel_off in three tests)
US3 tests:   T010 (password order)     ||  T011 (owner notices)
Polish:      T018 README || T019 CHANGELOG || T020 CLAUDE.md || T021 exchange.md || T022 ui.md || T023 || T024
```

## Implementation Strategy

- **MVP**: Phases 1-3 (the switch on, the suite as shipped, the notice and status back): the channel works for
  players as in spec 004.
- Then US4 (the one behaviour change, the protection against a second server refusal), then US2 and US3 (markers and
  pinning tests), then the documents. Release 1.3.0 waits for the in-game checklist or the author's `--force`.
