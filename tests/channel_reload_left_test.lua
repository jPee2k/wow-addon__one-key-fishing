-- Channel.lua: what a /reload keeps (specs/004-public-channel-sync, FR-005, data-model.md "State of the channel"):
-- a channel left by hand, the names found locked and the kicks last until the next login, not until a /reload.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
-- As the logout before the /reload saved it: left by hand after the main channel was found locked.
OneKeyFishingCharDB = { channelSession = { left = true, locked = { [1] = true }, kicks = 1 } }
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("after a /reload, a channel left by hand stays left: nothing joined", function()
    eq(ns.Channel.GetState(), "left", "left")
    advance(120)
    eq(#channel_joins, 0, "nothing joined")
    eq(ns.charDB.channelSession, nil, "read once")
end)

test("the next logout (or /reload) saves the state again", function()
    fire("PLAYER_LOGOUT")
    local saved = ns.charDB.channelSession
    eq(saved.left, true, "left")
    eq(saved.locked[1], true, "the main channel locked")
    eq(saved.kicks, 1, "the kicks")
    eq(saved.lockWait, false, "no lock waited on")
end)

test("a kick just before the /reload still waits its 60 s; the locked main channel is skipped", function()
    ns.charDB.channelSession = { locked = { [1] = true }, kicks = 1, rejoinAt = GetTime() + 30 }
    enter_world(false, true)
    eq(ns.Channel.GetState(), "waiting", "not left any more")
    advance(29)
    eq(#channel_joins, 0, "not before the kick's 60 s")
    advance(2)
    eq(channel_joins[1].name, "OneKeyFishingShare2", "the first fallback: the main one stays locked")
end)
