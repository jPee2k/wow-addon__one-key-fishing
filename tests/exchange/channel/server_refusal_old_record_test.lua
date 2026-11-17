-- Channel.lua: a session record written by 1.2.0, whose refusal flag was `true` (the game refusing the channel itself,
-- a Trial account or an invalid name), read after a /reload (spec 016 data model, contracts S4): it means "game".

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
OneKeyFishingCharDB = { channelSession = { refused = true } }
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("refused = true from 1.2.0 reads as refused by the game", function()
    eq(ns.Channel.GetState(), "locked", "locked")
    local line = ns.Channel.Describe()[1]
    assert(line:find("refused game", 1, true), "the debug line: " .. line)
end)
