-- CatchDB/Events.lua: a saved own record whose seq is a number but no count (a hand edit, a bad write) starts over at
-- login, by the same rule CatchDB.OwnRecord applies, so catches keep being recorded (spec 008 review).

local FISH, ID = 6291, "qqqqqqqq"
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
OneKeyFishingDB = { shared = { myID = ID, mine = {}, records = {
    [ID] = { id = ID, epoch = 0, seq = -1, builds = { ["1.60.1"] = {} } },
} } }
load_addon()

test("an own record with a seq of -1 starts over at login, and a catch is recorded", function()
    local own = ns.CatchDB.OwnRecord()
    assert(own, "a sound own record after the login")
    assert(own.seq >= 0, "its seq is a count")
    fish_cast({ { FISH, 1 } })
    fish_cast(nil)
    eq(ns.db.shared.mine["1415:3:47"].c, 1, "the catch is in mine")
end)
