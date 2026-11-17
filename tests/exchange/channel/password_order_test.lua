-- Channel.lua: a join of a channel with a password, in the order seen in game on 2026-11-16 (spec 016 FR-005,
-- contracts S6): CHANNEL_PASSWORD_REQUEST first, then the notice WRONG_PASSWORD for the same name. The prompt is
-- hidden once, the name is locked once, and the next fallback is joined once. One login.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
load_addon()
local Channel = ns.Channel
local MAIN, NEXT = "OneKeyFishingShare", "OneKeyFishingShare2"

local function joinsOf(name)
    local n = 0
    for _, join in ipairs(channel_joins) do
        if join.name == name then
            n = n + 1
        end
    end
    return n
end

-- How many times `value` was added to `list` after its first `from` entries.
local function countSince(list, from, value)
    local n = 0
    for i = from + 1, #list do
        if list[i] == value then
            n = n + 1
        end
    end
    return n
end

test("the password request and then WRONG_PASSWORD: one hide, one lock, one move", function()
    advance(61) -- 30-60 s after the login
    eq(joinsOf(MAIN), 1, "tried the main channel")
    local hidden, leaves = #popups_hidden, #channel_leaves

    fire("CHANNEL_PASSWORD_REQUEST", MAIN)
    eq(countSince(popups_hidden, hidden, "CHAT_CHANNEL_PASSWORD"), 1, "the prompt hidden once")
    eq(#channel_leaves, leaves + 1, "one leave: the one Lock sends")
    eq(channel_leaves[#channel_leaves], MAIN, "of the main channel")
    eq(joinsOf(NEXT), 1, "the first fallback joined")

    leaves = #channel_leaves
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "WRONG_PASSWORD", MAIN)
    eq(#channel_leaves, leaves, "no leave for the WRONG_PASSWORD")
    eq(joinsOf(NEXT), 1, "no second join of the fallback")
    eq(#channel_joins, 2, "no further move")

    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", NEXT)
    local state, index = Channel.GetState()
    eq(state, "in", "joined")
    eq(index, 2, "the first fallback")
end)
