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

-- The error log. The dispatchers below run each handler through ns.Safe, so one failing handler does not keep
-- the others from the same event, message or command. A failure is recorded (the debug report's "Errors and blocked
-- actions") and handed on to the game's error handler, which shows it as before (BugSack, the scriptErrors popup) or
-- not at all.
local ERROR_LOG_SIZE = 30
local ERROR_STACK_LINES = 10
local errorLog = {} -- in memory until the saved variables load, then db.errors (ADDON_LOADED below)

-- Adds an entry, or counts it into the entry of the same context and message, which becomes the newest. The list
-- is ordered by last occurrence, so the first entry is the one dropped over the cap.
local function AddError(log, entry)
    for i, old in ipairs(log) do
        if old.context == entry.context and old.message == entry.message then
            table.remove(log, i)
            old.count, old.last = old.count + entry.count, entry.last
            entry = old
            break
        end
    end
    table.insert(log, entry)
    while #log > ERROR_LOG_SIZE do
        table.remove(log, 1)
    end
end

local function RecordError(context, err, stack)
    local now = time()
    AddError(errorLog, { context = context, message = tostring(err), stack = stack, version = ns.version,
        first = now, last = now, count = 1 })
end

-- The saved log at ADDON_LOADED: entries of another version are of code that changed; the ones recorded before the
-- load join them. The result is the log from then on.
local function AttachErrorLog(saved)
    local log = {}
    for _, entry in ipairs(saved) do
        if entry.version == ns.version then
            table.insert(log, entry)
        end
    end
    for _, entry in ipairs(errorLog) do
        AddError(log, entry)
    end
    errorLog = log
    return log
end

-- One handler for every ns.Safe (no closure per call): it runs at the error, where the stack still holds the
-- failing code, and reads the context of the innermost ns.Safe running.
local safeContext
local function OnSafeError(err)
    -- With the error stack height set like Blizzard's CallErrorHandler, the game's handler shows the failing code's
    -- stack, once (V42, seen in game)
    pcall(RecordError, safeContext, err, debugstack(2, ERROR_STACK_LINES, 0)) -- never hides the error itself
    SetErrorCallstackHeight(GetCallstackHeight() - 1) -- the stack from the failure, as CallErrorHandler does
    geterrorhandler()(err) -- the game's handler returns nothing
    SetErrorCallstackHeight(nil)
    return err
end

-- Puts the outer context back and passes the results through.
local function LeaveSafe(outer, ...)
    safeContext = outer
    return ...
end

-- Runs fn(...) protected; returns true and its results, or false and the error. The game's xpcall passes the
-- arguments on (Blizzard's ExecuteFrameScript does the same).
function ns.Safe(context, fn, ...)
    local outer = safeContext
    safeContext = context
    return LeaveSafe(outer, xpcall(fn, OnSafeError, ...))
end

-- The log, ordered by last occurrence (the newest last); read only.
function ns.GetErrors()
    return errorLog
end

-- Event dispatch: several modules may listen to the same event; each handler runs on its own (ns.Safe).
local eventFrame = CreateFrame("Frame")
local handlers = {}
local unitEvents = {} -- event -> the unit RegisterUnitEvent registered it for

function ns.RegisterEvent(event, fn)
    assert(not unitEvents[event], event .. " is registered for one unit (ns.RegisterUnitEvent)")
    if not handlers[event] then
        handlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

-- A unit event the game sends for one unit only (UNIT_AURA of the player: the event fires for every unit around,
-- many times a second in a crowd). Every handler of the event then hears only that unit, so it is for an event no
-- other module registers (both functions refuse a mix, which would change what the other handlers hear).
function ns.RegisterUnitEvent(event, unit, fn)
    assert(handlers[event] == nil or unitEvents[event] == unit,
        event .. " is registered for every unit or for another one")
    if not handlers[event] then
        handlers[event] = {}
        unitEvents[event] = unit
        if eventFrame.RegisterUnitEvent then
            eventFrame:RegisterUnitEvent(event, unit)
        else
            eventFrame:RegisterEvent(event)
        end
    end
    table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do
        ns.Safe(event, fn, event, ...)
    end
end)

-- Internal messages between modules (e.g. UI reacting to mode changes). Each listener runs on its own (ns.Safe):
-- a listener's failure is recorded and handed on, and the sender goes on as if it had run.
local listeners = {}
local NO_LISTENERS = {}

function ns.On(message, fn)
    listeners[message] = listeners[message] or {}
    table.insert(listeners[message], fn)
end

function ns.Fire(message, ...)
    for _, fn in ipairs(listeners[message] or NO_LISTENERS) do
        ns.Safe(message, fn, ...)
    end
end

-- Blocked actions (specs/029-blocked-actions): the game's "Interface action failed because of an AddOn" names no
-- addon and no function and shows once per session, so the log keeps what the game refused, where it came from and
-- the state around it, for /okf debug. Nothing here is a Lua error: no entry goes to the game's error handler.

-- An entry of the log without an error (context, message, stack as in RecordError); never fails its caller. A repeat
-- counts into its entry, as an error does, and its stack replaces the entry's: for a blocked action the latest state
-- (the fight, the last menu) is the lead.
function ns.RecordEntry(context, message, stack)
    pcall(function()
        stack = stack or ""
        RecordError(context, message, stack)
        local entry = errorLog[#errorLog] -- AddError moves the entry it counted into, or the new one, to the end
        if entry and entry.context == context and entry.message == tostring(message) then
            entry.stack = stack
        end
    end)
end

-- The last menu the addon opened (its menu helper in the view layer notes it, named by the caller): a lead for a block.
-- The addon's menus once used the game's, whose rows are shared with the game's own menus (docs/forever-api.md).
local lastMenu
function ns.NoteMenu(name)
    lastMenu = { name = name, at = GetTime(), combat = InCombatLockdown() and true or false }
end

-- One line of state for a blocked action's entry.
local function BlockState()
    local line = "in combat: " .. ((InCombatLockdown() and "yes") or "no")
    if lastMenu then
        line = line .. (", last addon menu: %s %d s ago%s"):format(tostring(lastMenu.name),
            math.floor(GetTime() - lastMenu.at), lastMenu.combat and " (in combat)" or "")
    end
    return line
end

-- The addon closest to the block on its stack decides whose it is: the file and line of the first stack line in an
-- addon's folder (the game's path, Interface/AddOns/<name>/; Blizzard's own folders skipped) when that addon is this
-- one, else nil (another addon's block, or the game's own). Only the place, not how the function was named on the way
-- ("local", "upvalue", "field"), so a cause is always one entry.
local BLOCK_SEARCH_LINES = 60 -- a menu's layout runs deep in Blizzard_Menu before it reaches the addon
local function AddonLine(stack)
    for line in stack:gmatch("[^\n]+") do
        local folder = line:match("AddOns[/\\]([^/\\]+)[/\\]")
        if folder and not folder:find("^Blizzard_") then
            if folder ~= ADDON_NAME then
                return nil
            end
            return line:match("^%s*(.-:%d+):") or line
        end
    end
end

-- The first `count` lines of a stack, the leading ones of the addon's own event dispatch left out (xpcall's `[C]` line
-- and Core.lua's lines before the handler); the refused game function's own `[C]` line stays.
local function StackHead(stack, count)
    local lines = {}
    for line in stack:gmatch("[^\n]+") do
        -- only xpcall's own [C] line: a [C] line after it is the refused game function
        local dispatch = #lines == 0
            and (line:find("^%s*%[C%]: in function .x?pcall.") or line:find("Core[/\\]Core%.lua"))
        if #lines == count then
            break
        elseif not dispatch then
            table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n")
end

-- The game refused a protected call because of this addon (the taint path; other addons' refusals are theirs). The
-- entry keeps the function, the state and the stack the event came with: when the game fires it inside the refused
-- call, the stack leads to the caller; when later, it shows only the event's delivery.
local function OnActionRefused(event, addonName, func)
    if addonName ~= ADDON_NAME then
        return
    end
    local stack = debugstack(2, BLOCK_SEARCH_LINES, 0)
    pcall(function()
        local full = StackHead(stack or "", BLOCK_SEARCH_LINES) -- without the event's own dispatch
        local lead = AddonLine(full) -- the addon's place on the way, also beyond the 10 lines kept
        local state = BlockState() .. (lead and (", addon line: " .. lead) or "")
        ns.RecordEntry(event, tostring(func), state .. "\n" .. StackHead(full, ERROR_STACK_LINES))
    end)
end
ns.RegisterEvent("ADDON_ACTION_FORBIDDEN", OnActionRefused)
ns.RegisterEvent("ADDON_ACTION_BLOCKED", OnActionRefused)

-- Every block shows the game's message through this function, also the ones Blizzard's own Lua refuses with no event
-- (HideUIPanel in combat, a menu title in combat). Kept when the addon's code is the closest addon on the stack, the
-- message being that line, so causes stay apart and a repeat counts into its entry. That is the addon's code on the
-- way to the block, not proof that it caused it: the game may blame another addon's taint (its ADDON_ACTION_* event,
-- which Blizzard's handler hears before this addon, names that addon). The hook runs after the game's function,
-- changes nothing in it and never raises into it.
if type(DisplayInterfaceActionBlockedMessage) == "function" and hooksecurefunc then
    hooksecurefunc("DisplayInterfaceActionBlockedMessage", function()
        local stack = debugstack(2, BLOCK_SEARCH_LINES, 0) -- from the hook's caller: the hook itself is not on it
        pcall(function()
            local lead = AddonLine(stack or "")
            if lead then
                ns.RecordEntry("INTERFACE_ACTION_BLOCKED", lead,
                    BlockState() .. "\n" .. StackHead(stack, ERROR_STACK_LINES))
            end
        end)
    end)
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
        campBonusWarning = true, -- the camp bonus notices: 5 minutes left and ended (Fishing/Camp.lua, spec 020)
        auctionPrices = true,
        -- Take auction prices from Auctionator when it is installed (Catch/Prices.lua); written only by
        -- Prices.SetAuctionator. auctionPrices above is written only by Prices.SetAuctionPrices.
        auctionatorPrices = true,
        camera = true,
        cameraDistance = 10,
        minimapButton = true,
        tooltipChances = true, -- "Show catch chances in tooltips": item tooltips and the minimap tooltip (Catalog.lua)
        language = "auto", -- "auto" (the game client's language) or a language code, see Localization.lua
        languageHintShown = false, -- the one-time hint for clients without a translation was shown
        shareDB = true, -- exchange catch data with guild, group and friends (Share.lua); off: nothing sent or received
        shareChannel = true, -- "Use the public channel" (Channel.lua); without effect while shareDB is off
        -- The "Sound effects" page (spec 013): every option starts off.
        fishingSounds = false, -- "Play fishing sounds" (Fishing/Sound.lua); written only by Sound.SetEnabled
        soundVolume = 100, -- the addon's sounds, 0-100 in steps of 10 (Sound.Volume clamps and rounds it)
        backgroundSound = false, -- game sound in the background while fishing (a live CVar row of Fishing/Mode.lua)
        splashFocus = false, -- music, ambience, dialog off, effects up while fishing (Mode.lua rows, lifted in fights)
        -- The item kinds hidden in "What can be caught here" and the catalog (spec 014): kind name -> true; written
        -- only by Catalog.SetKindShown.
        hiddenKinds = {},
        -- The order of the catalog's list (spec 017): "name", "price" or "chance"; written only by
        -- Catalog.SetSort.
        catalogSort = "name",
    },
    shareNotice = false, -- true once the one-time popup about the exchange was closed (Exchange/ShareGame.lua)
    shareNoticeChannel = false, -- true once the notice that names the public channel was closed (ShareGame.lua)
    prices = {}, -- itemID -> { price = copper, quantity = pieces, lots = auctions, time = time() } from scans
    -- itemID -> time() of the last answered auction search, with a price or not on sale (spec 018)
    priceScans = {},
    -- The items the auction house did not answer for: itemID -> "own", "bundled" or "shared"; emptied by another
    -- addon version (Catch/Auction.lua, spec 018).
    scanGuard = { version = "", items = {} },
    minimapAngle = 220,
    indicatorPos = nil, -- { point, relativePoint, x, y }
    fishedItems = {}, -- itemID -> true for everything ever looted from fishing
    errors = {}, -- the error log, ordered by last occurrence (ns.Safe above; data-model in specs/006-error-log)
    statsTab = "stats", -- the last open tab of the statistics window: "stats" | "here" | "catalog" | "best"
    shared = { -- the catch database (CatchDB.lua); myID is created there
        mine = {}, -- place key -> cell: this account's catches, never reset
        records = {}, -- contribution ID (own) or "<id>@<epoch>" (others) -> record
        imported = {}, -- "<id>@<epoch>" -> true: came in by an import (ShareTransfer.lua); counts with sharing off
    },
}

local CHAR_DB_DEFAULTS = {
    schema = DB_SCHEMA,
    gear = {
        pole = nil, -- itemID chosen in settings; nil = best pole in bags
        items = {}, -- extra fishing item IDs
    },
    -- The best places' choices of this character (Catalog/BestPlaces.lua, spec 024): Safe for me, the continent.
    bestPlaces = { safe = true, continent = "all" },
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
    ns.db.errors = AttachErrorLog(ns.db.errors)
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
        ns.Safe("/okf " .. name, command.run, rest)
    else
        PrintHelp()
    end
end
