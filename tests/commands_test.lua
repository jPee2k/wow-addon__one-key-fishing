-- Slash commands stay English on every client and in every interface language (constitution, Principle II).

CLIENT_LOCALE = "deDE"
load_addon()

test("the interface is German, the /okf help is English", function()
    eq(ns.L["Time"], "Zeit", "the interface follows the client")
    wipe(chat)
    SlashCmdList.ONEKEYFISHING("")
    assert(chat_contains("v1.0.0-test commands:"), "English help header")
    assert(chat_contains("/okf config - open the settings"), "English description")
end)

test("a command runs its module function", function()
    local toggled = 0
    ns.Mode.Toggle = function() toggled = toggled + 1 end
    SlashCmdList.ONEKEYFISHING("TOGGLE")
    eq(toggled, 1, "the name is not case sensitive")
end)

test("/okf share prints the state in the interface language; its help line stays English", function()
    wipe(chat)
    SlashCmdList.ONEKEYFISHING("")
    assert(chat_contains("/okf share - show the state of the shared catch database"), "English description")
    wipe(chat)
    SlashCmdList.ONEKEYFISHING("share")
    assert(chat_contains(ns.L["Shared database"]), "header")
    assert(chat_contains("Gemeinsame Datenbank"), "German header")
    assert(chat_contains((ns.L["Bundled data: version %d, %d places"]):format(0, 0)), "the seed")
    assert(chat_contains(ns.L["Last exchange: none yet"]), "the last exchange")
    assert(chat_contains("Letzter Austausch"), "German")
    assert(chat_contains(ns.L["Waiting for you to read the notice"]), "the state")
    assert(not chat_contains(ns.db.shared.myID), "no anonymous ID")
end)
