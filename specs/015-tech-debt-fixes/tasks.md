---

description: "Task list for spec 015, tech debt fixes for 1.3.0"
---

# Tasks: Tech Debt Fixes for 1.3.0

**Input**: Design documents from `specs/015-tech-debt-fixes/`

**Prerequisites**:
- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/module-api.md](contracts/module-api.md), [quickstart.md](quickstart.md)

**Tests**: required. Spec FR-009 and constitution Principle V ask for a test that fails without its fix. Each test
is written first, and its failure is seen before the fix.

**Organization**: grouped by the user stories of spec.md (US1 to US3). Work on `015-tech-debt-fixes`; the whole
change is one bugfix commit (spec FR-010), made only when the author asks.

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it; a test written before its fix is the only allowed red.
- Addon Lua: ASCII, 120-character lines, Lua 5.1/5.3 neutral.
- No Cyrillic in Markdown.
- Write files with LF line endings (`.gitattributes` `eol=lf`).
- No new addon file and no TOC change. No new visible text (spec FR-011), so no locale file changes.
- No copies: a step two test files need lives once in `tests/wow.lua` (`docs/development.md`); a rule two addon
  files need lives once in its module (the same-client key: `Node:ClientKey`, research R5).
- A test file runs in a fresh Lua state, so a real login and a `/reload` each need their own file.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US3)

---

## Phase 1: Setup

- [X] T001 Run `npm run check` and `npm test` from the repository root. Note the marker count (1: V51) and the test
  count (853) for the hand-over.

---

## Phase 2: Foundational (test helpers)

**Purpose**: the login and reload tests of US1 and US2 share their loading steps; no addon change.

- [X] T002 In `tests/wow.lua`, add `function fishing_ready()` above `enter_fishing_mode`: `known_spells[7620] = true`
  and ``bindings["ONEKEYFISHING_ACTION"] = { "`" }`` (the fishing spell known, the key bound; it touches neither
  `ns.db` nor `in_combat`, so it can run before the addon loads and in a fight test). `enter_fishing_mode()` calls it
  in place of those two lines; the rest of `enter_fishing_mode` stays. Comment both.
- [X] T003 In `tests/wow.lua`, add `function login_with(db, charDB, isInitialLogin, isReloadingUi)` next to
  `load_addon`, and move the shared steps of both into one local function so neither copies the other: set
  `OneKeyFishingDB, OneKeyFishingCharDB = db, charDB`, `load_files(TOC_FILES)`, the empty bundled seed as in
  `load_addon` (`bundled_seed = ns.SeedData`, `ns.SeedData = { ... }`), `fire("ADDON_LOADED", "OneKeyFishing")`,
  `fire("PLAYER_LOGIN")`, `fire("PLAYER_ENTERING_WORLD", isInitialLogin, isReloadingUi)`, `check_no_errors()`.
  `load_addon(beforeLogin)` keeps its signature and behaviour (saved tables untouched, initial login, no advance);
  `login_with` then runs `advance(1)` for the resume delay of `Fishing/Mode.lua` (`RESUME_DELAY`). Comment it as
  "a login or a /reload with the given saved data (spec 015)".

**Checkpoint**: `npm test` still passes (853).

---

> **Revision, review 4 (2026-11-16): Phase 3 (T004-T009) reverted; T002-T003 stay (US2 uses them).** The game writes saved variables only at a logout,
> a `/reload` or the exit, never at a crash, and `PLAYER_LOGOUT` restores the CVars (emptying the record) before that
> write, so a crash leaves no record on disk on any character; a disconnect logs out and restores as before. The
> account-wide record (US1, FR-001 to FR-004, SC-001, the schema 2 migration, V52) was built and reverted at the
> author's choice; the CVar record stays per character as in 1.2.0. US2 and US3 stand. `docs/tech-debt.md` "History"
> records the dropped item.

---

## Phase 3: User Story 1 - Game sound comes back on any character after a crash (Priority: P1) 🎯 MVP

**Goal**: the CVar record is account-wide (`OneKeyFishingDB.savedCVars`), restored at any character's login; a 1.2.0
character record is migrated (schema 2).

**Independent Test**: a record in `OneKeyFishingDB.savedCVars` with a fresh character table is restored at login;
a schema-1 character record is moved into the account record (contract D0-D4, M1, M2, M6).

### Tests for User Story 1 (write first, see them fail)

- [X] T004 [P] [US1] In `tests/core/migrations_test.lua`: change every expected schema `1` of the existing tests to
  `2` (the test names that say "schema stays 1" say "schema becomes 2"). Add tests: (a) D2: account
  `{ schema = 1, settings = {}, savedCVars = { Sound_MusicVolume = "0.3" } }` and character
  `{ schema = 1, savedCVars = { Sound_MusicVolume = "0.8", autoLootDefault = "0" } }` load with
  `OneKeyFishingDB.savedCVars` = `{ Sound_MusicVolume = "0.8", autoLootDefault = "0" }` (the character's entry wins)
  and `OneKeyFishingCharDB.savedCVars == nil`, no chat line; (b) D3: a schema-1 character without `savedCVars` leaves
  `OneKeyFishingDB.savedCVars == nil`; (c) D1: a new player has no `savedCVars` in either table.
- [X] T005 [P] [US1] Create `tests/fishing/cvar_other_character_test.lua` (header comment: spec 015 US1, contract
  M2, M6). At the top: CVars `Sound_MusicVolume = "0"`, `Sound_AmbienceVolume = "0.2"` (changed by hand since the
  crash), `autoLootDefault = "1"` through `C_CVar.SetCVar`; `fishing_ready()`; then
  `login_with({ schema = 2, settings = { splashFocus = true, gear = false, camera = false }, savedCVars = {
  Sound_MusicVolume = "0.6", Sound_AmbienceVolume = "0.5", autoLootDefault = "0" } }, nil, true, false)` (character
  B, never seen). Tests: (a) music back to `"0.6"`, auto loot to `"0"`, ambience stays `"0.2"`; (b) the line
  `ns.L["Restored game settings from an unfinished fishing session."]` was printed once (`chat_count`); (c)
  `ns.db.savedCVars == nil` and `ns.charDB.savedCVars == nil`; (d) a second `fire("PLAYER_LOGIN")` (character A
  later) prints no new line; (e) `ns.charDB.gearSwap == nil` (gear untouched); (f) `ns.Mode.Enter()` with the focus
  on, then `ns.Mode.Exit()`, brings music back to `"0.6"` (US1 scenario 5).
- [X] T006 [P] [US1] In `tests/fishing/cvar_restore_test.lua` and `tests/fishing/cvar_sync_test.lua`: replace every
  `ns.charDB.savedCVars` with `ns.db.savedCVars` (reads and the records the tests write), and add to
  `cvar_restore_test.lua` a test "the record is account-wide": entering fishing mode writes `ns.db.savedCVars` and
  leaves `ns.charDB.savedCVars == nil` (M1). Update the header comment of each file if it names the character DB.

### Implementation for User Story 1

- [X] T007 [US1] In `OneKeyFishing/Core/Core.lua`: `DB_SCHEMA = 2`; `Migrate(data, migrations, account)` calls
  `migrations[version](data, account)`; in `ADDON_LOADED`, `Migrate(OneKeyFishingDB, MIGRATIONS.db)` stays first
  and the character call becomes `Migrate(OneKeyFishingCharDB, MIGRATIONS.charDB, OneKeyFishingDB)` (comment: the
  account table is migrated first and handed in). Add `MIGRATIONS.charDB[2] = function(data, account)`: when
  `data.savedCVars` is a table, copy each entry into `account.savedCVars` (create it on demand), "overwriting an
  entry of the same name (the character's is older, research R2)", then `data.savedCVars = nil`. No
  `MIGRATIONS.db[2]` entry (a new optional field). In the `DB_DEFAULTS` comments, name `savedCVars` (no default: nil
  when empty).
- [X] T008 [US1] In `OneKeyFishing/Fishing/Mode.lua`: replace every `ns.charDB.savedCVars` with
  `ns.db.savedCVars` (`RestoreSaved`, `DropEmptyRecord`, `SyncCVars`, `RestoreCVars`, the `PLAYER_REGEN_DISABLED`
  handler); update the file header ("saved to the character DB" -> the account-wide DB, because the game keeps the
  CVars for the whole installation; spec 015) and the `PLAYER_LOGIN` comment (any character restores a crash's
  record).
- [X] T009 [US1] In `OneKeyFishing/Core/Debug.lua` line 157: read `ns.db.savedCVars` instead of
  `ns.charDB.savedCVars`. Run `grep -rn "charDB.savedCVars" OneKeyFishing tools tests` and confirm only the
  migration (Core.lua) and its test name it.

**Checkpoint**: T004-T006 pass; `npm test` green.

---

## Phase 4: User Story 2 - A /reload keeps the settings the player changed while fishing (Priority: P2)

**Goal**: the player-owned rows survive a `/reload` in `charDB.resumeOwned`; a real login or a failed resume drops
them (contract M3-M5).

**Independent Test**: a hand-raised music volume stays through the logout, the resume and the exit.

### Tests for User Story 2 (write first, see them fail)

- [X] T010 [US2] In `tests/fishing/cvar_sync_test.lua` (splash focus section), add tests: (a) M3: focus on, music
  `"0.4"`, enter fishing mode (music `"0"`), set music to `"0.7"` by hand, `fire("PLAYER_LOGOUT")`: music `"0.7"`,
  `ns.charDB.resumeMode == true`, `ns.charDB.resumeOwned.Sound_MusicVolume == true`, ambience back to the player's
  value and not in `resumeOwned`; (b) M3: a logout with no hand change leaves `ns.charDB.resumeOwned == nil`. Leave
  the mode at the end of each test (`ns.Mode.Exit()`, clear `resumeMode` and `resumeOwned`) as the existing logout
  test does.
- [X] T011 [P] [US2] Create `tests/fishing/cvar_reload_test.lua` (header comment: spec 015 US2, contract M4, M5).
  At the top: CVars music `"0.7"`, ambience `"0.5"`, dialog `"1.0"`; `fishing_ready()`; then
  `login_with({ schema = 2, settings = { splashFocus = true, gear = false, camera = false } }, { schema = 2,
  resumeMode = true, resumeOwned = { Sound_MusicVolume = true } }, false, true)`. Tests: (a) the mode is on, music
  stays `"0.7"`, ambience and dialog `"0"`; (b) `ns.charDB.resumeOwned == nil` and `resumeMode == nil` (taken);
  (c) `ns.Mode.Exit()`: music still `"0.7"`, ambience `"0.5"`, dialog `"1.0"`; (d) `ns.Mode.Enter()` again silences
  the music (`"0"`): a fresh entry owns nothing (M5); (e) SC-002, run between (b) and (c), a second
  `/reload`: `fire("PLAYER_LOGOUT")` with the resumed mode on leaves `ns.charDB.resumeOwned.Sound_MusicVolume ==
  true` and music `"0.7"` (the owned row was never recorded, so it stays owned); clear `resumeMode` and
  `resumeOwned` afterwards so (c) and (d) see a mode that is still on.
- [X] T012 [P] [US2] Create `tests/fishing/cvar_reload_fight_test.lua` (spec 015 FR-006): CVars as T011,
  `in_combat = true`, `fishing_ready()`, the same `login_with(...)` as T011 (a `/reload` in a fight). Test: the mode
  is off and `ns.charDB.resumeOwned == nil`; after `in_combat = false`, `fire("PLAYER_REGEN_ENABLED")` and
  `ns.Mode.Enter()`, the music is silenced (`"0"`): nothing was kept.
- [X] T013 [P] [US2] Create `tests/fishing/cvar_login_owned_test.lua` (spec 015 FR-006, a real login is its own
  load sequence): CVars as T011, `fishing_ready()`, `login_with(<the db of T011>, { schema = 2, resumeOwned = {
  Sound_MusicVolume = true } }, true, false)` (left by a session that crashed after a `/reload`). Test:
  `ns.charDB.resumeOwned == nil`, the mode is off; `ns.Mode.Enter()` silences the music (`"0"`).

### Implementation for User Story 2

- [X] T014 [US2] In `OneKeyFishing/Fishing/Mode.lua`: move the body of `Mode.Enter` into a file-local
  `local function Enter(owned)` that sets `playerOwned = owned or {}` where it now sets `{}` (before `SyncCVars()`);
  `function Mode.Enter() Enter(nil) end` (no parameter: the minimap menu passes its own arguments to
  `Mode.Toggle`). `PLAYER_LOGOUT` with the mode on: after `RestoreCVars()` and `resumeMode = true`, set
  `ns.charDB.resumeOwned` to a copy of `playerOwned` when it has an entry, else nil. `PLAYER_ENTERING_WORLD`: read
  `local owned = resume and ns.charDB.resumeOwned or nil` and set `ns.charDB.resumeOwned = nil` next to
  `resumeMode = nil`; the delayed resume calls `Enter(owned)`. Comment each with spec 015 FR-005/FR-006.

**Checkpoint**: T010-T013 pass; `npm test` green.

---

## Phase 5: User Story 3 - A partner who relogs counts once (Priority: P3)

**Goal**: one definition of "the same client" (`Node:ClientKey`), and `Node:Activity` counts a client key once
(contract K1, K2, A1-A4).

**Independent Test**: a client heard by Battle.net, then by the group with a new tag, counts once.

### Tests for User Story 3 (write first, see them fail)

- [X] T015 [P] [US3] In `tests/exchange/share/protocol_test.lua`, add two tests (spec 015). Each sets up its own
  state with `NewNet()` and `local a = NewNode("A", "AAAAAAAA", { group = "g" })`; drive `a.node:Receive(address, via, text)`
  directly with HELLO texts `("H %s 0 1 %s"):format(tag, hash)` (4-character tag, a base32 hash different from
  `a.node:HashText()`). (1) "a partner who relogs counts once in the activity": `"b:7"` via `"bnet"` tag `"T1T1"`;
  `a.node.peers["b:7"].synced = GetTime()` (counts, not sessions); `advance(300)`; `"w:P"` via `"group"` tag
  `"T2T2"`; `"b:7"` via `"bnet"` tag `"T2T2"` (the "same client by another path" branch of `Handlers.H`). Then
  `a.node:Activity()`: `heard.group == 1`, `heard.bnet == 0`, `exchanged == 1`; then, in the same test (K1, K2):
  `a.node:ClientKey("b:7") == "T2T2"`, `ClientKey("w:Unknown") == "w:Unknown"`, `SameClient("b:7", "w:P")` true,
  `SameClient("w:Unknown", "w:Unknown")` true. (2) "different clients count apart":
  `"b:7"` tag `"T1T1"` and `"w:Q"` via `"group"` tag `"Q1Q1"` give `bnet 1, group 1`; a peer without a tag,
  `a.node.peers["w:R"] = { heard = GetTime(), via = "guild" }`, adds `guild 1` (A2); then, in the same test (K1, K2): `ClientKey("w:R") == "w:R"` (no tag),
  `SameClient("w:R", "w:Q")` false, `SameClient("b:7", "w:Q")` false (two tags).
  If `Receive` or `peers` are named differently, read `OneKeyFishing/Exchange/ShareNode.lua` and adapt; keep the
  scenario.

### Implementation for User Story 3

- [X] T016 [US3] In `OneKeyFishing/Exchange/ShareNode.lua`, next to `Node:SameClient`: add
  `function Node:ClientKey(address)` returning the `node` of `self.peers[address]` when the peer exists and has one,
  else `address` (comment: an address starts with `w:` or `b:`, so it never equals a 4-character tag; the one definition
  of "the same client", spec 015). Rewrite `Node:SameClient(a, b)` as `return self:ClientKey(a) == self:ClientKey(b)`
  (the same answers: research R5). Run `npm test -- share` to see the existing session tests still pass.
- [X] T017 [US3] In `OneKeyFishing/Exchange/ShareProtocol.lua` `Node:Activity`: iterate `pairs(self.peers)` with the
  address; a channel peer keeps today's per-address count in `heard.channel`; for any other peer take
  `local key = self:ClientKey(address)` and keep per key the peer with the latest `heard` within `HOUR` and a flag
  "synced within `HOUR`"; after the loop add 1 to `heard[path]` (whisper -> friend) of each key's latest peer and 1
  to `exchanged` per flagged key. `recent` and `lastExchange` unchanged. Update the function's comment ("per client:
  one `ClientKey` counts once, under the path heard last"; spec 015 FR-007).

**Checkpoint**: T015 passes; `npm test` green.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T018 [P] `docs/architecture/core.md`: in the `OneKeyFishingDB` table add `savedCVars` (the CVar record of
  fishing mode, account-wide because the game keeps CVars per installation; written by Mode.lua); in the
  `OneKeyFishingCharDB` row "`gearSwap`, the CVar and camera snapshots, `resumeMode`" drop "the CVar" and add
  `resumeOwned` (the player-owned rows across a `/reload`); where the migrations are described, note schema 2, its
  step and that `Migrate` hands the account table to the character steps.
- [X] T019 [P] `docs/architecture/fishing-mode.md`: the first bullet and the `SyncCVars` bullet name
  `db.savedCVars` (account-wide, restored at any character's `PLAYER_LOGIN`); the `PLAYER_LOGOUT` bullet adds
  `resumeOwned`; the player-owned bullet says the rows survive a `/reload`; add the accepted limit "two game
  accounts on one computer" (research R3).
- [X] T020 [P] `docs/architecture/exchange.md`: where the node's activity and status are described, say the counts
  are per client (`Node:ClientKey`, the key `SameClient` compares), under the path heard last; the gap until the
  other path's HELLO with the new tag (research R5).
- [X] T021 [P] `CLAUDE.md` cross-module rule "Everything fishing mode changes (CVars, gear, camera) is stored in the
  character DB" -> the CVars in the account DB (the game keeps them per installation), gear and camera in the
  character DB. Check `.specify/memory/constitution.md` Principle III still reads true (it says "saved variables",
  no change expected).
- [X] T022 [P] `CHANGELOG.md` `[Unreleased]`: add `### Fixed` with two lines: game settings changed by fishing mode
  come back after a crash or a disconnect on whichever character logs in next; a partner who logs in again no
  longer counts twice in the exchange's player count. (The `/reload` fix is part of the unreleased "Sound effects"
  page: no line.) `OneKeyFishing/README.md` already covers it (line 48, line 259): no change, confirm.
- [X] T023 [P] `docs/tech-debt.md`: remove batches 11 and 12 and the three open items; under "Fix batches" say
  every batch is fixed (batches 11 and 12 by spec 015); under "Open items" write "None."; add a History entry
  "2026-11-16, spec 015: batches 11 and 12 fixed with tests (the CVar record account-wide with a schema 2
  migration, the player-owned rows across a `/reload`, the exchange counts per client)". In `docs/release-plan.md`
  remove only the batch 11 line of the "1.2.1" section; the rest of that section stays for the author to rewrite
  when 1.3.0 is prepared.
- [X] T024 Run `npm run check` and `npm test`; compare with T001 (markers 1, tests 853 + the new ones). Run
  `grep -rn "savedCVars" OneKeyFishing docs CLAUDE.md` and confirm every mention names the account DB (the migration
  excepted); `grep -rn "\.node" OneKeyFishing/Exchange` shows no other place that compares the tags of two addresses
  (the own-tag checks `peer.node == self.tag` are not a same-client rule).
- [X] T025 Hand over: the list of changed files, the test count, and the proposed single commit message
  ("Spec 015 tech debt fixes: CVar record account-wide, player-owned rows across /reload, exchange counts per
  client"). Commit only when the author asks.

---

## Dependencies & Execution Order

- T001, then T002-T003 (the helpers the new US1/US2 test files use).
- US1 (T004-T009) before US2 (T010-T014): both change `Fishing/Mode.lua`, and the US2 tests read
  `ns.db.savedCVars`.
- US3 (T015-T017) needs neither; it can run beside US1 or US2. T016 before T017 (`Activity` calls `ClientKey`).
- Polish (T018-T023) after the stories they describe; T024-T025 last.

## Parallel Opportunities

- US1 tests: T004, T005, T006 (three files).
- US2 tests: T011, T012, T013 (new files) beside T010.
- US3 entirely beside US1/US2 (`ShareNode.lua`, `ShareProtocol.lua`, `protocol_test.lua`).
- Docs: T018-T023 touch seven different files.

```text
Example: after T002-T003, T004 + T005 + T006 + T015 at once (tests first), then T007-T009 and T016-T017, then US2.
```

## Implementation Strategy

- **MVP**: US1 alone fixes the only medium item (sound lost on another character after a crash).
- Then US2 and US3 (low), then the docs; one commit for everything (FR-010).
