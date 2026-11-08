-- Channel.lua: channels that refuse the join (specs/004-public-channel-sync, contracts/channel.md "Locks, kicks,
-- bans"): the password prompt, WRONG_PASSWORD, BANNED, WRONG_FACTION, a join that never lands, and all six locked.
-- The tests run in order and share one login.

channel_on = true

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
local NAMES = { "OneKeyFishingShare", "OneKeyFishingShare2", "OneKeyFishingShare3", "OneKeyFishingShare4",
    "OneKeyFishingShare5", "OneKeyFishingShare6" }
for _, name in ipairs(NAMES) do
    channel_join_result[name] = { 0, name } -- the game answers but never puts the player in the channel
end
load_addon()
local Channel = ns.Channel

local function lastJoin()
    return channel_joins[#channel_joins] and channel_joins[#channel_joins].name
end

test("the password prompt for our name is hidden at once and the next name is joined", function()
    while #channel_joins == 0 do
        advance(1) -- 30-60 s after the login
    end
    eq(lastJoin(), NAMES[1], "tried the main channel")
    fire("CHANNEL_PASSWORD_REQUEST", NAMES[1])
    eq(popups_hidden[#popups_hidden], "CHAT_CHANNEL_PASSWORD", "the game's prompt hidden")
    eq(lastJoin(), NAMES[2], "the first fallback")
end)

test("the prompt for somebody else's channel is left to the game", function()
    local hidden = #popups_hidden
    fire("CHANNEL_PASSWORD_REQUEST", "MyGuildOfficers")
    eq(#popups_hidden, hidden, "not hidden")
    eq(lastJoin(), NAMES[2], "no move")
end)

test("WRONG_PASSWORD, BANNED and WRONG_FACTION each move to the next name", function()
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "WRONG_PASSWORD", NAMES[2])
    eq(lastJoin(), NAMES[3], "after WRONG_PASSWORD")
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "BANNED", NAMES[3])
    eq(lastJoin(), NAMES[4], "after BANNED")
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "WRONG_FACTION", NAMES[4])
    eq(lastJoin(), NAMES[5], "after WRONG_FACTION")
end)

test("a join with no notice that does not land within three checks (15 s) counts as locked", function()
    advance(14)
    eq(lastJoin(), NAMES[5], "still waiting")
    advance(2)
    eq(lastJoin(), NAMES[6], "the last fallback")
end)

test("with all six locked: state locked and nothing more joined until logout", function()
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "WRONG_PASSWORD", NAMES[6])
    eq(Channel.GetState(), "locked", "locked")
    local joins = #channel_joins
    fire("CHANNEL_UI_UPDATE")
    advance(3 * 3600)
    eq(#channel_joins, joins, "nothing joined")
end)
