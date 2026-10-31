# Architecture: core

Localization, the core services, saved variables, slash commands and the shared helpers. The module map and the
message list are in `CLAUDE.md`; languages and translation file rules are in [languages.md](../languages.md).

## Core/Localization.lua (loaded first)

- `ns.L` is keyed by the English text: the effective translation, then English, then the key.
- The registry `ns.AddTranslation(code, nativeName, fill)`, `ns.GetLanguages()` (menu order),
  `ns.ResolveLanguage(preference, clientLocale)` and `ns.SetLanguage(code)`.
- Core resolves the language in `ADDON_LOADED`, the first point where the saved preference (`settings.language`,
  `"auto"` or a code) exists.
- **No `L[...]` lookup may run while the files load** (at file scope, in a table built at load): it would be stuck
  in English. Build such texts at runtime instead; `ns.earlyLookups` and `tests/core/locale_test.lua` catch a
  load-time lookup.

## Locales/

- `Locales/enUS.lua` is the English list. Every `L["..."]` in the code must be listed there and vice versa
  (`npm run check`).
- Use literal keys only (`L["text"]`, never `L[a .. b]`) and keep color codes outside the strings.
- Every other `Locales/<code>.lua` (listed after `enUS.lua`, before `Core/Core.lua`) registers a complete translation
  through `ns.AddTranslation`; `npm test` checks completeness and placeholder order, so a new English text needs
  its nine translations in the same change.
- Not localized on purpose: the debug report, slash commands (names, help descriptions and the `/okf` help
  output), the addon name and the language names (constitution, Principle II).

## Core/Core.lua

- `ns.RegisterEvent` (several handlers per event) and the internal message bus `ns.On` / `ns.Fire` (messages in
  `CLAUDE.md`).
- Widgets and helpers: `ns.CreateButton` (the shared panel button, which grows to its text on every `SetText`),
  `ns.CreateText`, `ns.ItemDisplay` (an item's link and icon), `ns.ShowItemTooltip` (item tooltip with the
  few-lots auction price), `ns.OpenRadioMenu` (a `MenuUtil` menu of choices), `ns.ShowPopup` (two-button popups),
  `ns.Print` (a chat line with the addon prefix), `ns.ReportSection` (a titled block of the debug report).
- The slash command dispatcher and help (`/okf` and `/onekeyfishing`; the commands themselves are in
  Commands.lua), `ns.version` from the TOC, and binding labels.

### Saved variables

`Migrate` runs `MIGRATIONS` up to `DB_SCHEMA` (1, no migration yet), then `ApplyDefaults` fills missing keys
without overwriting. Bump `DB_SCHEMA` and add a migration whenever a saved field is renamed, moved or reshaped; a
new field only needs a default.

`OneKeyFishingDB` (account-wide):

| Field | Holds | Written by |
|---|---|---|
| `settings` | the Features checkboxes (`autoLoot`, `bobberIcon`, `exitOnCombat`, `gear`, `lure`, `openContainers`, `indicator`, `lockIndicator`, `toasts`, `sessionTimer`, `pauseOnAFK`, `skillCapWarning`, `auctionPrices`, `camera`, `minimapButton`, `tooltipChances`), `cameraDistance`, `language` (`"auto"` or a code), `shareDB` and `shareChannel` (switched only through `Share.SetEnabled` / `Channel.SetEnabled`) | UI/Settings.lua |
| `shareNotice`, `shareNoticeChannel` | the one-time popup about the exchange was closed; the one that names the public channel was closed | Share.lua |
| `prices` | itemID -> `{ price, quantity, lots, time }` from auction scans | Auction.lua |
| `fishedItems` | itemID -> true for everything ever looted from fishing | Catch.lua |
| `minimapAngle`, `indicatorPos` | the positions of the minimap button and the indicator | UI/Minimap.lua, UI/Indicator.lua |
| `statsTab` | the last open tab of the statistics window (`"stats"`, `"here"`, `"catalog"`) | UI/StatsFrame.lua |
| `shared` | the catch database ([catch-db.md](catch-db.md)): `myID` (8 random base32 characters, never in the debug report), `mine` (place key -> cell, this account's catches, never reset), `records` (the own record under `myID`, frozen own records under `"<myID>@<epoch>"`, other players' records under `"<id>@<epoch>"` with `seen`), `chain` (the version chain's secret and marks, never sent) | CatchDB.lua, Share.lua |

`OneKeyFishingCharDB` (per character):

| Field | Holds | Written by |
|---|---|---|
| `gear` | `pole` (the chosen pole, nil = the best in the bags) and `items` (extra fishing item IDs) | Gear.lua |
| `gearSwap`, the CVar and camera snapshots, `resumeMode` | what fishing mode changed, stored *before* the change so that exit, logout, `/reload` and crashes restore it ([fishing-mode.md](fishing-mode.md)) | Mode.lua, Gear.lua, Camera.lua |
| `savedCameraZoom` | the zoom before fishing mode; survives a `/reload`, dropped on a real login | Camera.lua |
| `stats`, `countedCast` | the statistics buckets and the cast running across a `/reload` | Stats.lua |
| `pin` | `{ mapID, x, y }` of the map pin as the catalog last set it, to tell it from a pin the player set | UI/CatalogTab.lua |
| `channelSession` | the hidden channel's state across a `/reload` (joined by the addon, left by hand, locks) | Channel.lua |

## Core/Commands.lua (loaded last)

`ns.COMMANDS`: every slash command in one place, sorted by name, with its English description and a `run`
function that calls the module at runtime (constitution, Principles II and VI). Modules register no commands; the
names, descriptions and `/okf` help are English on every client. `catalog` passes the rest of the line through
`Catalog.CommandArg` (an item link becomes its ID) to `StatsFrame.OpenCatalog`. Every command is documented in the
player manual `OneKeyFishing/README.md` (`npm run check`), except a temporary one whose declaration carries a
`VERIFY` marker.

## Core/Data.lua

Shared data and helpers:

- Fishing: `ns.FISHING_SPELL_IDS` (the four rank spells), `ns.FISHING_SKILL_LINE` (356), `ns.IsFishingSpell`,
  `ns.GetFishingSpellID` (the highest rank learned), `ns.BOBBER_OBJECT_ID` (35591), `ns.GameObjectID(guid)` (the
  object ID of a game object GUID; Forever scrambles the spawn part) and `ns.IsBobberTargeted()` (the soft
  interact target is the bobber).
- Bags: `ns.ForEachBagItem`, the shared bag iterator.
- Names: `ns.WithRealm(name)` and `ns.SameCharacter(a, b)` (character names with their realm, as the exchange
  addresses them); `ns.CountKeys(tbl)`.
- Text: `ns.FoldCase(text)` (lower case for ASCII, Latin-1 Supplement and Cyrillic by UTF-8 byte patterns, the same
  in 5.1 and 5.3), `ns.SearchKey(text)` (folds after the game's `CaseAccentInsensitiveParse` when present) and
  `ns.CompareText(a, b)` (`strcmputf8i` when present, else the search keys): the catalog's search and order, and
  the subzone match.
- The catch database: `ns.BASE32`, `ns.Base32(value, width)` and `ns.RandomBase32(length)` (IDs, tags and hashes);
  `ns.CountRecent(counts, now, weight, minutes)` (the per-minute rolling sum behind Comm's budget, Share's
  per-sender limits, the channel's population estimate and the part flood count); `ns.SHA256(message)` (FIPS 180-4
  through the game's `bit` library, each result taken modulo 2^32, so it is the same on 5.1 and in the 5.3 tests),
  `ns.HexToBase32(hex, count)` and `ns.ProofStep(link)` (the first 80 bits of the SHA-256 of a link as 16 base32
  characters): one step down a version chain ([catch-db.md](catch-db.md)). The tests swap a fast stand-in for
  `ns.ProofStep` unless `real_proof` is set.

## Core/Debug.lua

Builds the `/okf debug` report (English, not localized): versions and locale, the language setting, the mode state
and keys, the Fishing spell and skill, gear, lures, pending restore, fished items, settings, the catch database
(`CatchDB.Describe()`, never the anonymous ID), the shared database (`Share.Describe()`, `Channel.Describe()`, no
names) and the catch catalog (`Catalog.Describe()`: the state of each index, its maps and items, the build times
and the name queue, never an item name).
