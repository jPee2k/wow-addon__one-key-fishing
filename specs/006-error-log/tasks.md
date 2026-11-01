---

description: "Task list for the error log"
---

# Tasks: Error Log

**Input**: Design documents from `specs/006-error-log/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md), [verification.md](verification.md)

**Tests**: requested by FR-015; each story writes its tests first and sees them fail.

**Branch**: `002-shared-db`, one separate commit for the whole feature, made only when the author asks.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1, US2, US3 of spec.md
- Paths are from the repository root; addon files are under `OneKeyFishing/`.

---

## Phase 1: Setup

**Purpose**: the lint and the test harness know the two new globals.

- [X] T001 [P] Add `geterrorhandler` and `debugstack` to `read_globals` in `.luacheckrc`.
- [X] T002 [P] In `tests/wow.lua`: a global `lua_errors = {}`; `geterrorhandler()` returns the current handler, by
  default one that appends `tostring(err)` to `lua_errors`; `take_errors()` returns the list and starts a new one;
  `debugstack(level, top)` returns `debug.traceback("", level)` without its header line, cut to its first `top`
  lines. In `test()`, after the test function, a non-empty `lua_errors` fails the test with its messages, and
  the list is wiped either way. `load_addon` raises with the messages when `lua_errors` is not empty after the login
  events, so a handler error while loading still stops the file as before (research R5).

---

## Phase 2: Foundational

**Purpose**: the helper and the in-memory log that every story uses.

- [X] T003 Write `tests/core/errors_test.lua` (load with `load_addon()`), helper cases, run them and see them fail:
  `ns.Safe("ctx", fn, 1, nil, 3)` passes three arguments with the nil kept and returns `true` plus `fn`'s results; a
  failing `fn` returns `false`, adds one message to `lua_errors` (read and wipe it in the test), and leaves one entry
  in `ns.GetErrors()` with `context` `"ctx"`, the message, `version` `ns.version`, `count` 1, `first == last`, and a
  `stack` of at most 10 lines; with `time` replaced by a failing function the error still reaches `lua_errors` once
  and `ns.Safe` returns `false`; `error({})` is recorded with its text form (a message starting with `table:`).
- [X] T004 In `OneKeyFishing/Core/Core.lua`, above the event dispatch: `ERROR_LOG_SIZE = 30`,
  `ERROR_STACK_LINES = 10`; `local errorLog = {}` (in memory until the saved variables load); `AddError(log, entry)`
  (plain append for now); `RecordError(context, err, stack)` building the entry of data-model.md (`message` is
  `tostring(err)`, `first` and `last` are `time()`, `count` 1); `ns.Safe(context, fn, ...)` per contracts/api.md:
  `select("#", ...)` and `{ ... }`, `xpcall` of a closure calling `fn(unpack(args, 1, n))`, a message handler that
  takes `debugstack(2, ERROR_STACK_LINES, 0)`, calls `pcall(RecordError, context, err, stack)` and returns
  `geterrorhandler()(err)`; the handler carries `-- VERIFY(V42): <the assumption of verification.md>`;
  `ns.GetErrors()` returns `errorLog`. A short comment above says why (research R1). T003 passes.

**Checkpoint**: `npm test -- core/errors` passes; nothing calls `ns.Safe` yet.

---

## Phase 3: User Story 1 - One failing module no longer stops the others (Priority: P1) MVP

**Goal**: a failing handler, listener or command no longer skips the others, and still reaches the game's handler.

**Independent Test**: three listeners of one message and three handlers of one event, the second failing: the first
and third run, and `lua_errors` holds one message per dispatch.

- [X] T005 [US1] Extend `tests/core/errors_test.lua` and see the cases fail: `ns.On` three listeners of a test
  message, the second raising; `ns.Fire(message, "a", nil, "c")` runs the first and third with the same three
  arguments in order, one entry with `context` the message name; `ns.RegisterEvent` three handlers of a test event,
  the second raising; `fire(event, 1)` runs the first and third with `(event, 1)`, one entry with `context` the
  event; a command appended to `ns.COMMANDS` whose `run` raises (removed again at the end of the test):
  `SlashCmdList.ONEKEYFISHING("<name> x")` records `context` `"/okf <name>"`; a listener that fires a second message
  whose listener fails: one entry for the inner message, the outer listeners keep running.
- [X] T006 [US1] In `OneKeyFishing/Core/Core.lua`: the `OnEvent` script calls `ns.Safe(event, fn, event, ...)` for
  each handler; `ns.Fire` calls `ns.Safe(message, fn, ...)` for each listener; the slash dispatcher calls
  `ns.Safe("/okf " .. name, command.run, rest)`. The comments above the dispatchers say each handler runs on its own.
  T005 passes.
- [X] T007 [US1] Run the whole `npm test`: every existing test passes. A test that now fails on `lua_errors` showed a
  handler error the old code also had; fix the test's setup or stub, not the check, and list any such case in the
  implementation summary for the author.

**Checkpoint**: Story 1 works on its own; the log exists only in memory.

---

## Phase 4: User Story 2 - The developer reads recent errors in the debug report (Priority: P2)

**Goal**: the log survives `/reload` and shows in `/okf debug`.

**Independent Test**: record an error, build the report: the "Errors" section lists it; on an empty log it reads
"none"; an error recorded before `ADDON_LOADED` is in `OneKeyFishingDB.errors` after it.

- [X] T008 [US2] Create `tests/core/errors_load_test.lua` (its own fresh Lua state): at the top `load_files(TOC_FILES)`
  and `ns.Safe` of a failing function (read and wipe `lua_errors`), then `fire("ADDON_LOADED", "OneKeyFishing")`; a test
  checks the entry is in `OneKeyFishingDB.errors` and `ns.GetErrors() == OneKeyFishingDB.errors`. Extend
  `tests/core/errors_test.lua`: `ns.Debug.Report()` holds `-- Errors --` followed by `  none` on an empty log; with two
  errors recorded (advance the clock between them) the newer one is listed first, each with its count, context, times,
  version, message and stack lines in the format of contracts/api.md.
- [X] T009 [US2] In `OneKeyFishing/Core/Core.lua`: `errors = {}` in `DB_DEFAULTS` with a comment (data-model.md);
  in the own `ADDON_LOADED` handler, after `ns.db` is set, merge the in-memory entries into `ns.db.errors` with
  `AddError` and set `errorLog = ns.db.errors`.
- [X] T010 [US2] In `OneKeyFishing/Core/Debug.lua`: a `Section(lines, "Errors", ...)` after "Game settings" and before
  "Addon settings", walking `ns.GetErrors()` backwards: `"%dx %s, %s, %s"` (count, context, the times as
  `date("%Y-%m-%d %H:%M:%S")`, joined with " to " when `first ~= last`, version), then the message and each stack
  line indented by four spaces; `none` when empty. T008 passes.
- [X] T011 [P] [US2] In `OneKeyFishing/README.md`, "Reporting bugs": one or two sentences saying the report ends with
  the addon's recent errors ("Errors"), so a Lua error text is no longer needed when it is listed there.

**Checkpoint**: Stories 1 and 2 work; the log can still grow without a limit.

---

## Phase 5: User Story 3 - The log stays small and current (Priority: P3)

**Goal**: at most 30 entries, repeats counted, other versions dropped.

**Independent Test**: 40 distinct errors, then one error 100 times: 30 entries, the repeated one with count 100; a
saved log of another version is empty after the load.

- [X] T012 [US3] Extend `tests/core/errors_test.lua` and see the cases fail: the same failure twice (clock advanced)
  gives one entry, `count` 2, `last` the later time, `first` unchanged, and it is the last entry; the same message
  under two contexts gives two entries; 35 distinct errors leave 30, the first five gone; a repeat of the oldest
  moves it to the end so the next new error drops the second oldest. In `tests/core/errors_load_test.lua`, as
  `migrations_test.lua` does: set `OneKeyFishingDB = { schema = 1, errors = { <an entry of version "0.9.0">, <an
  entry of ns.version> } }` and fire `ADDON_LOADED` again: only the second is kept; an in-memory entry equal to a
  saved one adds its count to it.
- [X] T013 [US3] In `OneKeyFishing/Core/Core.lua`: `AddError` finds the entry with the same `context` and
  `message`, removes it from its place, adds `entry.count` to it, takes `entry.last`, and appends it; otherwise it
  appends the new entry; then while `#log > ERROR_LOG_SIZE` it removes index 1 (research R3). In `ADDON_LOADED`,
  build the kept list from `ns.db.errors` entries whose `version == ns.version` before merging the in-memory ones
  (research R4). T012 passes.

**Checkpoint**: all three stories pass `npm test -- core/errors`.

---

## Phase 6: Polish and cross-cutting

- [X] T014 [P] In `OneKeyFishing/Core/Spike.lua`: a section `"Error log (V42)"` added to `BuildReport` before the last
  section call, that runs `ns.Safe("spike", fail)` with a local `fail` that calls `error("OneKeyFishing spike test
  error")` (not the global `error` passed directly, which would place the error in `Core.lua`; contracts/api.md), and
  prints its first result, the entry's count and the first line of its stack; extend `tests/ui/spike_test.lua`: the
  report holds the section, and the test reads and wipes `lua_errors` (one message).
- [X] T015 [P] In `docs/checklists/spike.md`: a "Part 5: error log (V42), section "Error log (V42)"" with one step
  E1: `/console scriptErrors 1`, `/okf spike`; expected: the popup (or BugSack) shows "OneKeyFishing spike test
  error" with a stack that starts in `Spike.lua`, once per run; `/okf debug` lists it under "Errors" with the count of
  runs; `/console scriptErrors 0` afterwards. Mention `specs/006-error-log/verification.md` in "Report back".
- [X] T016 [P] In `docs/architecture/core.md`: `ns.Safe` and `ns.GetErrors` in the Core.lua bullets (each
  dispatcher runs handlers through `ns.Safe`, why, and that a caller of `ns.Fire` no longer sees a listener's
  error); an `errors` row in the `OneKeyFishingDB` table (written by Core.lua); the "Errors" section in the
  Core/Debug.lua paragraph.
- [X] T017 [P] In `CLAUDE.md`: the `Core/Core.lua` row names the protected dispatch and the error log; "features 002
  to 005 have one" becomes "002 to 006".
- [X] T018 [P] In `CHANGELOG.md` under `[Unreleased]`: "Changed": a failing part of the addon no longer stops the
  others from getting the same event or message; "Added": the debug report lists the addon's recent errors.
- [X] T019 Run `npm run check` and `npm test`; both pass; `npm run check` lists V42 among the open markers. Leave the
  commit to the author.

---

## Dependencies and execution order

- T001 and T002 first (T002 before any test runs). T003 then T004.
- US1 (T005-T007) needs T004. US2 (T008-T011) needs T004; its tests use errors recorded through `ns.Safe` only, so
  it does not need US1. US3 (T012-T013) needs T009 (the load merge it filters).
- Polish: T014 needs T004; T015-T018 touch only documents and can run any time after the design; T019 last.
- Within a story: the test task, then the code task, all in `tests/core/errors_test.lua` (and
  `tests/core/errors_load_test.lua`) and `OneKeyFishing/Core/Core.lua`, so the stories run one after another, not in
  parallel.

## Parallel examples

```text
Phase 1:   T001 (.luacheckrc)  ||  T002 (tests/wow.lua)
US2:       T010 (Core/Debug.lua) after T008, with T011 (README.md) alongside
Polish:    T014 (Spike.lua)  ||  T015 (spike.md)  ||  T016 (core.md)  ||  T017 (CLAUDE.md)  ||  T018 (CHANGELOG.md)
```

## Implementation strategy

- **MVP**: Phases 1-3. The helper and the three dispatchers already stop one failure from hiding the others, which
  is the only part a player feels.
- **Then** US2 (the report and persistence), US3 (cap, repeats, versions), the polish, and one commit when the
  author asks.
