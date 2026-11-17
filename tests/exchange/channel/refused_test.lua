-- Channel.lua: a join that returns nothing (specs/004-public-channel-sync, contracts/channel.md; spec 016). At the
-- 20-channel limit JoinTemporaryChannel returns nothing (seen 2026-11-17), so an empty result waits for two free
-- slots, as after giving way, and tries the main channel again; no fallback is tried, since every name would fail
-- alike. A refusal of the channel itself looks the same, so the third empty result in a session counts as the game's
-- refusal. One login.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
channel_join_result.OneKeyFishingShare = {} -- JoinTemporaryChannel returns nothing
load_addon()

test("an empty join result: no slot, no fallback, tried again when slots are free", function()
    advance(65)
    eq(#channel_joins, 1, "one try")
    eq(ns.Channel.GetState(), "noslot", "waits for a free slot, not refused")
    assert(ns.Channel.Describe()[1]:find("refused false", 1, true), ns.Channel.Describe()[1])
    advance(3600)
    eq(#channel_joins, 1, "no fallback and no retry without a slot change")
    fire("CHANNEL_UI_UPDATE") -- the channel list changed: two slots are free
    eq(#channel_joins, 2, "tried again")
    eq(channel_joins[2].name, "OneKeyFishingShare", "the main channel")
end)

test("the third empty result in a session counts as the game refusing the channel", function()
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_joins, 3, "the third try")
    eq(ns.Channel.GetState(), "locked", "refused")
    assert(ns.Channel.Describe()[1]:find("refused game", 1, true), ns.Channel.Describe()[1])
    fire("CHANNEL_UI_UPDATE")
    advance(3600)
    eq(#channel_joins, 3, "nothing joined again")
end)
