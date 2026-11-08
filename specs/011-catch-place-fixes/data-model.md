# Data Model: Catch Place Fixes

No saved field changes shape: no `DB_SCHEMA` bump, no migration. Data recorded before the fix stays as it is
(the quiz: continent cells and pool catches written as open water are the author's only).

## Place of a cast (session, `CatchDB/Events.lua` `casts[castID]`)

| Field | Before | After |
|---|---|---|
| `key` | `"<mapID>:<range>:<cell>"` of the map the game reports | the same, but `mapID` is never a continent: the zone under the point (R2) |
| `x`, `y` | position on that map | position on the zone map |
| `area` | an explored region's ID whose name equals the subzone text, else nil | the lowest area ID whose folded name equals the subzone text, else nil; may be filled a few frames after the cast starts (R3) |

Rules:
- P1: a continent (map type 2 or lower) is never a place key.
- P2: without a zone under the point, or without a position on it, there is no place: no cast entry is made.
- P3: on a zone, city or smaller map nothing changes.

## Area lookup (session, `CatchDB`)

| State | Meaning |
|---|---|
| `areaByName[folded]` = number | the area ID found for that subzone text |
| `areaByName[folded]` = false | walked, no area has that name |
| `walk` = `{ needle, next, best, waiting = { callbacks } }` | the walk in progress; one at a time |

Transitions:
- A cast in a subzone whose text is cached: its area is set at once.
- Not cached and no walk: a walk starts at ID 1; the cast's callback waits.
- Not cached and a walk for the same text: the callback joins it.
- Not cached and a walk for another text: the cast keeps no area (the player changed subzone within a fraction of a
  second; rare), and the running walk goes on.
- Each step checks `AREA_CHUNK` IDs; past `MAX_AREA_ID` the result is cached and every waiting callback runs.

## Loot source

- Before: `FISH_CAUGHT` (items, fromPool, castID), fromPool true (pool) or false (bobber, open water).
- After: not known; `FISH_CAUGHT` is (items, castID) and `Settle` writes no `p` part; existing `p` parts in stored
  or received cells stay valid and readable.

## Next-rank check (session, `Fishing/Skill.lua`)

- `warned[cap]` as today.
- New: nothing is stored for a fight; `Check` returns at once while in combat, and `PLAYER_REGEN_ENABLED` runs
  `Check(false)`, which shows what is owed by the rules of today.
- `gameNpcNames[npcID]` holds only a plain, non-empty string.

## Pole choice (`Fishing/Gear.lua`)

- Input: the poles in the main hand and bags, `GameData.FishingPoles[itemID].skill`, `Skill.Get()`.
- Rule: a pole with a recorded requirement above a known rank is not a candidate.
- `charDB.gear.pole` (a choice by hand) is used as today.
