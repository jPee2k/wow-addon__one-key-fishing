-- CatchDB.lua: the skill filter's value of a skill range and the range of a rank (specs/021-cumulative-skill-filter,
-- research R1 and R5).

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {} }
end)

local CatchDB = ns.CatchDB

test("a skill range as a filter value: 300+ and none are \"all\"", function()
    eq(CatchDB.SkillFilter(nil), "all", "no range")
    eq(CatchDB.SkillFilter(CatchDB.MAX_RANGE), "all", "300+ (the last value of the menu)")
    for range = 0, 3 do
        eq(CatchDB.SkillFilter(range), range, "range " .. range)
    end
end)

test("the range of a Fishing rank", function()
    eq(CatchDB.RangeOf(nil), nil, "no rank")
    eq(CatchDB.RangeOf(0), 0, "0")
    eq(CatchDB.RangeOf(74), 0, "74")
    eq(CatchDB.RangeOf(75), 1, "75")
    eq(CatchDB.RangeOf(224), 2, "224")
    eq(CatchDB.RangeOf(299), 3, "299")
    eq(CatchDB.RangeOf(300), 4, "300")
    eq(CatchDB.RangeOf(375), 4, "375: the last range has no top")
end)

test("the current place's range comes from the rank", function()
    local mapID, range = CatchDB.GetCurrentPlace()
    eq(mapID, 1415, "the map")
    eq(range, 3, "230 is 225-299")
end)
