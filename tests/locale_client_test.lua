-- A German client: the addon follows the client language without any setting.

CLIENT_LOCALE = "deDE"
load_addon()
local L = ns.L

local _, german = load_translation("deDE")

test("a German client gets the German translation", function()
    eq(ns.language, "deDE", "language")
    eq(L["Cast"], german["Cast"], "a text")
    eq(BINDING_NAME_ONEKEYFISHING_ACTION, german["Fishing action (cast / hook)"], "key binding name")
end)

test("the addon works the same in German", function()
    chat = {}
    ns.Mode.Toggle() -- the stubs know no Fishing spell, so Action.Enable stops with a hint
    local last = chat[#chat] or ""
    assert(last:find(german["You have not learned Fishing."], 1, true), last)
end)

test("picking Deutsch on a German client needs no reload", function()
    reset_popup()
    ns.SettingsUI.ChooseLanguage("deDE")
    eq(ns.db.settings.language, "deDE", "saved")
    eq(rawget(_G, "last_popup"), nil, "no popup")
end)
