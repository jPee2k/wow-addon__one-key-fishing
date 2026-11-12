-- UI/Indicator.lua in a fight (specs/009-pin-combat-fixes, review): once the secure [combat] handler drops the key's
-- overrides, the indicator says the key is paused instead of offering "Cast" or "Hook!", and the fight's end brings
-- the normal label back (Action.IsPaused, ACTION_STATE).

load_addon()

local L = ns.L
local PAUSED = "|cffffd100" .. L["Paused in combat"] .. "|r"

local function Label()
    local frame = find_frame(PAUSED) or find_frame(L["Cast"])
    return frame and frame.text
end

test("out of a fight the indicator offers the cast", function()
    ns.db.settings.indicator = true
    ns.db.settings.exitOnCombat = false
    enter_fishing_mode()
    eq(ns.Action.IsPaused(), false, "not paused")
    eq(find_frame(PAUSED), nil, "no paused label")
end)

test("a fight pauses the key and the indicator says so", function()
    in_combat = false -- PLAYER_REGEN_DISABLED runs before the lockdown
    fire("PLAYER_REGEN_DISABLED")
    eq(ns.Action.IsPaused(), true, "paused")
    eq(Label(), PAUSED, "the paused label")
end)

test("the fight's end brings the normal label back", function()
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    eq(ns.Action.IsPaused(), false, "not paused")
    eq(find_frame(PAUSED), nil, "the paused label is gone")
    eq(ns.Mode.IsActive(), true, "the mode stays on")
end)

test("leaving the mode clears the pause", function()
    in_combat = false
    fire("PLAYER_REGEN_DISABLED")
    eq(ns.Action.IsPaused(), true, "paused")
    -- Left before the lockdown (still the PLAYER_REGEN_DISABLED moment): Action.Disable itself must drop the pause.
    OneKeyFishing_ToggleMode()
    eq(ns.Mode.IsActive(), false, "off")
    eq(ns.Action.IsPaused(), false, "not paused")
    fire("PLAYER_REGEN_ENABLED")
end)
