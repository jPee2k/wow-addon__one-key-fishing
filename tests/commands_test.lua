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
