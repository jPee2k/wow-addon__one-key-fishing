# Quickstart: Cumulative Skill Filter

**Feature**: [spec.md](spec.md) | **Contracts**: [contracts/api.md](contracts/api.md)

## Run

```text
npm install      # once
npm run check    # luacheck, layers, locales (every key in ten files, removed keys gone), Markdown
npm test         # fengari, Lua 5.3
```

## What the tests prove

| Test file | Proves | Spec |
|---|---|---|
| `tests/catchdb/skill_ranges_test.lua` (new) | `up to N` sums ranges 0..N (items, catches, players); a place with data only below the own range shows it; data above stays out; `"all"` equals the old all-range sums; a stray `4` reads as `"all"`; spot or map chosen on the summed catches | FR-001, FR-002, US1, SC-001, SC-002 |
| `tests/catchdb/skill_misses_test.lua` (new) | the miss rate from the chosen range alone at the view's scope (spot, and map after a fallback); `missLittleData` below 50 casts with the list still shown; `"all"` reads 300+ only; under a bonus filter the bonus part of that range; no miss rate under a water filter; `QueryMap` / `QueryCells` carry none | FR-005 to FR-008, US2, SC-003 |
| `tests/catchdb/skill_filter_test.lua` (new) | `CatchDB.SkillFilter`: nil and 4 give `"all"`, 0..3 themselves; `CatchDB.RangeOf` of a rank, and `GetCurrentPlace` through it | FR-010, FR-013 |
| `tests/ui/here_skill_test.lua` (new) | the button text per value; the menu's five values in order with "(yours)" on the own range, also without a map, none without Fishing; the tooltip's two lines; the counts line with "little data"; no hint; the default follows the rank until a hand pick, which lasts | FR-009 to FR-014, US3 |
| `tests/ui/catalog_skill_test.lua` (new) | the catalog opens on "Skill: All"; "(yours)" in its menu; `up to 149` sums zones and spots; the Skill column unchanged | FR-002, FR-013, FR-015, US4 |
| `tests/catalog/index_test.lua` (extended, next to the other `MinimapLines` tests) | the minimap lines sum up to the own range; 300+ reads every range | FR-002, US4 |
| `tests/ui/tooltips_test.lua` (unchanged, must pass) | item tooltips read as before | FR-003, SC-006 |
| `tests/catchdb/bonus_views_test.lua`, `water_test.lua` (adjusted; `weights_test.lua` passed unchanged) | their miss rates read from `Query` in the data's own range (research R7) | FR-005 |
| `tests/catchdb/recording_test.lua`, `tests/catalog/sort_test.lua` (adjusted) | a cell of a higher range moved to 300+, so the filter still leaves it out under cumulative sums | FR-001 |
| `tests/ui/catalog_list_test.lua`, `here_page_test.lua`, `here_login_test.lua` (adjusted) | the new labels; the removed hint | FR-011, FR-014 |

Each new test fails on `develop` before the change.

## In game

`docs/checklists/skill-filter.md` (new): the menu in both tabs with "(yours)", also in an instance; the button and
the tooltip in German and French, then the other seven languages, within the button; the counts line with a miss rate
and with "little data"; the minimap lines in fishing mode; a place with data only below the own range.
