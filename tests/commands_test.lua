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

test("/okf catalog is listed in order with its English description", function()
    local previous
    for _, command in ipairs(ns.COMMANDS) do
        assert(not previous or previous < command.name, "sorted: " .. command.name)
        previous = command.name
    end
    wipe(chat)
    SlashCmdList.ONEKEYFISHING("")
    assert(chat_contains("/okf catalog - open the catch catalog (optionally with an item name or link)"), "listed")
end)

test("/okf catalog opens the list, fills the search, chooses a single match or a linked item", function()
    item_names[6291], item_names[6303], item_names[6304] = "Deviate Fish", "Rainbow Trout", "Brook Trout"
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:3:47"] = catch_cell(10, 0, { [6291] = { 5, 5 }, [6303] = { 3, 3 }, [6304] = { 2, 2 } }) } }
    ns.Fire("SHARED_DATA_CHANGED")
    ns.Catalog.Items({ range = "all", source = "all", water = "all" })
    advance(0)
    SlashCmdList.ONEKEYFISHING("catalog")
    local window = _G.OneKeyFishingStatsFrame
    local tab = window.catalogPage
    assert(window:IsShown() and tab:IsShown(), "the window on the catalog")
    assert(tab.listView:IsShown(), "the list")
    SlashCmdList.ONEKEYFISHING("catalog trout")
    eq(tab.search:GetText(), "trout", "the search filled")
    assert(tab.listView:IsShown(), "two matches: the list")
    SlashCmdList.ONEKEYFISHING("catalog deviate")
    assert(tab.itemView:IsShown(), "one match: chosen")
    SlashCmdList.ONEKEYFISHING("catalog |cffffffff|Hitem:6303::|h[x]|h|r")
    assert(tab.itemView:IsShown(), "a linked item in the index: chosen")
    eq(tab.title.text, "[Item 6303]", "that item")
    SlashCmdList.ONEKEYFISHING("catalog |cffffffff|Hitem:9999::|h[x]|h|r")
    assert(tab.listView:IsShown(), "not in the index: the list")
    eq(tab.search:GetText(), "Item 9999", "its name in the search")
end)
