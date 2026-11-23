-- UI/Toast.lua and the trophy notice (specs/023-item-kinds US3, FR-008, FR-009): the account's first catch of a
-- trophy gives a gold notice with the count after it, also with catch notifications off, in place of its catch line;
-- a trophy caught again gives the ordinary catch line. The tests share one login and run in order.

local FISH, T1, T2, T3 = 6291, 6292, 6294, 13917
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()

local L = ns.L
local total = select(2, ns.Catalog.TrophyCount())

local function link(itemID)
    return GetLootSlotLink and ("|cffffffff|Hitem:%d::::::::|h[Item %d]|h|r"):format(itemID, itemID)
end

local function caughtLine(...)
    return L["Caught: %s"]:format(table.concat({ ... }, ", "))
end

local function trophyLine(itemID, count)
    return L["New trophy: %s (%d/%d)"]:format(link(itemID), count, total)
end

-- The texts the toast showed since the last cast (ns.Toast is looked up at each call, so a wrapper sees them all).
local toasts = {}
local Toast = ns.Toast
ns.Toast = function(text, ...)
    toasts[text] = { ... }
    return Toast(text, ...)
end

local function shown(text)
    return toasts[text] ~= nil
end

local function cast(items)
    toasts = {}
    fish_cast(items)
end

test("a first item that is no trophy: the ordinary catch line, no trophy notice", function()
    cast({ { FISH, 1 } })
    assert(shown(caughtLine(link(FISH))), "the catch line")
end)

test("a first trophy: the gold notice with the count, also with catch notifications off; no catch line", function()
    ns.db.settings.toasts = false
    cast({ { T1, 1 } })
    assert(shown(trophyLine(T1, 1)), "the trophy notice")
    eq(toasts[trophyLine(T1, 1)][4], true, "shown with catch notifications off")
    eq(shown(caughtLine(link(T1))), false, "no catch line for it")
    ns.db.settings.toasts = true
end)

test("the trophy leaves the catch line, the other items stay", function()
    cast({ { FISH, 1 }, { T2, 1 } })
    assert(shown(caughtLine(link(FISH))), "the fish alone in the catch line")
    assert(shown(trophyLine(T2, 2)), "the trophy notice, 2 now")
end)

test("a trophy caught again: the ordinary catch line only", function()
    cast({ { T1, 1 } })
    assert(shown(caughtLine(link(T1))), "the catch line")
    eq(shown(trophyLine(T1, 1)), false, "no new notice")
end)

test("two new trophies in one loot: two notices, each with its own count", function()
    cast({ { T3, 1 }, { 13916, 1 } })
    assert(shown(trophyLine(T3, 3)), "the first, 3")
    assert(shown(trophyLine(13916, 4)), "the second, 4")
end)
