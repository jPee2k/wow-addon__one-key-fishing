-- Channel.lua: a join the server confirms late, a /leave before the join is confirmed, and the kick rejoin's timer
-- (specs/004-public-channel-sync, contracts/channel.md "Joining", "Locks, kicks, bans"). The tests run in order and
-- share one login.

channel_on = true

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
local MAIN, SECOND = "OneKeyFishingShare", "OneKeyFishingShare2"
channel_join_result[MAIN] = { 0, MAIN } -- the game answers; the test puts the player in the channel when it lands
load_addon()
local Channel = ns.Channel

local function JoinsOf(name)
    local count = 0
    for _, join in ipairs(channel_joins) do
        if join.name == name then
            count = count + 1
        end
    end
    return count
end

local function Land()
    table.insert(channels_joined, { name = MAIN, number = 1 })
end

local function Kick()
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "PLAYER_KICKED", MAIN, "First Last")
    for i, entry in ipairs(channels_joined) do
        if entry.name == MAIN then
            table.remove(channels_joined, i)
        end
    end
end

local function Where()
    local state, index = Channel.GetState()
    return state .. tostring(index or "")
end

test("a join confirmed by its notice after 8 s (a slow login) stays: the name is not locked", function()
    while #channel_joins == 0 do
        advance(1) -- 30-60 s after the login
    end
    advance(8)
    eq(JoinsOf(SECOND), 0, "no move to the fallback")
    Land()
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_JOINED", MAIN)
    eq(Where(), "in1", "in the main channel")
    advance(30)
    eq(JoinsOf(SECOND), 0, "still no move")
end)

test("a kick rejoin timer that reads a hair before the 60 s still rejoins", function()
    local joins = JoinsOf(MAIN)
    Kick()
    advance(59)
    fire("CHANNEL_UI_UPDATE")
    eq(JoinsOf(MAIN), joins, "not a second early")
    advance(0.8)
    fire("CHANNEL_UI_UPDATE") -- as a timer firing at 59.8 s would
    eq(JoinsOf(MAIN), joins + 1, "rejoined")
end)

test("a join that lands after 12 s with no notice is taken by a later check", function()
    advance(12)
    Land()
    advance(4)
    eq(Where(), "in1", "in the main channel")
    eq(JoinsOf(SECOND), 0, "no move")
end)

test("the echo of the addon's own leave, late during a join of the same name, is not a leave by hand", function()
    Channel.SetEnabled(false) -- leaves
    Channel.SetEnabled(true) -- joins the same name again; the server is slow
    advance(7)
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_LEFT", MAIN) -- the answer to the leave, 7 s late
    eq(Channel.GetState(), "waiting", "still joining")
    Land()
    advance(5)
    eq(Where(), "in1", "in the main channel")
end)

test("a /leave by hand before the join is confirmed counts as left: no fallback joined", function()
    Kick()
    advance(61)
    advance(10) -- the addon's own leave above is long past
    eq(Channel.GetState(), "waiting", "joining again")
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_LEFT", MAIN)
    eq(Channel.GetState(), "left", "left")
    advance(30)
    eq(JoinsOf(SECOND), 0, "no fallback")
    eq(Channel.GetState(), "left", "still left")
end)
