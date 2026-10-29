-- "What can be caught here" on a fresh install with a bundled seed: numbers from the first login.

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = {
        epoch = 1, built = "2026-12-01", build = "1.60.1", absorbed = {}, resets = {},
        cells = { ["1415:3:47"] = { c = 120, m = 8, t = 1300, i = { [6291] = { 90, 95 }, [6303] = { 30, 30 } } } },
    }
end)

local L = ns.L
ns.StatsFrame.Toggle()
local window = _G.OneKeyFishingStatsFrame
local here = window.herePage
click(L["What can be caught here"], window)

test("a character with no catches sees the bundled numbers", function()
    eq(here.counts.text:sub(1, #"120 catches"), (L["%d catches"]):format(120), "catches")
    eq(here.rows[1].itemID, 6291, "most caught first")
    eq(here.rows[1].chance.text, "75%", "90 of 120")
    eq(here.rows[2].chance.text, "25%", "30 of 120")
    eq(here.hint.text, "", "no note: the seed is there")
end)

test("Only mine shows that nothing of their own was caught here", function()
    ns.CatchHere.SetSource("mine")
    eq(here.message.text, L["Nothing has been caught here yet."], "empty text")
    ns.CatchHere.SetSource("all")
end)
