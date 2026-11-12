# Quickstart: validating the architecture alignment

## Before the game (what the tests prove)

Baseline before the change (2026-11-06): 91 `*_test.lua` files, 623 `test(` cases in Lua, `npm test` 665 passed /
0 failed (Lua and Node), 61 VERIFY markers in `npm run check`.
After the change (2026-11-06): 96 `*_test.lua` files, 639 `test(` cases in Lua, `npm test` 691 passed / 0 failed,
65 VERIFY markers (V43 x6 and V44 added; V7, V32 and the FishingRanks.lua header gone).

1. `npm run check` passes, and:
   - no file under `OneKeyFishing/GameData/` holds a function, an `ns.L` or another module (contract C1);
   - no layer break;
   - no test is named `<module>_test.lua`;
   - the VERIFY list shows V43 and V44 and no longer shows V7 or V32.
2. `npm test` passes. These prove the change:

   | Test | Proves |
   |---|---|
   | `tests/gamedata/shape_test.lua` | every entity has its fields with values of the right kind; the range step 75 and 4 ranges (data-model "Rules") |
   | `tests/gamedata/load_order_test.lua` | the GameData files come before `Core/Core.lua` in the TOC; `Core/Data.lua` finds the spells at load |
   | `tests/fishing/lure_skill_test.lua` | a known lure above the skill is never offered, one at the skill is, a rise during the session offers it, an unknown skill holds nothing back (spec US2) |
   | `tests/core/pin_target_test.lua`, `pin_set_test.lua` | one pin for the catalog and the rank: the parent map fallback, no question when the pin is already there, the toast through `MAP_PIN_SET` (spec US3) |
   | `tests/catalog/spot_pin_test.lua` | the catalog's own rules (a dungeon cell, a cell without a position) still give no pin |
   | `tests/tools/gamedata_check_test.mjs` | `npm run check` rejects a function or `ns.L` in `GameData/` |
   | the renamed and moved tests ([research.md](research.md) R10) | the same cases as before, under their new names |

3. Search: `git grep -n "FISHING_SPELL_IDS\|BOBBER_OBJECT_ID\|FISHING_SKILL_LINE\|PinTarget\|KNOWN_POLE_BONUS" -- OneKeyFishing tests`
   finds nothing. `git grep -n "UI/MapPin.lua\|OneKeyFishing/SeedData.lua" -- CLAUDE.md README.md docs` finds
   nothing.
4. `npm run install-addon`, then **restart the game**: new files and a TOC change need it, so `/reload` is not
   enough.

## In game

The steps are in the existing checklists; the ones this change affects are unticked there (research R13).

| # | Story | Checklist step | Expected |
|---|---|---|---|
| 1 | US1 | `fishing-mode.md` On / Off / `/reload` / Relog, Chosen pole, Find fishing items, Clam | as before the change: the pole and gear swap, the bonus, the clam opens |
| 2 | US2 | `fishing-mode.md` Lure too high | below the lure's skill it is never offered (no "Cannot apply"); at the skill it is |
| 3 | US2 | `fishing-mode.md` Debug report | each lure line shows `needs: N`; the report has the line `early L lookups: none` |
| 4 | US1 | `interface-language.md` the rank names, the next-rank notices, `/okf debug` next rank | as in 1.1.0 |
| 5 | US3 | `interface-language.md` Pin button, own pin replace, chat map link | as in 1.1.0; pinning the same place twice asks nothing |
| 6 | US3 | `catch-catalog.md` steps 3 to 5 | a catalog pin behaves like the rank pin; a cave spot pins on its zone map |
