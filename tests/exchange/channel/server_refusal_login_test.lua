-- Channel.lua: a real login after the server refused the channel (spec 016 FR-009): the session record is dropped,
-- so the addon tries the main channel again after the login delay (the server may have changed back).

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
-- Left by the last /reload of the earlier session; a real login does not restore it.
OneKeyFishingCharDB = { channelSession = { refused = "server" } }
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(true, false)

test("a real login joins the main channel again", function()
    advance(61) -- 30-60 s after the login
    eq(#channel_joins, 1, "one join")
    eq(channel_joins[1].name, "OneKeyFishingShare", "the main channel")
    local line = ns.Channel.Describe()[1]
    assert(line:find("refused false", 1, true), "the debug line: " .. line)
end)
