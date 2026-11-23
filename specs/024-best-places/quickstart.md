# Quickstart: The Best Places to Farm

## Run

```text
npm run check
npm test
```

## What the tests prove

| Test | Proves |
|---|---|
| `tests/catchdb/view_time_test.lua` | views carry `seconds` and `catchesPerHour` from raw cells, the seed's too, unchanged by water or bonus filters and by weights |
| `tests/catalog/best_places_test.lua` | gold per hour = catch value x catches per hour (SC-001); hidden kinds count nothing; at most 10 zones, none under 50 catches, ordered (SC-002); Safe for me (level + 3) and Continent; the `*` at 25 % unpriced |
| `tests/catalog/group_spots_test.lua` | subzones once per zone (SC-003), one-spot groups collapse, "No subzone", group sums and the best-chance pin |
| `tests/ui/best_tab_test.lua` | the tab's rows, columns, red level, expand to subzone and spot, pins, tooltip top 5, the filters and their reset / per-character memory, "Nothing matches the filters." |
| `tests/catalog/group_spots_test.lua`, `tests/ui/catalog_skill_test.lua`, `tests/catalog/spot_pin_test.lua` | the catalog's three levels with its columns; the "No subzone" group and its pin |
| `tests/ui/minimap_menu_test.lua`, `tests/core/` commands | the menu entries and `/okf best` |

## In game (checklist `docs/checklists/best-places.md`)

1. V75: the ranges of `GameData/ZoneLevels.lua` match the game (the API gives 0 in Forever, seen 2026-11-23).
2. V76: the continents of Kalimdor and Eastern Kingdoms zones.
3. The tab, its ten zones, a zone's subzones and spots with pins; the catalog's Wetlands for Oily Blackmouth without
   duplicate subzones.
