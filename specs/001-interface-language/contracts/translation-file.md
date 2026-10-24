# Contract: Translation File

The format every `OneKeyFishing/Locales/<code>.lua` (other than `enUS.lua`) follows. Translators and the
tests rely on it.

```lua
-- <Language name in English> translation. Keys are the English texts of Locales/enUS.lua.
local _, ns = ...

ns.AddTranslation("<code>", "<native name>", function(L)
    -- Core.lua
    L["Fishing action (cast / hook)"] = "<translation>"
    L["A long English text that would not fit on one line with its translation"] =
        "<translation>"
end)
```

## Rules

- **File and code**: the file name is the code (`deDE.lua` registers `"deDE"`); it is listed in the TOC after
  `Locales/enUS.lua` and before `Core.lua`.
- **Keys**: literal English keys copied from `Locales/enUS.lua`; unknown keys fail `npm run check`, missing
  keys fail `npm test` (completeness, FR-011).
- **Text**: plain UTF-8 in the language itself; the only Lua files where non-ASCII text is allowed.
- **Placeholders**: the same `%s`, `%d`, `%02d`, `%.1f` ... in the same order as the English key; `|` escape
  sequences unchanged (`npm test` compares them).
- **No color codes** inside strings (they stay in the code, as in English).
- **Lines** up to 120 characters; break after `=` and join pieces with `..` when needed.
- **Game terms** (rank names, places, NPCs) as the client of that language names them; Ukrainian uses the
  common Ukrainian community terms.

# Contract: Localization API (inside the addon)

| Function | Called by | Contract |
|---|---|---|
| `ns.L[key]` | every module, at runtime only | returns the text in the effective language, else the key |
| `ns.AddTranslation(code, name, fill)` | translation files at load | registers a language; a duplicate code is an error |
| `ns.ResolveLanguage(preference, clientLocale)` | Core `ADDON_LOADED`, tests | returns a registered code (R3) |
| `ns.SetLanguage(code)` | Core `ADDON_LOADED`, tests | rebuilds the active translation from `fill` of `code`, sets `ns.language`; in game once per session |
| `ns.GetLanguages()` | settings menu | `{ { code, name }, ... }` in menu order, registered only |

# Contract: Settings Control

- Placement: main settings page, right of the title and version.
- Shows: `Language:` (translated) + a button with the current preference ("Game client language" translated,
  or the native name).
- Click: menu with radio entries, current one checked: "Game client language", then each registered language
  by native name.
- Hover: tooltip with the FR-013 warning (translated): Korean and Chinese may show as squares on a client in
  another language; pick English to return.
- Choosing a different entry: saves the preference, then the reload popup ("Reload now" / "Later").
