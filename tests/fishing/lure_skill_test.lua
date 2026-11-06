-- Bags.lua: a known lure above the character's Fishing skill is never offered; once the skill reaches its
-- requirement it is (specs/008-architecture-alignment, User Story 2, contracts C3; GameData/Lures.lua).

local NIGHTCRAWLERS, BAUBLE = 6530, 6529 -- needs 50, needs nothing
load_addon()
local Bags = ns.Bags

local readyFired = 0
ns.On("LURE_READY", function() readyFired = readyFired + 1 end)

local function Bags_(items)
    bag_items = {}
    for itemID, count in pairs(items) do
        bag_items[itemID] = count
    end
end

test("below a lure's skill the next lower lure is offered", function()
    fishing_skill, fishing_rank = nil, 49
    Bags_({ [NIGHTCRAWLERS] = 1, [BAUBLE] = 1 })
    eq(Bags.FindLure(), BAUBLE, "Shiny Bauble, not Nightcrawlers")
end)

test("at the lure's skill it is offered", function()
    fishing_rank = 50
    eq(Bags.FindLure(), NIGHTCRAWLERS, "Nightcrawlers at 50")
end)

test("only a lure above the skill: nothing is offered and nothing is waited for", function()
    fishing_rank = 49
    Bags_({ [NIGHTCRAWLERS] = 1 })
    readyFired = 0
    local lure, wait = Bags.FindLure()
    eq(lure, nil, "no lure")
    eq(wait, nil, "no cooldown to wait for")
    advance(10)
    eq(readyFired, 0, "no LURE_READY")
end)

test("a skill-up in the same session offers the lure", function()
    fishing_rank = 50
    eq(Bags.FindLure(), NIGHTCRAWLERS, "offered after the skill rose")
end)

test("an unknown skill holds no lure back", function()
    fishing_skill, fishing_rank = nil, nil
    eq(Bags.FindLure(), NIGHTCRAWLERS, "Nightcrawlers while Fishing is unknown")
end)

test("the debug report names each lure's requirement", function()
    Bags_({ [NIGHTCRAWLERS] = 2 })
    local found = false
    for _, line in ipairs(Bags.DescribeLures()) do
        if line:find("^6530 x2") and line:find("needs: 50", 1, true) then
            found = true
        end
    end
    eq(found, true, "the Nightcrawlers line says needs: 50")
end)
