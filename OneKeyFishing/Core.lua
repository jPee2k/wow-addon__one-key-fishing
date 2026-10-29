-- Core: namespace, event dispatch, saved variables and slash commands.
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

-- Widens a button to its text when the text is wider than the button's own width (translations are often
-- longer than English). Call it again after changing the text.
function ns.FitButton(button)
    local fontString = button:GetFontString()
    -- GetStringWidth can stop at the width the button already has; the unbounded width is the full text.
    local textWidth = fontString and (fontString.GetUnboundedStringWidth and fontString:GetUnboundedStringWidth()
        or fontString:GetStringWidth())
    if textWidth and textWidth + 16 > button.minWidth then
        button:SetWidth(textWidth + 24)
    else
        button:SetWidth(button.minWidth)
    end
end

-- A standard UI panel button; shared by the settings and statistics windows. `width` is the minimum width.
function ns.CreateButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetHeight(22)
    button.minWidth = width
    button:SetText(text)
    ns.FitButton(button)
    button:SetScript("OnClick", onClick)
    return button
end

-- A font string with the game's font object `template` (it picks a font for the text's script).
function ns.CreateText(parent, template, justify)
    local fontString = parent:CreateFontString(nil, "OVERLAY", template)
    fontString:SetJustifyH(justify or "LEFT")
    return fontString
end

-- An item's link (or name, or "item:<id>" until the client knows it) and icon.
function ns.ItemDisplay(itemID)
    local name, link, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    return link or name or ("item:" .. itemID), icon or C_Item.GetItemIconByID(itemID)
end

-- The item tooltip of a row; withPrice adds the auction price when it is not used for values (Prices.lua).
function ns.ShowItemTooltip(owner, itemID, withPrice)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(itemID)
    if withPrice then
        ns.Prices.AddTooltipLine(GameTooltip, itemID)
    end
    GameTooltip:Show()
end

local CHECK_MARK = "|TInterface\\Buttons\\UI-CheckBox-Check:0|t "

-- A menu of choices ({ value, text }) with the selected one marked; choose(value) runs on a click.
function ns.OpenRadioMenu(owner, choices, isSelected, choose)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, choice in ipairs(choices) do
            local function IsSelected() return isSelected(choice.value) end
            local function Select() choose(choice.value) end
            if root.CreateRadio then
                root:CreateRadio(choice.text, IsSelected, Select)
            else
                root:CreateButton((IsSelected() and CHECK_MARK or "") .. choice.text, Select)
            end
        end
    end)
end

-- A two-button popup (Yes / No unless other texts are given); onAccept runs on the first button, onCancel on
-- the second, onHide whenever the popup closes (either button or Escape).
function ns.ShowPopup(key, text, onAccept, acceptText, cancelText, onCancel, onHide)
    StaticPopupDialogs[key] = {
        text = text,
        button1 = acceptText or YES,
        button2 = cancelText or NO,
        OnAccept = onAccept,
        OnCancel = onCancel,
        OnHide = onHide,
        noCancelOnEscape = onCancel ~= nil, -- Escape only closes: such a second button does more than "no"
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show(key)
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
        language = "auto", -- "auto" (the game client's language) or a language code, see Localization.lua
        shareDB = true, -- exchange catch data with guild, group and friends (Share.lua); off: nothing sent or received
    },
    shareNotice = false, -- true once the one-time popup about the exchange was closed (Share.lua)
    prices = {}, -- itemID -> { price = copper, quantity = pieces, lots = auctions, time = time() } from scans
    minimapAngle = 220,
    indicatorPos = nil, -- { point, relativePoint, x, y }
    fishedItems = {}, -- itemID -> true for everything ever looted from fishing
    statsTab = "stats", -- the last open tab of the statistics window: "stats" | "here"
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
