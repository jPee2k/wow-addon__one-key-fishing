---

description: "Task list for spec 010, exchange fixes for Forever"
---

# Tasks: Exchange Fixes for Forever

**Input**: Design documents from `specs/010-exchange-forever-fixes/`

**Prerequisites**:
- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/exchange.md](contracts/exchange.md), [quickstart.md](quickstart.md)

**Tests**: required. Spec FR-015 and constitution Principle V ask for a test that fails without its fix. Each test
is written first, and its failure is seen before the fix.

**Organization**: grouped by the user stories of spec.md (US1 to US6). Work on `002-shared-db`; commit only when the
author asks.

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it; a test written before its fix is the only allowed red.
- Addon Lua: ASCII outside `Locales/`, 120-character lines, Lua 5.1/5.3 neutral.
- No Cyrillic in Markdown.
- Write files with LF line endings (`.gitattributes` `eol=lf`). In Python, open with `newline=''` or write bytes.
- No TOC change, so a `/reload` is enough in game.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US6)

---

## Phase 1: Setup

- [X] T001 Run `npm run check` and `npm test` from the repository root. Note the marker count (50) and the test
  count (716) for the hand-over.

---

## Phase 2: Foundational (test stubs)

**Purpose**: the stubs the stories need (data-model.md "Test stubs").

- [X] T002 In `tests/wow.lua`:
  - **`GetUnitName(unit, showServer)`**: returns `player_full_name` for `"player"` (default `"First Last"`), and
    `nil` for other units. Add `player_full_name` to the header list. Add it only if no `GetUnitName` stub exists.
  - **`channel_on`**: if `rawget(_G, "channel_on")` is true, `load_addon(beforeLogin)` sets
    `ns.Channel.AVAILABLE = true` right after `load_files(TOC_FILES)` and before `beforeLogin` and the login events.
    Add `channel_on` to the header list and to `NIL_GAME_DATA`, so an unset flag reads nil.
  - Run `npm test`: everything passes (nothing reads the new stubs yet).

---

## Phase 3: User Story 1 - Friends are reached under their real names (Priority: P1) 🎯 MVP

**Goal**: names as the game gives them; one peer per friend (contracts N1-N5, research R1).

**Independent Test**: `tests/core/names_test.lua` and `tests/exchange/comm/friends_test.lua` pass.

### Tests for User Story 1

- [X] T003 [P] [US1] Create `tests/core/names_test.lua` (header: spec 010 US1, contracts N1-N2). Cases:
  - `ns.PlayerName()` is `"First Last"`; it is `"Ann Lee"` with `player_full_name = "Ann Lee"`.
  - `ns.SameCharacter`:
    - the stub `GetNormalizedRealmName` returns `"Realm"` (`tests/wow.lua:1687`), the own realm;
    - `("First Last", "First Last")` is true;
    - `("First Last", "First Last-Realm")` and `("First Last-Realm", "First Last")` are true;
    - `("First Last", "First Last-OtherRealm")` is false (another realm is another character);
    - `("First Last-RealmA", "First Last-RealmB")` is false;
    - `("First Last", "First Other")` is false;
    - `("First", "First Last")` is false (a space is no realm separator).
  - `ns.WithRealm` is nil.
  - Run it: it fails (`PlayerName` missing; `WithRealm` present).
- [X] T004 [P] [US1] Create `tests/exchange/comm/friends_test.lua` (header: contracts N3-N4). Steps:
  - Set `friends = { { name = "Ann Lee", connected = true } }` before `load_addon()`. Check the existing stub's field
    names at `tests/wow.lua:1319` first.
  - Collect `ns.Comm.ForEachFriend` addresses: expect `"w:Ann Lee"`.
  - Then follow how `tests/exchange/share/game_test.lua` receives a HELLO. Deliver a HELLO from `"Ann Lee"` by
    `receive_addon(..., "WHISPER", "Ann Lee")`. Check that the game node's `peers` table
    (`Exchange/ShareNode.lua:39`, keyed by address) holds `"w:Ann Lee"` and no second key under a realm form. Reach
    the node the way the existing share tests do (`ns.Share.private`); the test sits in `tests/exchange/`, so the
    private-table rule allows it.
  - Run it: the address test fails today (`w:Ann Lee-<realm>`).

### Implementation for User Story 1

- [X] T005 [US1] In `OneKeyFishing/Core/Data.lua`:
  - Remove `ns.WithRealm`.
  - Rewrite `ns.SameCharacter(a, b)` per contract N2: return `a == b`, or compare the two after taking a trailing
    `"-" .. GetNormalizedRealmName()` off each (a plain-text suffix check, no pattern). A suffix of another realm
    stays, so the names differ. Keep the comment that a player of the same name on another realm is somebody else.
  - Add `ns.PlayerName()`: `return GetUnitName("player", true)`, with a comment on V11 ("First Last"; `UnitName`
    gives two values).
  - Update the comments.
  - Check `.luacheckrc`: `GetUnitName` must be in `read_globals`; add it if it is missing.
- [X] T006 [US1] Update the callers:
  - `OneKeyFishing/Exchange/Comm.lua` `Comm.ForEachFriend`: `fn("w:" .. info.name)`. Replace the `VERIFY(V11)` text
    with "the friends list names a friend as the friend's own messages do ('First Last'; a realm only when the game
    gives one)".
  - `OneKeyFishing/Exchange/Channel.lua` `IsMe`: `ns.SameCharacter(name, ns.PlayerName())`, keeping its type checks.
  - `OneKeyFishing/Core/Spike.lua`: the WHISPER to self uses `ns.PlayerName()`.
  - Grep `OneKeyFishing/` for `WithRealm` and `UnitName("player")`: none left.
  - Run `npm test`: T003 and T004 pass. Fix any existing test that built a realm address. The exchange tests use
    names like `"Me-Realm"`: keep them where they test a sender with a realm.

**Checkpoint**: US1 done.

---

## Phase 4: User Story 2 - No public channel that reaches nobody (Priority: P1)

**Goal**: the channel off; a leftover channel left once; the refusal counted (contracts C1-C4, research R2).

**Independent Test**: `tests/exchange/channel/off_test.lua` passes; every channel test passes with `channel_on`.

### Tests for User Story 2

- [X] T007 [US2] Create `tests/exchange/channel/off_test.lua` (header: contracts C1, C3, C4). Without `channel_on`:
  - After `load_addon()` and `advance(120)`, `channels_joined` is empty and `ns.Channel.GetState()` is
    `"unavailable"`.
  - **Leftover**:
    1. Before `load_addon`, make the client be in `OneKeyFishingShare`. Use the channel stubs (`chat_window_add`,
       the channel number lookup); read `tests/exchange/channel/reload_test.lua` for how a joined channel is set up.
    2. After the login events, `channel_leaves` holds that name exactly once, no chat line was printed
       (`#chat == 0` for it), and the chat windows removed it.
    3. A second `enter_world(false, true)` leaves nothing more.
  - **C4**, in a separate file: create `tests/exchange/channel/not_allowed_test.lua` with `channel_on = true` at the
    top.
    1. Join as `joining_test.lua` does.
    2. `channel_notice("CHAT_MSG_CHANNEL_NOTICE", "NOT_ALLOWED_IN_CHANNEL", "OneKeyFishingShare")` `CHANNEL_REFUSALS`
       times. Read the value from `Exchange/Comm.lua`; expose it through `Comm.private` if the tests need it.
    3. Expect the channel locked or moved: `GetState()` no longer `"joined"`, and `channel_leaves` has the name. One
       notice alone does not lock it.
    4. A notice for another channel name changes nothing.
  - Run both: they fail today.
- [X] T008 [US2] Add `channel_on = true` as the first line (after the header comment) of every test file that
  exercises the channel switched on:
  - all of `tests/exchange/channel/*_test.lua` except `off_test.lua`;
  - `tests/exchange/comm/channel_path_test.lua`;
  - `tests/exchange/share/channel_game_test.lua` and `channel_sessions_test.lua`;
  - every other file that fails once T009 sets `AVAILABLE = false` and expects the channel on. Find them by running
    `npm test` after T009.
  - Leave the files that test the switched-off state as they are: `tests/ui/notice_nochannel_test.lua`,
    `tests/ui/shared_page_nochannel_test.lua`, and the `AVAILABLE` cases in `joining_test.lua` and `game_test.lua`.
    Read them first: a test that sets `ns.Channel.AVAILABLE = false` itself keeps working either way.

### Implementation for User Story 2

- [X] T009 [US2] In `OneKeyFishing/Exchange/Channel.lua`:
  - `Channel.AVAILABLE = false`, with the comment "V19 failed in game (2026-11-06): the server refuses addon messages
    in a custom channel (NOT_ALLOWED_IN_CHANNEL); the code stays, switched off (spec 010)". Remove that line's
    `VERIFY(V19)`.
  - **Leftover**: in the `PLAYER_ENTERING_WORLD` handler, when `Gate()` is `"unavailable"`:
    - for each index of `Channel.NAMES` that `NumberOf(index)` finds, call `LeaveName(index)`;
    - remove it from the chat windows with the existing helper;
    - return before the join logic;
    - print no chat line;
    - make sure the existing `YOU_LEFT` bookkeeping (the owed leaves) does not print or rejoin.
  - **C4**: in `OnNotice`, for `token == "NOT_ALLOWED_IN_CHANNEL"` with the index of one of the addon's names, count
    a refusal and lock at the limit through the same counter Comm uses. Expose a `Comm.ChannelRefused()` that does
    what the `message.path == "channel"` branch of `Deliver` does (increment `channelRefusals`; at
    `CHANNEL_REFUSALS`, reset and `ns.Channel.OnRefused()`), and call it from both places. Channel may use Comm: both
    are layer 2.
  - The remaining `VERIFY(V20)` to `VERIFY(V25)` and `VERIFY(V41)` comments in `Channel.lua`, `Comm.lua` and
    `Share*.lua` become plain comments ending "(not shipped, V19)". Remove `VERIFY(V19)` in `Comm.lua` `SendNow` the
    same way.
  - Run `npm test`, then do T008. All pass, including T007.

**Checkpoint**: US2 done.

---

## Phase 5: User Story 3 - Checking a received record does not stutter (Priority: P2)

**Goal**: proof steps in chunks within a time budget (contracts P1-P3, research R3).

**Independent Test**: `tests/exchange/share/budget_test.lua` passes.

### Tests for User Story 3

- [X] T010 [US3] Create `tests/exchange/share/budget_test.lua` (header: contracts P1-P3). Use the node setup of
  `tests/exchange/share/protocol_test.lua` (read it first) to queue a version check of a chain with 40 links to
  walk. Cases:
  - **With a clock** whose every call adds 1 ms (an `env.clock` that counts, or `profile_ms = 0` and
    `profile_step = 1` if the node's clock is `debugprofilestop`): one `MergeOne` walks 4 to 16 links. Count the
    `ns.ProofStep` calls by wrapping it.
  - **The rest**: repeated `MergeOne` finishes the chain, and the result equals the result of an unbudgeted check.
  - **Without a clock** (`env.clock = nil`): one `MergeOne` walks exactly `PROOF_CHUNK` links, and the 40-link chain
    takes exactly 10 `MergeOne` calls (`links / PROOF_CHUNK`; the same rule gives 1024 frame steps for 4096 links,
    FR-009).
  - **The login seed check** (`ShareGame`): it walks in chunks too. Use the existing seed-chain test as the model if
    there is one; otherwise cover it through `Store.CheckSeedChains` with a small budget.
  - Run it: it fails today (32 links per step, no budget).

### Implementation for User Story 3

- [X] T011 [US3] Implement the budget:
  - `OneKeyFishing/Exchange/Share.lua`: replace `PROOF_STEPS = 32` with `PROOF_CHUNK = 4` and
    `PROOF_BUDGET_MS = 4`. Change the `VERIFY(V26)` text to "debugprofilestop measures ms; at about 0.3 ms per proof
    step a frame step stays under 5 ms". Export both through `P` in place of `PROOF_STEPS`.
  - `OneKeyFishing/Exchange/ShareProtocol.lua` `Node:MergeOne`: the verify branch loops
    `CatchDB.CheckVersion(held, record, PROOF_CHUNK, state)` while the result is `"more"` and
    `clock and clock() - started < PROOF_BUDGET_MS`. It runs at least one call, and keeps the queue's front as
    today when it stops with `"more"`. Update the comment above `MergeOne`.
  - `OneKeyFishing/Exchange/ShareGame.lua`: the seed-chain check uses `PROOF_CHUNK` with the same budget loop. Read
    how `Store.CheckSeedChains(ns.db.shared, work, PROOF_STEPS)` steps; keep its interface if possible and loop
    around it.
  - Run `npm test`: T010 passes, and the existing protocol tests still pass. Adjust a test that counted on 32 links
    per step only if it asserted that number.

**Checkpoint**: US3 done.

---

## Phase 6: User Story 4 - A friend who logged out ends the session at once (Priority: P3)

**Goal**: the hidden "No player named" line ends the session to its address (contracts O1-O2, research R4).

**Independent Test**: `tests/exchange/comm/offline_test.lua` passes.

- [X] T012 [US4] Create `tests/exchange/comm/offline_test.lua` (header: contracts O1-O2). Steps:
  1. Register an offline handler with `ns.Comm.OnOffline` that records the address.
  2. Send a whisper with `ns.Comm.Send("w:Ann Lee", ...)` and let the pump deliver it (`advance`).
  3. Fire `filter_hides("CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Ann Lee"))`.
  Expect:
  - the line is hidden;
  - the handler got `"w:Ann Lee"` once;
  - a second message queued to that address is dropped.
  Also: a line for another name is not hidden and calls nothing. Run it: the handler case fails today.
- [X] T013 [US4] In `OneKeyFishing/Exchange/Comm.lua`:
  - `Deliver` stores `notFound[text] = { at = GetTime(), address = message.address }` for both texts.
  - The pruning loop reads `.at`.
  - `HideNotFound` hides a line within `FILTER_WINDOW`. The first time it matches an entry with an address, it
    calls `Unreachable({ address = entry.address })`, which needs only `.address`, and clears that entry's address
    so a repeat line does not call twice.
  - Update both `VERIFY(V12)` texts: "a whisper to an offline player returns 0 and the game prints 'No player named
    ...', which this filter hides and takes as the offline signal".
  - Keep the `TARGET_OFFLINE` branch.
  - Run `npm test`: T012 passes.

---

## Phase 7: User Story 5 - One catch reads "1 catch" (Priority: P3)

**Goal**: singular texts for one (contracts T1-T2, research R5).

**Independent Test**: the text tests pass; `npm run check` (locale completeness) passes.

- [X] T014 [P] [US5] Tests:
  - In `tests/catalog/helpers_test.lua` (or a new `tests/catalog/catches_text_test.lua` if that file has no fitting
    place), `ns.Catalog.CatchesText(1, 1)` is `L["1 catch"]`, `(2, 1)` is `("%d catches"):format(2)`, and `(5, 3)`
    is the players form.
  - For the zone list and the minimap tooltip, extend the existing tests that read those lines
    (`tests/ui/stats_window_test.lua`, `tests/ui/minimap_tooltip_test.lua`): with one catch, the line holds the
    `"1 catch, %s"` and `"Session: 1 catch, %s"` text. Read each test first, and set one catch the way it sets the
    data.
  - Run them: they fail today.
- [X] T015 [US5] Add the three keys `L["1 catch"]`, `L["1 catch, %s"]` and `L["Session: 1 catch, %s"]` to
  `OneKeyFishing/Locales/enUS.lua` next to their plural keys, and to the nine translations. Each translation keeps
  its own plural key's wording with the singular noun:
  - `deDE.lua`: "1 Fang", "1 Fang, %s", "Sitzung: 1 Fang, %s". Match the existing session key's word for
    "Session".
  - `esES.lua` / `esMX.lua`: "1 captura", "1 captura, %s", the session key's word + "1 captura, %s".
  - `frFR.lua`: "1 prise", "1 prise, %s", the same pattern.
  - `ptBR.lua`: "1 captura", "1 captura, %s", the same pattern.
  - `ukUA.lua`, `koKR.lua`, `zhCN.lua`, `zhTW.lua`: copy the existing plural text with `%d` replaced by `1` (a
    neutral form or no plural).
  Then:
  - `OneKeyFishing/Catalog/Catalog.lua` `CatchesText`: return `L["1 catch"]` when `catches == 1`.
  - `OneKeyFishing/UI/StatsFrame.lua` `ZoneDetail` and `OneKeyFishing/UI/Minimap.lua` (line 51): pick the singular
    key when the count is 1.
  - Run `npm run check` and `npm test`: T014 passes.

---

## Phase 8: User Story 6 - The spike keeps only what is still open (Priority: P3)

**Goal**: no deliberate error; only the needed sections; old test entries dropped (contracts S1-S3, research R6).

**Independent Test**: `tests/ui/spike_test.lua` passes; `tests/core/` has the `ForgetErrors` case.

- [X] T016 [US6] Tests first:
  - In `tests/core/errors_test.lua` add a case: entries from two contexts; `ns.ForgetErrors(function(e) return
    e.context == "spike" end)` removes only those and returns their count.
  - In `tests/ui/spike_test.lua`:
    - remove the channel cases (lines 68-111) and the error-log case (line 180);
    - rewrite "the map pins and areas section survives every new call failing" (line 152) to the areas and the
      folding only: drop its pin stubs and the `CanSetUserWaypointOnMap` line, keep the area and order lines;
    - change the sections test to the kept sections (contracts S2);
    - add "a run hands on no error" (`take_errors()` empty after `ns.Spike` report);
    - add "a saved spike test entry is dropped at load": put one in `ns.db.errors` through `beforeLogin` and expect
      it gone after the login.
  - Read the file first and keep the network, area, fold and search cases.
  - Run them: they fail today.
- [X] T017 [US6] Implement:
  - `OneKeyFishing/Core/Core.lua`: add `ns.ForgetErrors(match)` next to `ns.GetErrors`. It walks `errorLog`
    backwards, removes the entries `match` accepts and returns the number removed.
  - `OneKeyFishing/Core/Spike.lua`:
    - Remove `ErrorLogSection` and `FailOnPurpose`, the chat channel section and everything only it uses (test
      channel state, notices, the password popup, `ChannelChecks`, `ChannelNumbers`, `ItemLines`, `ArgShape`), and
      `PinLines`, `ItemNameLines`, `TemplateLines` with the helpers only they use. Remove the loot lines (V1, V2, V7
      closed).
    - Keep the Network section, `HashLines` as its own section "Proof steps (V26)", `AreaLines`, `FoldLines` and the
      auction search.
    - Update the file header (what it covers now) and `BuildReport`.
    - At load (`PLAYER_LOGIN` through `ns.RegisterEvent`, after the saved variables), call `ns.ForgetErrors` for
      `context == "spike"` and a message containing "OneKeyFishing spike test error".
    - Remove the events the removed parts registered.
  - `docs/architecture/ui.md` (the Spike part) and `CLAUDE.md` (the `Core/Spike.lua` row stays; its text stays
    true): say what the spike covers now.
  - Run `npm run check` and `npm test`: T016 passes.

---

## Phase 9: Documents and the test page

- [X] T018 [P] `CHANGELOG.md` `[Unreleased]`:
  - In "Added", remove the public channel entry (lines 25-32). The channel is not part of 1.2.0.
  - From the shared catch database entry, remove any sentence that promises reaching every addon user.
  - Under "Fixed", add nothing for the channel: it was never released.
  - Add nothing for the friends path either: the exchange is unreleased, so these are fixes of an unreleased
    feature.
  - Add nothing for "1 catch": the catch tab is unreleased.
- [X] T019 [P] `OneKeyFishing/README.md`:
  - Remove the public channel. Edit lines 60, 171-195 and the settings line 288: the "Use the public channel"
    option goes, and the shared database reaches guild, group and friends (character and Battle.net).
  - Keep the rest of the exchange text. Make sure `npm run check`'s slash-command rule still passes.
- [X] T020 [P] Verification records:
  - `specs/003-guild-group-sync/verification.md`:
    - V11 "Fixed by spec 010 (names as the game gives them, the own name from GetUnitName); the friends list name
      and a sender from another realm still wait for a second player";
    - V12 "Built (spec 010): the hidden line is the offline signal; waiting for d-offline".
  - `specs/004-public-channel-sync/verification.md`:
    - V19 "Failed; the channel is off (spec 010, Channel.AVAILABLE = false)";
    - V20, V21, V22, V23, V24, V25 and V41 "Not shipped (V19, spec 010): closed by the author's decision in the spec
      010 input, not by an in-game check; the code stays, switched off";
    - V27: drop "Spike step 9" from its checks (the item lines leave the spike); the open part (a real hidden item's
      loot link) stays with `docs/checklists/fishing-mode.md` "Unknown item";
    - V26 "Budget built (spec 010): chunks of 4 links within 4 ms; waiting for the longest merge step in game".
  - `specs/006-error-log/verification.md` V42: add "the spike's test error removed (spec 010)".
- [X] T021 [P] `docs/forever-api.md`:
  - Under the names fact, add "the addon keeps names as the game gives them; its own name is
    `GetUnitName("player", true)` (spec 010)".
  - Under the channel fact, add "the addon's channel is off (spec 010)".
  - Remove the open question for the public channel's reach. Keep the friends-list and other-realm questions.
- [X] T022 [P] `CLAUDE.md`:
  - The names bullet: the addon keeps names as given; the own name is `ns.PlayerName()`.
  - The `Core/Data.lua` row: add "the own name".
  - The `Exchange/Channel.lua` part of the Exchange row: "the hidden public channel (off since spec 010:
    `Channel.AVAILABLE`)".
  - The server-refusal bullet: add "the addon's channel is off".
  - `docs/architecture/exchange.md` and `docs/architecture/core.md`:
    - the friend address;
    - `SameCharacter`;
    - `PlayerName` and `ForgetErrors`;
    - the channel off with its leftover leave and the notice refusal;
    - the proof step budget;
    - the offline line.
- [X] T023 [P] `docs/tech-debt.md`:
  - Remove batch 1 from "Fix batches" and its open items: friends' address, the channel refusal, the proof step
    cost, the offline whisper.
  - Remove the "1 catches" item, and drop it from batch 5's list.
  - Add a History line "2026-11-07, spec 010: batch 1 and '1 catches' fixed with tests; V11 (friends list, other
    realm), V12 and V26 wait for the game".
  - `docs/release-plan.md` step 1: batches 1 and 2 → "batch 1 built by spec 010; batch 2 is spec 011". Under
    step 2, the channel decision is made (off).
- [X] T024 [P] Checklists:
  - `docs/checklists/spike.md`:
    - C2, C6 and C7 become "not shipped (V19, spec 010)";
    - E1, P1, P3 and P5 "closed; removed from the spike (spec 010)";
    - the note under C9 about the channel decision says the channel is off.
  - `docs/checklists/public-channel.md`: a status line at the top, "The public channel is off in 1.2.0 (spec 010);
    this checklist applies only if it is switched on again". Untick nothing.
  - `docs/checklists/catch-exchange.md`: wherever a step expects the public channel or `Public channel: in use`,
    expect no channel. Add the friends step expectation (one peer, no "No player named").
- [X] T025 The author's 1.2.0 test page (`https://claude.ai/artifact/8bqDcm6BKLMFQgkMgySQpy`):
  - Read the page (Artifact `read`) and its `steps` collection (ArtifactData `list`). Keep every mark.
  - Edit the local copy
    `C:\Users\jpeed\AppData\Local\Temp\claude\ef033a43c823919f\9816f776-8fa2-44d8-8ca4-845217d2a837\scratchpad\okf-120-test.html`.
    If it is gone, save the page with Artifact `read` `path: "index.html"` and strip the platform skeleton up to
    `<title>`.
  - Phase `b` becomes "After spec 010", in Ukrainian like the page. Its steps:
    - `b-check` (check and test);
    - `b-channel` (no channel joined, no option);
    - `b-proof` (the spike's "Proof steps" and later the longest merge step);
    - `b-names` (the spike's WHISPER to self echoes, no "No player named");
    - new `b-spike` (no error popup; `/okf debug` shows no spike errors);
    - new `b-onecatch` ("1 catch" at a place with one catch).
  - Move `b-pool`, `b-cave` and `b-subzone` to a new phase "After spec 011 (batch 2)" before phase `d`.
  - In phase `d`, mark `d-c6` "not shipped": remove it, or note it skipped with a reason if it has a mark. Point
    `d-protect` at the channel-free text.
  - Validate the script by evaluating `PHASES` with node, as in spec 009. Publish to the same URL with a label.

---

## Phase 10: Polish

- [X] T026 Run `npm run check` and `npm test`.
  - Every test passes.
  - Grep `OneKeyFishing/` for `WithRealm`, `PROOF_STEPS`, `FailOnPurpose` and `UnitName("player")`: none.
  - The marker count goes from 50 to about 43 (V19-V25 and V41 go; V11, V12 and V26 change text).
- [X] T027 Revert check: for T005/T006, T009, T011, T013, T015 and T017, revert only that change, run its test file,
  see it fail, and restore it. Note the results.
- [X] T028 Hand-over to the author:
  - the in-game steps of quickstart.md and phase `b` of the test page;
  - the files changed;
  - the markers left (V11, V12, V26), each waiting for its step;
  - no commit until asked.

---

## Dependencies & Execution Order

- T001, then T002.
- **US1** (T003-T006) and **US2** (T007-T009) are independent. US2's T008 runs after T009.
- **US3** (T010-T011), **US4** (T012-T013) and **US5** (T014-T015) are independent of each other and of US1-US2.
  US4 and US2 both touch `Comm.lua`: do them one after the other.
- **US6** (T016-T017) after US1, since T006 also touches `Spike.lua`.
- Documents (T018-T025) after the stories; T025 last of them.
- Polish (T026-T028) last.

### Parallel opportunities

- T003 and T004; T010, T012 and T014 (different test files).
- All of T018-T024.

## Implementation Strategy

1. **MVP**: US1 + US2, both P1. The friends path works and no channel is taken.
2. US3, US4, US5: small and independent.
3. US6: the spike trim.
4. The documents and the test page, then Polish.
