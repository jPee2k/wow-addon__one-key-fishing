-- UI/Indicator.lua and Core/Data.lua in an instance (specs/012-release-fixes, User Story 1): the game gives the soft
-- target's GUID as a secret value there (seen 2026-11-11), and splitting it raised an error on every indicator update.
-- A secret GUID makes the bobber answer "unknown": no error, and the indicator keeps "Hook!" instead of warning
-- "No bobber". A readable GUID of something else still warns.

load_addon()

local L = ns.L
local SPELL = 7620
local NO_BOBBER = "|cffff4444" .. L["No bobber"] .. "|r"
local SECRET = "GameObject-0-1-2-3-35591-SECRET"
secret_values[SECRET] = true

local function StartChannel()
    channel_info = { "Fishing", nil, nil, GetTime() * 1000, GetTime() * 1000 + 30000, nil, nil, SPELL }
    fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-1", SPELL)
end

local function StopChannel()
    channel_info = nil
    fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-1", SPELL)
end

local function Shows(text)
    return find_frame(text) ~= nil
end

test("IsSecret tells a secret value from plain ones", function()
    eq(ns.IsSecret(SECRET), true, "a secret GUID")
    eq(ns.IsSecret(nil), false, "nil")
    eq(ns.IsSecret("GameObject-0-1-2-3-35591-0"), false, "a plain GUID")
    eq(ns.GameObjectID(SECRET), nil, "no object ID from a secret GUID")
end)

test("a secret soft target: no error, the bobber answer is unknown", function()
    soft_target_guid = SECRET
    local targeted, known = ns.IsBobberTargeted()
    eq(targeted, false, "not claimed as the bobber")
    eq(known, false, "unknown")
end)

test("while channeling with a secret soft target the indicator keeps Hook!", function()
    ns.db.settings.indicator = true
    enter_fishing_mode()
    soft_target_guid = SECRET
    StartChannel()
    ns.Indicator.Update()
    advance(10) -- past the indicator's grace time for the bobber
    ns.Indicator.Update()
    eq(Shows(NO_BOBBER), false, "no 'No bobber' warning")
    eq(Shows(L["Hook!"]), true, "Hook!")
    StopChannel()
end)

test("a readable soft target of another object still warns after the grace time", function()
    soft_target_guid = "GameObject-0-1-2-3-12345-0"
    StartChannel()
    advance(10)
    ns.Indicator.Update()
    eq(Shows(NO_BOBBER), true, "'No bobber' for another object")
    StopChannel()
end)

test("the bobber itself gives Hook!", function()
    soft_target_guid = "GameObject-0-1-2-3-" .. ns.GameData.Bobber.objectID .. "-0"
    StartChannel()
    advance(10)
    ns.Indicator.Update()
    eq(Shows(NO_BOBBER), false, "no warning")
    eq(Shows(L["Hook!"]), true, "Hook!")
    StopChannel()
    soft_target_guid = nil
end)
