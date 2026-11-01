# Research: Error Log

## R1. How the error reaches the game's handler

**Decision**: the `xpcall` message handler calls `geterrorhandler()(err)` itself, at the point of the error, and
returns `err`: the game's handler returns nothing, so `ns.Safe` returns the error on its own.

**Rationale**: inside the message handler the stack still holds the failing function. Blizzard's handler in the
1.60.1 export (`Blizzard_ScriptErrors.lua:48-60`, `HandleLuaError`) reads the stack level from
`GetErrorCallstackHeight()`, which a hand-made call must set: Blizzard's own `CallErrorHandler` and `assertsafe`
(`ErrorUtil.lua`) wrap the call in `SetErrorCallstackHeight(GetCallstackHeight() - 1)` and
`SetErrorCallstackHeight(nil)`, and so does the message handler. BugSack and the `scriptErrors` popup then show the
same file and line as today. Ace3 (`AceAddon`, `CallbackHandler`) hands errors on with `geterrorhandler()(err)` from
an `xpcall` handler on Mainline too.

**Alternatives considered**:
- Calling the handler after `xpcall` returns: the stack would show `ns.Safe`, not the failing code.
- Blizzard's `CallErrorHandler` itself: a Blizzard helper, not an API, and its height would start one frame higher,
  at our handler.
- `seterrorhandler` of our own: out of scope; it would sit between Blizzard and BugGrabber.

## R2. Lua 5.1 and the arguments

**Decision**: `xpcall(fn, OnSafeError, ...)`; `ns.Safe` returns what `xpcall` returns. The
message handler is one shared function that reads the context of the innermost `ns.Safe` from a module variable,
saved and put back around each call (`LeaveSafe` passes the results through).

**Rationale**: the game's `xpcall` passes the arguments on: Blizzard calls `xpcall(script, CallErrorHandler, frame,
...)` (`Blizzard_SharedXMLBase/FunctionUtil.lua:4`), and fengari's Lua 5.3 does the same, so there is no 5.1/5.3
difference and no closure or argument table is needed. Trailing nils are kept. Returning `xpcall`'s results gives the
caller `true, results...` or `false, err` at no cost.

**Alternatives considered**: a new handler closure per call capturing the context; simpler by three lines, but one
more allocation on every handler call (R6).

## R3. The log's order, cap and deduplication

**Decision**: a list ordered by last occurrence. A repeat (same `context` and `message`) is removed from its place,
counted and appended. Over 30 entries, the first (least recently seen) is dropped. The report walks it backwards.

**Rationale**: the order is then also the report's order (newest first) and the drop order, with no sort. A linear
search over at most 30 entries per error is nothing.

**Alternatives considered**: a ring buffer with a separate index (more code for 30 entries); keeping repeats in place
(the cap would drop an error that still happens every minute).

## R4. Before the saved variables load, and other versions

**Decision**: the log starts as an in-memory list. Core's `ADDON_LOADED` handler, after `ApplyDefaults`, keeps the
saved entries whose `version` equals `ns.version`, adds the in-memory ones with the same merge, and from then on the
log is `ns.db.errors`.

**Rationale**: one code path for both cases; an error in an early handler is kept (FR-012). Errors of an older
version are of code that changed, so they would only mislead (FR-011).

## R5. Tests keep failing on handler errors

**Decision**: `tests/wow.lua` stubs `geterrorhandler()` with a handler that appends the message to `lua_errors`.
`test()` fails a test whose run leaves anything in `lua_errors`, prints it, and wipes the list. Tests that expect an
error take it with `take_errors()`. An error outside a test stops the file with its messages, as an uncaught error
did before: `check_no_errors()` runs before each test, after the login events of `load_addon` and, from
`tests/run.mjs`, after each file. A test that fails on its own also reports the errors it left
(`tests/core/errors_harness_test.mjs`).

**Rationale**: today an error in a handler stops `fire()` or `ns.Fire` and fails the test. With `ns.Safe` it would be
caught and the test could pass. The check in `test()` keeps every existing test as strict as before (SC-006).

`debugstack(level, top, bottom)` is stubbed with `debug.traceback`, cut to `top` lines.

## R6. Cost

**Decision**: no allocation per handler call: the arguments go straight through `xpcall` and the message handler is
shared (R2).

**Rationale**: the busiest dispatch is the `UNIT_*` events (spell casts, `UNIT_INVENTORY_CHANGED`), registered for
every unit, so in a city or a raid some hundred handler calls a second, almost all for units the handlers ignore.
Registering those events for the player only (`RegisterUnitEvent`) would remove most
of the calls, with or without `ns.Safe`; it changes the registration API and is left for later.

**Alternatives considered**: one protected call per dispatch that resumes the loop after a failure; harder to read and
to test for a saving nobody would notice.

## R7. Where the code lives

**Decision**: `Core/Core.lua`, above the event dispatcher; `ns.GetErrors()` for `Debug.lua`.

**Rationale**: the helper exists for the dispatchers and the log for the helper; about 50 lines. A new file needs a TOC
entry, a game restart and a load-order rule (it must exist before the first event).

## Facts to check in game

`geterrorhandler` and `debugstack` are in the export and used by Blizzard; that the stack from the message handler
starts at the failing line in Forever is V42 ([verification.md](verification.md)). Errors with secret values: the
recording runs in `pcall`, so a value that cannot be turned into text is not recorded, and the game's handler still
gets it.
