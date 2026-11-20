-- The camp bonus tag in the catch catalog (specs/020-camp-buffs FR-019, research R19): the camp feature's icon on the
-- list rows and on the zone and spot rows, the bonus's numbers in their cells, and the tag's words in their tooltips.
-- The tests run in order and share one login.

local FISH, BLOATED, MACKEREL = 6291, 6643, 6644
local TAG = 14 -- the icon's size
item_names[FISH] = "Deviate Fish"
item_names[BLOATED] = "Bloated Brilliant Smallfish"
item_names[MACKEREL] = "Bloated Mackerel"
item_icons[279965] = 777

local function cell(c, items, k, q, x, y)
    local out = catch_cell(c, 0, items)
    out.k, out.q = k, q
    if x then
        out.px, out.py = math.floor(x * 1000 + 0.5) * c, math.floor(y * 1000 + 0.5) * c
    end
    return out
end

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:3:47"] = cell(100, { [FISH] = { 90, 90 }, [BLOATED] = { 10, 10 } }, 3,
            { ["1"] = { c = 50, m = 0, k = 3, i = { [FISH] = { 40, 40 }, [BLOATED] = { 10, 10 } } } }, 0.45, 0.72),
        -- known items without data under the Rack
        ["1416:3:x"] = cell(20, { [FISH] = { 16, 16 }, [BLOATED] = { 2, 2 }, [MACKEREL] = { 2, 2 } }, 2),
    } }
end)

local L, Catalog = ns.L, ns.Catalog
ns.StatsFrame.Toggle()
local window = _G.OneKeyFishingStatsFrame
local tab = window.catalogPage
click(L["Catch catalog"], window)
advance(0)
tick(window)

local function rows(list)
    local all = list.box and scroll_rows(list.box) or list.rows
    local shown = {}
    for _, row in ipairs(all) do
        if row:IsShown() and not row.kindHeader then
            table.insert(shown, row)
        end
    end
    return shown
end

local function listRow(itemID)
    for _, row in ipairs(rows(tab.list)) do
        if row.itemID == itemID then
            return row
        end
    end
end

-- The tag's line as drawn: its colour as a code in the text too (spec 020 decision 34).
local function tagLine(key)
    return ns.ColoredText(Catalog.BonusTag(key), unpack(ns.TOOLTIP_COLOR))
end

local function has(text)
    for _, line in ipairs(tooltip_lines) do
        if line == text then
            return true
        end
    end
    return false
end

test("a tagged list row shows the icon at the end of its name; an untagged one does not", function()
    local row = assert(listRow(BLOATED), "the Bloated fish's row")
    assert(row.tag:IsShown(), "the icon")
    eq(row.tag.texture, 777, "the Fishing Rack's icon")
    eq(row.name:GetWidth(), 350 - TAG, "the name makes room")
    local fish = assert(listRow(FISH), "the fish's row")
    assert(not fish.tag:IsShown(), "no icon")
    eq(fish.name:GetWidth(), 350, "the full width")
end)

test("hovering a tagged list row: the tag, its explanation and the chance with the bonus", function()
    local row = listRow(BLOATED)
    row.scripts.OnEnter(row)
    assert(has(tagLine("rack")), "the tag")
    assert(has(Catalog.BonusTip("rack", true)), "the explanation")
    assert(has(Catalog.ChanceText(0.2, false, 3, true)), "the chance with the bonus and its players")
    GameTooltip:Hide()
end)

test("by chance, a known item without data reads \"Little data\", not an empty cell", function()
    ns.Catalog.SetSort("chance")
    tick(window)
    eq(listRow(MACKEREL).zones.text, L["Little data"], "little data")
    ns.Catalog.SetSort("name")
    tick(window)
end)

test("zone and spot rows: the icon, the bonus's chance and catches", function()
    ns.CatalogTab.Show(BLOATED)
    local zones = rows(tab.places)
    eq(#zones, 2, "two zones")
    local zone = zones[1]
    assert(zone.tag:IsShown(), "the icon on the zone row")
    eq(zone.name:GetWidth(), 230 - TAG, "the name makes room")
    eq(zone.chance.text, ns.Percent(0.2), "the bonus chance")
    eq(zone.catches.text, "50", "the bonus catches")
    eq(zones[2].chance.text, L["Little data"], "the zone without data")
    eq(zones[2].catches.text, "0", "0 catches")
    ns.CatalogTab.Toggle(1415)
    local spot = rows(tab.places)[2]
    assert(spot.tag:IsShown(), "the icon on the spot row")
    eq(spot.chance.text, ns.Percent(0.2), "the spot's bonus chance")
end)

test("hovering a zone row: its name, the bonus's catches, then the bonus lines", function()
    local zone = rows(tab.places)[1]
    zone.scripts.OnEnter(zone)
    eq(tooltip_lines[1], ns.Catalog.ZoneName(1415), "the zone")
    eq(tooltip_lines[2], Catalog.CatchesText(50, 3), "the bonus's catches")
    eq(tooltip_lines[3], tagLine("rack"), "the tag")
    eq(tooltip_lines[4], Catalog.BonusTip("rack", true), "the explanation")
    GameTooltip:Hide()
    local other = rows(tab.places)[3]
    other.scripts.OnEnter(other)
    eq(tooltip_lines[2], (L["%d catches"]):format(0), "0 catches, no error")
    eq(#take_errors(), 0, "no error")
    GameTooltip:Hide()
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

local SEED = ns.SeedData.cells

local function setSeed(cells)
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = cells }
    ns.Fire("SHARED_DATA_CHANGED")
    advance(0)
    tick(window)
end

test("the catalog's button: shown with Rack data, its values, a choice filters the list", function()
    ns.CatalogTab.Show(nil)
    tick(window)
    local button = tab.bonusButton
    assert(button:IsShown(), "shown")
    eq(button.text, L["Camp bonus: All"], "the title with the value in short")
    assert(not tab.waterButton:IsShown(), "no Water button")
    eq(menuTexts(button), table.concat({ L["All catches"], L["No camp bonus"], L["Bonus catches only"],
        L["Fishing Rack"] }, ";"), "values")
    menu_entry(L["Fishing Rack"]).onClick()
    advance(0)
    tick(window)
    eq(button.text, L["Camp bonus: Rack"], "named")
    eq(listRow(MACKEREL), nil, "an item without catches under the Rack is not listed")
    assert(listRow(BLOATED), "the Bloated fish is")
end)

test("under a bonus the search and the order still narrow and order the list (FR-028)", function()
    type_text(tab.search, "bloated")
    advance(0)
    tick(window)
    eq(#rows(tab.list), 1, "the search narrows")
    type_text(tab.search, "")
    ns.Catalog.SetSort("chance")
    advance(0)
    tick(window)
    eq(rows(tab.list)[1].itemID, FISH, "by chance: the fish (80 %) before the Bloated fish (20 %)")
    ns.Catalog.SetSort("name")
end)

test("the catalog falls back to all catches when its bonus leaves; the button hides without bonus data", function()
    local cells = {}
    for key, value in pairs(SEED) do
        cells[key] = value
    end
    local hut = catch_cell(4, 0, { [FISH] = { 4, 4 } })
    hut.k, hut.q = 1, { ["2"] = { c = 2, m = 0, k = 1, i = { [FISH] = { 2, 2 } } } }
    cells["1417:3:x"] = hut
    setSeed(cells)
    menuTexts(tab.bonusButton)
    menu_entry(L["Fishing Hut"]).onClick()
    advance(0)
    tick(window)
    eq(tab.bonusButton.text, L["Camp bonus: Hut"], "the Hut chosen")
    setSeed(SEED)
    eq(tab.bonusButton.text, L["Camp bonus: All"], "back to all catches")
    setSeed({ ["1416:3:x"] = SEED["1416:3:x"] })
    assert(not tab.bonusButton:IsShown(), "no bonus data: hidden")
end)

test("Bonus catches only: the tagged items, all zones on an item's page, no index of its own", function()
    setSeed(SEED)
    ns.CatalogTab.Show(nil)
    ns.CatalogTab.SetBonus("bonusOnly")
    advance(0)
    tick(window)
    eq(tab.bonusButton.text, L["Camp bonus: Bonus only"], "the button")
    eq(listRow(FISH), nil, "an ordinary fish is left out")
    assert(listRow(BLOATED), "the Bloated fish")
    assert(listRow(MACKEREL), "a known item without data, as tagged")
    eq(table.concat(ns.Catalog.Describe(), "\n"):find("bonusOnly", 1, true), nil, "no index of its own")
    ns.CatalogTab.Show(FISH)
    eq(#rows(tab.places), 2, "an item's page: all its zones")
    ns.CatalogTab.Show(nil)
    ns.CatalogTab.SetBonus("all")
end)

test("Bonus catches only with bonus data but no tagged item: the catalog's empty text", function()
    -- A Rack part of ordinary fish only: bonus data, nothing tagged.
    local cell = catch_cell(10, 0, { [FISH] = { 10, 10 } })
    cell.k, cell.q = 1, { ["1"] = { c = 4, m = 0, k = 1, i = { [FISH] = { 4, 4 } } } }
    setSeed({ ["1420:3:x"] = cell })
    ns.CatalogTab.SetBonus("bonusOnly")
    advance(0)
    tick(window)
    eq(#rows(tab.list), 0, "no item")
    eq(tab.status.text, L["No bonus catch has been recorded yet."], "said so")
    ns.CatalogTab.SetBonus("all")
    setSeed(SEED)
end)
