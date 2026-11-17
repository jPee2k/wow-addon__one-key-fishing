-- Debug.lua, /okf debug: the section "Seed items without a kind" lists the items of the bundled seed that
-- GameData/ItemKinds.lua does not list (a harvest brought them), with their names and classes, so each gets its kind
-- by ID (spec 014). A release has none: tests/catalog/kinds_test.lua fails for a missing one.

local LISTED, NEW_FISH, NEW_POTION, UNLOADED = 6291, 90301, 90302, 90303
item_names[NEW_FISH] = "Bloated Testfish"
item_classes[NEW_FISH] = { 7, 8 }
item_names[NEW_POTION] = "Test Potion"
item_classes[NEW_POTION] = { 0, 1 }
unknown_items[UNLOADED] = true

load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:3:47"] = catch_cell(60, 0, { [LISTED] = { 40, 40 }, [NEW_POTION] = { 10, 10 }, [UNLOADED] = { 5, 5 } }),
        ["1416:3:11"] = catch_cell(60, 0, { [NEW_FISH] = { 50, 50 }, [NEW_POTION] = { 5, 5 } }),
    } }
end)

-- The lines of one section of the report, without its title.
local function section(title)
    local _, report = ns.Debug.Report()
    local out, inside = {}, false
    for line in (report .. "\n"):gmatch("([^\n]*)\n") do
        if line == "-- " .. title .. " --" then
            inside = true
        elseif inside then
            if line == "" then
                break
            end
            table.insert(out, (line:gsub("^%s+", "")))
        end
    end
    assert(inside, "no section " .. title .. ":\n" .. report)
    return out
end

test("the seed items without a kind: each once, by ID, with its name and class; listed items left out", function()
    local lines = section("Seed items without a kind")
    eq(#lines, 3, "three items:\n" .. table.concat(lines, "\n"))
    eq(lines[1], "90301 Bloated Testfish (7 / 8)", "a new fish")
    eq(lines[2], "90302 Test Potion (0 / 1)", "a new potion, in two cells, listed once")
    eq(lines[3], "90303 not loaded yet (nil / nil)", "an item the client does not know yet")
end)

test("an item the client does not know yet is asked for, so a second report names it", function()
    local asked = 0
    for _, itemID in ipairs(item_load_requests) do
        if itemID == UNLOADED then
            asked = asked + 1
        end
    end
    assert(asked >= 1, "RequestLoadItemDataByID for the unloaded item")
    for _, itemID in ipairs(item_load_requests) do
        assert(itemID ~= NEW_FISH and itemID ~= NEW_POTION, "a known item is not asked for: " .. itemID)
    end
end)

test("with every seed item listed, the section reads none", function()
    local byItem = ns.GameData.ItemKinds.byItem
    byItem[NEW_FISH], byItem[NEW_POTION], byItem[UNLOADED] = "fish", "potions", "other"
    local lines = section("Seed items without a kind")
    byItem[NEW_FISH], byItem[NEW_POTION], byItem[UNLOADED] = nil, nil, nil
    eq(table.concat(lines, "|"), "none", "none")
end)
