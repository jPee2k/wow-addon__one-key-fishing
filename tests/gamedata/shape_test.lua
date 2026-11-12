-- The game data model ns.GameData (docs/architecture/game-data.md, specs/008-architecture-alignment data-model.md):
-- every entity has its fields, with values of the right kind.

load_addon()
local GameData = ns.GameData

local function IsWhole(value, minimum)
    return type(value) == "number" and value == math.floor(value) and value >= (minimum or 0)
end

local function IsID(value)
    return IsWhole(value, 1)
end

test("the Fishing spells are the four ranks in order, with their caps", function()
    local spells = GameData.FishingSpells
    eq(#spells, 4, "ranks")
    local caps = { 75, 150, 225, 300 }
    for i, spell in ipairs(spells) do
        assert(IsID(spell.spellID), "spell " .. i .. " has an ID")
        eq(spell.cap, caps[i], "cap of rank " .. i)
    end
end)

test("every rank step follows a cap and names the next rank's spell", function()
    local spells = GameData.FishingSpells
    local count = 0
    for cap, step in pairs(GameData.FishingRanks) do
        count = count + 1
        local index
        for i, spell in ipairs(spells) do
            if spell.cap == cap then
                index = i
            end
        end
        assert(index and spells[index + 1], "step " .. cap .. " follows a cap below the last")
        eq(step.next, spells[index + 1].spellID, "next of " .. cap)
        assert(IsWhole(step.learnAt) and IsWhole(step.level), "skill and level of " .. cap)
        assert(type(step.source) == "table" and type(step.source.kind) == "string", "source of " .. cap)
    end
    eq(count, 3, "steps")
end)

test("NPC names are keyed by NPC ID and client language, with an English name", function()
    for npcID, names in pairs(GameData.NpcNames) do
        assert(IsID(npcID), "NPC ID")
        assert(type(names.enUS) == "string" and names.enUS ~= "", "English name of " .. npcID)
    end
end)

test("the bobber's object ID is a string of digits", function()
    local id = GameData.Bobber.objectID
    assert(type(id) == "string" and id:match("^%d+$"), "object ID")
end)

test("lures: bonus, skill and an order 1..n without a gap", function()
    local orders, count = {}, 0
    for itemID, lure in pairs(GameData.Lures) do
        count = count + 1
        assert(IsID(itemID), "item ID")
        assert(IsWhole(lure.bonus, 1), "bonus of " .. itemID)
        assert(IsWhole(lure.skill), "skill of " .. itemID)
        assert(IsWhole(lure.order, 1) and not orders[lure.order], "order of " .. itemID)
        orders[lure.order] = true
    end
    for order = 1, count do
        assert(orders[order], "order " .. order .. " is taken")
    end
end)

test("fished containers are a set of item IDs", function()
    for itemID, flag in pairs(GameData.FishedContainers) do
        assert(IsID(itemID) and flag == true, "container " .. tostring(itemID))
    end
end)

test("fishing poles: bonus and skill, and the pole's item class", function()
    for itemID, pole in pairs(GameData.FishingPoles) do
        assert(IsID(itemID), "item ID")
        assert(IsWhole(pole.bonus) and IsWhole(pole.skill), "bonus and skill of " .. itemID)
    end
    assert(IsWhole(GameData.FishingPoleClass.classID) and IsWhole(GameData.FishingPoleClass.subclassID), "class")
end)

test("equipment slots: weapon slots and equip locations map to slots 1-19", function()
    local slots = GameData.EquipSlots
    for _, key in ipairs({ "first", "last", "mainHand", "offHand", "ranged" }) do
        assert(IsWhole(slots[key], 1) and slots[key] <= 19, key)
    end
    for equipLoc, list in pairs(slots.byEquipLoc) do
        assert(type(equipLoc) == "string" and #list > 0, equipLoc)
        for _, slot in ipairs(list) do
            assert(IsWhole(slot, 1) and slot <= 19, equipLoc .. " slot")
        end
    end
end)

test("icons are file IDs", function()
    for name, fileID in pairs(GameData.Icons) do
        assert(IsID(fileID), name)
    end
end)

test("the catch database keeps its range step and number of ranges (the saved keys depend on them)", function()
    eq(ns.CatchDB.RANGE_STEP, 75, "range step")
    eq(ns.CatchDB.MAX_RANGE, 4, "highest range")
    eq(ns.GameData.FishingSpells[1].cap, ns.CatchDB.RANGE_STEP, "a range per Fishing rank")
    eq(#ns.GameData.FishingSpells, ns.CatchDB.MAX_RANGE, "the highest range starts at the last cap")
end)
