-- GameData/NpcNames: official NPC names per client language (docs/architecture/game-data.md). Data only: no logic
-- and no L lookup. String literals in GameData/ files may hold UTF-8 official names (constitution, Technical
-- Constraints); code, keys and comments stay ASCII.
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

-- Official NPC names per client language (GetLocale()), for when the client cannot tell them (no API reads an NPC
-- name by ID). enUS is the fallback for every other client language (esMX: no confirmed source, so English).
-- Source: Wowhead's localized pages and tooltips (2026-11-03). deDE Heming is "Der alte Mann Heming" in the
-- modern data but English in Wowhead's Classic data (R12, accepted without a German client).
GameData.NpcNames = {
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
