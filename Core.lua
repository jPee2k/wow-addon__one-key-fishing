-- Core: namespace, event dispatch, saved variables and slash commands.
local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = GetMetadata and GetMetadata(ADDON_NAME, "Version") or "dev"

local CHAT_PREFIX = "|cff33ccffOneKeyFishing|r: "

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

-- Key binding labels (Options -> Keybindings -> AddOns)
BINDING_HEADER_ONEKEYFISHING = "OneKeyFishing"
BINDING_NAME_ONEKEYFISHING_ACTION = "Fishing action (cast / hook)"
BINDING_NAME_ONEKEYFISHING_TOGGLE = "Toggle fishing mode"

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
    },
    fishedItems = {}, -- itemID -> true for everything ever looted from fishing
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

ns.RegisterEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= ADDON_NAME then
        return
    end
    OneKeyFishingDB = OneKeyFishingDB or {}
    OneKeyFishingCharDB = OneKeyFishingCharDB or {}
    ApplyDefaults(OneKeyFishingDB, DB_DEFAULTS)
    ApplyDefaults(OneKeyFishingCharDB, CHAR_DB_DEFAULTS)
    ns.db = OneKeyFishingDB
    ns.charDB = OneKeyFishingCharDB
end)

-- Slash commands. Every command is also reachable from the menus;
-- these exist only as a fallback.
ns.commands = {}

function ns.RegisterCommand(name, description, fn)
    ns.commands[name] = { description = description, fn = fn }
end

local function PrintHelp()
    ns.Print("v%s commands:", ns.version)
    local names = {}
    for name in pairs(ns.commands) do
        table.insert(names, name)
    end
    table.sort(names)
    for _, name in ipairs(names) do
        DEFAULT_CHAT_FRAME:AddMessage(("  /okf %s - %s"):format(name, ns.commands[name].description))
    end
end

SLASH_ONEKEYFISHING1 = "/okf"
SLASH_ONEKEYFISHING2 = "/fish"
SlashCmdList.ONEKEYFISHING = function(input)
    local name, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    name = name:lower()
    local command = ns.commands[name]
    if command then
        command.fn(rest)
    else
        PrintHelp()
    end
end
