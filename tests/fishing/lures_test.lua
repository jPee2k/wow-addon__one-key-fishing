-- Bags.lua: which lure the key applies, cooldowns and failed attempts.

local ATTRACTOR, BAUBLE = 6533, 6529 -- the best lure and a weaker one
bag_items[ATTRACTOR], bag_items[BAUBLE] = 1, 3

load_addon()
local Bags = ns.Bags

local readyFired = 0
ns.On("LURE_READY", function() readyFired = readyFired + 1 end)

local function OnCooldown(itemID, remaining, duration)
    duration = duration or 60
    item_cooldowns[itemID] = { now - (duration - remaining), duration }
end

-- Lets pending timers run (Bags.lua keeps one lure timer pending at a time), then a clean state.
local function Reset()
    item_cooldowns, weapon_enchant = {}, false
    flush_timers()
    chat = {}
end

test("the best lure in the bags comes first", function()
    Reset()
    eq(Bags.FindLure(), ATTRACTOR)
end)

test("a lure on cooldown is passed over for the next one", function()
    Reset()
    OnCooldown(ATTRACTOR, 50)
    eq(Bags.FindLure(), BAUBLE)
end)

test("with every lure on cooldown there is none, and one timer waits for the soonest", function()
    Reset()
    OnCooldown(ATTRACTOR, 50)
    OnCooldown(BAUBLE, 25, 30)
    eq(Bags.FindLure(), nil, "lure")
    eq(#timers, 1, "timers")
    near(timers[1].at - now, 25.1, "timer delay")
    Bags.FindLure()
    eq(#timers, 1, "still one timer")
end)

test("LURE_READY fires when the cooldown is over", function()
    Reset()
    OnCooldown(ATTRACTOR, 20)
    OnCooldown(BAUBLE, 20)
    eq(Bags.FindLure(), nil, "lure while both cool down")
    readyFired = 0
    advance(21)
    eq(readyFired, 1, "LURE_READY")
    eq(Bags.FindLure(), ATTRACTOR, "lure")
end)

test("the global cooldown does not count", function()
    Reset()
    item_cooldowns[ATTRACTOR] = { now, 1.5 }
    eq(Bags.FindLure(), ATTRACTOR)
end)

test("an attempt that put the lure on cooldown is not a failure", function()
    Reset()
    Bags.NoteLureAttempt(ATTRACTOR)
    OnCooldown(ATTRACTOR, 600, 600)
    advance(10)
    eq(Bags.FindLure(), BAUBLE, "next lure while it cools down")
    assert(not chat_contains("Cannot apply"), "no 'Cannot apply' message")
end)

test("a lure that does not land is skipped, with a message", function()
    Reset()
    Bags.NoteLureAttempt(ATTRACTOR)
    advance(9)
    eq(Bags.FindLure(), BAUBLE, "lure")
    assert(chat_contains("until fishing mode is turned on again"), "message")
end)

test("a skipped lure is tried again when fishing mode is entered", function()
    Reset()
    Bags.NoteLureAttempt(ATTRACTOR)
    advance(9)
    eq(Bags.FindLure(), BAUBLE, "skipped")
    ns.Fire("MODE_CHANGED", true)
    eq(Bags.FindLure(), ATTRACTOR, "tried again")
end)

test("a lure that landed is not a failure when it wears off later", function()
    Reset()
    Bags.NoteLureAttempt(ATTRACTOR)
    weapon_enchant = true
    fire("UNIT_INVENTORY_CHANGED", "player")
    advance(600)
    weapon_enchant = false
    eq(Bags.FindLure(), ATTRACTOR, "lure")
    assert(not chat_contains("Cannot apply"), "no 'Cannot apply' message")
end)

test("the debug report lists every lure in the bags", function()
    Reset()
    OnCooldown(BAUBLE, 20)
    local lines = Bags.DescribeLures()
    eq(#lines, 2, "lines")
    eq(lines[1], "6533 x1, needs: 100, usable: true, cooldown: 0 s, skipped: false")
    eq(lines[2], "6529 x3, needs: 0, usable: true, cooldown: 20 s, skipped: false")
end)

-- Camper's Lure (specs/020-camp-buffs FR-036, research R13): +60 from a placed Fishing Rack, between the +75 and the
-- +50 lures, needing Fishing 50.
local CAMPERS, NIGHTCRAWLERS, BRIGHT = 291005, 6530, 6532

local function bags(items)
    bag_items = {}
    for itemID, count in pairs(items) do
        bag_items[itemID] = count
    end
end

test("Camper's Lure comes before the +50 lures and after the +75 ones", function()
    Reset()
    fishing_rank = 150
    bags({ [CAMPERS] = 1, [NIGHTCRAWLERS] = 1 })
    eq(Bags.FindLure(), CAMPERS, "before Nightcrawlers")
    bags({ [CAMPERS] = 1, [BRIGHT] = 1 })
    eq(Bags.FindLure(), BRIGHT, "after Bright Baubles")
end)

test("Camper's Lure needs Fishing 50", function()
    Reset()
    bags({ [CAMPERS] = 1 })
    fishing_rank = 49
    eq(Bags.FindLure(), nil, "passed over at 49")
    fishing_rank = 50
    eq(Bags.FindLure(), CAMPERS, "offered at 50")
end)

test("the lures' orders are 1 to 7 without a gap", function()
    local orders, count = {}, 0
    for _, lure in pairs(ns.GameData.Lures) do
        count = count + 1
        orders[lure.order] = true
    end
    eq(count, 7, "seven lures")
    for order = 1, 7 do
        assert(orders[order], "order " .. order)
    end
    eq(ns.GameData.Lures[CAMPERS].order, 4, "Camper's Lure fourth")
    eq(ns.GameData.Lures[CAMPERS].bonus, 60, "+60")
end)

test("with Camper's Lure on the pole the key offers no lure until it runs out", function()
    Reset()
    bags({ [CAMPERS] = 1 })
    local equipped = ns.IsFishingPoleEquipped
    ns.IsFishingPoleEquipped = function() return true end
    weapon_enchant = true
    eq(Bags.NeedsLure(), false, "a lure is on")
    weapon_enchant = false
    eq(Bags.NeedsLure(), true, "it ran out")
    ns.IsFishingPoleEquipped = equipped
end)
