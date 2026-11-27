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
| 0 Core | `Core/` (Localization, Core, Data, MapPin), `Locales/`, `GameData/` (the game data model, [game-data.md](game-data.md)) | nothing above |
| 1 Game | `Fishing/`, `Catch/`: the game's state and actions | layers 0-1 |
| 2 Data | `CatchDB/`, `Exchange/`, `Catalog/`: the catch data, its exchange and index | layers 0-2 |
| 3 View | `UI/`: every frame | everything |

- Entries: `Core/Commands.lua` is the one place a command opens a window (it sees everything); `Core/Debug.lua`
  reads every module but the UI and returns text that `Commands.lua` shows.
- Chat output (`ns.Print`) and the game's popup (`ns.ShowPopup`) stay in Core as infrastructure any layer may use:
  they are not addon frames.
- `npm run check` enforces the rule: what a file defines at the start of a line (`ns.Name = ...`,
  `function ns.Name(`) belongs to its folder's layer, and a file may name only what its layer and the layers below
  define. `CreateFrame` outside `UI/` is allowed only where `tools/addon.mjs` (`FRAMES_OUTSIDE_UI`) lists it: the
  event frame, the secure button and its state handler, the scanning tooltip.
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

- `ns.RegisterEvent` (several handlers per event; `ns.RegisterUnitEvent(event, unit, fn)` for an event heard for one
  unit only, the player's `UNIT_AURA` of `Fishing/Camp.lua`; the two refuse to mix on one event) and the internal message bus `ns.On` / `ns.Fire` (messages in
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
- Blocked actions in the same log (specs/029-blocked-actions): `ADDON_ACTION_FORBIDDEN` and `ADDON_ACTION_BLOCKED`
  naming OneKeyFishing (context the event, message the refused function) and every call of the game's
  `DisplayInterfaceActionBlockedMessage` through a `hooksecurefunc` (context `INTERFACE_ACTION_BLOCKED`, message the
  first stack line inside the addon's folder when the addon is the closest one on the stack, the stack's first 10
  lines kept; a block whose closest addon is another, or with none, is not kept). An entry starts with a state line: in a fight or not, and the addon's last
  menu with its age (`ns.NoteMenu(name)`: `ns.OpenMenu` in `UI/Widgets.lua` notes every
  menu it opens, named by its caller). The events' entries add the addon's place on the stack to the state line ("addon line", searched past the 10 lines kept) and keep the stack they came with, its first 10 lines
  after the addon's own event dispatch (the game fires them inside the refused call, so the stack holds its
  callers: seen in game 2026-11-26). A hook entry means the addon's code was the closest on the way to the block,
  not that it caused it: the game may blame another addon's taint. `ns.RecordEntry(context, message, stack)` adds an
  entry without an error: nothing goes to the game's error handler. The report's last section is "Errors and blocked
  actions". A repeat counts into its entry and its state replaces the entry's (the latest fight and menu). A refused
  protected call may give two entries (the event and the hook, when Blizzard's handler shows the message).
- Helpers: `ns.ShowPopup` (two-button popups; the default buttons are the addon's `L["Yes"]` / `L["No"]`, never
  the client's `YES` / `NO`), `ns.Print` (a chat line with the addon prefix). The frame helpers (`ns.CreateButton`,
  `ns.CreateText`, `ns.ItemDisplay`, `ns.ShowItemTooltip`, `ns.OpenRadioMenu`, `ns.KeyText`) are the view's, in
  `UI/Widgets.lua` ([ui.md](ui.md)).
- The slash command dispatcher and help (`/okf` and `/onekeyfishing`; the commands themselves are in
  Commands.lua), `ns.version` from the TOC, and binding labels.
- `ns.FormatDecimal(value, digits)`: the client's `DECIMAL_SEPERATOR`, the same as gold amounts.
- `ns.TallGlyphs()`: the addon is in Korean or Chinese on a client in another language. The minimap and Language
  tooltips then do not wrap and end with a blank line, because the game measures the lines with the client's
  shorter font; the other tooltips do not use it yet (spec 007 research R9).

## Core/MapPin.lua

The game's own map pin (user waypoint) with its tracking (the minimap's arrow), set on the player's click. Every pin of the addon
goes through it: `Fishing/Skill.lua` (the next rank) and the catch catalog (`Catalog.Spots`, `UI/CatalogTab.lua`).
In Core because both use it; it makes no frame, and its toasts are the UI's (`MAP_PIN_SET`, `UI/Toast.lua`).

- `MapPin.Target(maps, x, y)`: the first candidate map the client knows and allows pins on (V30); else, when the
  first candidate (the point's own map) is a Micro map (a cave, a building), the same place on its zone's map through
  the world position (V33); none without the waypoint API, under the game rule that turns pins off, or in instances.
- `MapPin.Set(target, placeName)`: the game's pin, its tracking, `charDB.pin`, a popup before replacing a pin the
  player set (none for the addon's own pin or a pin already at the place). It never opens the world map: a map
  opened from addon code is tainted for a later fight (spec 009, R14). The arrow on screen depends on the game's
  hidden navigation setting, which the addon leaves alone (V31).
- `MapPin.Link(target, text)`: a chat map link (`worldmap:`), which the game handles itself.

### Saved variables

`Migrate` runs `MIGRATIONS` up to `DB_SCHEMA` (1, no migration yet), then `ApplyDefaults` fills missing keys
without overwriting. Bump `DB_SCHEMA` and add a migration whenever a saved field is renamed, moved or reshaped; a
new field only needs a default.

`OneKeyFishingDB` (account-wide):

| Field | Holds | Written by |
|---|---|---|
| `settings` | the Features checkboxes (`autoLoot`, `bobberIcon`, `exitOnCombat`, `gear`, `lure`, `openContainers`, `indicator`, `lockIndicator`, `toasts`, `sessionTimer`, `pauseOnAFK`, `skillCapWarning`, `campBonusWarning` (spec 020: the camp bonus notices of Fishing/Camp.lua, on by default), `camera`, `minimapButton`, `tooltipChances`), `auctionPrices` and `auctionatorPrices` (spec 019, the "Auction prices" page: auction prices for the catch value, and taking them from Auctionator; both on by default, switched only through `Prices.SetAuctionPrices` / `Prices.SetAuctionator`), `cameraDistance`, `language` (`"auto"` or a code), `languageHintShown` (the one-time hint for clients without a translation was shown; Core.lua), `shareDB` and `shareChannel` (switched only through `Share.SetEnabled` / `Channel.SetEnabled`), the "Sound effects" page (spec 013): `fishingSounds` (only through `Sound.SetEnabled`), `soundVolume` (0-100, step 10), `backgroundSound`, `splashFocus` (Mode.lua CVar rows), `hiddenKinds` (spec 014: the item kinds hidden in the catch lists, only through `Catalog.SetKindShown`), `catalogSort` (spec 017: the order of the catalog's list, `"name"`, `"price"` or `"chance"`, only through `Catalog.SetSort`) | UI/Settings.lua; also Core.lua (`languageHintShown`), Fishing/Camera.lua (`cameraDistance`), Exchange/ShareGame.lua (`shareDB`), Exchange/Channel.lua (`shareChannel`), Fishing/Sound.lua (`fishingSounds`, `soundVolume`), Catalog/Catalog.lua (`hiddenKinds`, the kind menu of UI/CatchHere.lua; `catalogSort`, the Sort menu of UI/CatalogTab.lua), Catch/Prices.lua (`auctionPrices`, `auctionatorPrices`) |
| `shareNotice`, `shareNoticeChannel` | the one-time popup about the exchange was closed; the one that names the public channel was closed | Exchange/ShareGame.lua |
| `prices` | itemID -> `{ price, quantity, lots, time }` from auction scans | Auction.lua |
| `priceScans` | itemID -> `time()` of the last answered auction search, with a price or not on sale (spec 018: fresh prices) | Auction.lua |
| `priceRule` | the rule the saved `prices` were computed by (2 since 1.3.2: an item row's `buyoutAmount` is one piece's price); a lower or missing value drops `prices` and `priceScans` once at login | Auction.lua |
| `scanGuard` | `{ version, items }`: the items the auction house did not answer for, itemID -> `"own"`, `"bundled"` or `"shared"`; emptied when the addon runs as another version (spec 018) | Auction.lua |
| `fishedItems` | itemID -> true for everything ever looted from fishing | Fishing/Bags.lua |
| `minimapAngle`, `indicatorPos` | the positions of the minimap button and the indicator | UI/Minimap.lua, UI/Indicator.lua |
| `errors` | the error log: `{ context, message, stack, version, first, last, count }`, at most 30, ordered by last occurrence | Core.lua |
| `statsTab` | the last open tab of the statistics window (`"stats"`, `"here"`, `"catalog"`, `"best"`) | UI/StatsFrame.lua |
| `shared` | the catch database ([catch-db.md](catch-db.md)): `myID` (8 random base32 characters, never in the debug report), `mine` (place key -> cell, this account's catches, never reset; a cell may carry `q`, its camp bonus parts by mask, spec 020), `records` (the own record under `myID`, frozen own records under `"<myID>@<epoch>"`, other players' records under `"<id>@<epoch>"` with `seen`), `chain` (the version chain's secret and marks, never sent), `imported` (`"<id>@<epoch>"` -> `true`: the units an import brought or confirmed, which count with sharing off; dropped with their record by `Store.CleanUp`; spec 027) | CatchDB.lua, Share.lua, ShareTransfer.lua |

`OneKeyFishingCharDB` (per character):

| Field | Holds | Written by |
|---|---|---|
| `gear` | `pole` (the chosen pole, nil = the best in the bags) and `items` (extra fishing item IDs) | Gear.lua |
| `gearSwap`, the CVar and camera snapshots, `resumeMode` | what fishing mode changed, stored *before* the change so that exit, logout, `/reload` and crashes restore it ([fishing-mode.md](fishing-mode.md)) | Mode.lua, Gear.lua, Camera.lua |
| `resumeOwned` | CVar name -> true: the live rows ("Sound effects") the player changed by hand while fishing, from the logout of a `/reload` to the resume, so the resumed mode leaves them alone (spec 015); nil otherwise | Mode.lua |
| `savedCameraZoom` | the zoom before fishing mode; survives a `/reload`, dropped on a real login | Camera.lua |
| `stats`, `countedCast` | the statistics buckets (`session`, `total`, `zones[key]`; since spec 020 also `bonusCasts` and `bonusCatches`, read as 0 when missing) and the cast running across a `/reload` | Stats.lua |
| `session` | the current fishing session (its counts and times; `skillStart`, the Fishing rank it began with, read by Fishing/Skill.lua) | Catch/Stats.lua, Fishing/Skill.lua (`skillStart`) |
| `bestPlaces` | `{ safe, continent }`: the best places' Safe for me (true by default) and continent (`"all"`, `"kalimdor"`, `"eastern"`), spec 024; written only by `BestPlaces.SetSafe` / `SetContinent` | Catalog/BestPlaces.lua |
| `pin` | `{ mapID, x, y }` of the map pin as the addon last set it (nil by default), to tell it from a pin the player set | Core/MapPin.lua |
| `channelSession` | the hidden channel's state across a `/reload` (joined by the addon, left by hand, locks, `generalOwed`: the comparison of its number with General's is still owed, `known`: the channel names and numbers that are not new to the repair of the numbers, spec 022) | Channel.lua |

## Core/Commands.lua (loaded last)

`ns.COMMANDS`: every slash command in one place, sorted by name, with its English description and a `run`
function that calls the module at runtime (constitution, Principles II and VI). Modules register no commands; the
names, descriptions and `/okf` help are English on every client. `sound` opens the "Sound effects" page (`SettingsUI.OpenSounds`). `best` opens the best places (`StatsFrame.OpenBest`, spec 024). `catalog` passes the rest of the line through
`Catalog.CommandArg` (an item link becomes its ID) to `StatsFrame.OpenCatalog`. Every command is documented in the
player manual `OneKeyFishing/README.md` (`npm run check`), except a temporary one whose declaration carries a
`VERIFY` marker.

## Core/Data.lua

Shared helpers; the game data they read is in `GameData/` ([game-data.md](game-data.md)):

- Fishing: `ns.IsFishingSpell`, `ns.GetFishingSpellID` (the highest rank learned, from `GameData.FishingSpells`),
  `ns.GameObjectID(guid)` (the object ID of a game object GUID; Forever scrambles the spawn part; nil for a secret
  value) and `ns.IsBobberTargeted()` -> `targeted, known` (the soft interact target is `GameData.Bobber`; in an
  instance its GUID is a secret value, so the answer is `false, false`: unknown, spec 012).
- Secrets: `ns.IsSecret(value)` (`issecretvalue`, false when the game has none): a value the game hides from addon
  code (an instance, a fight) cannot be compared, split or printed.
- Bags: `ns.ForEachBagItem`, the shared bag iterator.
- Names: `ns.PlayerName()` (the own name, `GetUnitName("player", true)`: "First Last" on Forever) and
  `ns.SameCharacter(a, b)` (the same character with or without the own realm suffix; another realm is somebody else);
  names are kept as the game gives them; `ns.CountKeys(tbl)`; `ns.Percent(value)` (a share as a percent, spec 020
  research R9: a whole number from 9.95 % up, "37%"; one decimal from 0.995 %, "3.4%"; two decimals from 0.005 %,
  "0.47%"; "<0.01%" below; "0%" only for 0; the bounds are the rounding edges, so "10.0%" and "1.00%" never appear;
  a point in every language); `ns.FormatCount(value)` (a count with one decimal, the "Per catch" column, spec 020
  decision 27: rounded to tenths, written whole when the rounded value is whole, "1" for 1 and 1.04, else with
  `ns.FormatDecimal(value, 1)`, the client's separator: "1.3", "1,5"); `ns.ColoredText(text, r, g, b)` (the text
  wrapped in the colour's code, `|cffrrggbb...|r`, spec 020 decision 34: a coloured tooltip line carries its colour
  this way too, since the game or another addon may reset the line colours; it wraps a translated text, never part
  of an `L[...]` string); `ns.ItemIDFromLink(text)` (the item ID in an item link).
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
and keys, the Fishing spell and skill, "Camp bonus" (`Camp.Describe()`, spec 020: each bonus's aura and state,
whether aura reads are restricted, the last cast's mask, the setting), gear, lures, pending restore, fished items,
settings, the catch database (`CatchDB.Describe()`, never the anonymous ID; its "bonus parts here" line gives the
own parts of the current place, `CatchDB.DescribeBonusParts`), the auction prices (`Prices.Describe()`, spec 019: the source in use, both switches, Auctionator's two functions present or missing, a failed call, the own catches by the source of their price, the oldest Auctionator price), the auction scan (`Auction.Describe()`: the state, the last scan's
counts, the list's groups, the remembered items, the coverage of the last result), the shared database (`Share.Describe()`, `Channel.Describe()`, no
names) and the catch catalog (`Catalog.Describe()`: the state of each index, its maps and items, the build times
and the name queue, never an item name), "Seed items without a kind" (the bundled seed's items that
`GameData/ItemKinds.lua` does not list, by ID with name and class, an unloaded one asked for; "none" in a release, a
dev build after a harvest lists them), the sections other files added through `Debug.AddSection(title, fn)` (spec 027, an
extension point: `fn(add)` writes lines like the report's own sections, an error becomes a `!! failed` line), then
"Errors and blocked actions" (the error log with the blocked actions of spec 029, the newest first: count, context, times, version, message and stack). `Debug.Report()` returns the window title and the text; `/okf debug`
(`Commands.lua`) shows them in the copy window.
