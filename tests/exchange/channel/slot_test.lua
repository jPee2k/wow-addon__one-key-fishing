-- Channel.lua: giving the chat channel slot up for the player (specs/004-public-channel-sync, FR-005, research R3).
-- The tests run in order and share one login.

local MAIN = "OneKeyFishingShare"
local LINE = "OneKeyFishing left its hidden channel to free a chat channel slot. Try joining again."

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
load_addon()
local Channel = ns.Channel
local LIMIT = ERR_TOO_MANY_CHAT_CHANNELS:format(20)

local function lines()
    local count = 0
    for _, line in ipairs(chat) do
        count = count + (line:find(LINE, 1, true) and 1 or 0)
    end
    return count
end

test("with fewer than two free slots the channel is not joined", function()
    channel_extra = 19
    advance(65)
    eq(#channel_joins, 0, "not joined")
    eq(Channel.GetState(), "noslot", "no free slot")
end)

test("two slots free again: CHANNEL_UI_UPDATE joins", function()
    channel_extra = 18
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_joins, 1, "joined")
    advance(5)
    eq(Channel.GetState(), "in", "in")
end)

test("the game's channel limit text leaves at once with one chat line, and the state says no slot", function()
    channel_extra = 19 -- the player joined one more of their own and tried another
    fire("CHAT_MSG_SYSTEM", LIMIT)
    eq(channel_leaves[#channel_leaves], MAIN, "left")
    eq(lines(), 1, "one line")
    eq(Channel.GetState(), "noslot", "no slot")
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_joins, 1, "one slot free is not enough")
end)

test("a second limit text in the session, on UI_ERROR_MESSAGE, leaves again but prints nothing", function()
    channel_extra = 18
    fire("CHANNEL_UI_UPDATE")
    advance(5)
    eq(Channel.GetState(), "in", "in again")
    channel_extra = 19
    fire("UI_ERROR_MESSAGE", 0, LIMIT)
    eq(Channel.GetState(), "noslot", "left")
    eq(lines(), 1, "still one line")
end)

test("the limit text during the addon's own join, or as a secret value, changes nothing", function()
    channel_extra = 18
    fire("CHANNEL_UI_UPDATE")
    local leaves = #channel_leaves
    fire("CHAT_MSG_SYSTEM", LIMIT)
    eq(#channel_leaves, leaves, "the addon's own join")
    advance(5)
    eq(Channel.GetState(), "in", "in")
    secret_values[LIMIT] = true
    fire("CHAT_MSG_SYSTEM", LIMIT)
    secret_values[LIMIT] = nil
    eq(Channel.GetState(), "in", "a secret text is not read")
    fire("CHAT_MSG_SYSTEM", "Some other system line.")
    eq(Channel.GetState(), "in", "another text")
end)

test("a channel round after a give-way joins again once two slots are free", function()
    channel_extra = 19
    fire("CHAT_MSG_SYSTEM", LIMIT)
    eq(Channel.GetState(), "noslot", "gave way")
    channel_extra = 18
    Channel.CheckSlots() -- what Share's channel round calls
    advance(5)
    eq(Channel.GetState(), "in", "in again")
end)
