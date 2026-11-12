# Contract: Module Functions Changed by Spec 011

No message is added; `FISH_CAUGHT` loses its `fromPool` argument and is `(items, castID)`. The
exchange format does not change.

## `ns.CatchDB` (`CatchDB/CatchDB.lua`)

### `CatchDB.GetCurrentPlace()` -> mapID, range, cell, x, y | nil

- C1: on a map of type Zone (3) or deeper: as today.
- C2: on a map of type Continent (2) or lower: the map is `C_Map.GetMapInfoAtPosition(mapID, x, y)` of the player's
  position on it, if that is of type Zone or deeper; cell, x and y are read on that map.
- C3: no zone under the point, no position on the continent, or no position on the zone: nil.
- C4: without Fishing or a map: nil, as today.

### `CatchDB.LookupArea(done)` (replaces `CatchDB.GetArea(mapID, x, y)`)

- A1: `GetSubZoneText()` empty or not a string (also a secret value): `done` is not called; the cast keeps no area.
- A2: the folded text is cached: `done(areaID)` at once (nothing for a cached false).
- A3: not cached: a walk over the area IDs 1..`MAX_AREA_ID`, `AREA_CHUNK` per frame step; at its end the result
  (the lowest matching ID, or false) is cached and `done(areaID)` runs for every waiting caller when an ID was
  found.
- A4: a call for another text while a walk runs: `done` is not called.
- A5: no frame step checks more than `AREA_CHUNK` IDs.

`CatchDB/Events.lua` at `FISHING_CAST_START`: when the place has a position, it calls
`CatchDB.LookupArea(function(areaID) cast.area = areaID end)` for the new cast entry.

### `CatchDB.private` additions (tests only)

- `P.MAX_AREA_ID`, `P.AREA_CHUNK`, and a reset of the area cache (`P.ResetAreas()`), for the tests.

## Pool source (`Catch/Catch.lua`, `CatchDB`)

- L1: the source is not known in Forever: `ns.IsPoolLoot` is removed, and no catch writes a pool part.

## `ns.Skill` (`Fishing/Skill.lua`)

- K1: every name read from the game that is a secret value counts as missing: the advice uses its fallback, and no
  error is raised.
- K2: the skill check does nothing while `InCombatLockdown()` is true: no advice, no tooltip read, no notice.
- K3: `PLAYER_REGEN_ENABLED` runs the check; a notice owed during the fight is shown once.
- K4: a secret NPC name is not cached; a later call outside the fight reads the game's name.

## `ns.Gear` (`Fishing/Gear.lua`)

### `Gear.FindBestPole()` -> itemID, bonus

- G1: a pole in the bags whose `GameData.FishingPoles[itemID].skill` is above `Skill.Get()` is passed over; the
  pole in the main hand is not (the game let it be equipped; final review).
- G2: `Skill.Get()` nil, or a pole without an entry: no pole is held back.
- G3: among the usable poles the order is as today (bonus, then item level).

`Gear.GetPole()` is unchanged: a pole chosen by hand and still held is used.
