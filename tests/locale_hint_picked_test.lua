-- A Russian client whose player already picked Ukrainian: the addon is in Ukrainian and gives no hint.

CLIENT_LOCALE = "ruRU"
OneKeyFishingDB = { schema = 1, settings = { language = "ukUA" } }
chat = {}
load_addon()
local L = ns.L

-- The hint in the language in use (Ukrainian here), so a hint printed by mistake is found in any language.
local HINT = "Your game client has no translation, so the addon is in English. Others, such as %s, are in /okf config."
local function hintShown()
    return chat_contains(L[HINT]:format(ns.translations.ukUA.name))
end

test("a picked language is used and no hint is shown", function()
    eq(ns.language, "ukUA", "language")
    eq(ns.db.settings.language, "ukUA", "the preference is kept")
    eq(ns.db.settings.languageHintShown, false, "flag")
    assert(not hintShown(), "no hint")
end)

test("choosing a language in the settings counts as having seen the hint", function()
    ns.SettingsUI.ChooseLanguage("ukUA") -- already the preference: nothing changes
    eq(ns.db.settings.languageHintShown, false, "the same language")
    ns.SettingsUI.ChooseLanguage("xxXX") -- not shipped: ignored
    eq(ns.db.settings.languageHintShown, false, "a language that is not shipped")
    ns.SettingsUI.ChooseLanguage("auto")
    eq(ns.db.settings.languageHintShown, true, "back to the client language")
    fire("PLAYER_LOGIN") -- the next login, now on "auto" with a client that has no translation
    assert(not hintShown(), "no hint after the player used the language menu")
end)
