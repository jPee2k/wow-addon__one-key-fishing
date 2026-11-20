-- GameData/FishedQuestItems: quest items fished as an extra loot slot beside the ordinary catch, without any camp
-- bonus (docs/fishing-investigation.md, "A second loot slot without a buff"; the bundled data's places with more item
-- slots than catches hold them). The statistics' camp bonus catches leave their slots out (Fishing/Camp.lua,
-- IsBonusCatch; specs/020-camp-buffs decision 33). Data only: no logic and no L lookup.
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.FishedQuestItems = {
    classID = 12, -- Enum.ItemClass.Questitem: any item of the quest class counts as one too
    items = { -- the known ones (most are of the class Miscellaneous, so the class alone misses them)
        [6718] = true, -- Electropeller (Darkshore)
        [16967] = true, -- Feralas Ahi (Nat Pagle)
        [16968] = true, -- Sar'theris Striker (Nat Pagle)
        [16969] = true, -- Savage Coast Blue Sailfin (Nat Pagle)
        [16970] = true, -- Misty Reed Mahi Mahi (Nat Pagle)
        [19806] = true, -- Dezian Queenfish (Stranglethorn Fishing Extravaganza)
        [19807] = true, -- Speckled Tastyfish (Stranglethorn Fishing Extravaganza)
    },
}
