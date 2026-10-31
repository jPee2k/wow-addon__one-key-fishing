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

local function index(lines, text)
    for i, line in ipairs(lines) do
        if line == text then
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
    eq(tooltip_lines[header + 1], "  Deviate Fish | 50%", "the item")
    eq(tooltip_lines[header + 2], "  " .. (L["%d catches from %d players"]):format(60, 2), "the footer")
    OneKeyFishing_OnAddonCompartmentEnter(nil, UIParent)
    assert(index(tooltip_lines, L["Likely catch here:"]), "the compartment entry")
    ns.Mode.IsActive = active
end)
