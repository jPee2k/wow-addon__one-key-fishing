-- GameData/Icons: icon file IDs of game entities (docs/architecture/game-data.md). Data only: no logic and no L
-- lookup.
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.Icons = {
    unknownItem = 134400, -- INV_Misc_QuestionMark: an item the client does not know yet
}
