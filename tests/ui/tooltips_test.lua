-- UI/ItemHooks.lua and UI/Minimap.lua: the catch chances in tooltips (specs/005-catch-catalog, US3, FR-017/018).

local FISH = 6291
item_names[FISH] = "Deviate Fish"

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    local cell = catch_cell(60, 0, { [FISH] = { 30, 30 } })
    cell.k = 2
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = { ["1415:3:47"] = cell } }
end)
advance(10) -- the default index

local L = ns.L

-- A line as the player reads it: the minimap tooltip wraps its lines in colour codes (spec 012 R5).
local function plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function index(lines, text)
    for i, line in ipairs(lines) do
        if plain(line) == text then
            return i
        end
    end
end

test("an item tooltip gets Caught in and its zones; a chat link's tooltip too", function()
    show_item_tooltip(GameTooltip, FISH)
    local header = index(tooltip_lines, L["Caught in:"])
    assert(header, "the header")
    eq(tooltip_lines[header + 1], "  Test Zone | " .. (L["%s (%d players)"]):format("50%", 2), "the zone line")
    show_item_tooltip(ItemRefTooltip, FISH)
    assert(index(itemref_lines, L["Caught in:"]), "chat links")
end)

test("the catch lines come before the fishing gear line", function()
    local gear = ns.Gear.IsFishingGear
    ns.Gear.IsFishingGear = function() return true end
    local instant = C_Item.GetItemInfoInstant
    C_Item.GetItemInfoInstant = function(item) return item, nil, nil, "INVTYPE_HEAD" end
    show_item_tooltip(GameTooltip, FISH)
    C_Item.GetItemInfoInstant, ns.Gear.IsFishingGear = instant, gear
    local header = index(tooltip_lines, L["Caught in:"])
    local gearLine = index(tooltip_lines, L["OneKeyFishing: fishing gear (Alt+Click to remove)"])
    assert(header and gearLine and header < gearLine, "Caught in first")
end)

test("no lines for an item without data or with the setting off", function()
    show_item_tooltip(GameTooltip, 424242)
    eq(index(tooltip_lines, L["Caught in:"]), nil, "no data")
    ns.db.settings.tooltipChances = false
    show_item_tooltip(GameTooltip, FISH)
    eq(index(tooltip_lines, L["Caught in:"]), nil, "setting off")
    ns.db.settings.tooltipChances = true
end)

test("the minimap button and the compartment entry show the likely catch in fishing mode only", function()
    local button = _G.OneKeyFishingMinimapButton
    button.scripts.OnEnter(button)
    eq(index(tooltip_lines, L["Likely catch here:"]), nil, "not fishing")
    local active = ns.Mode.IsActive
    ns.Mode.IsActive = function() return true end
    button.scripts.OnEnter(button)
    local header = index(tooltip_lines, L["Likely catch here:"])
    assert(header, "fishing")
    eq(plain(tooltip_lines[header + 1]), "  Deviate Fish | 50%", "the item")
    eq(plain(tooltip_lines[header + 2]), "  " .. (L["%d catches from %d players"]):format(60, 2), "the footer")
    OneKeyFishing_OnAddonCompartmentEnter(nil, UIParent)
    assert(index(tooltip_lines, L["Likely catch here:"]), "the compartment entry")
    ns.Mode.IsActive = active
end)

-- The addon's own auction price line of its row tooltips (ns.ShowItemTooltip, UI/Widgets.lua), with Auctionator as
-- the price source (specs/019-auctionator-prices, FR-014). The stub is set after load_addon().
local OWN_ONLY, FEW_LOTS = 6303, 6522

local function own_line()
    for _, line in ipairs(tooltip_lines) do
        if line:find("OneKeyFishing", 1, true) then
            return line
        end
    end
end

test("a row tooltip shows the addon's price line without Auctionator", function()
    ns.db.prices[FISH] = { price = 300, quantity = 20, lots = 5, time = 1 }
    ns.ShowItemTooltip(UIParent, FISH, true)
    eq(own_line(), (L["Auction price (OneKeyFishing): %s"]):format(ns.FormatMoney(300)), "the own price")
end)

test("with Auctionator's price for the item the addon adds no price line; the fallback keeps its line", function()
    Auctionator = { API = { v1 = {
        GetAuctionPriceByItemID = function(_, itemID) return itemID == FISH and 500 or nil end,
        RegisterForDBUpdate = function() end,
    } } }
    ns.ShowItemTooltip(UIParent, FISH, true)
    eq(own_line(), nil, "Auctionator shows its own line")
    ns.db.prices[OWN_ONLY] = { price = 200, quantity = 20, lots = 5, time = 1 }
    ns.ShowItemTooltip(UIParent, OWN_ONLY, true)
    eq(own_line(), (L["Auction price (OneKeyFishing): %s"]):format(ns.FormatMoney(200)), "the fallback price")
    ns.db.prices[FEW_LOTS] = { price = 900, quantity = 2, lots = 1, time = 1 }
    ns.ShowItemTooltip(UIParent, FEW_LOTS, true)
    local fewLots = (L["Auction price (OneKeyFishing): %s (few lots)"]):format(ns.FormatMoney(900))
    eq(own_line(), ns.ColoredText(fewLots, 0.6, 0.6, 0.6), "with its mark, its grey as a code too")
    ns.Prices.SetAuctionator(false)
    ns.ShowItemTooltip(UIParent, FISH, true)
    eq(own_line(), (L["Auction price (OneKeyFishing): %s"]):format(ns.FormatMoney(300)), "the switch off: as before")
    ns.Prices.SetAuctionator(true)
end)

-- The camp bonus tag's explanation under "Caught in:" (specs/020-camp-buffs FR-019): a tagged item's tooltip outside
-- the addon's rows gets one more line; an untagged item none; with the chances in tooltips off neither.
test("a tagged item's tooltip has the tag's explanation under Caught in:", function()
    local BLOATED = 6643
    local tagged = catch_cell(20, 0, { [FISH] = { 18, 18 }, [BLOATED] = { 2, 2 } })
    tagged.k = 2
    local seed = { epoch = 1, absorbed = {}, resets = {}, cells = {} }
    for key, value in pairs(ns.SeedData.cells) do
        seed.cells[key] = value
    end
    seed.cells["1416:3:x"] = tagged
    ns.SeedData = seed
    ns.Fire("SHARED_DATA_CHANGED")
    local tip = ns.Catalog.BonusTip("rack", true) -- a Bloated fish: the Rack or the Hut
    show_item_tooltip(GameTooltip, BLOATED)
    local header = index(tooltip_lines, L["Caught in:"])
    local line = index(tooltip_lines, tip)
    assert(header and line and line > header, "the explanation after Caught in:")
    show_item_tooltip(GameTooltip, FISH)
    eq(index(tooltip_lines, tip), nil, "an untagged item")
    ns.db.settings.tooltipChances = false
    show_item_tooltip(GameTooltip, BLOATED)
    eq(index(tooltip_lines, tip), nil, "setting off")
    ns.db.settings.tooltipChances = true
end)
