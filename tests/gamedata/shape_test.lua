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

test("the items the auction house does not answer are a set of item IDs", function()
    for itemID, flag in pairs(GameData.AuctionUnanswered) do
        assert(type(itemID) == "number" and itemID > 0 and math.floor(itemID) == itemID, tostring(itemID))
        eq(flag, true, "flag of " .. itemID)
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

test("item kinds: every value a known kind, byItem keyed by item ID, byClass by class or class:subclass", function()
    local known = {}
    for _, kind in ipairs(ns.Catalog.KINDS) do
        known[kind] = true
    end
    local kinds = GameData.ItemKinds
    local count = 0
    for itemID, kind in pairs(kinds.byItem) do
        count = count + 1
        assert(IsID(itemID), "item ID " .. tostring(itemID))
        assert(known[kind], "kind of " .. itemID .. ": " .. tostring(kind))
    end
    assert(count > 0, "items listed")
    for key, kind in pairs(kinds.byClass) do
        assert(type(key) == "string" and (key:match("^%d+$") or key:match("^%d+:%d+$")), "class key " .. tostring(key))
        assert(known[kind], "kind of class " .. key .. ": " .. tostring(kind))
    end
end)

test("continents: UiMap IDs by key (spec 024)", function()
    eq(GameData.Continents.kalimdor, 1414, "Kalimdor")
    eq(GameData.Continents.eastern, 1415, "Eastern Kingdoms")
end)

test("zone levels: { lowest, highest } by UiMap ID (spec 024)", function()
    local count = 0
    for mapID, range in pairs(GameData.ZoneLevels) do
        count = count + 1
        assert(IsID(mapID), "map ID " .. tostring(mapID))
        assert(IsWhole(range[1], 1) and IsWhole(range[2], 1) and range[1] <= range[2], "range of " .. mapID)
    end
    assert(count >= 40, "every zone of both continents")
    eq(GameData.ZoneLevels[2548][1], 35, "Riverglades 35-45, as the game's map shows")
end)

test("zone factions: Alliance or Horde by UiMap ID (spec 026)", function()
    local counts = { Alliance = 0, Horde = 0 }
    for mapID, faction in pairs(GameData.ZoneFactions) do
        assert(IsID(mapID), "map ID " .. tostring(mapID))
        assert(counts[faction], "faction of " .. mapID .. ": " .. tostring(faction))
        counts[faction] = counts[faction] + 1
        assert(GameData.ZoneLevels[mapID], "a zone of ZoneLevels: " .. mapID)
    end
    eq(counts.Alliance, 9, "six Alliance zones and three capitals")
    eq(counts.Horde, 8, "five Horde zones and three capitals")
    eq(GameData.ZoneFactions[1429], "Alliance", "Elwynn Forest")
    eq(GameData.ZoneFactions[1411], "Horde", "Durotar")
    eq(GameData.ZoneFactions[1440], nil, "Ashenvale is contested")
end)
