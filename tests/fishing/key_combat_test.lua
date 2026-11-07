-- Fishing/Action.lua: the owner's [combat] state handler clears the fishing key's overrides in a fight, so the key runs
-- its own binding (OneKeyFishing_ActionKeyIdle) and says it is paused (specs/009-pin-combat-fixes US4, contracts/
-- combat.md C9, research R1). The game's state driver passes the state as a number: resolveDriver in
-- SecureStateDriver.lua turns "1" into 1 with tonumber, and the handler gets it unchanged. The snippet runs here the
-- way the restricted environment would run it: its own text, with self, stateid and newstate.

load_addon()

local OWNER = OneKeyFishingBindingOwner
local CLICK = "CLICK OneKeyFishingButton:LeftButton"

-- Runs the owner's combat snippet with this newstate. In the stubs loadstring is Lua 5.3's load, which takes the
-- environment as its fourth argument (fengari has no setfenv); test-only, the addon is not touched.
local function RunSnippet(newstate)
    local snippet = OWNER:GetAttribute("_onstate-combat")
    assert(type(snippet) == "string", "the owner has no _onstate-combat snippet")
    local handle = {
        ClearBindings = function()
            ClearOverrideBindings(OWNER)
        end,
    }
    local env = { tonumber = tonumber }
    local chunk = assert(loadstring("local self, stateid, newstate = ...; " .. snippet, "=snippet", "t", env))
    chunk(handle, "combat", newstate)
end

local function KeyAction()
    return (override_bindings[OWNER] or {})["`"]
end

test("in fishing mode the key is bound to the cast button", function()
    enter_fishing_mode()
    eq(KeyAction(), CLICK, "the key clicks the cast button")
end)

test("the fight's state as the driver sends it (the number 1) clears the overrides", function()
    RunSnippet(1)
    eq(KeyAction(), nil, "the key falls back to its own binding")
end)

test("the state 0 (out of a fight) keeps them", function()
    ns.Action.Rebind()
    eq(KeyAction(), CLICK, "bound again")
    RunSnippet(0)
    eq(KeyAction(), CLICK, "still bound")
end)

test("the string \"1\" clears them too", function()
    RunSnippet("1")
    eq(KeyAction(), nil, "cleared")
end)
