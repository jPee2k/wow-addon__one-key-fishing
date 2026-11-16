-- Channel.lua: the game refusing the channel itself (specs/004-public-channel-sync, contracts/channel.md): a nil
-- result from the join means every name would fail alike, so no fallback is tried. One login.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
channel_join_result.OneKeyFishingShare = {} -- JoinTemporaryChannel returns nothing
load_addon()

test("a nil join result: locked at once, no fallback, nothing joined again", function()
    advance(65)
    eq(#channel_joins, 1, "one try")
    eq(ns.Channel.GetState(), "locked", "locked")
    advance(3600)
    eq(#channel_joins, 1, "no fallback")
end)
