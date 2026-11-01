# Quickstart: validating the error log

Shapes and functions: [data-model.md](data-model.md), [contracts/api.md](contracts/api.md).

## Without the game (every change)

```text
npm run check     # Lua 5.1 syntax, globals (geterrorhandler, debugstack), ASCII, line length, VERIFY list
npm test          # fengari tests
```

| Test | Proves |
| --- | --- |
| `tests/core/errors_test.lua` (new) | `ns.Safe`: arguments with trailing nils in, `true` and results out; a failure returns `false`, is recorded (context, message, stack of at most 10 lines, version, times, count 1) and reaches the error handler once; a failing recording still hands the error on; deduplication moves the entry to the end; the cap of 30 drops the least recent; an error value that is not text; three listeners of `ns.Fire` and three handlers of one event with the second failing: first and third run with their arguments; a failing slash command is recorded as `/okf <name>`; the report's "Errors" section, empty and newest first |
| `tests/core/errors_load_test.lua` (new) | an error before `ADDON_LOADED` joins the saved log; entries of another version are dropped on load, an in-memory entry equal to a saved one adds its count |
| `tests/ui/spike_test.lua` (extended) | the "Error log" section runs and leaves one entry |
| `tests/core/errors_harness_test.mjs` (new) | an error handed on before a test or after the last one stops the file; a failing test reports the error it left as well |
| every existing test | still passes; `test()` now fails a test that leaves an error in `lua_errors`, and an error outside a test stops the file, as an uncaught error did before |

## In game

Step V42 in [docs/checklists/spike.md](../../docs/checklists/spike.md): `/console scriptErrors 1`, then `/okf spike`.
The popup (or BugSack) shows "OneKeyFishing spike test error" at the spike's line, and `/okf debug` lists it under
"Errors".
