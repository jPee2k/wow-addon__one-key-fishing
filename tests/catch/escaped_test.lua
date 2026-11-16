-- Catch.lua: the game's lines for a fish that got away or was not hooked become FISH_ESCAPED (castID), once per cast,
-- while the line is out or just after it (spec 013 research R1, moved from Fishing/Sound.lua by review 2).

load_addon()

local escaped = {}
ns.On("FISH_ESCAPED", function(castID) table.insert(escaped, castID) end)

test("a fish line while the line is out: FISH_ESCAPED once for that cast", function()
    ns.Fire("FISHING_CAST_START", 7620)
    local cast = ns.GetFishingCastID()
    fire("UI_ERROR_MESSAGE", 0, ERR_FISH_NOT_HOOKED)
    fire("UI_ERROR_MESSAGE", 0, ERR_FISH_ESCAPED)
    eq(#escaped, 1, "once")
    eq(escaped[1], cast, "that cast")
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
end)

test("just after the line ends it still counts; long after, or another line, it does not", function()
    escaped = {}
    ns.Fire("FISHING_CAST_START", 7620)
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(0.5)
    fire("UI_ERROR_MESSAGE", 0, ERR_FISH_ESCAPED)
    eq(#escaped, 1, "within the grace time")
    ns.Fire("FISHING_CAST_START", 7620)
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
    fire("UI_ERROR_MESSAGE", 0, ERR_FISH_ESCAPED)
    fire("UI_ERROR_MESSAGE", 0, "Something else.")
    eq(#escaped, 1, "nothing more")
end)

-- Review 3: a line arriving just after the line ended belongs to the cast that ended, not to a recast, and not to a
-- cast that already caught something.
test("a late fish line names the cast that ended, and none after a catch", function()
    escaped = {}
    ns.Fire("FISHING_CAST_START", 7620)
    local first = ns.GetFishingCastID()
    ns.Fire("FISHING_CAST_STOP", 7620)
    ns.Fire("FISHING_CAST_START", 7620) -- a quick recast
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(0.3)
    fire("UI_ERROR_MESSAGE", 0, ERR_FISH_ESCAPED)
    eq(escaped[1], ns.GetFishingCastID(), "the cast that stopped last")
    advance(2)
    escaped = {}
    ns.Fire("FISHING_CAST_START", 7620)
    loot = { fishing = true, items = { { 6303, 1 } } }
    fire("LOOT_READY")
    loot = nil
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(0.3)
    fire("UI_ERROR_MESSAGE", 0, ERR_FISH_NOT_HOOKED)
    eq(#escaped, 0, "no escape for a cast that caught")
    assert(first < ns.GetFishingCastID(), "casts numbered")
    advance(2)
end)

test("a fish line while a new line is out after a recast does not name an earlier cast", function()
    escaped = {}
    ns.Fire("FISHING_CAST_START", 7620)
    ns.Fire("FISHING_CAST_STOP", 7620)
    ns.Fire("FISHING_CAST_START", 7620)
    local current = ns.GetFishingCastID()
    fire("UI_ERROR_MESSAGE", 0, ERR_FISH_ESCAPED)
    eq(escaped[1], current, "the line that is out")
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
end)

-- In game 2026-11-16: "No fish are hooked." played no hook sound with only UI_ERROR_MESSAGE read. The game may send
-- the fish lines as UI_INFO_MESSAGE (ForeverFishing reads both), so both count.
test("a fish line sent as UI_INFO_MESSAGE counts too", function()
    escaped = {}
    ns.Fire("FISHING_CAST_START", 7620)
    fire("UI_INFO_MESSAGE", 0, ERR_FISH_NOT_HOOKED)
    eq(#escaped, 1, "FISH_ESCAPED from the info line")
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
end)
