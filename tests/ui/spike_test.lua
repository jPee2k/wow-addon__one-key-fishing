-- Spike.lua (temporary, removed with it before the release): the /okf spike report.

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
-- Saved entries of the spike's old deliberate error, and one real error that stays (contracts S3).
local TEST_ERROR = "Interface/AddOns/OneKeyFishing/Core/Spike.lua:576: OneKeyFishing spike test error"
load_addon(function()
    local function entry(context, message)
        return { context = context, message = message, stack = "", version = ns.version, first = 1, last = 1,
            count = 1 }
    end
    OneKeyFishingDB = { errors = { entry("spike", TEST_ERROR), entry("LOOT_READY", "a real error"),
        entry("spike", "Spike.lua:9: a real spike error") } }
end)

-- A report hands on no error (spec 010: the deliberate one of the error log section is gone).
local function report()
    local _, text = ns.Spike.Report()
    eq(#take_errors(), 0, "no error handed on")
    return text
end

test("the saved test error entries are dropped at login; other entries stay", function()
    local contexts = {}
    for _, entry in ipairs(ns.GetErrors()) do
        assert(not entry.message:find("OneKeyFishing spike test error", 1, true), "the test entry is gone")
        table.insert(contexts, entry.context)
    end
    eq(table.concat(contexts, " "), "LOOT_READY spike", "the real errors stay, the spike's own too")
end)

test("the report has the sections still open, and none of the closed ones (spec 010, contracts S2)", function()
    local text = report()
    assert(text:find("OneKeyFishing spike report", 1, true), "the version header")
    for _, title in ipairs({ "Network (V10-V15)", "Proof steps (V26)", "Areas (V34)", "Folding (V36)",
        "Last auction search (V5)" }) do
        assert(text:find("-- " .. title .. " --", 1, true), title)
    end
    for _, title in ipairs({ "Build", "Map (V1", "Last fishing loot", "Tabs", "Chat channel", "Map pins",
        "Error log" }) do
        assert(not text:find("-- " .. title, 1, true), "removed: " .. title)
    end
    eq(#channel_joins, 0, "no test channel joined")
end)

test("the proof steps section times 64 steps and checks the hash", function()
    profile_ms, profile_step = 0, 1
    local text = report()
    profile_ms, profile_step = nil, nil
    assert(text:find("SHA256(abc) known digest: true", 1, true), "the digest")
    assert(text:find("64 proof steps: %d+%.%d%d ms"), "the timing")
end)

test("the network section asks every V10-V15 question without names", function()
    in_guild = true
    bn_friends = { { { gameAccountID = 21, clientProgram = "WoW", wowProjectID = 18, isOnline = true } } }
    receive_addon("OKFSPIKE", "spike", "WHISPER", "First Last")
    local text = report()
    assert(text:find("-- Network (V10-V15) --", 1, true), "section")
    eq(addon_prefixes.OKFSPIKE, true, "test prefix registered")
    assert(text:find("GUILD: 0", 1, true), "guild result")
    assert(text:find("WHISPER to self: 0", 1, true), "whisper result")
    assert(text:find("echo on WHISPER from a sender shaped Name", 1, true), "echo shape")
    assert(text:find("WHISPER to a made-up name: 0; check the chat", 1, true), "made-up name")
    assert(text:find("Battle.net game accounts online 1, on WoW 1, on this project 1", 1, true), "Battle.net counts")
    assert(text:find("SendGameData to the first: 0", 1, true), "SendGameData")
    assert(text:find("Chat=false", 1, true), "restrictions")
    assert(text:find("round trip: equal, encoded length %d+, Base64 characters only: true"), "round trip")
    assert(text:find("BNET_CLIENT_WOW WoW, WOW_PROJECT_ID 18", 1, true), "constants")
    assert(not text:find("First Last", 1, true), "no name")
    eq(bn_sent[#bn_sent].prefix, "OKFSPIKE", "the test prefix, not the exchange's")
end)

test("a failing send shows a failure line, not a Lua error", function()
    local send = C_ChatInfo.SendAddonMessage
    C_ChatInfo.SendAddonMessage = function() error("boom") end
    local text = report()
    C_ChatInfo.SendAddonMessage = send
    assert(text:find("WHISPER to self: failed: ", 1, true), "failure line")
    assert(not text:find("!! failed", 1, true), text:match("!! failed[^\n]*") or "")
end)

---------------------------------------------------------------------------
-- Areas and folding (specs/005-catch-catalog, research R13)
---------------------------------------------------------------------------
test("the areas and folding sections read the areas at the position, the subzone and the fold, setting nothing",
    function()
    explored_areas = { 10, 20 }
    area_names = { [10] = "Elwynn Forest", [20] = "Crystal Lake" }
    sub_zone = "Crystal Lake"
    local text = report()
    assert(text:find("area 20: Crystal Lake", 1, true), "an area with its name")
    assert(text:find("GetSubZoneText: Crystal Lake", 1, true), "the subzone")
    assert(text:find("the area the addon keeps: ", 1, true), "the kept area")
    assert(text:find("CaseAccentInsensitiveParse false: -", 1, true), "no game fold here")
    assert(text:find("strcmputf8i(b, A): missing", 1, true), "no order function here")
    eq(#waypoint_sets, 0, "no waypoint set")
    eq(#world_maps_opened, 0, "no map opened")
end)

test("the areas and folding sections survive every call failing", function()
    local function boom()
        error("boom")
    end
    local area, explored, vector = C_Map.GetAreaInfo, C_MapExplorationInfo.GetExploredAreaIDsAtPosition, CreateVector2D
    C_Map.GetAreaInfo, C_MapExplorationInfo.GetExploredAreaIDsAtPosition = boom, boom
    CreateVector2D, CaseAccentInsensitiveParse, strcmputf8i = boom, boom, boom
    local text = report()
    C_Map.GetAreaInfo, C_MapExplorationInfo.GetExploredAreaIDsAtPosition = area, explored
    CreateVector2D, CaseAccentInsensitiveParse, strcmputf8i = vector, nil, nil
    assert(text:find("GetExploredAreaIDsAtPosition failed: ", 1, true), "areas")
    assert(text:find("strcmputf8i(b, A): failed: ", 1, true), "order")
    assert(not text:find("!! failed", 1, true), text:match("!! failed[^\n]*") or "")
end)
