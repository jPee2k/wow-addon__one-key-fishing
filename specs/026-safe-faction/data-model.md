# Data Model: "Safe for me" and the factions

## Zone faction (`GameData.ZoneFactions`, layer 0, new)

`[uiMapID] = "Alliance" | "Horde"`; data only. A map not listed (and whose parents are not listed) is contested.

| UiMap ID | Zone | Faction |
|---|---|---|
| 1429 | Elwynn Forest | Alliance |
| 1436 | Westfall | Alliance |
| 1426 | Dun Morogh | Alliance |
| 1432 | Loch Modan | Alliance |
| 1438 | Teldrassil | Alliance |
| 1439 | Darkshore | Alliance |
| 1453 | Stormwind City | Alliance |
| 1455 | Ironforge | Alliance |
| 1457 | Darnassus | Alliance |
| 1411 | Durotar | Horde |
| 1412 | Mulgore | Horde |
| 1413 | The Barrens | Horde |
| 1420 | Tirisfal Glades | Horde |
| 1421 | Silverpine Forest | Horde |
| 1454 | Orgrimmar | Horde |
| 1456 | Thunder Bluff | Horde |
| 1458 | Undercity | Horde |

Source: `AreaTable.FactionGroupMask` (2 Alliance, 4 Horde) of each map's area through `UiMapAssignment`, product
`wowf`, build 1.60.1.71037 (research R1). Validation (shape test): every key a map ID, every value one of the two
tags, nine Alliance and eight Horde entries, every key also a zone of `GameData.ZoneLevels`.

## Zone place numbers (`BestPlaces`, changed)

The zone numbers of spec 024 (`specs/024-best-places/data-model.md`) gain one field:

| Field | Meaning |
|---|---|
| `faction` | `"Alliance"`, `"Horde"` or nil (contested), from `BestPlaces.ZoneFaction(mapID)`, set in `Compute` with `levels` |

## Character faction (read, not stored)

`BestPlaces.PlayerFaction()`: `"Alliance"`, `"Horde"` or nil (unknown or neutral).

## Rules

| Rule | When |
|---|---|
| hostile | zone `faction` and character faction both known, and different |
| hidden by Safe for me | Safe for me on and (hostile, or lowest level > character level + 3) |
| Level in red (`Unsafe`) | hostile, or lowest level > character level |

No saved field changes; `charDB.bestPlaces.safe` keeps its default (on).
