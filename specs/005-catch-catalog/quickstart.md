# Quickstart: validating the catch catalog

How to check part 4 without the game (every change), on launch day with the spike, and in game. Shapes and
functions: [data-model.md](data-model.md), [contracts/api.md](contracts/api.md), [contracts/ui.md](contracts/ui.md).

## Without the game (every change)

```text
npm run check     # Lua 5.1 syntax, globals, ASCII, line length, L keys and translations, seed shape (with `a`)
npm test          # fengari tests and harvest_test.mjs
```

| Test | Proves |
| --- | --- |
| `tests/fold_test.lua` (new) | `ns.FoldCase` (ASCII, Latin-1 Supplement, Cyrillic; Korean and Chinese unchanged), `SearchKey` and `CompareText` with and without the game's functions |
| `tests/catchdb_views_test.lua` (new) | `QueryMap`, `QueryCells` (point, ranges, cell), `Maps`; stamps: a catch bumps one map, `SHARED_DATA_CHANGED` with keys the records' maps, without keys all; the cache per stamp; the own-cells index equals a full walk |
| `tests/catchdb_area_test.lua` (new) | the area of a cast (stubbed `GetExploredAreaIDsAtPosition`, `GetAreaInfo`, `GetSubZoneText`), matched by folded names, so a case change still matches; `a` in `mine` and the own record, at most 8 areas, no area for cell `"x"`; `CheckRecord` refuses a bad `a`; the spot's main area |
| `tests/catchdb_water_test.lua` (new) | the water filter sums (`"open"` + `"pool"` = `"all"` catches, SC-007), `missRate` nil under a filter, the fallback on filtered catches, the cache keys, `HasPoolData` |
| `tests/catalog_test.lua` (new) | items of the seed, the own catch and other records; part 3's three-contributions rule; unknown items hidden until the load event; grey items only with a search; a lower-case search over item names in Latin with accents, Cyrillic, Korean and Chinese (SC-001); order; zones and spots: reliable ones by chance, little-data ones after them by the item's catches; spots with names and coordinates; every read refreshes changed maps (FR-028); `TooltipLines` (reliable first, fallback marked, players from 2); `MinimapLines` (fishing mode only, the setting, grey skipped); sharing off; the name request queue (20 per step); the debug section |
| `tests/tooltips_test.lua` (new) | the "Caught in" lines in `GameTooltip` and `ItemRefTooltip`, before the gear line; the minimap button's and the compartment entry's lines in fishing mode only; the setting off |
| `tests/catalog_pin_test.lua` (new) | `PinTarget`: an allowed map, a Micro map through the parent, a dungeon and cell `"x"` without a target, the game rule; `CatalogTab.Pin`: the own pin replaced silently, another pin asks and Cancel keeps it, combat leaves the map closed, a refused pin toasts and saves nothing |
| `tests/catalogtab_test.lua` (new) | the tab between the others and `statsTab = "catalog"`; typing in the search, drilling down, Back keeps the search, expanding a zone; the fixed-row fallback without the scroll templates; `/okf catalog` with text, a single match and a link; the CatchHere row click; FR-028 (a new catch keeps the chosen item) |
| `tests/catalog_load_test.lua` (new) | the largest database (3,000 seed cells, 20,000 places of others, 2,000 own cells on 150 maps): every build step within 8 maps, one own catch rebuilds one map, a tooltip, a search over all names and the largest zone in one call each (SC-003) |
| `tests/catchhere_test.lua`, `settings_test.lua`, `commands_test.lua`, `share_store_test.lua`, `spike_test.lua`, `locale_test.lua` (extended) | the Water button, the setting, the command list, `CleanCell` keeps `a`, the spike section, the new keys in all languages |
| `tests/harvest_test.mjs` (extended) | `a` checked, summed (8 largest), scaled by the cast factor, written and read back by `seedProblems`; a 500-place record with areas encodes under 28 KB with the test's minimal CBOR encoder, `zlib.deflateRawSync` and Base64 (V18) |

## The spike (launch day, research R13)

`/okf spike`, section "Map pins and areas (V30-V36)"; copy the report from the copy window.

1. Stand in an open-world zone, then inside a cave with its own map, then inside an instance: `CanSetUserWaypointOnMap`
   for the map and its parent, the map type, the game rule, `showInGameNavigation`, the current waypoint (V30, V31,
   V33).
2. Fish at three waters (a zone without a subzone, a named subzone, a city): the area IDs at the position with their
   names, `GetSubZoneText()` and the area the addon keeps (V34).
3. The load state of three catalog items before and after opening the catalog (V35).
4. `CaseAccentInsensitiveParse` of the sample and the `strcmputf8i` order, on the client's language (V36).
5. Whether the scroll and search templates and the pin atlas exist (V37).

The answers go into `docs/forever-api.md`.

## In game: the feature (after the spike, V40)

The checklist is `docs/checklists/catch-catalog.md` (written with the code). In short:

1. Open the catalog on a fresh client folder: "Counting the catch..." at most a moment, then every item of the seed;
   type part of a name in lower case on a deDE or ruRU client; no grey items until a search (V35-V37).
2. Choose an item: zones sorted, little data last; expand a zone: subzone names and coordinates.
3. Press a spot's pin button: the pin on the map and the minimap, the arrow points to it, the toast, the map opens;
   in combat the map stays closed (V30-V32). From typing a name to the pin takes at most five actions (SC-002).
4. Set a pin by hand, press another pin button: the question; Cancel keeps the hand pin.
5. A spot in a cave and one in an instance: the cave's pin lands on the zone map at the cave entrance's water or the
   button is missing; the instance has none (V33).
6. A second client in another language: the same zones, chances and catches, names in its own language (SC-005,
   V34).
7. Hover a fish in the bags, the auction house and a chat link: "Caught in"; the minimap tooltip in fishing mode;
   the setting off removes both (V38).
8. `/okf debug` after an hour of fishing with the exchange on: the catalog's longest step under 5 ms, no stutter
   (V39).
9. With pool data (V3 passed): the Water filter in both tabs; "Open water" plus "Pools" catches add up to
   "Everywhere".
