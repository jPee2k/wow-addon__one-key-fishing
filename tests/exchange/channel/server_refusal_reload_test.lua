-- Channel.lua: a /reload after the server refused the channel (spec 016 US4, contracts S4): the session record
-- carries the refusal, so the channel stays stopped and no name is joined until the next real login.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
-- As the logout of the /reload saved it after two NOT_ALLOWED_IN_CHANNEL notices.
OneKeyFishingCharDB = { channelSession = { refused = "server" } }
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("after the /reload the channel is still refused by the server and joins nothing", function()
    eq(ns.Channel.GetState(), "locked", "locked")
    local line = ns.Channel.Describe()[1]
    assert(line:find("refused server", 1, true), "the debug line: " .. line)
    advance(3600)
    eq(#channel_joins, 0, "no join in the next hour")
end)
