# Architecture: core

Localization, the core services, saved variables, slash commands and the shared helpers. The module map and the
message list are in `CLAUDE.md`; languages and translation file rules are in [languages.md](../languages.md).

## Localization.lua (loaded first)

- `ns.L` is keyed by the English text: the effective translation, then English, then the key.
- The registry `ns.AddTranslation(code, nativeName, fill)`, `ns.GetLanguages()` (menu order),
  `ns.ResolveLanguage(preference, clientLocale)`, `ns.NeedsLanguageHint` (a client without a translation, left on
  `"auto"`, is told once in English that other languages exist; `settings.languageHintShown`) and
  `ns.SetLanguage(code)`.
- Core resolves the language in `ADDON_LOADED`, the first point where the saved preference (`settings.language`,
  `"auto"` or a code) exists.
- **No `L[...]` lookup may run while the files load** (at file scope, in a table built at load): it would be stuck
  in English. Build such texts at runtime instead; `ns.earlyLookups` and `tests/locale_test.lua` catch a
  load-time lookup.

## Locales/

- `Locales/enUS.lua` is the English list. Every `L["..."]` in the code must be listed there and vice versa
  (`npm run check`).
- Use literal keys only (`L["text"]`, never `L[a .. b]`) and keep color codes outside the strings.
- Every other `Locales/<code>.lua` (listed after `enUS.lua`, before `Core.lua`) registers a complete translation
  through `ns.AddTranslation`; `npm test` checks completeness and placeholder order, so a new English text needs
  its nine translations in the same change.
- Not localized on purpose: the debug report, slash commands (names, help descriptions and the `/okf` help
  output), the addon name and the language names (constitution, Principle II).

## Core.lua

- `ns.RegisterEvent` (several handlers per event) and the internal message bus `ns.On` / `ns.Fire` (messages in
  `CLAUDE.md`).
- Widgets and helpers: `ns.CreateButton` (the shared panel button, which grows to its text on every `SetText`),
  `ns.CreateText`, `ns.ItemDisplay` (an item's link and icon), `ns.ShowItemTooltip` (item tooltip with the
  few-lots auction price), `ns.OpenRadioMenu` (a `MenuUtil` menu of choices), `ns.ShowPopup` (two-button popups;
  the default buttons are the addon's `L["Yes"]` / `L["No"]`, never the client's `YES` / `NO`).
- `ns.FormatDecimal(value, digits)`: the client's `DECIMAL_SEPERATOR`, the same as gold amounts.
- `ns.KeyText(binding, short, unbound, separator)`: every key bound to a binding, in the game's order, joined
  with " / "; the minimap tooltip, the settings key line and the indicator use it.
- `ns.TallGlyphs()`: the addon is in Korean or Chinese on a client in another language. The minimap and Language
  tooltips then do not wrap and end with a blank line, because the game measures the lines with the client's
  shorter font; the other tooltips do not use it yet (spec 007 research R9).
- Saved variables: `Migrate` runs `MIGRATIONS` up to `DB_SCHEMA`, then `ApplyDefaults` fills missing keys without
  overwriting. Bump `DB_SCHEMA` and add a migration whenever a saved field is renamed, moved or reshaped.
  - `OneKeyFishingDB` holds account-wide data: settings, fished item IDs, auction prices, the minimap button and
    indicator positions, the last statistics tab `statsTab`, `shareNotice`, `shareNoticeChannel` (the notice that
    names the public channel was closed, part 3) and the catch database `shared` (with `shared.chain`, the version
    chain's secret and marks). The settings gain `shareChannel` (default on).
  - `OneKeyFishingCharDB` holds per-character data: fishing gear, statistics, pending restore state, and `pin`,
    the map pin the addon set last (nil by default).
- The slash command dispatcher and help (`/okf` and `/onekeyfishing`; the commands themselves are in
  Commands.lua), `ns.version` from the TOC, and binding labels.

## Commands.lua (loaded last)

`ns.COMMANDS`: every slash command in one place, sorted by name, with its English description and a `run`
function that calls the module at runtime (constitution, Principles II and VI). Modules register no commands; the
names, descriptions and `/okf` help are English on every client. `catalog` (part 4) passes the rest of the line
through `Catalog.CommandArg` (an item link becomes its ID) to `StatsFrame.OpenCatalog`.

## Data.lua

Shared data and helpers:

- `ns.ForEachBagItem`: the shared bag iterator.
- `ns.BASE32`, `ns.Base32(value, width)` and `ns.RandomBase32(length)`: IDs, tags and hashes of the catch
  database.
- `ns.CountRecent(counts, now, weight, minutes)`: the per-minute rolling sum of Comm's budget and Share's
  per-sender limits (and the channel's population estimate and part flood count).
- `ns.SHA256(message)` (FIPS 180-4 through the game's `bit` library, each result taken modulo 2^32, so it is the
  same on 5.1 and in the 5.3 tests), `ns.HexToBase32(hex, count)` and `ns.ProofStep(link)` (the first 80 bits of
  the SHA-256 of a link as 16 base32 characters): one step down a version chain ([catch-db.md](catch-db.md)). The
  tests swap a fast stand-in for `ns.ProofStep` unless `real_proof` is set.
- `ns.GameObjectID(guid)`: the object ID of a game object GUID (Forever scrambles the spawn part), and
  `ns.BOBBER_OBJECT_ID`.
- `ns.FoldCase(text)`: lower case for ASCII, Latin-1 Supplement (U+00C0-U+00DE but U+00D7) and Cyrillic
  (U+0400-U+042F) by UTF-8 byte patterns, the same in 5.1 and 5.3 (`string.lower` handles ASCII only);
  `ns.SearchKey(text)` folds after the game's `CaseAccentInsensitiveParse` when present; `ns.CompareText(a, b)` uses
  `strcmputf8i` when present, else the search keys. The catalog's search and order, and the subzone match.

## Debug.lua

Builds the `/okf debug` report (English, not localized). The "Catch catalog" section lists `Catalog.Describe()`:
the state of each index, its maps and items, the build times and the name queue, never an item name.
