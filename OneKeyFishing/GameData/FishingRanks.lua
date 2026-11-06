-- GameData/FishingRanks: how each Fishing rank is learned (spec 001, User Story 3; research R11, R15).
-- Data only: no logic and no L lookup. Names shown to the player are read from the client by ID (Skill.lua); the
-- English names here are the fallback until the client has loaded its own. String literals in GameData/ files may
-- hold UTF-8 official names (constitution, Technical Constraints); code, keys and comments stay ASCII.
-- Source: the original game (Wowhead Classic, 2026-11-03). VERIFY(R11) marks what the in-game check confirms.
local _, ns = ...

-- The Fishing spell of each rank, keyed by the rank's skill cap (the IDs are in Data.lua, which loads first). Its
-- spell subtext is the rank name.
local SPELLS = ns.FISHING_SPELL_IDS -- Apprentice, Journeyman, Expert, Artisan
ns.FishingRankSpells = { [75] = SPELLS[1], [150] = SPELLS[2], [225] = SPELLS[3], [300] = SPELLS[4] }

-- What follows each cap: the next rank's spell, the skill and character level from which it can be learned, and
-- where. A place has a sub-zone and a zone (AreaTable IDs for C_Map.GetAreaInfo), candidate uiMapIDs (the Classic
-- map first, then the modern one; the first the client knows and allows pins on is used) and the NPC's point.
ns.FishingRanks = {
    [75] = {
        next = SPELLS[2], -- Journeyman
        learnAt = 50, -- VERIFY(R11)
        level = 10,
        source = { kind = "trainer" },
    },
    [150] = {
        next = SPELLS[3], -- Expert
        learnAt = 125, -- VERIFY(R11)
        level = 20, -- VERIFY(R11)
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
        next = SPELLS[4], -- Artisan
        learnAt = 225, -- VERIFY(R11)
        level = 35, -- VERIFY(R11)
        source = {
            kind = "quest",
            questID = 6607, -- Nat Pagle, Angler Extreme; VERIFY(R11)
            npcID = 12919, -- Nat Pagle, gives it; VERIFY(R11)
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

-- Official NPC names per client language (GetLocale()), for when the client cannot tell them (no API reads an NPC
-- name by ID). enUS is the fallback for every other client language (esMX: no confirmed source, so English).
-- Source: Wowhead's localized pages and tooltips (2026-11-03). VERIFY(R12): deDE Heming is "Der alte Mann Heming"
-- in the modern data but English in Wowhead's Classic data.
ns.NpcNames = {
    [2626] = {
        enUS = "Old Man Heming",
        deDE = "Der alte Mann Heming",
        esES = "Viejo Heming",
        frFR = "Vieil Heming",
        itIT = "Vecchio Heming",
        ptBR = "Velho Heming",
        ruRU = "Старик Хеминг",
        koKR = "노인 헤밍",
        zhCN = "老人海明威",
        zhTW = "老人海明威",
    },
    [12919] = {
        enUS = "Nat Pagle",
        deDE = "Nat Pagle",
        esES = "Nat Pagle",
        frFR = "Nat Pagle",
        itIT = "Nat Pagle",
        ptBR = "Nat Pagle",
        ruRU = "Нат Пэгл",
        koKR = "내트 페이글",
        zhCN = "纳特·帕格",
        zhTW = "納特‧帕格",
    },
}
