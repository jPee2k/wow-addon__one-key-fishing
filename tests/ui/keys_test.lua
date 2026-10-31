-- ns.KeyText (UI/Widgets.lua): every key bound to an action, the same everywhere (spec 007, User Story 4).
-- Players bind a punctuation key once per keyboard layout, so two keys per action are common.

local recorded = {} -- the minimap tooltip's lines
GameTooltip = {
    SetOwner = function() end,
    AddLine = function(_, text) table.insert(recorded, { text }) end,
    AddDoubleLine = function(_, left, right) table.insert(recorded, { left, right }) end,
    Show = function() end,
    Hide = function() end,
}

load_addon()
local L = ns.L
local ACTION, TOGGLE = "ONEKEYFISHING_ACTION", "ONEKEYFISHING_TOGGLE"
local NOT_BOUND = "|cffff5555" .. L["not bound"] .. "|r"

test("no key: not bound", function()
    bindings[ACTION] = nil
    eq(ns.KeyText(ACTION), NOT_BOUND, "default")
    eq(ns.KeyText(ACTION, true, ""), "", "the indicator's empty text")
end)

test("one key: that key", function()
    bindings[ACTION] = { "`" }
    eq(ns.KeyText(ACTION), "`", "key")
end)

test("two keys: both, in the game's order", function()
    bindings[ACTION] = { "'", "`" }
    eq(ns.KeyText(ACTION), "' / `", "keys")
end)

test("modifiers are written the game's way", function()
    bindings[TOGGLE] = { "SHIFT-`", "SHIFT-'" }
    eq(ns.KeyText(TOGGLE), "Shift-` / Shift-'", "keys")
end)

test("the same key twice is named once", function()
    bindings[ACTION] = { "`", "`" }
    eq(ns.KeyText(ACTION), "`", "key")
end)

test("the minimap tooltip names both keys of each action", function()
    bindings[ACTION] = { "`", "'" }
    bindings[TOGGLE] = { "SHIFT-`", "SHIFT-'" }
    local button = assert(_G.OneKeyFishingMinimapButton, "the minimap button")
    button.scripts.OnEnter(button)
    local keys = {}
    for _, line in ipairs(recorded) do
        if line[2] then
            keys[line[1]] = line[2]
        end
    end
    eq(keys[L["Fishing key:"]], "` / '", "fishing key line")
    eq(keys[L["Toggle mode key:"]], "Shift-` / Shift-'", "toggle key line")
end)

test("the indicator puts two keys on two lines and leaves one key as it was", function()
    ns.Mode.IsActive = function() return true end
    local key = _G.OneKeyFishingIndicator.key
    bindings[ACTION] = { "`", "'" }
    ns.Indicator.Update()
    eq(key.text, "`\n'", "two keys")
    bindings[ACTION] = { "CTRL-SHIFT-BUTTON4" }
    ns.Indicator.Update()
    eq(key.text, "CTRL-Shift-BUTTON4", "one key")
    eq(rawget(key, "width"), nil, "no width cap that would cut one long key")
end)
