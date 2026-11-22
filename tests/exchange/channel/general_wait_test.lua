-- Channel.lua: a join waits for General (specs/022-channel-order). A join gets the lowest free chat channel number,
-- and General's is free while the player is not in General, so the hidden channel would take number 1 and General
-- would come back behind every channel. The tests run in order and share one login.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
local MAIN = "OneKeyFishingShare"
general_local_id = false -- no General yet
channels_joined = { { name = "Trade", number = 2, zone = 2, disabled = true } } -- the game keeps Trade's number
load_addon()
local Channel = ns.Channel

local function NumberOf(name)
    return (GetChannelName(name))
end

local function LeaveGeneral()
    for i, entry in ipairs(channels_joined) do
        if entry.general then
            table.remove(channels_joined, i)
            return
        end
    end
end

-- The seconds joins waited for General, as /okf debug says them.
local function Waited()
    return tonumber(Channel.Describe()[2]:match("waited for General (%d+) s"))
end

test("a login without General: the channel is not joined after its delay, and the state says waiting", function()
    advance(65)
    eq(#channel_joins, 0, "not joined")
    eq(Channel.GetState(), "waiting", "waiting")
end)

test("General joins with the player's channels behind it: the channel follows 10 s later, after all of them", function()
    eq(game_channel_join("General", 1, true), 1, "General on 1")
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_joins, 0, "not in the moment General shows")
    advance(2)
    table.insert(channels_joined, { name = "LocalDefense", number = 3, zone = 22 }) -- the rest of that moment
    table.insert(channels_joined, { name = "mychannel", number = 4 })
    fire("CHANNEL_UI_UPDATE")
    advance(7)
    eq(#channel_joins, 0, "still giving them their time")
    eq(Channel.GetState(), "waiting", "waiting")
    advance(1)
    eq(#channel_joins, 1, "joined 10 s after General")
    advance(5)
    eq(Channel.GetState(), "in", "in")
    eq(NumberOf("General"), 1, "General keeps 1")
    eq(NumberOf("mychannel"), 4, "the player's channel keeps its number")
    eq(NumberOf(MAIN), 5, "the channel after all of them")
    eq(#channel_swaps, 0, "nothing to repair")
    assert(Waited() >= 15 and Waited() <= 45, "the wait and the 10 s are counted: " .. Waited())
end)

test("the setting turned on without General waits too, 120 s at most", function()
    local before = Waited()
    Channel.SetEnabled(false)
    LeaveGeneral() -- /leave 1
    Channel.SetEnabled(true)
    eq(#channel_joins, 1, "no join at the click")
    advance(100)
    eq(#channel_joins, 1, "still waiting after 100 s")
    eq(Channel.GetState(), "waiting", "waiting")
    advance(20)
    eq(#channel_joins, 2, "joined once the wait ran out, on time")
    fire("PLAYER_LOGOUT") -- a /reload before the join is confirmed would still owe the comparison with General
    eq(ns.charDB.channelSession.generalOwed, true, "owed while joining")
    ns.charDB.channelSession = nil
    advance(5)
    eq(NumberOf(MAIN), 1, "on the free number 1")
    eq(Waited(), before + 120, "the wait in /okf debug")
end)

test("General coming back with no event is seen within 5 s and gets its number 1 again", function()
    eq(game_channel_join("General", 1, true), 5, "the game puts General behind")
    advance(5)
    eq(NumberOf("General"), 1, "General on 1")
    eq(NumberOf(MAIN), 5, "the channel where General was put")
    eq(#channel_swaps, 1, "one swap")
end)

test("after General was seen again the next join waits anew; General's join notice starts its last 10 s", function()
    advance(20)
    Channel.SetEnabled(false)
    LeaveGeneral()
    Channel.SetEnabled(true)
    eq(#channel_joins, 2, "no join at the click")
    advance(30)
    eq(#channel_joins, 2, "waiting")
    game_channel_join("General", 1, true)
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "General")
    eq(#channel_joins, 2, "not at the notice itself")
    advance(10)
    eq(#channel_joins, 3, "joined 10 s after General's notice")
    advance(5)
    eq(NumberOf("General"), 1, "General on 1")
end)

test("a wait given up (the setting off) does not shorten the next one, though no event told of General", function()
    Channel.SetEnabled(false)
    LeaveGeneral()
    Channel.SetEnabled(true) -- a wait starts
    advance(10)
    Channel.SetEnabled(false) -- and is given up
    game_channel_join("General", 1, true) -- General is back for ten minutes; no event, no notice
    advance(600)
    LeaveGeneral()
    local before = Waited()
    Channel.SetEnabled(true)
    eq(#channel_joins, 3, "no join at the click")
    advance(100)
    eq(#channel_joins, 3, "a whole wait")
    advance(20)
    eq(#channel_joins, 4, "joined once it ran out")
    eq(Waited(), before + 120, "only the waits are counted")
end)

test("a wait that ran out with the setting off again: General seen later, the next join waits anew", function()
    advance(5)
    eq(NumberOf(MAIN), 1, "joined without General")
    Channel.SetEnabled(false)
    game_channel_join("General", 1, true)
    advance(600)
    LeaveGeneral()
    Channel.SetEnabled(true)
    eq(#channel_joins, 4, "no join at the click")
    game_channel_join("General", 1, true)
    advance(5)
    eq(#channel_joins, 4, "General is seen; its 10 s run")
    advance(10)
    eq(#channel_joins, 5, "joined once General had its time")
end)

test("with General there all along, the setting joins at the click", function()
    advance(30)
    Channel.SetEnabled(false)
    Channel.SetEnabled(true)
    eq(#channel_joins, 6, "joined at the click")
end)

test("a game that does not have the call for General's number: the join does not wait", function()
    Channel.SetEnabled(false)
    LeaveGeneral()
    C_ChatInfo.GetGeneralChannelLocalID = false
    Channel.SetEnabled(true)
    eq(#channel_joins, 7, "joined at the click")
end)
