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

test("every slash command is declared in Commands.lua, sorted, with an English description", function()
    local names = {}
    for _, command in ipairs(ns.COMMANDS) do
        assert(type(command.description) == "string" and command.description ~= "", "description of " .. command.name)
        assert(not command.description:find("[\128-\255]"), "English (ASCII) description of " .. command.name)
        assert(type(command.run) == "function", "run of " .. command.name)
        table.insert(names, command.name)
    end
    local sorted = { unpack(names) }
    table.sort(sorted)
    eq(table.concat(names, " "), table.concat(sorted, " "), "commands in name order")
    local all = " " .. table.concat(names, " ") .. " "
    for _, name in ipairs({ "config", "debug", "scan", "stats", "toggle" }) do
        assert(all:find(" " .. name .. " ", 1, true), "/okf " .. name)
    end
end)

test("an unknown command prints the help", function()
    wipe(chat)
    SlashCmdList.ONEKEYFISHING("nonsense")
    assert(chat_contains("v1.0.0-test commands:"), "help header")
    assert(chat_contains("/okf stats - show the fishing statistics"), "a command line")
end)

test("the version comes from the TOC's Version field", function()
    eq(ns.version, "1.0.0-test")
end)
