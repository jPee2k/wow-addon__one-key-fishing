# Data Model: Import and Export of Catch Records

## Export string (not saved)

| Part | Value | Rule |
|---|---|---|
| start | `OKF` | the first `OKF:` in the pasted text; anything before it is ignored |
| format | `1` | an unknown or higher number: refused, "update the addon" |
| count | the number of tokens, a decimal number | must equal the tokens found, or the string counts as cut |
| check | 7 base32 characters, `ns.Base32(Share.Hash(tokens joined by ","), 7)` | a mismatch: refused as damaged |
| tokens | `,`-separated Base64 strings: one record each, `Share.Encode(Store.ForSending(record))` | each at most `MAX_RECORD_BYTES` (32 KB) |
| end | `END` | missing: cut |

Whitespace anywhere is removed before parsing. Order: the own units first, then others' by `seen`, newest first.
The whole text stays under `EXPORT_LIMIT` (256 KB). Contract: [contracts/export-string.md](contracts/export-string.md).

## Imported marks (saved, account-wide)

`OneKeyFishingDB.shared.imported`: unit `"<id>@<epoch>"` -> `true`.

- Set by an import for every record answered `new`, `newer`, `same` or `older` (a record held before is marked too).
  It is set before `Store.Accept`, and taken back on `refused` if the unit had no mark before.
- Read by `Share.IsImported(unit)`, which `CatchDB/Index.lua` uses to file the unit's entries in the imported indexes
  as well.
- Dropped by `Store.CleanUp` for units no longer under `shared.records`.
- Never sent: the exchange sends only record fields (`Store.ForSending`).
- A missing table is filled by `ApplyDefaults` (`{}`). No `DB_SCHEMA` change.

## Index additions (memory only)

`CatchDB.private.others` keeps `byKey`, `byPrefix` and `byRecord`, and beside them `others.imported` with the same
three sets, holding only the entries of marked units (the same entry tables, not copies). `CountedOthers()` returns
`others` with sharing on and `others.imported` with sharing off. Both are rebuilt or updated by the existing
`SHARED_DATA_CHANGED` handler.

## Transfer state (memory only)

`Share.TransferState()` returns a copy of:

| Field | Values |
|---|---|
| `state` | `"idle"`, `"exporting"`, `"importing"` |
| `export` | the last export: `{ text, records, bytes }`, or nil |
| `result` | the last import: `{ new, known, own, refused }`, or `{ error = "damaged" | "cut" | "format" | "empty" }` (a call while a transfer runs returns `false, "busy"` and keeps it), or nil |
| `progress` | while importing: tokens done and total |

## Session rules (memory only, per node)

| Field | Default | Clamp |
|---|---|---|
| `gap` | 120 s (`SESSION_GAP`) | at least 15 s |
| `strangerChance` | nil: `min(1, CHANNEL_TARGET / H)` | nil or 0..1 |
| `offerOthers` | true | boolean |

`Share.SetSessionRules(rules)` merges the given fields into the game node's rules (clamped).
`ResetSessionRules()` puts back the defaults, and `SessionRules()` returns a copy. Not saved: a `/reload` or a login
starts with the defaults.

## Extension registries (memory only)

| Registry | Holds | Shown |
|---|---|---|
| `Share.AddStatusLine(fn)` | functions returning a line or nil | after the addon's lines of `/okf share` |
| `Debug.AddSection(title, fn)` | `{ title, fn(add) }` | after the addon's sections of the report |
| `ns.MinimapMenu.AddEntries(fn)` | functions `fn(root)` | after "Debug report" in the minimap menu |
| `SettingsUI.AddPage(frame, title)` | frames waiting for the registration | subcategories after the addon's own pages |
