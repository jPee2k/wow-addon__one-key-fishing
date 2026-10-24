-- Localization.lua: the language is chosen once the saved variables exist, and no text is looked up before.

load_addon()
local L = ns.L

test("an English client gets English", function()
    eq(ns.language, "enUS")
end)

test("no text is looked up while the addon files load", function()
    eq(table.concat(ns.earlyLookups, " | "), "", "load-time lookups")
end)

test("the effective language follows the preference, then the client, then English", function()
    eq(ns.ResolveLanguage("auto", "enUS"), "enUS", "English client")
    eq(ns.ResolveLanguage("auto", "ruRU"), "enUS", "client without a translation")
    eq(ns.ResolveLanguage("auto", "xxXX"), "enUS", "unknown client")
    eq(ns.ResolveLanguage("enUS", "deDE"), "enUS", "picked English on another client")
    eq(ns.ResolveLanguage("gone", "enUS"), "enUS", "a stored code that is no longer shipped")
    eq(ns.ResolveLanguage("auto", "ptPT"), "ptBR", "a variant of a shipped language")
    eq(ns.ResolveLanguage("auto", "enGB"), "enUS", "British English")
end)

test("English is the first language, named in English", function()
    local first = ns.GetLanguages()[1]
    eq(first.code, "enUS", "code")
    eq(first.name, "English", "name")
end)

test("a listed key returns the English text", function()
    eq(L["Cast"], "Cast")
end)

test("an unlisted key falls back to itself", function()
    eq(L["Something unlisted"], "Something unlisted")
end)

test("a translation replaces the English text, and a gap falls back to English", function()
    ns.AddTranslation("xxXX", "Test", function(T)
        T["Cast"] = "Cast (translated)"
    end)
    ns.SetLanguage("xxXX")
    eq(L["Cast"], "Cast (translated)", "translated")
    eq(L["Hook!"], "Hook!", "missing from the translation")
    ns.SetLanguage("enUS")
    eq(L["Cast"], "Cast", "back to English")
    ns.translations.xxXX = nil
end)

---------------------------------------------------------------------------
-- The translation files (Locales/<code>.lua)
---------------------------------------------------------------------------

-- The English keys, read from Locales/enUS.lua with a recording table.
local englishKeys = {}
do
    local recorder = setmetatable({}, { __newindex = function(_, key) englishKeys[key] = true end })
    assert(loadfile(ADDON_DIR .. "/Locales/enUS.lua"))("OneKeyFishing", {
        L = recorder,
        AddTranslation = function() end,
    })
end

-- The format specifiers and escape sequences of a text, in order: a translation must keep them.
local function Markers(text)
    local list = {}
    for spec in text:gmatch("%%[-+ #0]*%d*%.?%d*[cdeEfgGioqsuxX%%]") do
        table.insert(list, spec)
    end
    for escape in text:gmatch("|[nr|]") do
        table.insert(list, escape)
    end
    return table.concat(list, " ")
end

local translationFiles = {}
for _, file in ipairs(TOC_FILES) do
    local code = file:match("^Locales/(%a%a%a%a)%.lua$")
    if code and code ~= "enUS" then
        table.insert(translationFiles, code)
    end
end

test("all ten languages are registered, in menu order", function()
    local codes = {}
    for _, language in ipairs(ns.GetLanguages()) do
        table.insert(codes, language.code)
    end
    eq(table.concat(codes, " "), "enUS deDE esES esMX frFR ukUA koKR ptBR zhTW zhCN")
end)

test("every translation is complete and keeps the placeholders", function()
    for _, code in ipairs(translationFiles) do
        local name, texts = load_translation(code) -- also checks that it registers its own file name
        assert(type(name) == "string" and name ~= "", code .. ": native name")
        for key in pairs(englishKeys) do
            assert(texts[key], code .. ": missing " .. key)
            eq(Markers(texts[key]), Markers(key), code .. ": placeholders of " .. key)
        end
        for key in pairs(texts) do
            assert(englishKeys[key], code .. ": unknown key " .. key)
        end
    end
end)

---------------------------------------------------------------------------
-- The language setting
---------------------------------------------------------------------------

test("choosing a language saves it and offers a reload", function()
    ns.db.settings.language = "auto"
    reset_popup()
    reload_count = 0
    ns.SettingsUI.ChooseLanguage("ukUA")
    eq(ns.db.settings.language, "ukUA", "saved")
    assert(rawget(_G, "last_popup"), "the reload popup is shown")
    eq(ns.language, "enUS", "nothing changes before the reload")
    accept_popup()
    eq(reload_count, 1, "Reload now reloads the interface")
end)

test("Later keeps the choice without a reload", function()
    reload_count = 0
    ns.SettingsUI.ChooseLanguage("deDE")
    local dialog = StaticPopupDialogs[last_popup]
    eq(dialog.button2, L["Later"], "the second button is Later")
    cancel_popup()
    eq(reload_count, 0, "Later does not reload")
    eq(ns.db.settings.language, "deDE", "saved")
end)

test("only the names of the languages stay in memory after login", function()
    for code, entry in pairs(ns.translations) do
        eq(entry.fill, nil, code .. ": fill released")
        assert(entry.name, code .. ": name kept")
    end
end)

test("choosing the current value again shows no popup", function()
    ns.SettingsUI.ChooseLanguage("auto")
    eq(ns.db.settings.language, "auto", "back to the client language")
    reset_popup()
    ns.SettingsUI.ChooseLanguage("auto")
    eq(rawget(_G, "last_popup"), nil, "no popup")
end)

test("picking the language already in use saves it without a reload", function()
    reset_popup()
    ns.SettingsUI.ChooseLanguage("enUS") -- English client, English in use
    eq(ns.db.settings.language, "enUS", "saved")
    eq(rawget(_G, "last_popup"), nil, "no popup")
    ns.db.settings.language = "auto"
end)

test("going back to the language in use withdraws the reload offer", function()
    ns.db.settings.language = "auto"
    ns.SettingsUI.ChooseLanguage("deDE")
    assert(rawget(_G, "last_popup"), "offered for Deutsch")
    ns.SettingsUI.ChooseLanguage("auto")
    eq(rawget(_G, "last_popup"), nil, "withdrawn")
end)

test("the language button names the preference", function()
    local auto = ns.SettingsUI.LanguageLabel("auto")
    eq(auto, L["Game client language"], "auto")
    eq(ns.SettingsUI.LanguageLabel("gone"), auto, "a language that is no longer shipped")
    eq(ns.SettingsUI.LanguageLabel("enUS"), "English", "a language by its native name")
end)

test("the debug report names the preference, the language in use and the client", function()
    local report
    local show = ns.ShowCopyWindow
    ns.ShowCopyWindow = function(_, text) report = text end
    ns.db.settings.language = "ukUA"
    ns.ShowReport()
    ns.ShowCopyWindow = show
    ns.db.settings.language = "auto"
    assert(report:find("ukUA", 1, true), "preference")
    assert(report:find("in use: enUS", 1, true), "language in use")
    assert(report:find("locale enUS", 1, true), "client locale")
end)
