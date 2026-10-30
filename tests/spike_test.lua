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

test("the chat channel section joins a test channel, then checks it and leaves, without names", function()
    local text = report()
    assert(text:find("-- Chat channel (V19-V27) --", 1, true), "section")
    assert(text:find("MaxChatChannels 20, active channels 0", 1, true), "slots")
    assert(text:find("too many channels text: You can only be in 20 channels at a time.", 1, true), "limit text")
    local name = channel_joins[#channel_joins].name
    assert(name:find("^OKFSpike%d%d%d%d$"), "a test channel name: " .. name)
    assert(text:find("JoinTemporaryChannel: 0, the test channel name", 1, true), "join result")
    chat_window_add(1, name)
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", name)
    receive_addon("OKFSPIKE", "ping", "CHANNEL", "Other-Realm", name, 5, name)
    text = report()
    assert(text:find("chat window 1 listed it", 1, true), "window check")
    assert(not ChatFrame1:ContainsChannel(name), "removed from the window")
    assert(text:find("SendAddonMessage CHANNEL: 0", 1, true), "send result")
    assert(text:find("CHAT_MSG_CHANNEL_NOTICE YOU_CHANGED", 1, true), "notice token")
    assert(text:find("channel echo: sender Name-Realm, target the test channel name", 1, true), "echo shapes")
    eq(channel_passwords[1].password, "x", "password set")
    eq(channel_passwords[2].password, "", "password cleared")
    eq(channel_leaves[#channel_leaves], name, "left the test channel")
    assert(not text:find("Other-Realm", 1, true), "no name")
    text = report()
    assert(text:find("channel numbers back as before the last join: true", 1, true), "numbers compared")
end)

test("the chat channel section hides a password popup for the test channel and survives failing calls", function()
    local name = channel_joins[#channel_joins].name
    fire("CHANNEL_PASSWORD_REQUEST", name)
    eq(popups_hidden[#popups_hidden], "CHAT_CHANNEL_PASSWORD", "popup hidden")
    LeaveChannelByName(name) -- the last report joined it again
    local join, send = JoinTemporaryChannel, C_ChatInfo.SendAddonMessage
    JoinTemporaryChannel = function() error("boom") end
    C_ChatInfo.SendAddonMessage = function() error("boom") end
    local text = report()
    JoinTemporaryChannel, C_ChatInfo.SendAddonMessage = join, send
    assert(text:find("password request for the test channel", 1, true) or text:find("CHANNEL_PASSWORD_REQUEST", 1,
        true), "the request is reported")
    assert(text:find("JoinTemporaryChannel: failed: ", 1, true), "failure line")
    assert(not text:find("!! failed", 1, true), text:match("!! failed[^\n]*") or "")
end)
