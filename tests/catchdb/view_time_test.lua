-- CatchDB/Views.lua (specs/024-best-places, research R1): every view carries the casting time of its raw cells
-- (`seconds`) and the catches per hour they give (`catchesPerHour`), never weighted and never filtered by water or a
-- camp bonus (those parts keep no time); a seed cell the harvest weighted has its time scaled with its catches
-- (tools/harvest.mjs scaleCell), so its counted catches `c`, not its raw `r`, go with that time.

local FISH = 6291
local function record(id, key, cell)
    return { id = id, epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16), builds = { ["1.60.1"] = { [key] = cell } } }
end
local records = {
    ["baaaaaa2@0"] = record("baaaaaa2", "1415:3:47", { c = 30, m = 6, t = 360, i = { [FISH] = { 30, 30 } },
        p = { c = 10, i = { [FISH] = { 10, 10 } } } }),
}
-- Map 1420: five honest records (100 catches in 1000 s each) and one that claims 5000 catches in 5000 s.
for n, id in ipairs({ "caaaaaa2", "daaaaaa2", "eaaaaaa2", "faaaaaa2", "gaaaaaa2", "haaaaaa2" }) do
    local c = n == 6 and 5000 or 100
    records[id .. "@0"] = record(id, "1420:3:47", { c = c, m = 0, t = n == 6 and 5000 or 1000,
        i = { [FISH] = { c, c } } })
end
OneKeyFishingDB = { shareNotice = true, settings = { shareDB = true }, shared = { records = records } }
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        -- weighted by the harvest by 1/4: 10 counted catches of 40 real ones, 720 s of casting scaled to 180
        ["1415:3:47"] = { c = 10, r = 40, x = 10, m = 1, t = 180, k = 2, px = 5160, py = 9360,
            i = { [FISH] = { 10, 10 } } },
        ["1429:2:11"] = { c = 20, m = 0, t = 0, k = 3, i = { [FISH] = { 20, 20 } } },
    } }
end)

local CatchDB = ns.CatchDB
local ALL = { range = "all", source = "all" }

test("a map view sums the raw seconds and gives the raw catches per hour", function()
    local view = CatchDB.QueryMap(1415, ALL)
    eq(view.seconds, 540, "180 + 360")
    near(view.catchesPerHour, 3600 * (10 + 30) / 540, "the seed's counted catches with its scaled time")
end)

test("a spot view and Query's view carry the same numbers", function()
    local spots = CatchDB.QueryCells(1415, ALL)
    eq(#spots, 1, "one spot")
    eq(spots[1].seconds, 540, "seconds")
    eq(CatchDB.Query(1415, "47", ALL).seconds, 540, "Query's view")
end)

test("the water filter keeps the place's time and pace", function()
    local pool = CatchDB.QueryMap(1415, { range = "all", source = "all", water = "pool" })
    eq(pool.seconds, 540, "seconds")
    near(pool.catchesPerHour, 3600 * 40 / 540, "the whole place's pace")
end)

test("no time: no catches per hour", function()
    local view = CatchDB.QueryMap(1429, ALL)
    eq(view.seconds, 0, "no seconds")
    eq(view.catchesPerHour, nil, "nil")
end)

test("another player's pace is weighted like its catches: one record cannot set a place's pace", function()
    local view = CatchDB.QueryMap(1420, ALL)
    local unweighted = 3600 * (5 * 100 + 5000) / (5 * 1000 + 5000)
    assert(view.catchesPerHour < unweighted * 0.75, "capped: " .. view.catchesPerHour .. " of " .. unweighted)
    assert(view.catchesPerHour > 360, "above the honest records' 360 an hour")
end)

test("another player's record counts at least 5 seconds a cast: a claimed cast a second cannot set the pace", function()
    ns.db.shared.records["iaaaaaa2@0"] = record("iaaaaaa2", "1425:3:47", { c = 500, m = 0, t = 500,
        i = { [FISH] = { 500, 500 } } })
    ns.Fire("SHARED_DATA_CHANGED")
    local view = CatchDB.QueryMap(1425, ALL)
    near(view.catchesPerHour, 3600 / 5, "one catch every 5 seconds at most")
end)

test("under the water filter the pace's weights come from the catches before the filter", function()
    for n, id in ipairs({ "jaaaaaa2", "kaaaaaa2", "laaaaaa2", "maaaaaa2", "naaaaaa2", "oaaaaaa2" }) do
        local cheat = n == 6
        ns.db.shared.records[id .. "@0"] = record(id, "1426:3:47", cheat
            and { c = 5000, m = 0, t = 25000, i = { [FISH] = { 5000, 5000 } } } -- open water only
            or { c = 100, m = 0, t = 1000, i = { [FISH] = { 100, 100 } }, p = { c = 50, i = { [FISH] = { 50, 50 } } } })
    end
    ns.Fire("SHARED_DATA_CHANGED")
    local pool = CatchDB.QueryMap(1426, { range = "all", source = "all", water = "pool" })
    local all = CatchDB.QueryMap(1426, ALL)
    near(pool.catchesPerHour, all.catchesPerHour, "the same capped pace with and without the filter")
end)
