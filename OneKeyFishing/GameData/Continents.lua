-- GameData/Continents: the continents the best places filter by (specs/024-best-places), as UiMap IDs of the
-- Forever client (docs/architecture/game-data.md). Data only: no logic and no L lookup.
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.Continents = {
    kalimdor = 1414,
    eastern = 1415, -- Eastern Kingdoms
}
