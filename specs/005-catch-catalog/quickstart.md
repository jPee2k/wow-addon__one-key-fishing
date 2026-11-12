# Quickstart: validating the catch catalog

How to check part 4 without the game (every change), and where the in-game steps are. Shapes and
functions: [data-model.md](data-model.md), [contracts/api.md](contracts/api.md), [contracts/ui.md](contracts/ui.md).

## Without the game (every change)

```text
npm run check     # Lua 5.1 syntax, globals, ASCII, line length, L keys and translations, seed shape (with `a`)
npm test          # fengari tests and harvest_test.mjs
```

| Test | Proves |
| --- | --- |
| `tests/core/fold_test.lua` (new) | `ns.FoldCase` (ASCII, Latin-1 Supplement, Cyrillic; Korean and Chinese unchanged), `SearchKey` and `CompareText` with and without the game's functions |
| `tests/catchdb/map_views_test.lua` (new) | `QueryMap`, `QueryCells` (point, ranges, cell), `Maps`; stamps: a catch bumps one map, `SHARED_DATA_CHANGED` with keys the records' maps, without keys all; the cache per stamp; the own-cells index equals a full walk |
| `tests/catchdb/area_test.lua` (new) | the area of a cast (stubbed `GetExploredAreaIDsAtPosition`, `GetAreaInfo`, `GetSubZoneText`), matched by folded names, so a case change still matches; `a` in `mine` and the own record, at most 8 areas, no area for cell `"x"`; `CheckRecord` refuses a bad `a`; the spot's main area |
| `tests/catchdb/water_test.lua` (new) | the water filter sums (`"open"` + `"pool"` = `"all"` catches, SC-007), `missRate` nil under a filter, the fallback on filtered catches, the cache keys, `HasPoolData` |
| `tests/catalog/index_test.lua` (new) | items of the seed, the own catch and other records; part 3's three-contributions rule; unknown items hidden until the load event; grey items only with a search; a lower-case search over item names in Latin with accents, Cyrillic, Korean and Chinese (SC-001); order; zones and spots: reliable ones by chance, little-data ones after them by the item's catches; spots with names and coordinates; every read refreshes changed maps (FR-028); `TooltipLines` (reliable first, fallback marked, players from 2); `MinimapLines` (fishing mode only, the setting, grey skipped); sharing off; the name request queue (20 per step); the debug section |
| `tests/ui/tooltips_test.lua` (new) | the "Caught in" lines in `GameTooltip` and `ItemRefTooltip`, before the gear line; the minimap button's and the compartment entry's lines in fishing mode only; the setting off |
| `tests/core/pin_target_test.lua`, `tests/core/pin_set_test.lua`, `tests/catalog/spot_pin_test.lua` (since spec 008: the catalog pins through `Core/MapPin.lua`) | the target: an allowed map, a Micro map through the parent, a dungeon and cell `"x"` without a target, the game rule; `MapPin.Set`: the own pin replaced silently, another pin asks and Cancel keeps it, combat leaves the map closed, a refused pin toasts and saves nothing |
| `tests/ui/catalog_list_test.lua` (new) | the tab between the others and `statsTab = "catalog"`; typing in the search, drilling down, Back keeps the search, expanding a zone; the fixed-row fallback without the scroll templates; `/okf catalog` with text, a single match and a link; the CatchHere row click; FR-028 (a new catch keeps the chosen item) |
| `tests/catalog/load_test.lua` (new) | the largest database (3,000 seed cells, 20,000 places of others, 2,000 own cells on 150 maps): every build step within 8 maps, one own catch rebuilds one map, a tooltip, a search over all names and the largest zone in one call each (SC-003) |
| `tests/ui/here_page_test.lua`, `ui/shared_page_test.lua`, `core/english_commands_test.lua`, `exchange/share/store_test.lua`, `ui/spike_test.lua`, `core/locale_test.lua` (extended) | the Water button, the setting, the command list, `CleanCell` keeps `a`, the spike section, the new keys in all languages |
| `tests/tools/harvest_test.mjs` (extended) | `a` checked, summed (8 largest), scaled by the cast factor, written and read back by `seedProblems`; a 500-place record with areas encodes under 28 KB with the test's minimal CBOR encoder, `zlib.deflateRawSync` and Base64 (V18) |

## In game

The in-game steps live in `docs/checklists/`: [spike.md](../../docs/checklists/spike.md) prints the game facts
(V30-V37) with `/okf spike`, then [catch-catalog.md](../../docs/checklists/catch-catalog.md) checks the feature; the order of everything is
`docs/release-plan.md`.
