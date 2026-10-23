-- The whole addon loads in TOC order and survives the login events.

load_addon()

test("saved variables are set up on login", function()
    assert(ns.db and ns.charDB, "ns.db and ns.charDB")
    assert(OneKeyFishingDB == ns.db and OneKeyFishingCharDB == ns.charDB, "the saved variable globals")
    assert(ns.charDB.stats and ns.charDB.session, "statistics buckets")
end)

test("every module is in the namespace", function()
    for _, name in ipairs({ "Action", "Mode", "Gear", "Bags", "Camera", "Stats", "Prices", "Auction", "Skill",
        "Indicator", "StatsFrame", "SettingsUI" }) do
        assert(ns[name], "ns." .. name)
    end
end)

test("every slash command has a description", function()
    local names = {}
    for name, command in pairs(ns.commands) do
        assert(type(command.description) == "string" and command.description ~= "", "description of " .. name)
        table.insert(names, name)
    end
    table.sort(names)
    eq(table.concat(names, " "), "config debug scan stats toggle", "commands")
end)

test("the version comes from the TOC's Version field", function()
    eq(ns.version, "1.0.0-test")
end)
