# Contract: "Safe for me" and the factions

## GameData (layer 0)

| Table | Contract |
|---|---|
| `GameData.ZoneFactions` | `[uiMapID] = "Alliance" \| "Horde"` (data-model.md); a map not listed is contested |

## BestPlaces (layer 2, `Catalog/BestPlaces.lua`)

| Function | Contract |
|---|---|
| `BestPlaces.ZoneFaction(mapID)` | new: `"Alliance"`, `"Horde"` or nil; the map's own entry or its first listed parent's (the walk of `ZoneLevels`); `VERIFY(V77)` |
| `BestPlaces.PlayerFaction()` | new: `"Alliance"` or `"Horde"` from `UnitFactionGroup("player")`, else nil |
| `BestPlaces.Hostile(zone)` | new: true when `zone.faction` and `PlayerFaction()` are both known and differ |
| `BestPlaces.Zones(filter)` | changed: with Safe for me on, a hostile zone is left out (besides the level rule); zone numbers carry `faction` |
| `BestPlaces.Unsafe(zone)` | changed: also true for a hostile zone |
| `BestPlaces.Describe()` | changed: the last line names the character's faction (`faction Horde`, or `none`) |

Unchanged: `GetSafe` / `SetSafe` (the setter still fires `SETTINGS_CHANGED("bestPlaces")` and only redraws),
`ZoneLevels`, `Continent`, `Spots` (subzones and spots are not filtered by faction).

## UI (layer 3)

Unchanged: `UI/BestPlacesTab.lua` colours the Level column by `BestPlaces.Unsafe`.

## Messages, texts, settings

None new.
