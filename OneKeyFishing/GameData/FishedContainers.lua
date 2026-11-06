-- GameData/FishedContainers: the containers that are caught while fishing (docs/architecture/game-data.md). Data
-- only: no logic and no L lookup. Anything else with loot that was caught while fishing is opened too (Bags.lua).
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.FishedContainers = {
    [5523] = true, -- Small Barnacled Clam
    [5524] = true, -- Thick-shelled Clam
    [7973] = true, -- Big-mouth Clam
    [15874] = true, -- Soft-shelled Clam
}
