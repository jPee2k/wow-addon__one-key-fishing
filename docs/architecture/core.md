# Architecture: core

Localization, the core services, saved variables, slash commands and the shared helpers. The module map and the
message list are in `CLAUDE.md`; languages and translation file rules are in [languages.md](../languages.md).

## Layers

WoW addons follow the pattern Ace3 formalized and the large addons use: a core plus feature modules over a message
bus. Here it is layered, one folder per area, so that MVC maps onto it: the model is the data and its rules
(`CatchDB/`, `Catalog/`, the statistics and prices of `Catch/`, the exchange's records and protocol); the
controller is what turns game events and key presses into model changes and game actions (`Fishing/`, catch
detection and auction scans, the transport and the channel, `Core/Commands.lua`); the view is `UI/`; the message
bus `ns.On` / `ns.Fire` is the observer: model and controller announce, the view listens, nothing below knows a
frame.

| Layer | Folders | May use the module tables (`ns.<Name>`) of |
|---|---|---|
| 0 Core | `Core/` (Localization, Core, Data), `Locales/` | nothing above |
| 1 Game | `Fishing/`, `Catch/`: the game's state and actions | layers 0-1 |
| 2 Data | `CatchDB/`, `Exchange/`, `Catalog/`: the catch data, its exchange and index | layers 0-2 |
| 3 View | `UI/`: every frame | everything |

- Entries: `Core/Commands.lua` is the one place a command opens a window (it sees everything); `Core/Debug.lua`
  and `Core/Spike.lua` read every module but the UI and return text that `Commands.lua` shows.
- Chat output (`ns.Print`) and the game's popup (`ns.ShowPopup`) stay in Core as infrastructure any layer may use:
  they are not addon frames.
- `npm run check` enforces the rule: what a file defines at the start of a line (`ns.Name = ...`,
  `function ns.Name(`) belongs to its folder's layer, and a file may name only what its layer and the layers below
  define. `CreateFrame` outside `UI/` is allowed only where `tools/addon.mjs` (`FRAMES_OUTSIDE_UI`) lists it: the
  event frame, the secure button and its state handler, the scanning tooltip, the spike's probes.
- Lifecycle: a module registers its own `ADDON_LOADED` / `PLAYER_LOGIN` handlers with `ns.RegisterEvent` (no
  `OnInitialize` / `OnEnable` framework); handlers of one event run in TOC order.
- A new feature goes into the module of its area (layer 1 or 2) and `UI/`, joined by messages and module
  functions; a new area adds a folder, its document here and its folder in `tests/`.

## Core/Localization.lua (loaded first)

- `ns.L` is keyed by the English text: the effective translation, then English, then the key.
- The registry `ns.AddTranslation(code, nativeName, fill)`, `ns.GetLanguages()` (menu order),
  `ns.ResolveLanguage(preference, clientLocale)`, `ns.NeedsLanguageHint` (a client without a translation, left on
  `"auto"`, is told once in English that other languages exist; `settings.languageHintShown`) and
  `ns.SetLanguage(code)`.
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
- The error log. `ns.Safe(context, fn, ...)` runs `fn` protected and returns `true` and its results, or `false` and
  the error. On a failure it records the error and hands it on to `geterrorhandler()`, from inside the `xpcall`
  handler and with the error stack height set as Blizzard's `CallErrorHandler` does, so BugSack and the
  `scriptErrors` popup show it with the failing code's stack. The event dispatcher
  (context: the event), `ns.Fire` (the message) and the slash dispatcher (`/okf <command>`) run every handler
  through it, so one failing handler no longer keeps the others from the same event, message or command. A caller of
  `ns.Fire` no longer sees a listener's error. Nothing else is wrapped. `ns.GetErrors()` returns the log: at most 30
  entries ordered by last occurrence, a repeat of the same context and message counted into its entry. Before
  `ADDON_LOADED` the log lives in memory; the load drops saved entries of another addon version and adds the ones in
  memory (specs/006-error-log).
- Helpers: `ns.ShowPopup` (two-button popups; the default buttons are the addon's `L["Yes"]` / `L["No"]`, never
  the client's `YES` / `NO`), `ns.Print` (a chat line with the addon prefix), `ns.ReportSection` (a titled block
  of the debug report). The frame helpers (`ns.CreateButton`, `ns.CreateText`, `ns.ItemDisplay`,
  `ns.ShowItemTooltip`, `ns.OpenRadioMenu`, `ns.KeyText`) are the view's, in `UI/Widgets.lua` ([ui.md](ui.md)).
- `ns.FormatDecimal(value, digits)`: the client's `DECIMAL_SEPERATOR`, the same as gold amounts.
- `ns.TallGlyphs()`: the addon is in Korean or Chinese on a client in another language. The minimap and Language
  tooltips then do not wrap and end with a blank line, because the game measures the lines with the client's
  shorter font; the other tooltips do not use it yet (spec 007 research R9).

## Core/MapPin.lua

The game's own map pin (user waypoint) with the navigation arrow, set on the player's click. In Core because
`Fishing/Skill.lua` (the next rank) and the catch catalog use it; it makes no frame, and its toasts are the UI's
(`MAP_PIN_SET`, `UI/Toast.lua`).

- `MapPin.Target(maps, x, y)`: the first candidate map the client knows and allows pins on, none under the game
  rule that turns pins off.
- `MapPin.Set(target, placeName)`: the game's pin, the navigation arrow, `charDB.pin`, a popup before replacing a
  pin the player set; out of combat the world map opens at that map.
- `MapPin.Link(target, text)`: a chat map link (`worldmap:`), which the game handles itself.
- The slash command dispatcher and help (`/okf` and `/onekeyfishing`; the commands themselves are in
  Commands.lua), `ns.version` from the TOC, and binding labels.

### Saved variables

`Migrate` runs `MIGRATIONS` up to `DB_SCHEMA` (1, no migration yet), then `ApplyDefaults` fills missing keys
without overwriting. Bump `DB_SCHEMA` and add a migration whenever a saved field is renamed, moved or reshaped; a
new field only needs a default.

`OneKeyFishingDB` (account-wide):

| Field | Holds | Written by |
|---|---|---|
| `settings` | the Features checkboxes (`autoLoot`, `bobberIcon`, `exitOnCombat`, `gear`, `lure`, `openContainers`, `indicator`, `lockIndicator`, `toasts`, `sessionTimer`, `pauseOnAFK`, `skillCapWarning`, `auctionPrices`, `camera`, `minimapButton`, `tooltipChances`), `cameraDistance`, `language` (`"auto"` or a code), `languageHintShown` (the one-time hint for clients without a translation was shown; Core.lua), `shareDB` and `shareChannel` (switched only through `Share.SetEnabled` / `Channel.SetEnabled`) | UI/Settings.lua |
| `shareNotice`, `shareNoticeChannel` | the one-time popup about the exchange was closed; the one that names the public channel was closed | Share.lua |
| `prices` | itemID -> `{ price, quantity, lots, time }` from auction scans | Auction.lua |
| `fishedItems` | itemID -> true for everything ever looted from fishing | Fishing/Bags.lua |
| `minimapAngle`, `indicatorPos` | the positions of the minimap button and the indicator | UI/Minimap.lua, UI/Indicator.lua |
| `errors` | the error log: `{ context, message, stack, version, first, last, count }`, at most 30, ordered by last occurrence | Core.lua |
| `statsTab` | the last open tab of the statistics window (`"stats"`, `"here"`, `"catalog"`) | UI/StatsFrame.lua |
| `shared` | the catch database ([catch-db.md](catch-db.md)): `myID` (8 random base32 characters, never in the debug report), `mine` (place key -> cell, this account's catches, never reset), `records` (the own record under `myID`, frozen own records under `"<myID>@<epoch>"`, other players' records under `"<id>@<epoch>"` with `seen`), `chain` (the version chain's secret and marks, never sent) | CatchDB.lua, Share.lua |

`OneKeyFishingCharDB` (per character):

| Field | Holds | Written by |
|---|---|---|
| `gear` | `pole` (the chosen pole, nil = the best in the bags) and `items` (extra fishing item IDs) | Gear.lua |
| `gearSwap`, the CVar and camera snapshots, `resumeMode` | what fishing mode changed, stored *before* the change so that exit, logout, `/reload` and crashes restore it ([fishing-mode.md](fishing-mode.md)) | Mode.lua, Gear.lua, Camera.lua |
| `savedCameraZoom` | the zoom before fishing mode; survives a `/reload`, dropped on a real login | Camera.lua |
| `stats`, `countedCast` | the statistics buckets and the cast running across a `/reload` | Stats.lua |
| `pin` | `{ mapID, x, y }` of the map pin as the addon last set it (nil by default), to tell it from a pin the player set | Core/MapPin.lua, UI/CatalogTab.lua |
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
  addresses them); `ns.CountKeys(tbl)`; `ns.Percent(value)` (a share as whole percent); `ns.ItemIDFromLink(text)`
  (the item ID in an item link).
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
and the name queue, never an item name), then "Errors" (the error log, the newest first: count, context, times,
version, message and stack). `Debug.Report()` returns the window title and the text; `/okf debug`
(`Commands.lua`) shows them in the copy window.
