# Contract: Error Log

Nothing here runs at file load. Shapes are in [../data-model.md](../data-model.md).

## `Core/Core.lua`

| Function | Behaviour |
| --- | --- |
| `ns.Safe(context, fn, ...)` | Runs `fn(...)` (trailing nils kept). Returns `true, results...`, or `false, err` when it failed. On failure, at the point of the error: records `context`, `tostring(err)` and the stack (a failure of the recording is ignored), then calls `geterrorhandler()(err)` once. |
| `ns.GetErrors()` | The log list (data-model.md), ordered by last occurrence, the newest last; the caller only reads it. |

Changed:

| Code | Before | After |
| --- | --- | --- |
| Event dispatcher (`OnEvent`) | `fn(event, ...)` | `ns.Safe(event, fn, event, ...)` for each handler |
| `ns.Fire(message, ...)` | `fn(...)` | `ns.Safe(message, fn, ...)` for each listener |
| Slash dispatcher | `command.run(rest)` | `ns.Safe("/okf " .. name, command.run, rest)` |
| `ADDON_LOADED` (own) | sets `ns.db` | also drops other versions' entries and merges the in-memory ones |

Order and arguments of handlers do not change. A caller of `ns.Fire` no longer sees a listener's error; it is
recorded and handed on.

## `Core/Debug.lua`: the "Errors" section

Built with `Section`, after "Game settings" and before "Addon settings". English. Newest first:

```text
-- Errors --
  none
```

```text
-- Errors --
  3x FISH_CAUGHT, 2026-11-05 12:00:01 to 12:30:00, 1.2.0
    Interface/AddOns/OneKeyFishing/Catch/Stats.lua:120: attempt to index a nil value
    <stack line 1>
    ...
```

The first line of an entry: count, context, first and last time (`date("%Y-%m-%d %H:%M:%S")`; one time when they are
equal), version. Then the message, then the stack lines, indented.

## `Core/Spike.lua` (temporary, `VERIFY(spike)`): "Error log" section

Runs `ns.Safe("spike", fail)`, where `fail` is a local function of `Spike.lua` that calls
`error("OneKeyFishing spike test error")`, so the message and the stack start at `Spike.lua` (the global
`error` passed directly would carry no file and line at all). Prints whether it returned `false`, and the recorded
entry's count and the first stack line of a Lua file. The game's handler shows the error as usual (V42).
