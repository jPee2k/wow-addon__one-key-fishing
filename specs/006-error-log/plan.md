# Implementation Plan: Error Log

**Branch**: `002-shared-db` (one separate commit on the current branch; no branch of its own) | **Date**: 2026-11-01 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/006-error-log/spec.md`

## Summary

One helper, `ns.Safe(context, fn, ...)` in `Core/Core.lua`, runs a function under `xpcall`, which passes the arguments
on in the game as in Blizzard's own code. Its message handler runs at the point of the error. It takes the stack there,
records the error, then calls `geterrorhandler()(err)` and returns the error itself, the pattern Ace3 uses on Mainline,
so BugSack and the `scriptErrors` popup see the same error with the same stack as today (research R1, R2).

The three dispatchers in `Core/Core.lua` call each handler through it: the event dispatcher (context: the event
name), `ns.Fire` (the message name) and the slash dispatcher (`/okf <command>`). Nothing else is wrapped.

The log is `OneKeyFishingDB.errors`, a list of at most 30 entries ordered by last occurrence. A repeat of the same
context and message counts into its entry and moves it to the end. Before the saved variables load, the log lives in
memory. Core's `ADDON_LOADED` handler drops saved entries of another addon version and adds the in-memory ones
(research R3, R4).

`Core/Debug.lua` gets an "Errors" section over `ns.GetErrors()`, newest first. The temporary spike gets one section
that runs a deliberate error through `ns.Safe`, so the author can check in game that the error reaches the game's
handler with the right stack (V42).

## Technical Context

**Language/Version**: Lua 5.1 (WoW Forever 1.60.1, Mainline API); tests in fengari (Lua 5.3); Node.js 18+ for tools.

**Primary Dependencies**: `xpcall`, `pcall`, `unpack`, `time`, `date` (already used); `geterrorhandler` and
`debugstack`, both used by Blizzard's own code in the 1.60.1 client export (`Blizzard_SharedXMLBase/ErrorUtil.lua`,
`Blizzard_ScriptErrors/Blizzard_ScriptErrors.lua`). The two new globals go into `.luacheckrc` `read_globals`.

**Storage**: new account-wide field `OneKeyFishingDB.errors` (default `{}`), filled by `ApplyDefaults`; `DB_SCHEMA`
stays 1. Shape in [data-model.md](data-model.md).

**Testing**: `npm test`. `tests/wow.lua` gets stubs for `geterrorhandler` and `debugstack`, and `take_errors()`. The
default handler collects errors in `lua_errors`, and `test()` fails a test that leaves an error there, so a handler
failure still fails a test as it does today (research R5). `load_addon` also fails when the login events left an error
there. New files `tests/core/errors_test.lua` and `tests/core/errors_load_test.lua` (cases that need a fresh load);
`tests/ui/spike_test.lua` extended.

**Target Platform**: WoW Forever client (Windows/macOS), Interface 16001.

**Project Type**: game addon (single Lua project).

**Performance Goals**: no noticeable cost: no allocation per handler call (research R6).

**Constraints**: Lua 5.1 only; ASCII; lines up to 120; layer 0 (Core) only, apart from the report section; no new
visible text, command, setting, frame or message.

**Scale/Scope**: about 50 lines of addon code in `Core/Core.lua`, 15 in `Core/Debug.lua`, 10 in `Core/Spike.lua`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
| --- | --- | --- |
| I. Blizzard policy | No game action, no automation; errors stay inside the client | Pass |
| II. Language-independent | The report section is English like the rest of the report; no new `L` key, so no translation | Pass |
| III. Safe, restorable state | A new field with a default, nothing renamed or reshaped: no `DB_SCHEMA` bump | Pass |
| IV. Verified Forever API | `geterrorhandler` and `debugstack` read from the client export; the behaviour in game is V42 with a `VERIFY` marker and a spike step; the two globals go into `.luacheckrc` | Pass |
| V. Checked and tested | `errors_test.lua` and `errors_load_test.lua` cover FR-015; `test()` keeps failing on handler errors; Lua 5.1 safe (`xpcall` with arguments, as the game's own code uses it) | Pass |
| VI. Module boundaries | Core only; `Debug.lua` reads `ns.GetErrors()`; no command, no message; the smallest change: three call sites | Pass |

Re-check after Phase 1: unchanged, all pass. No complexity tracking needed.

## Project Structure

### Documentation (this feature)

```text
specs/006-error-log/
|-- spec.md
|-- plan.md              # this file
|-- research.md          # R1-R7
|-- data-model.md        # the log and its entries
|-- contracts/api.md     # ns.Safe, ns.GetErrors, the dispatchers, the report section
|-- quickstart.md        # what the tests prove, the in-game step
|-- verification.md      # V42
|-- checklists/requirements.md
`-- tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/Core/Core.lua      # ns.Safe, the log, the three dispatchers, DB default, ADDON_LOADED merge
OneKeyFishing/Core/Debug.lua     # the "Errors" section
OneKeyFishing/Core/Spike.lua     # VERIFY(spike): one "Error log" section (V42)
.luacheckrc                      # geterrorhandler, debugstack
tests/wow.lua                    # stubs; test() fails on collected errors
tests/core/errors_test.lua       # new
tests/core/errors_load_test.lua  # new: the early buffer and the version drop
tests/ui/spike_test.lua          # extended
docs/architecture/core.md        # ns.Safe, the field, the report section
docs/checklists/spike.md         # the V42 step
CLAUDE.md                        # Core.lua row; features with verification.md
CHANGELOG.md, OneKeyFishing/README.md
```

**Structure Decision**: everything stays in `Core/Core.lua`, next to the dispatchers it protects. A separate
`Core/Errors.lua` would add a TOC entry and a load-order rule for about 50 lines (research R7).

## Complexity Tracking

None.
