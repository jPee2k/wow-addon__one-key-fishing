-- Fishing/Gear.lua: the automatic pole choice passes over a pole above the Fishing skill (spec 011, User Story 5).
-- Requirements from GameData/FishingPoles.lua: Strong Fishing Pole 6365 needs 10, Darkwood 6366 needs 50.

local STRONG, DARKWOOD, UNLISTED = 6365, 6366, 99001

fishing_rank = 40
load_addon()

local Gear = ns.Gear
local poles = { [STRONG] = true, [DARKWOOD] = true, [UNLISTED] = true }
local bonuses = { [STRONG] = 5, [DARKWOOD] = 15, [UNLISTED] = 30 }
local held = { STRONG, DARKWOOD }

-- Bag 0 holds the poles of `held`; each is a weapon of the Fishingpole subclass.
local getInstant = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(item)
    local itemID = tonumber(item)
    if poles[itemID] then
        local class = ns.GameData.FishingPoleClass
        return itemID, nil, nil, "INVTYPE_2HWEAPON", nil, class.classID, class.subclassID
    end
    return getInstant(item)
end
C_Container.GetContainerNumSlots = function(bag)
    return bag == 0 and #held or 0
end
C_Container.GetContainerItemInfo = function(bag, slot)
    local itemID = bag == 0 and held[slot]
    return itemID and { itemID = itemID, stackCount = 1 } or nil
end
ns.GetFishingBonus = function(itemID)
    return bonuses[itemID] or 0
end

test("a pole above the Fishing skill is passed over, even with the larger bonus", function()
    fishing_rank = 40
    eq((Gear.FindBestPole()), STRONG, "Strong at skill 40, not Darkwood (needs 50)")
end)

test("once the skill reaches the requirement the better pole is taken", function()
    fishing_rank = 50
    eq((Gear.FindBestPole()), DARKWOOD, "Darkwood at skill 50")
    fishing_rank = 40
end)

test("an unknown skill, or a pole the addon does not list, holds nothing back", function()
    fishing_rank = nil
    eq((Gear.FindBestPole()), DARKWOOD, "no Fishing skill known: the best bonus")
    fishing_rank = 40
    held = { STRONG, DARKWOOD, UNLISTED }
    eq((Gear.FindBestPole()), UNLISTED, "a pole without a recorded requirement")
    held = { STRONG, DARKWOOD }
end)

test("a pole chosen by hand is still used", function()
    fishing_rank = 40
    bag_items[DARKWOOD] = 1
    ns.charDB.gear.pole = DARKWOOD
    eq(Gear.GetPole(), DARKWOOD, "the player's choice")
    ns.charDB.gear.pole = nil
    bag_items[DARKWOOD] = nil
end)

test("a pole already in the main hand is usable: it is not passed over", function()
    fishing_rank = 40
    inventory[ns.GameData.EquipSlots.mainHand] = DARKWOOD
    held = { STRONG }
    eq((Gear.FindBestPole()), DARKWOOD, "the equipped Darkwood stays the best")
    inventory[ns.GameData.EquipSlots.mainHand] = nil
    held = { STRONG, DARKWOOD }
end)
