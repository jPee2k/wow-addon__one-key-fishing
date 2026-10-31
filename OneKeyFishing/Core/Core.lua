-- Core: namespace, event dispatch, saved variables, chat output, popups and the slash dispatcher. The frame
-- helpers of the windows are in UI/Widgets.lua (the view layer; docs/architecture/core.md, Layers).
local ADDON_NAME, ns = ...
local L = ns.L

ns.name = ADDON_NAME

local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = GetMetadata and GetMetadata(ADDON_NAME, "Version") or "dev"
-- Loaded straight from the repository, the TOC still has its version placeholder, which starts with "@". The
-- placeholder cannot be written out here: the release packager fills it in in every file, this one included.
if ns.version:sub(1, 1) == "@" then
    ns.version = "dev"
end

local CHAT_PREFIX = "|cff33ccffOneKeyFishing|r: "

-- A two-button popup (Yes / No unless other texts are given); onAccept runs on the first button, onCancel on
-- the second, onHide whenever the popup closes (either button or Escape). Returns the dialog, or nil when the game
-- had no free dialog frame (other addons' prompts): nothing is shown then. The default texts are the addon's: the
-- game's YES / NO are in the client's language, which may not be the addon's.
function ns.ShowPopup(key, text, onAccept, acceptText, cancelText, onCancel, onHide)
    StaticPopupDialogs[key] = {
        text = text,
        button1 = acceptText or L["Yes"],
        button2 = cancelText or L["No"],
        OnAccept = onAccept,
        -- The game also runs OnCancel, without a dialog, when it could not show the popup (no free dialog frame):
        -- that is not the second button, so the caller does not hear of it.
        OnCancel = onCancel and function(dialog, ...)
            if dialog then
                return onCancel(dialog, ...)
            end
        end,
        OnHide = onHide,
        noCancelOnEscape = onCancel ~= nil, -- Escape only closes: such a second button does more than "no"
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    return StaticPopup_Show(key)
end

-- Every key bound to a binding, readable, joined with " / " (players bind a punctuation key once per keyboard
-- layout, so two keys are common). The order is the game's (GetBindingKey), as in its Keybindings columns; the game
-- may swap the two on a reload. It is the same wherever the keys are shown. `short` asks the game for the short key
-- names (small labels); `unbound` is the text without a key, the red "not bound" by default; `separator`
-- joins two keys, " / " by default.
function ns.KeyText(binding, short, unbound, separator)
    local texts, seen = {}, {}
    for _, key in ipairs({ GetBindingKey(binding) }) do
        if not seen[key] then
            seen[key] = true
            table.insert(texts, GetBindingText(key, short))
        end
    end
    if #texts == 0 then
        return unbound or ("|cffff5555" .. L["not bound"] .. "|r")
    end
    return table.concat(texts, separator or " / ")
end

-- Korean and Chinese text on a client in another language: the game measures tooltip lines with the client's
-- font, the Korean and Chinese glyphs are taller, so wrapped lines and the last line fell below the frame (seen in
-- game, spec 007). Tooltips then do not wrap and end with a blank line.
local TALL_GLYPHS = { koKR = true, zhCN = true, zhTW = true }
function ns.TallGlyphs()
    return TALL_GLYPHS[ns.language] and not TALL_GLYPHS[GetLocale()] or false
end

-- A number with `digits` decimals and the game client's decimal separator: numbers follow the client's
-- conventions, as gold amounts do (GetMoneyString uses the client's thousands separator), whatever the interface
-- language. The replacement is a function, so no separator acts as a pattern.
function ns.FormatDecimal(value, digits)
    local separator = type(DECIMAL_SEPERATOR) == "string" and DECIMAL_SEPERATOR or "."
    local text = ("%." .. digits .. "f"):format(value)
    return (text:gsub("%.", function() return separator end, 1))
end

function ns.Print(msg, ...)
    if select("#", ...) > 0 then
        msg = msg:format(...)
    end
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. tostring(msg))
end

-- Event dispatch: several modules may listen to the same event.
local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns.RegisterEvent(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do
        fn(event, ...)
    end
end)

-- Internal messages between modules (e.g. UI reacting to mode changes).
local listeners = {}

function ns.On(message, fn)
    listeners[message] = listeners[message] or {}
    table.insert(listeners[message], fn)
end

function ns.Fire(message, ...)
    for _, fn in ipairs(listeners[message] or {}) do
        fn(...)
    end
end

-- Key binding labels (Options -> Keybindings -> AddOns). The names are translated in ADDON_LOADED, once the
-- language is known; the Keybindings panel reads them when it opens.
BINDING_HEADER_ONEKEYFISHING = "OneKeyFishing"

-- Saved variables
local DB_SCHEMA = 1

local DB_DEFAULTS = {
    schema = DB_SCHEMA,
    settings = {
        autoLoot = true,
        bobberIcon = true,
        exitOnCombat = true,
        gear = true,
        lure = true,
        openContainers = true,
        indicator = true,
        lockIndicator = false,
        toasts = true,
        sessionTimer = true,
        pauseOnAFK = true,
        skillCapWarning = true,
        auctionPrices = true,
        camera = true,
        cameraDistance = 10,
        minimapButton = true,
        tooltipChances = true, -- "Show catch chances in tooltips": item tooltips and the minimap tooltip (Catalog.lua)
        language = "auto", -- "auto" (the game client's language) or a language code, see Localization.lua
        languageHintShown = false, -- the one-time hint for clients without a translation was shown
        shareDB = true, -- exchange catch data with guild, group and friends (Share.lua); off: nothing sent or received
        shareChannel = true, -- "Use the public channel" (Channel.lua); without effect while shareDB is off
    },
    shareNotice = false, -- true once the one-time popup about the exchange was closed (Share.lua)
    shareNoticeChannel = false, -- true once the notice that names the public channel was closed (Share.lua)
    prices = {}, -- itemID -> { price = copper, quantity = pieces, lots = auctions, time = time() } from scans
    minimapAngle = 220,
    indicatorPos = nil, -- { point, relativePoint, x, y }
    fishedItems = {}, -- itemID -> true for everything ever looted from fishing
    statsTab = "stats", -- the last open tab of the statistics window: "stats" | "here" | "catalog"
    shared = { -- the catch database (CatchDB.lua); myID is created there
        mine = {}, -- place key -> cell: this account's catches, never reset
        records = {}, -- contribution ID (own) or "<id>@<epoch>" (others) -> record
    },
}

local CHAR_DB_DEFAULTS = {
    schema = DB_SCHEMA,
    gear = {
        pole = nil, -- itemID chosen in settings; nil = best pole in bags
        items = {}, -- extra fishing item IDs
    },
    -- pin: { mapID, x, y } of the map pin as the addon last set it (Core/MapPin.lua, UI/CatalogTab.lua), nil until it
    -- sets one; tells it apart from a pin the player set. The game's navigation setting (showInGameNavigation) is
    -- never touched.
}

-- Fills missing keys from defaults without touching values the user already has.
local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                ApplyDefaults(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            ApplyDefaults(target[key], value)
        end
    end
end

-- Upgrades of the saved data layout: MIGRATIONS[n] turns schema n - 1 into schema n.
-- Bump DB_SCHEMA and add an entry whenever a saved field is renamed, moved or reshaped.
local MIGRATIONS = {
    db = {},
    charDB = {},
}

-- Runs the pending migrations; returns false when the data comes from a newer version of the addon.
local function Migrate(data, migrations)
    if next(data) == nil then
        data.schema = DB_SCHEMA -- new data, nothing to upgrade
        return true
    end
    local schema = data.schema or 1
    if schema > DB_SCHEMA then
        return false
    end
    for version = schema + 1, DB_SCHEMA do
        -- A schema bump that only adds fields needs no entry: ApplyDefaults fills them in.
        if migrations[version] then
            migrations[version](data)
        end
    end
    data.schema = DB_SCHEMA
    return true
end

ns.RegisterEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= ADDON_NAME then
        return
    end
    OneKeyFishingDB = OneKeyFishingDB or {}
    OneKeyFishingCharDB = OneKeyFishingCharDB or {}
    local dbOk = Migrate(OneKeyFishingDB, MIGRATIONS.db)
    local charOk = Migrate(OneKeyFishingCharDB, MIGRATIONS.charDB)
    ApplyDefaults(OneKeyFishingDB, DB_DEFAULTS)
    ApplyDefaults(OneKeyFishingCharDB, CHAR_DB_DEFAULTS)
    ns.db = OneKeyFishingDB
    ns.charDB = OneKeyFishingCharDB
    -- The first point where the saved preference exists; no text is looked up before this.
    ns.SetLanguage(ns.ResolveLanguage(ns.db.settings.language, GetLocale()))
    BINDING_NAME_ONEKEYFISHING_ACTION = L["Fishing action (cast / hook)"]
    BINDING_NAME_ONEKEYFISHING_TOGGLE = L["Toggle fishing mode"]
    if not (dbOk and charOk) then
        ns.Print(L["Your saved data comes from a newer version of OneKeyFishing. Update the addon to avoid problems."])
    end
end)

-- A client without a translation of its own gets English; it is told once per account that the language can be
-- changed. The text stays English (the language in use); the example is Ukrainian, named in its own language.
ns.RegisterEvent("PLAYER_LOGIN", function()
    local settings = ns.db.settings
    local ukrainian = ns.translations.ukUA
    if settings.languageHintShown or not ukrainian or not ns.NeedsLanguageHint(settings.language, GetLocale()) then
        return
    end
    settings.languageHintShown = true
    ns.Print(
        L["Your game client has no translation, so the addon is in English. Others, such as %s, are in /okf config."],
        ukrainian.name)
end)

-- Slash commands, declared in Commands.lua (ns.COMMANDS, sorted by name). Every command is also reachable from
-- the menus; these exist only as a fallback. Names, descriptions and the help are English on every client.
local function FindCommand(name)
    for _, command in ipairs(ns.COMMANDS) do
        if command.name == name then
            return command
        end
    end
end

local function PrintHelp()
    ns.Print("v%s commands:", ns.version)
    for _, command in ipairs(ns.COMMANDS) do
        DEFAULT_CHAT_FRAME:AddMessage(("  /okf %s - %s"):format(command.name, command.description))
    end
end

SLASH_ONEKEYFISHING1 = "/okf"
SLASH_ONEKEYFISHING2 = "/onekeyfishing"
SlashCmdList.ONEKEYFISHING = function(input)
    local name, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    name = name:lower()
    local command = FindCommand(name)
    if command then
        command.run(rest)
    else
        PrintHelp()
    end
end
