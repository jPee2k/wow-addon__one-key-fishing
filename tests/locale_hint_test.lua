-- A Russian client: there is no Russian translation, so the addon stays in English and says once that other
-- languages, Ukrainian among them, can be picked in the settings. Nothing is switched for the player.

CLIENT_LOCALE = "ruRU"
chat = {}
load_addon()
local L = ns.L

local HINT = "Your game client has no translation, so the addon is in English. Others, such as %s, are in /okf config."

local function hints()
    local count = 0
    for _, line in ipairs(chat) do
        if line:find("/okf config", 1, true) then
            count = count + 1
        end
    end
    return count
end

test("a Russian client gets English", function()
    eq(ns.language, "enUS", "language")
    eq(ns.db.settings.language, "auto", "the preference is not changed")
end)

test("the hint names Ukrainian in its own language and is shown once", function()
    eq(hints(), 1, "hints after the first login")
    assert(chat_contains(L[HINT]:format(ns.translations.ukUA.name)), "the hint text")
    local line = chat[#chat]
    local _, names = line:gsub("OneKeyFishing", "")
    eq(names, 1, "the addon name once, from the chat prefix: " .. line)
    eq(ns.db.settings.languageHintShown, true, "flag")
    fire("PLAYER_LOGIN")
    eq(hints(), 1, "hints after the next login")
end)
