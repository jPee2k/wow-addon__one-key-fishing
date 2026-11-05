# Contracts: shared UI helpers

Internal functions other modules call. They run at runtime only (no `L[...]` lookup at file load).

## `ns.KeyText(binding, short, unbound, separator)` (Core.lua, new)

Names every key bound to a binding.

- `binding`: a binding name from `Bindings.xml` (`"ONEKEYFISHING_ACTION"`, `"ONEKEYFISHING_TOGGLE"`).
- `short`: passed to `GetBindingText(key, short)`; true gives the short form for small labels (the indicator).
- `unbound`: the text when no key is bound; default the red `L["not bound"]` (as the minimap tooltip and the
  settings line show today). The indicator passes `""`.
- `separator`: joins two keys; default `" / "`. The indicator passes `"\n"` (one key per line).
- Returns: the readable key texts in the game's order (`GetBindingKey`), duplicates removed, joined by `separator`.

| Bound keys | Result |
|---|---|
| none | `unbound` |
| `` ` `` | `` ` `` |
| `` ` `` and `'` | `` ` / ' `` |
| `SHIFT-`` and `SHIFT-'` | `` Shift-` / Shift-' `` (as `GetBindingText` writes modifiers) |
| `` ` `` twice | `` ` `` |

Callers: `UI/Minimap.lua` (tooltip, both bindings), `UI/Settings.lua` (main page key line, both bindings),
`UI/Indicator.lua` (`ns.KeyText("ONEKEYFISHING_ACTION", true, "", "\n")`). The three local `KeyText` functions are
removed.

## `ns.ShowPopup(key, text, onAccept, acceptText, cancelText)` (Core.lua, changed default)

Unchanged signature. When `acceptText` / `cancelText` is nil, the buttons read `L["Yes"]` / `L["No"]` in the
addon's language (was the client's `YES` / `NO`). Callers that pass their own texts keep them; `UI/MapPin.lua`
passes `L["Replace"]`, `L["Cancel"]` (was `CANCEL`).

## `StatsFrame.ButtonRows(leftWidth, scanWidth, minWidth)` (UI/StatsFrame.lua, new, exposed for tests)

- `leftWidth`: the width of the left row with its margins (14 + three buttons + two gaps of 8 + 14).
- `scanWidth`: the Scan button's width.
- `minWidth`: the window's normal width (`WIDTH`).
- Returns `windowWidth, wraps`: `windowWidth = max(minWidth, leftWidth)`; `wraps` is true when
  `leftWidth + 8 + scanWidth > windowWidth`.

The window applies it: no wrap keeps today's layout; a wrap makes the window `HEIGHT + 28` tall, puts the left
three at `BOTTOMLEFT 14, 40` onwards and Scan at `BOTTOMLEFT 14, 12`.
