-- GameData/Bobber: the fishing bobber (docs/architecture/game-data.md). Data only: no logic and no L lookup.
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

-- The game object entry of the bobber, as seen in its GUID (the "softinteract" unit, fishing loot sources). A string:
-- it is compared with a part of the GUID. Seen in game (release 1.1.0).
GameData.Bobber = { objectID = "35591" }
