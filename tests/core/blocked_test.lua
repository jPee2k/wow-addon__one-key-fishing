-- Blocked actions (Core.lua, specs/029-blocked-actions): the game's refusals because of this addon and the game's
-- blocked-action message called with the addon's code on the stack are kept in the error log, with their state, and
-- none goes to the game's error handler. Its own file: the hook is set while the files load, so the stubs come first.

local hooked
function hooksecurefunc(name, fn)
    if name ~= "DisplayInterfaceActionBlockedMessage" then
        return
    end
    local original = _G[name]
    hooked = fn
    _G[name] = function(...) -- the game's hook is C code: a tail call leaves no Lua line of its own
        original(...)
        return fn(...)
    end
end
function DisplayInterfaceActionBlockedMessage() end

-- A function of a file in the addon's folder, as the game names it, that calls the game's blocked-action message.
local function AddonCaller(file, folder)
    return assert(loadstring("return function(f) if f then f() return end DisplayInterfaceActionBlockedMessage() end",
        "@Interface/AddOns/" .. (folder or "OneKeyFishing") .. "/" .. file))()
end
local Block = AddonCaller("UI/Fake.lua")
local OtherBlock = AddonCaller("UI/Other.lua")
local OtherAddonBlock = AddonCaller("Hook.lua", "SomeOtherAddon") -- another addon's code, closer to the block
local BlizzardBlock = AddonCaller("Shared/Panel.lua", "Blizzard_UIPanels") -- the game's code: skipped
local function ForeignBlock() -- another addon's or the game's block: no line of the addon on the stack
    DisplayInterfaceActionBlockedMessage()
end

load_files(TOC_FILES)
Block() -- before the saved variables load
fire("ADDON_LOADED", "OneKeyFishing")

local function Find(context)
    local found = {}
    for _, entry in ipairs(ns.GetErrors()) do
        if entry.context == context then
            table.insert(found, entry)
        end
    end
    return found
end

test("the hook is set at load, and a block before the saved variables is kept", function()
    assert(hooked, "hooked")
    local blocked = Find("INTERFACE_ACTION_BLOCKED")
    eq(#blocked, 1)
    eq(blocked[1].version, ns.version)
    eq(blocked[1].count, 1)
    assert(blocked[1].message:find("AddOns/OneKeyFishing/UI/Fake.lua", 1, true), blocked[1].message)
    assert(blocked[1].stack:find("in combat: no", 1, true), blocked[1].stack)
end)

test("a block without the addon on the stack is not kept", function()
    local before = #ns.GetErrors()
    ForeignBlock()
    eq(#ns.GetErrors(), before)
end)

test("a refusal because of this addon is recorded with its function and state, not handed to the error handler",
    function()
        take_errors()
        fire("ADDON_ACTION_FORBIDDEN", "OneKeyFishing", "SetRaidTarget()")
        local entries = Find("ADDON_ACTION_FORBIDDEN")
        eq(#entries, 1)
        eq(entries[1].message, "SetRaidTarget()")
        assert(entries[1].stack:find("^in combat: no\n"), entries[1].stack)
        local second = entries[1].stack:match("^[^\n]*\n([^\n]*)") or ""
        assert(not second:find("Core/Core.lua", 1, true) and not second:find("^%s*%[C%]"),
            "the addon's event dispatch is left out: " .. second)
        local count = select(2, entries[1].stack:gsub("\n", "\n"))
        assert(count <= 10, "at most the state and 10 stack lines")
        eq(#take_errors(), 0, "nothing for the error handler")
    end)

test("a refusal names the addon's place on its stack, also beyond the 10 lines kept", function()
    local refuse = assert(loadstring("return function() fire('ADDON_ACTION_FORBIDDEN', 'OneKeyFishing', 'Deep()') end",
        "@Interface/AddOns/OneKeyFishing/UI/Deep.lua"))()
    local function nest(depth)
        if depth == 0 then
            refuse()
        else
            nest(depth - 1) -- not a tail call: each level is a line of the stack
            return
        end
    end
    nest(15)
    local entries = Find("ADDON_ACTION_FORBIDDEN")
    local stack = entries[#entries].stack
    assert(stack:find("addon line: Interface/AddOns/OneKeyFishing/UI/Deep.lua:1", 1, true), stack)
end)

test("another addon's refusal is not recorded", function()
    fire("ADDON_ACTION_BLOCKED", "SomeOtherAddon", "CastSpellByName()")
    eq(#Find("ADDON_ACTION_BLOCKED"), 0)
    fire("ADDON_ACTION_BLOCKED", "OneKeyFishing", "CastSpellByName()")
    eq(#Find("ADDON_ACTION_BLOCKED"), 1)
end)

test("the closest addon on the stack decides: another addon's code there makes it theirs, Blizzard's is skipped",
    function()
        local before = #Find("INTERFACE_ACTION_BLOCKED")
        Block(OtherAddonBlock) -- OneKeyFishing calls another addon's code, which is blocked
        eq(#Find("INTERFACE_ACTION_BLOCKED"), before, "not ours")
        OtherBlock(BlizzardBlock) -- OneKeyFishing calls the game's code, which is blocked
        local blocked = Find("INTERFACE_ACTION_BLOCKED")
        eq(#blocked, before + 1, "ours")
        assert(blocked[#blocked].message:find("UI/Other.lua", 1, true), blocked[#blocked].message)
    end)

test("a repeat keeps the latest state", function()
    in_combat = true
    fire("ADDON_ACTION_FORBIDDEN", "OneKeyFishing", "SetRaidTarget()")
    in_combat = false
    local entry
    for _, found in ipairs(Find("ADDON_ACTION_FORBIDDEN")) do
        entry = found.message == "SetRaidTarget()" and found or entry
    end
    eq(entry.count, 2)
    assert(entry.stack:find("^in combat: yes"), entry.stack)
end)

test("the same place counts into one entry; another place gets its own", function()
    Block()
    OtherBlock()
    OtherBlock()
    local blocked = Find("INTERFACE_ACTION_BLOCKED")
    eq(#blocked, 2)
    for _, entry in ipairs(blocked) do
        if entry.message:find("Fake.lua", 1, true) then
            eq(entry.count, 2, "Fake.lua twice")
        else
            eq(entry.count, 3, "Other.lua twice, after the one of the test above")
        end
    end
end)

test("the state line names the fight and the last addon menu, with a whole number of seconds", function()
    in_combat = true
    ns.NoteMenu("minimap")
    local now = GetTime
    GetTime = function() return now() + 2.5 end -- a fraction: Lua 5.3 refuses it for %d
    fire("ADDON_ACTION_FORBIDDEN", "OneKeyFishing", "SetRaidTarget(2)")
    GetTime = now
    in_combat = false
    local entries = Find("ADDON_ACTION_FORBIDDEN")
    local stack = entries[#entries].stack
    assert(stack:find("in combat: yes", 1, true), stack)
    assert(stack:find("last addon menu: minimap 2 s ago (in combat)", 1, true), stack)
end)

test("RecordEntry never fails its caller", function()
    ns.RecordEntry("TEST", nil, nil)
    ns.RecordEntry("TEST", "text")
    assert(#Find("TEST") >= 1)
end)
