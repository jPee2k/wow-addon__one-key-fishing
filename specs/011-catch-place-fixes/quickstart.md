# Quickstart: Catch Place Fixes

The rules being checked are in [contracts/module-api.md](contracts/module-api.md); the state is in
[data-model.md](data-model.md).

## Automated

```sh
npm run check
npm test
```

Each test fails without its fix (spec FR-017):

| Test | Proves | Fails without |
|---|---|---|
| `tests/fishing/skill_secret_test.lua` (new) | K1, K4: a secret tooltip line gives the table's name, no error, and is read again later; K2, K3: a skill event in a fight reads no tooltip and shows nothing, the end of the fight shows the owed notice once | the `issecretvalue` guard; the fight skip and the `PLAYER_REGEN_ENABLED` handler |
| `tests/catchdb/cave_test.lua` (new) | C1-C3: a continent map gives the zone under the point with its cell; no zone or no position gives no place; a zone map is unchanged | the continent branch of `GetCurrentPlace` |
| `tests/catchdb/area_test.lua` (rewritten) | A1-A5: found by name (folded), lowest ID of several, false cached, walk spread over steps with at most `AREA_CHUNK` IDs each, a cast gets its area at the end of the walk | `LookupArea` |
| catch and catalog tests | L1: no pool part is written for any loot source, `HasPoolData` stays false, the "Water" filter stays hidden | `IsPoolLoot` returning nil |
| `tests/fishing/gear_pole_test.lua` (new, or the gear tests) | G1-G3: a pole above the skill is passed over; unknown skill holds nothing back | the skill rule in `FindBestPole` |
| `tests/ui/spike_test.lua` | the Areas section is gone | the spike trim |

## In game, before the code (done 2026-11-08)

- Cave: `C_Map.GetMapInfoAtPosition(1414, x, y)` gives The Barrens 1413.
- Subzone by name: Ratchet 392, Stonebull Lake 223, the Thunder Bluff pond has no subzone text; 4.3 to 4.7 ms per
  walk; highest area ID 17853.
- Cave: `C_Map.GetPlayerMapPosition(1413, "player")` gives a position inside the cave (x 0.461).

## In game (after the implementation)

Already confirmed, not repeated: the continent map in the cave, the zone under it, the area IDs by name.

1. **A fight** (batch 6): a dungeon run with skill-ups while the next rank waits for a character level (or at the
   cap): no Lua error; after the fight the "can learn" notice comes only if it is owed.
2. **The cave** (`b-cave`): a few casts in the cave before Wailing Caverns, then "What can be caught here" and the
   catalog: the place is The Barrens, the spot in the right point with its pin; no "Kalimdor".
3. **Spot names** (`b-subzone`): a few casts at Stonebull Lake and at Ratchet, then catalog -> the fish -> "+":
   "Stonebull Lake (46, 58)", "Ratchet (63, 36)"; at the Thunder Bluff pond coordinates only.
4. **Pools** (`b-pool`): a catch from a pool and one from open water: no "Water" button on either tab.
5. **The pole** (only if such a pole is at hand): a pole above the skill in the bags is not equipped by fishing
   mode.
