-- The camp bonuses of the game data model (specs/020-camp-buffs data-model.md): the Fishing Rack and the Fishing Hut
-- in rank order, their auras, the camp feature's item and the known bonus items.

load_addon()
local bonuses = ns.GameData.CampBonuses

test("two bonuses in rank order: the Rack, then the Hut", function()
    assert(type(bonuses) == "table", "GameData.CampBonuses")
    eq(#bonuses, 2, "entries")
    eq(bonuses[1].key, "rack", "first key")
    eq(bonuses[1].bit, 1, "Rack bit")
    eq(bonuses[1].aura, 1280341, "Rack aura")
    eq(bonuses[1].item, 279965, "Rack item")
    eq(bonuses[2].key, "hut", "second key")
    eq(bonuses[2].bit, 2, "Hut bit")
    eq(bonuses[2].aura, 1280342, "Hut aura")
    eq(bonuses[2].item, 279966, "Hut item")
end)

test("both bonuses know the twelve Bloated fish (decision 32: the Hut gives them too)", function()
    local expected = { 6643, 6644, 6645, 6646, 6647, 8366, 13881, 13891, 21162, 21163, 21164, 21243 }
    local count = 0
    for itemID, value in pairs(bonuses[1].items) do
        count = count + 1
        eq(value, true, "item " .. itemID)
    end
    eq(count, #expected, "Rack items")
    for _, itemID in ipairs(expected) do
        eq(bonuses[1].items[itemID], true, "Bloated fish " .. itemID)
    end
    eq(bonuses[2].items, bonuses[1].items, "the Hut names the same list")
end)

test("the fished quest items: the quest class and the known list (decision 33)", function()
    local quest = ns.GameData.FishedQuestItems
    eq(quest.classID, 12, "Enum.ItemClass.Questitem")
    for _, itemID in ipairs({ 6718, 16967, 16968, 16969, 16970, 19806, 19807 }) do
        eq(quest.items[itemID], true, "quest item " .. itemID)
    end
end)

test("keys and bits are distinct, each bit a power of two", function()
    local keys, bits = {}, {}
    for _, bonus in ipairs(bonuses) do
        assert(not keys[bonus.key], "key " .. bonus.key .. " once")
        assert(not bits[bonus.bit], "bit " .. bonus.bit .. " once")
        keys[bonus.key], bits[bonus.bit] = true, true
        local b = bonus.bit
        while b > 1 and b % 2 == 0 do
            b = b / 2
        end
        eq(b, 1, "bit of " .. bonus.key .. " a power of two")
    end
end)
