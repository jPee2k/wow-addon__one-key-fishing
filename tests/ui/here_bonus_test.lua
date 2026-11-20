-- The camp bonus tag in "What can be caught here" (specs/020-camp-buffs FR-019, research R19): the camp feature's
-- icon at the right end of a tagged row's name, the bonus's chance in its cell, and the tag's words in the row's
-- tooltip, never twice. The tests run in order and share one login.

local FISH, BLOATED, UNKNOWN = 6291, 6643, 88888
local TAG = 14 -- the icon's size
local NAME_WIDTH = 195 -- the name column (the chance column took 25 for French "Little data")
unknown_items[UNKNOWN] = true
item_icons[279965] = 777

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    local cell = catch_cell(100, 0, { [FISH] = { 85, 85 }, [BLOATED] = { 10, 10 }, [UNKNOWN] = { 5, 5 } })
    cell.k = 3
    cell.q = { ["1"] = { c = 50, m = 0, k = 3, i = { [FISH] = { 35, 35 }, [BLOATED] = { 10, 10 },
        [UNKNOWN] = { 5, 5 } } } }
    local old = catch_cell(20, 0, { [FISH] = { 18, 18 }, [BLOATED] = { 2, 2 } })
    old.k = 2
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = { ["1415:3:47"] = cell, ["1416:3:x"] = old } }
end)
advance(10) -- the default index, for the item tooltips' lines

local L, Catalog = ns.L, ns.Catalog
ns.StatsFrame.Toggle()
local window = _G.OneKeyFishingStatsFrame
local here = window.herePage
click(L["What can be caught here"], window)
tick(window)

local function rowOf(itemID)
    for _, row in ipairs(list_rows(here.list)) do
        if row:IsShown() and row.itemID == itemID then
            return row
        end
    end
end

local function count(text)
    local n = 0
    for _, line in ipairs(tooltip_lines) do
        if line == text then
            n = n + 1
        end
    end
    return n
end

-- The tag's line as drawn: its colour as a code in the text too (spec 020 decision 34).
local function tagLine(key)
    return ns.ColoredText(Catalog.BonusTag(key), unpack(ns.TOOLTIP_COLOR))
end

local function has(text)
    return count(text) > 0
end

test("a tagged row shows the Rack's icon at the end of its name and the bonus chance", function()
    local row = assert(rowOf(BLOATED), "the Bloated fish's row")
    assert(row.tag:IsShown(), "the icon")
    eq(row.tag.texture, 777, "the Fishing Rack's item icon")
    eq(row.name:GetWidth(), NAME_WIDTH - TAG, "the name makes room for it")
    eq(row.chance.text, ns.Percent(10 / 50), "the bonus chance, without the words")
    local fish = assert(rowOf(FISH), "the fish's row")
    assert(not fish.tag:IsShown(), "no icon on an untagged row")
    eq(fish.name:GetWidth(), NAME_WIDTH, "the full name width")
    for _, header in ipairs(list_rows(here.list)) do
        if header:IsShown() and not header.itemID then
            assert(not header.tag:IsShown(), "no icon on a header row")
        end
    end
end)

test("hovering a tagged row: the tag, its explanation and the chance with the bonus", function()
    local row = rowOf(BLOATED)
    row.scripts.OnEnter(row)
    assert(has(tagLine("rack")), "the tag")
    assert(has(Catalog.BonusTip("rack", true)), "the explanation (a Bloated fish: the Rack or the Hut)")
    assert(has(Catalog.ChanceText(0.2, false, 3, true)), "the chance with the bonus")
    GameTooltip:Hide()
    ns.db.settings.tooltipChances = false
    row.scripts.OnEnter(row)
    assert(has(Catalog.BonusTip("rack", true)), "also with the chances in tooltips off")
    GameTooltip:Hide()
    ns.db.settings.tooltipChances = true
end)

test("a plain tag shows the tag and the explanation only", function()
    GameTooltip:SetOwner(UIParent)
    ns.AddBonusLines(GameTooltip, { key = "rack", plain = true })
    eq(#tooltip_lines, 2, "two lines")
    eq(tooltip_lines[1], tagLine("rack"), "the tag")
    eq(tooltip_lines[2], Catalog.BonusTip("rack"), "the explanation")
end)

test("a tagged \"Unknown item\" row: its own lines, then the bonus lines", function()
    local row = assert(rowOf(UNKNOWN), "the unknown item's row")
    row.scripts.OnEnter(row)
    eq(tooltip_lines[1], L["Unknown item"], "its own first line")
    local tip
    for i, line in ipairs(tooltip_lines) do
        if line == Catalog.BonusTip("rack") then
            tip = i
        end
    end
    assert(tip and tip > 3, "the bonus lines after its own")
    GameTooltip:Hide()
end)

test("the explanation is not doubled by the game's item hook, and comes back for another owner", function()
    local row = rowOf(BLOATED)
    row.scripts.OnEnter(row)
    run_item_post_calls(GameTooltip, BLOATED)
    assert(has(ns.ColoredText(L["Caught in:"], unpack(ns.TOOLTIP_COLOR))), "the hook ran")
    eq(count(Catalog.BonusTip("rack", true)), 1, "once")
    GameTooltip:Hide()
    local bag = CreateFrame("Button")
    GameTooltip:SetOwner(bag)
    run_item_post_calls(GameTooltip, BLOATED)
    eq(count(Catalog.BonusTip("rack", true)), 1, "a bag tooltip after the hide gets it")
    ns.ShowItemTooltip(bag, BLOATED, false)
    run_item_post_calls(GameTooltip, BLOATED)
    eq(count(Catalog.BonusTip("rack", true)), 1, "a tooltip without a bonus keeps nothing")
    ns.ShowItemTooltip(row, BLOATED, false, nil)
    run_item_post_calls(GameTooltip, BLOATED)
    eq(count(Catalog.BonusTip("rack", true)), 1, "the same owner without a bonus neither")
    GameTooltip:Hide()
end)

test("a known item without data under its bonus: the icon and \"Little data\"", function()
    player_map_id = 1416
    fire("ZONE_CHANGED_NEW_AREA")
    tick(window)
    local row = assert(rowOf(BLOATED), "the row")
    assert(row.tag:IsShown(), "the icon")
    eq(row.chance.text, L["Little data"], "little data")
    row.scripts.OnEnter(row)
    assert(has(L["Little data"]), "the tooltip's chance line")
    GameTooltip:Hide()
    player_map_id = 1415
end)

---------------------------------------------------------------------------
-- The "Camp bonus" button (FR-023, FR-024, FR-027, FR-028, research R8)
---------------------------------------------------------------------------
local function menuTexts(button)
    menu_entries = {}
    button.scripts.OnClick(button)
    local texts = {}
    for _, entry in ipairs(menu_entries) do
        table.insert(texts, entry.text)
    end
    return table.concat(texts, ";")
end

local function setSeed(cells)
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = cells }
    ns.Fire("SHARED_DATA_CHANGED")
    tick(window)
end

local SEED = ns.SeedData.cells

test("the button shows with Rack data: its title, its values, its tooltip", function()
    tick(window)
    local button = here.bonusButton
    assert(button:IsShown(), "shown")
    eq(button.text, L["Camp bonus: All"], "the title with the value in short (spec 020)")
    eq(menuTexts(button), table.concat({ L["All catches"], L["No camp bonus"], L["Bonus catches only"],
        L["Fishing Rack"] }, ";"), "no Hut without Hut data")
    button.scripts.OnEnter(button)
    eq(tooltip_lines[1], L["Camp bonus"], "the tooltip's title")
    assert(has(L["Show the catches made with a camp bonus: the fishing buff of a Fishing Rack or a Fishing Hut by a "
        .. "campfire."]), "the first line")
    assert(has(L["\"No camp bonus\" also holds older catches for which the bonus is not known."]), "the second line")
    GameTooltip:Hide()
end)

test("a choice filters the list and names itself on the button; an aura coming or going keeps it", function()
    menuTexts(here.bonusButton)
    menu_entry(L["Fishing Rack"]).onClick()
    eq(here.bonusButton.text, L["Camp bonus: Rack"], "the value's short label")
    eq(rowOf(FISH).chance.text, ns.Percent(35 / 50), "the Rack's numbers")
    auras[1280341] = { expirationTime = GetTime() + 600, duration = 3600 }
    fire("UNIT_AURA", "player")
    tick(window)
    eq(here.bonusButton.text, L["Camp bonus: Rack"], "kept when the aura comes")
    auras[1280341] = nil
    fire("UNIT_AURA", "player")
    tick(window)
    eq(here.bonusButton.text, L["Camp bonus: Rack"], "kept when it goes")
end)

test("under a bonus the skill filter and the kind choice still narrow the list (FR-028)", function()
    ns.Catalog.SetKindShown("fish", false)
    eq(rowOf(FISH), nil, "the kind hidden")
    ns.Catalog.SetKindShown("fish", true)
    ns.CatchHere.SetRange(0)
    eq(rowOf(FISH), nil, "another skill range: nothing")
    ns.CatchHere.SetRange(3)
    assert(rowOf(FISH), "back")
end)

test("the Hut appears with Hut data; a value no longer offered falls back to all catches", function()
    local cells = {}
    for key, value in pairs(SEED) do
        cells[key] = value
    end
    local hut = catch_cell(4, 0, { [FISH] = { 4, 4 } })
    hut.k, hut.q = 1, { ["2"] = { c = 2, m = 0, k = 1, i = { [FISH] = { 2, 2 } } } }
    cells["1416:3:x"] = hut
    setSeed(cells)
    assert(menuTexts(here.bonusButton):find(L["Fishing Hut"], 1, true), "the Hut offered")
    menu_entry(L["Fishing Hut"]).onClick()
    eq(here.bonusButton.text, L["Camp bonus: Hut"], "chosen")
    setSeed(SEED)
    eq(here.bonusButton.text, L["Camp bonus: All"], "back to all catches")
end)

test("\"No camp bonus\" where every catch had a buff: the tab's usual empty message", function()
    local all = catch_cell(10, 0, { [FISH] = { 10, 10 } })
    all.k, all.q = 1, { ["1"] = { c = 10, m = 0, k = 1, i = { [FISH] = { 10, 10 } } } }
    local cells = { ["1417:3:x"] = all }
    for key, value in pairs(SEED) do
        cells[key] = value
    end
    setSeed(cells)
    player_map_id = 1417
    fire("ZONE_CHANGED_NEW_AREA")
    ns.CatchHere.SetBonus("none")
    tick(window)
    eq(here.message.text, L["Nothing has been caught here yet."], "the empty message")
    ns.CatchHere.SetBonus("all")
    player_map_id = 1415
    fire("ZONE_CHANGED_NEW_AREA")
    setSeed(SEED)
end)

test("with pool and bonus data only the bonus button shows, and the query's water is all", function()
    local pooled = catch_cell(10, 0, { [FISH] = { 10, 10 } })
    pooled.k, pooled.p = 1, { c = 4, i = { [FISH] = { 4, 4 } } }
    local cells = { ["1418:3:x"] = pooled }
    for key, value in pairs(SEED) do
        cells[key] = value
    end
    setSeed(cells)
    ns.CatchHere.SetWater("pool")
    local query, asked = ns.CatchDB.Query, nil
    ns.CatchDB.Query = function(mapID, cell, filter)
        asked = filter
        return query(mapID, cell, filter)
    end
    ns.CatchHere.Refresh()
    ns.CatchDB.Query = query
    assert(here.bonusButton:IsShown(), "the bonus button")
    assert(not here.waterButton:IsShown(), "no Water button")
    eq(asked.water, "all", "the query's water")
    setSeed({ ["1418:3:x"] = pooled })
    assert(here.waterButton:IsShown(), "pool data alone: the Water button as before")
    assert(not here.bonusButton:IsShown(), "no bonus button")
    ns.CatchHere.SetWater("all")
end)

test("when the last bonus data leave, the button hides and the filter is all catches", function()
    setSeed(SEED)
    menuTexts(here.bonusButton)
    menu_entry(L["Fishing Rack"]).onClick()
    setSeed({})
    assert(not here.bonusButton:IsShown(), "hidden")
    local query, asked = ns.CatchDB.Query, nil
    ns.CatchDB.Query = function(mapID, cell, filter)
        asked = filter
        return query(mapID, cell, filter)
    end
    ns.CatchHere.Refresh()
    ns.CatchDB.Query = query
    eq(asked.bonus, "all", "all catches")
end)

---------------------------------------------------------------------------
-- Bonus catches only, and the layout (spec 020 decisions 24 to 30)
---------------------------------------------------------------------------
test("Bonus catches only: the tagged rows, the counts of all catches", function()
    setSeed(SEED)
    ns.CatchHere.SetBonus("all")
    tick(window)
    local counts = here.counts.text
    ns.CatchHere.SetBonus("bonusOnly")
    tick(window)
    eq(here.bonusButton.text, L["Camp bonus: Bonus only"], "the button")
    eq(rowOf(FISH), nil, "an ordinary fish is left out")
    assert(rowOf(BLOATED), "the Bloated fish")
    assert(rowOf(UNKNOWN), "the item tagged from the data")
    eq(here.counts.text, counts, "the numbers of all catches")
    eq(rowOf(BLOATED).chance.text, ns.Percent(10 / 50), "the chance with the bonus")
end)

test("No camp bonus: a tagged item is left out, ordinary ones stay (decision 35)", function()
    -- the place's cell with two Bloated fish outside its part: catches whose bonus is not known
    local cells = {}
    for key, value in pairs(SEED) do
        cells[key] = value
    end
    local cell = catch_cell(102, 0, { [FISH] = { 85, 85 }, [BLOATED] = { 12, 12 }, [UNKNOWN] = { 5, 5 } })
    cell.k, cell.q = 3, SEED["1415:3:47"].q
    cells["1415:3:47"] = cell
    setSeed(cells)
    ns.CatchHere.SetBonus("none")
    tick(window)
    eq(rowOf(BLOATED), nil, "the Bloated fish of catches whose bonus is not known")
    assert(rowOf(FISH), "an ordinary fish")
    eq(here.message.text or "", "", "no empty-list text: the list has rows")
    local inView = false
    for _, entry in ipairs(ns.CatchDB.Query(1415, "47", { range = "all", source = "all", water = "all",
        bonus = "none" }).items) do
        inView = inView or entry.itemID == BLOATED
    end
    assert(inView, "the view of \"none\" still holds it: only the list leaves it out")
    setSeed(SEED)
    ns.CatchHere.SetBonus("bonusOnly")
    tick(window)
end)

test("Bonus catches only where nothing tagged was caught: the empty text", function()
    local plain = catch_cell(20, 0, { [FISH] = { 20, 20 } })
    plain.k = 1
    local cells = { ["1419:3:x"] = plain }
    for key, value in pairs(SEED) do
        cells[key] = value
    end
    setSeed(cells)
    player_map_id = 1419
    fire("ZONE_CHANGED_NEW_AREA")
    tick(window)
    eq(here.message.text, L["No bonus catch has been recorded here yet."], "said so")
    eq(#list_rows(here.list), 0, "no rows")
    player_map_id = 1415
    fire("ZONE_CHANGED_NEW_AREA")
    ns.CatchHere.SetBonus("all")
    setSeed(SEED)
end)

test("the layout: the hints and the exchange line under the place, two button rows, Kinds after the slot", function()
    local function y(frame)
        return anchor(frame, "TOPLEFT")[3]
    end
    assert(y(here.hint) > y(here.counts), "the hints above the counts")
    assert(y(here.status) > y(here.counts), "the exchange line above the counts")
    assert(y(here.counts) > y(here.skillButton), "the counts above row A")
    eq(y(here.bonusButton), y(here.waterButton), "row B: one slot")
    assert(y(here.skillButton) > y(here.bonusButton), "row A above row B")
    local kinds = anchor(here.kindButton, "LEFT")
    eq(kinds[2], here.bonusButton, "Kinds after the Camp bonus button")
    eq(here.more, nil, "no 'and N more': the list scrolls")
end)
