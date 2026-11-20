-- UI/CatchHere.lua and UI/Widgets.lua: the Skill button of "What can be caught here" (specs/021-cumulative-skill-
-- filter, US3): its label, its menu with the own range marked "(yours)", its tooltip, the counts line's miss rate and
-- the removed hint. The tests run in order and share one login.

local FISH = 6291

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 180
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:1:47"] = catch_cell(60, 0, { [FISH] = { 60, 60 } }), -- 75-149 only: nothing at the own 150-224
    } }
end)

local L = ns.L
ns.StatsFrame.Toggle()
local window = _G.OneKeyFishingStatsFrame
local here = window.herePage
click(L["What can be caught here"], window)

local function menuTexts()
    here.skillButton.scripts.OnClick(here.skillButton)
    local texts = {}
    for _, entry in ipairs(menu_entries) do
        texts[#texts + 1] = entry.text
    end
    return table.concat(texts, "|")
end

local function hover()
    here.skillButton.scripts.OnEnter(here.skillButton)
    return table.concat(tooltip_lines, "|")
end

local function skillUp(rank)
    fishing_rank = rank
    fire("SKILL_LINES_CHANGED")
    tick(window)
end

test("the own range by default, with the catches of lower skill on the page", function()
    eq(here.skillButton.text, (L["Skill: Up to %d"]):format(224), "the button")
    eq(here.message.text, "", "not empty: 75-149 is summed")
    eq(here.counts.text:sub(1, #"60 catches"), (L["%d catches"]):format(60), "the catches of 75-149")
end)

test("the menu: five values in order, the own range marked (yours) and checked", function()
    eq(menuTexts(), table.concat({ (L["Up to %d"]):format(74), (L["Up to %d"]):format(149),
        (L["Up to %d (yours)"]):format(224), (L["Up to %d"]):format(299), (L["All (%d+)"]):format(300) }, "|"),
        "the values")
    for i, entry in ipairs(menu_entries) do
        eq(entry.kind, "radio", "a radio entry")
        eq(entry.isSelected(), i == 3, "checked: " .. entry.text)
    end
end)

test("the tooltip: what the list holds, where the misses come from", function()
    eq(hover(), table.concat({ L["Skill"], (L["Catches with skill up to %d."]):format(224),
        (L["Misses only with skill %s."]):format("150-224") }, "|"), "up to 224")
end)

test("no cast at the own range: the miss rate is little data, no hint", function()
    eq(here.counts.text, (L["%d catches"]):format(60) .. "    " .. L["Nothing caught: little data"], "counts line")
    assert(not here.hint.text:find("All skill levels", 1, true), "no old hint: " .. here.hint.text)
end)

test("enough casts at the own range: the miss rate as a percentage", function()
    ns.SeedData.cells["1415:2:47"] = catch_cell(90, 10, { [FISH] = { 90, 90 } })
    ns.Fire("SHARED_DATA_CHANGED")
    tick(window)
    eq(here.counts.text, (L["%d catches"]):format(150) .. "    " .. (L["Nothing caught: %s"]):format(ns.Percent(0.1)),
        "10 % at 150-224")
end)

test("the default follows the rank; 300+ is \"all\"", function()
    skillUp(230)
    eq(here.skillButton.text, (L["Skill: Up to %d"]):format(299), "225-299")
    skillUp(300)
    eq(here.skillButton.text, L["Skill: All"], "300+")
    eq(menuTexts():match("[^|]*$"), (L["All (%d+) (yours)"]):format(300), "the last value is the own one")
    local tip = { L["Skill"], L["Catches with any skill."], (L["Misses only with skill %s."]):format("300+") }
    eq(hover(), table.concat(tip, "|"), "the tooltip for all")
end)

test("a value picked by hand stays through a skill-up", function()
    menuTexts()
    menu_entry((L["Up to %d"]):format(149)).onClick()
    eq(here.skillButton.text, (L["Skill: Up to %d"]):format(149), "picked")
    skillUp(180)
    eq(here.skillButton.text, (L["Skill: Up to %d"]):format(149), "still picked")
    eq(menuTexts():find((L["Up to %d (yours)"]):format(224), 1, true) ~= nil, true, "the own range still marked")
end)

test("no map: the own range is still marked (from the rank, FR-010)", function()
    player_map_id = nil
    fire("ZONE_CHANGED_NEW_AREA")
    tick(window)
    assert(menuTexts():find((L["Up to %d (yours)"]):format(224), 1, true), "marked without a map")
    player_map_id = 1415
end)

test("Fishing not learned: no value is marked", function()
    skillUp(nil)
    eq(menuTexts(), table.concat({ (L["Up to %d"]):format(74), (L["Up to %d"]):format(149),
        (L["Up to %d"]):format(224), (L["Up to %d"]):format(299), (L["All (%d+)"]):format(300) }, "|"), "no (yours)")
end)
