-- Localization: ns.L, the registered languages and the choice of the effective language.
-- Locales/enUS.lua fills the English list; every other Locales/<code>.lua registers a translation through
-- ns.AddTranslation. Core picks the language in ADDON_LOADED, when the saved preference exists, so no text may be
-- looked up while the addon files load (the lookup would be stuck in English; tests/locale_test.lua checks it).
local _, ns = ...

-- Order of the language menu (docs/languages.md); only registered languages are listed.
local LANGUAGE_ORDER = { "enUS", "deDE", "esES", "esMX", "frFR", "ukUA", "koKR", "ptBR", "zhTW", "zhCN" }

local strings = {} -- English: key -> text (the key itself)
local active = {} -- the effective translation: key -> text

ns.earlyLookups = {} -- keys looked up before the language was set
ns.translations = {} -- code -> { name = native name, fill = function(T) ... end }

-- Keys are the English text. A missing translation falls back to English, a missing English entry to the key,
-- so the addon never shows a blank.
ns.L = setmetatable({}, {
    __index = function(_, key)
        if not ns.language then
            table.insert(ns.earlyLookups, key)
        end
        return active[key] or strings[key] or key
    end,
    __newindex = function(_, key, value)
        strings[key] = value == true and key or value
    end,
})

-- fill(T) sets T[english] = translation; it runs only for the language in use.
function ns.AddTranslation(code, name, fill)
    if ns.translations[code] then
        error("translation registered twice: " .. code)
    end
    ns.translations[code] = { name = name, fill = fill }
end

-- The registered languages in menu order, as { code, name }.
function ns.GetLanguages()
    local list = {}
    for _, code in ipairs(LANGUAGE_ORDER) do
        local translation = ns.translations[code]
        if translation then
            table.insert(list, { code = code, name = translation.name })
        end
    end
    return list
end

-- Client locales that are a variant of a shipped language.
local LOCALE_ALIASES = { enGB = "enUS", ptPT = "ptBR" }

-- preference is "auto" or a language code; a code that is not registered (any more) counts as "auto".
function ns.ResolveLanguage(preference, clientLocale)
    if preference ~= "auto" and ns.translations[preference] then
        return preference
    end
    clientLocale = LOCALE_ALIASES[clientLocale] or clientLocale
    if ns.translations[clientLocale] then
        return clientLocale
    end
    return "enUS"
end

-- Builds the translation of `code`. Core calls it once per session; a new language needs a UI reload.
function ns.SetLanguage(code)
    wipe(active)
    local translation = ns.translations[code]
    if translation and translation.fill then
        translation.fill(active)
    end
    ns.language = code
    -- The texts are in `active` now; the fill functions of all languages (and their strings) can go. The menu
    -- only needs the names.
    for _, entry in pairs(ns.translations) do
        entry.fill = nil
    end
end
