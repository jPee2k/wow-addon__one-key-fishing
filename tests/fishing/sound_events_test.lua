-- Fishing/Sound.lua: which fishing sound plays when (specs/013-fishing-sounds US1, FR-005 to FR-008, FR-011): the
-- bell when the line is cast, the hook sound on the hook's result (the loot or the game's fish line), the rare
-- sound a moment later for an Uncommon or better item; nothing with the sounds or fishing mode off.

load_addon()

local function cast_start()
    ns.Fire("FISHING_CAST_START", 7620)
end

local function cast_stop()
    ns.Fire("FISHING_CAST_STOP", 7620)
end

-- The open loot of the current cast: items { { itemID, quantity, quality } }.
local function loot_now(items)
    loot = { fishing = true, items = items }
    fire("LOOT_READY")
    loot = nil
end

local function played()
    return table.concat(sounds_played(), " ")
end

local function setup()
    ns.Sound.SetEnabled(true)
    enter_fishing_mode()
end

test("the bell plays once per cast when the line is cast, on the Master channel", function()
    setup()
    cast_start()
    eq(played(), "bell.ogg", "the bell")
    eq(sound_calls[1].channel, "Master", "the Master channel")
    cast_stop()
    advance(2)
end)

test("a white fish: the hook sound once, no rare sound", function()
    setup()
    cast_start()
    loot_now({ { 6303, 1, 1 } })
    cast_stop()
    advance(2)
    eq(played(), "bell.ogg hook.ogg", "bell, then hook")
end)

test("a green item: the hook sound, then the rare sound a moment later", function()
    setup()
    cast_start()
    loot_now({ { 6303, 1, 1 }, { 6304, 1, 2 }, { 6305, 1, 3 } })
    eq(played(), "bell.ogg hook.ogg", "the rare sound waits")
    advance(0.4)
    eq(played(), "bell.ogg hook.ogg rare.ogg", "then the rare sound, once")
    cast_stop()
    advance(2)
end)

test("the game's fish lines while the line is out play the hook sound, once per cast", function()
    setup()
    cast_start()
    fire("UI_ERROR_MESSAGE", 0, ERR_FISH_ESCAPED)
    fire("UI_ERROR_MESSAGE", 0, ERR_FISH_NOT_HOOKED)
    cast_stop()
    advance(2)
    eq(played(), "bell.ogg hook.ogg", "one hook sound")
    sound_calls = {}
    cast_start()
    cast_stop()
    advance(0.5)
    fire("UI_ERROR_MESSAGE", 0, ERR_FISH_NOT_HOOKED) -- just after the channel stopped: still the hook's answer
    eq(played(), "bell.ogg hook.ogg", "within the grace time")
    advance(2)
end)

test("a line that ends with no loot and no fish line plays no hook sound", function()
    setup()
    cast_start()
    cast_stop()
    advance(2)
    fire("UI_ERROR_MESSAGE", 0, ERR_FISH_ESCAPED) -- long after: not this cast's answer
    fire("UI_ERROR_MESSAGE", 0, "Something else.")
    eq(played(), "bell.ogg", "only the bell")
end)

test("nothing plays with the sounds off or fishing mode off", function()
    ns.Sound.SetEnabled(false)
    enter_fishing_mode()
    cast_start()
    loot_now({ { 6304, 1, 2 } })
    advance(1)
    cast_stop()
    advance(2)
    eq(played(), "", "sounds off")
    ns.Sound.SetEnabled(true)
    ns.Mode.Exit()
    cast_start()
    loot_now({ { 6304, 1, 2 } })
    advance(1)
    cast_stop()
    advance(2)
    eq(played(), "", "mode off")
end)

test("leaving fishing mode and turning the sounds off stop what plays", function()
    setup()
    cast_start()
    ns.Mode.Exit()
    eq(#sound_stops, 1, "the bell stopped with the mode")
    setup()
    cast_start()
    ns.Sound.SetEnabled(false)
    eq(#sound_stops, 1, "stopped when switched off")
    cast_stop()
    advance(2)
end)

test("a sound the game refuses raises no error", function()
    setup()
    sound_play_result = false
    cast_start()
    loot_now({ { 6304, 1, 2 } })
    advance(1)
    cast_stop()
    advance(2)
    sound_play_result = true
    eq(#sound_calls, 3, "tried bell, hook and rare")
end)
