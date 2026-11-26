# Verification: "Safe for me" and the factions

The code built on assumptions only the game can confirm carries `-- VERIFY(<id>): <what>`; the IDs continue the V
series (V75 and V76 were spec 024's; this spec has V77). A marker is removed after the author confirms the behaviour
in game, or when the author accepts the assumption without a check (the row then says "Accepted" and what happens if
it is wrong).

To close an item: run its check, record the answer in `docs/forever-api.md` (the zone territory facts), adjust the
code or the table if the game differs, remove the marker. Each `/run` line is at most 255 characters (counted).

| ID | Assumed | Where | If wrong | Check | Status |
|---|---|---|---|---|---|
| V77 | The factions of `GameData.ZoneFactions` (from `AreaTable.FactionGroupMask`, build 1.60.1.71037) are the game's territory in play: six Alliance zones and three capitals, five Horde zones and three capitals; every other zone (Redridge, Duskwood, Wetlands, Ashenvale, Stonetalon, Hillsbrad, Forever's new zones) contested | `GameData/ZoneFactions.lua`, `Catalog/BestPlaces.lua` `ZoneFaction` | A zone is hidden by "Safe for me" for the wrong faction, or an enemy zone is not hidden; its row in the table is corrected | `C_PvP.GetZonePVPInfo()` cannot confirm it: in Forever it names only the capitals (seen 2026-11-24, PvP realm; `docs/forever-api.md`, "Zone territory"). The check is the tab on both characters: Safe for me on hides the other side's zones and capitals, off shows them with the Level in red ([checklist](../../docs/checklists/best-places.md), steps 12 and 13) | Confirmed 2026-11-24: Horde (level 40) and Alliance (level 1) characters; with Safe for me off the other side's zones and capitals of levels 1-12 and 1-60 showed their Level in red beside white own ones, with it on they were gone and the own and contested zones (Zephras Isle too) stayed |
