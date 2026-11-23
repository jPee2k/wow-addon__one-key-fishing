# Verification: The Best Places to Farm

The code built on assumptions only the game can confirm carries `-- VERIFY(<id>): <what>`; the IDs continue the V
series (V74 was spec 022's; this spec has V75 and V76). A marker is removed after the author confirms the behaviour
in game, or when the author accepts the assumption without a check (the row then says "Accepted" and what happens if
it is wrong).

To close an item: run its check, record the answer in `docs/forever-api.md`, adjust the code if the game differs,
remove the marker. Each `/run` line is at most 255 characters (counted).

| ID | Assumed | Where | If wrong | Check | Status |
|---|---|---|---|---|---|
| V75 | The level ranges of `GameData.ZoneLevels` (from LibTouristClassicEra) match Forever's zones | `GameData/ZoneLevels.lua`, `Catalog/BestPlaces.lua` `ZoneLevels` | A zone is hidden too early or too late by "Safe for me" and its Level column is off; the table row is corrected | The first assumption failed in game on 2026-11-23: `C_Map.GetMapLevels` gives `0 0 0 0` for Elwynn, Westfall, Durotar, the Barrens, Ashenvale and Stranglethorn (the client has no zone levels: `UiMap.ContentTuningID` and `AreaTable.ExplorationLevel` are 0), so the table replaced it. Check: hover a few zones on the world map with an addon that shows levels, or compare with the zone's quests; Riverglades showed 35-45, as in the table | Open (the table) |
| V76 | A zone map's first parent of type Continent is Kalimdor (1414) or the Eastern Kingdoms (1415) | `Catalog/BestPlaces.lua` `Continent` | The Continent filter keeps no zone (only "All" shows them) | `/run for _,m in ipairs({1429,1436,1411,1413,1440,1434})do local i=C_Map.GetMapInfo(m)while i and i.mapType>2 do i=C_Map.GetMapInfo(i.parentMapID)end print(m,i and i.mapID,i and i.name)end` (187 characters): 1415 for 1429, 1436, 1434; 1414 for 1411, 1413, 1440 | Open |
