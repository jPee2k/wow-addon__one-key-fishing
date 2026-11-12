-- GameData/EquipSlots: the inventory slots and the slots each equip location goes to (docs/architecture/game-data.md).
-- Data only: no logic and no L lookup. The numbers are the client's inventory slot IDs (INVSLOT_*).
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.EquipSlots = {
    first = 1, -- INVSLOT_FIRST_EQUIPPED
    last = 19, -- INVSLOT_LAST_EQUIPPED
    mainHand = 16, -- INVSLOT_MAINHAND
    offHand = 17, -- INVSLOT_OFFHAND
    ranged = 18, -- INVSLOT_RANGED
    -- Slots an extra fishing item can go to. Weapons are left out: the pole takes both hands.
    byEquipLoc = {
        INVTYPE_HEAD = { 1 },
        INVTYPE_NECK = { 2 },
        INVTYPE_SHOULDER = { 3 },
        INVTYPE_BODY = { 4 },
        INVTYPE_CHEST = { 5 },
        INVTYPE_ROBE = { 5 },
        INVTYPE_WAIST = { 6 },
        INVTYPE_LEGS = { 7 },
        INVTYPE_FEET = { 8 },
        INVTYPE_WRIST = { 9 },
        INVTYPE_HAND = { 10 },
        INVTYPE_FINGER = { 11, 12 },
        INVTYPE_TRINKET = { 13, 14 },
        INVTYPE_CLOAK = { 15 },
        INVTYPE_TABARD = { 19 },
    },
}
