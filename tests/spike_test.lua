-- Spike.lua (temporary, removed with it before the release): the /okf spike report.

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()

local function report()
    local text
    local show = ns.ShowCopyWindow
    ns.ShowCopyWindow = function(_, body) text = body end
    ns.ShowSpikeReport()
    ns.ShowCopyWindow = show
    return text
end

test("the report has every section and the pool decision of the last fishing loot", function()
    ns.Fire("FISHING_CAST_START", 7620)
    loot = { fishing = true, items = { { 6291, 1 } } }
    loot_sources = { [1] = "GameObject-0-1-2-3-180582-4" }
    fire("LOOT_READY")
    loot, loot_sources = nil, {}
    local text = report()
    for _, title in ipairs({ "Build (V7)", "Map (V1, V2)", "Last fishing loot (V3)", "Last auction search (V4, V5)",
        "Tabs (V6)" }) do
        assert(text:find("-- " .. title .. " --", 1, true), title)
    end
    assert(text:find("(game object 180582)", 1, true), "the object ID the addon compares")
    assert(text:find("ns.IsPoolLoot(): true", 1, true), "the pool decision")
    assert(text:find("position: 0.43, 0.78", 1, true), "the position")
end)

test("running the report again makes no new tab frame", function()
    local count = #frames
    report()
    eq(#frames, count, "frames")
end)

test("the network section asks every V10-V15 question without names", function()
    in_guild = true
    bn_friends = { { { gameAccountID = 21, clientProgram = "WoW", wowProjectID = 18, isOnline = true } } }
    receive_addon("OKFSPIKE", "spike", "WHISPER", "Me-Realm")
    local text = report()
    assert(text:find("-- Network (V10-V15) --", 1, true), "section")
    eq(addon_prefixes.OKFSPIKE, true, "test prefix registered")
    assert(text:find("GUILD: 0", 1, true), "guild result")
    assert(text:find("WHISPER to self: 0", 1, true), "whisper result")
    assert(text:find("echo on WHISPER from a sender shaped Name-Realm", 1, true), "echo shape")
    assert(text:find("WHISPER to a made-up name: 0; check the chat", 1, true), "made-up name")
    assert(text:find("Battle.net game accounts online 1, on WoW 1, on this project 1", 1, true), "Battle.net counts")
    assert(text:find("SendGameData to the first: 0", 1, true), "SendGameData")
    assert(text:find("Chat=false", 1, true), "restrictions")
    assert(text:find("round trip: equal, encoded length %d+, Base64 characters only: true"), "round trip")
    assert(text:find("BNET_CLIENT_WOW WoW, WOW_PROJECT_ID 18", 1, true), "constants")
    assert(not text:find("Me-Realm", 1, true), "no name")
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
