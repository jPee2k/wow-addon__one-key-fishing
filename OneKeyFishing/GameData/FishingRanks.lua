-- GameData/FishingRanks: how each Fishing rank is learned (spec 001, User Story 3; research R11, R15;
-- docs/architecture/game-data.md).
-- Data only: no logic and no L lookup. Names shown to the player are read from the client by ID (Skill.lua); the
-- English names here are the fallback until the client has loaded its own. String literals in GameData/ files may
-- hold UTF-8 official names (constitution, Technical Constraints); code, keys and comments stay ASCII.
-- Source: the original game (Wowhead Classic, 2026-11-03). The VERIFY marks of research R11
-- (specs/001-interface-language/verification.md) show what the in-game check still has to confirm.
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

-- The Fishing spells by rank (GameData/FishingSpells.lua loads first): 1 Apprentice, 2 Journeyman, 3 Expert,
-- 4 Artisan.
local SPELLS = GameData.FishingSpells

-- What follows each cap: the next rank's spell, the skill and character level from which it can be learned, and
-- where. A place has a sub-zone and a zone (AreaTable IDs for C_Map.GetAreaInfo), candidate uiMapIDs (the Classic
-- map first, then the modern one; the first the client knows and allows pins on is used) and the NPC's point.
GameData.FishingRanks = {
    [75] = {
        next = SPELLS[2].spellID, -- Journeyman
        learnAt = 50, -- VERIFY(R11)
        level = 10,
        source = { kind = "trainer" },
    },
    [150] = {
        next = SPELLS[3].spellID, -- Expert
        learnAt = 125, -- the book's tooltip: Requires Fishing (125) (seen in game)
        level = 20, -- the book's tooltip: Requires Level 20 (seen in game)
        source = {
            kind = "book",
            itemID = 16083, -- Expert Fishing - The Bass and You (Heming sells it, seen in game)
            npcID = 2626, -- Old Man Heming, sells it (seen in Booty Bay)
            areaID = 35, -- Booty Bay
            zoneAreaID = 33, -- Stranglethorn Vale
            maps = { 1434, 224 }, -- Forever uses the Classic map (seen in game)
            x = 0.274,
            y = 0.770,
        },
        fallback = {
            item = "Expert Fishing - The Bass and You",
            area = "Booty Bay",
            zone = "Stranglethorn Vale",
        },
    },
    [225] = {
        next = SPELLS[4].spellID, -- Artisan
        learnAt = 225, -- VERIFY(R11)
        level = 35, -- VERIFY(R11)
        source = {
            kind = "quest",
            questID = 6607, -- Nat Pagle, Angler Extreme (the game gives this title, seen in game)
            npcID = 12919, -- Nat Pagle, gives it (the game names this NPC so, seen in game)
            areaID = 517, -- Tidefury Cove
            zoneAreaID = 15, -- Dustwallow Marsh
            maps = { 1445, 70 }, -- VERIFY(R11)
            x = 0.586, -- VERIFY(R11)
            y = 0.602, -- VERIFY(R11)
        },
        fallback = {
            quest = "Nat Pagle, Angler Extreme",
            area = "Tidefury Cove",
            zone = "Dustwallow Marsh",
        },
    },
}
