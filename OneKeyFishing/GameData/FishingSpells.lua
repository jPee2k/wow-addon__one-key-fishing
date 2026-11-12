-- GameData/FishingSpells: the Fishing spell of each rank and the skill cap it gives, lowest first
-- (docs/architecture/game-data.md). Data only: no logic and no L lookup. The spell's subtext is the rank name.
-- Source: the original game (Wowhead Classic); the IDs are seen in game (release 1.1.0).
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.FishingSpells = {
    { spellID = 7620, cap = 75 }, -- Apprentice
    { spellID = 7731, cap = 150 }, -- Journeyman
    { spellID = 7732, cap = 225 }, -- Expert
    { spellID = 18248, cap = 300 }, -- Artisan
}
