# Data Model: Error Log

## `OneKeyFishingDB.errors` (account-wide, new)

A list of entries, ordered by last occurrence: index 1 is the least recently seen, the last index the most recent.
Default `{}` (`DB_DEFAULTS`, filled by `ApplyDefaults`; `DB_SCHEMA` stays 1).

| Field | Type | Holds |
| --- | --- | --- |
| `context` | string | the event name, the message name, or `"/okf <command>"` |
| `message` | string | `tostring(err)`, whole (it starts with the file and line) |
| `stack` | string | `debugstack` at the error, at most 10 lines |
| `version` | string | `ns.version` when recorded |
| `first` | number | `time()` of the first occurrence |
| `last` | number | `time()` of the last occurrence |
| `count` | number | occurrences, at least 1 |

## Rules

- **Identity**: `context` and `message` together. A new error with the same pair adds its count to the entry, takes
  its `last`, and moves the entry to the end; `first`, `stack` and `version` stay.
- **Cap**: at most 30 entries; adding the 31st drops index 1.
- **Load**: entries whose `version` differs from `ns.version` are dropped; entries recorded in memory before the
  load are then merged in by the identity rule.
- **Before the load**: the same list shape in memory only; it becomes `OneKeyFishingDB.errors` at `ADDON_LOADED`.
- **Written by**: `Core/Core.lua` only. **Read by**: `Core/Debug.lua` (and the spike) through `ns.GetErrors()`.
- **Size**: at most about 40 KB in the saved file (30 entries of a message and 10 stack lines).
