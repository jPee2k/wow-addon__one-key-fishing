-- Share.lua and CatchDB.lua after an update whose bundled seed absorbed records this client got from the
-- network: the network copies go, the counts stay, and a copy sent again is neither wanted nor accepted.

local FISH = 6291
local IDS = { "qqqqqqqq", "rrrrrrrr", "ssssssss" }

-- Saved data of the last session: three other players' records, 10 + 20 + 30 catches at 1415:3:47 (60 in the
-- tab before the update, next to an empty own record).
local records = {}
for i, id in ipairs(IDS) do
    records[id .. "@0"] = { id = id, epoch = 0, seq = 2, seen = 100,
        builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(10 * i, 0, { [FISH] = { 10 * i, 10 * i } }) } } }
end
records["ttttttt2@0"] = { id = "ttttttt2", epoch = 0, seq = 1, seen = 100,
    builds = { ["1.60.1"] = { ["1416:3:x"] = catch_cell(5, 0, { [FISH] = { 5, 5 } }) } } }
OneKeyFishingDB = { shareNotice = true, shared = { mine = {}, records = records } }
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230

-- The new release: its seed holds the same sums and names the three IDs as absorbed (the harvest of US4).
load_addon(function()
    ns.SeedData = { epoch = 1, built = "2026-12-01", build = "1.60.1",
        absorbed = { qqqqqqqq = 0, rrrrrrrr = 0, ssssssss = 0 }, resets = {},
        cells = { ["1415:3:47"] = { c = 60, m = 0, t = 600, k = 3, i = { [FISH] = { 60, 60 } } } } }
end)

local shared = ns.db.shared
local ALL = { range = 3, source = "all" }

test("the absorbed network copies are deleted at login; the others stay", function()
    for _, id in ipairs(IDS) do
        eq(shared.records[id .. "@0"], nil, id)
    end
    assert(shared.records["ttttttt2@0"], "a record the seed does not hold stays")
end)

test("the counts are the same as before the update", function()
    local view = ns.CatchDB.Query(1415, "47", ALL)
    eq(view.catches, 60, "60 before, 60 now")
    eq(view.players, 3, "the seed's three players")
end)

test("a peer sending one of them again: not wanted, and refused if pushed", function()
    receive_addon("OKF1", sum_text("xx"), "WHISPER", "Peer-Realm")
    advance(1)
    receive_addon("OKF1", "Dxx " .. ns.BASE32 .. " qqqqqqqq.0.2 ttttttt2.0.1", "WHISPER", "Peer-Realm")
    receive_addon("OKF1", "Wxx", "WHISPER", "Peer-Realm")
    advance(3)
    local want
    for _, message in ipairs(addon_sent) do
        if message.text:sub(1, 3) == "Wxx" then
            want = message.text
        end
    end
    eq(want, "Wxx", "nothing wanted: the seed has q, and t is the same version")
    local again = { id = "qqqqqqqq", epoch = 0, seq = 2,
        builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(10, 0, { [FISH] = { 10, 10 } }) } } }
    receive_addon("OKF1", "Rxx " .. ns.Share.Encode(again), "WHISPER", "Peer-Realm")
    advance(1)
    eq(shared.records["qqqqqqqq@0"], nil, "not stored")
    eq(ns.CatchDB.Query(1415, "47", ALL).catches, 60, "not counted again")
    eq(ns.Share.Store.Accept(shared, again), "refused", "the store refuses it too")
end)
