-- ItemHooks: Alt+Click an item (bags, character panel) to add it to or remove it from the fishing gear,
-- a line in item tooltips showing its fishing gear status, and the zones an item is caught in (Catalog.lua).
local _, ns = ...
local L = ns.L

local function IsOnlyAltDown()
    return IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown()
end

-- Bag and character panel buttons pass every modified click through HandleModifiedItemClick.
local function OnModifiedItemClick(link)
    if not IsOnlyAltDown() then
        return
    end
    local itemID = ns.ItemIDFromLink(link)
    if not itemID then
        return
    end
    local ok, message = ns.Gear.ToggleItem(itemID)
    ns.Print("%s %s", link, ok and message or ("|cffff5555" .. message .. "|r"))
end

if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", OnModifiedItemClick)
end

-- The addon's lines carry their colour as a code in the text too (ns.AddColoredLine, UI/Widgets.lua): another addon or
-- the game may reset the tooltip's line colours (spec 020 decision 34).
local function AddColored(tooltip, text)
    local r, g, b = unpack(ns.TOOLTIP_COLOR)
    ns.AddColoredLine(tooltip, text, r, g, b)
end

-- "Caught in:" and up to three zones with the item's chance (specs/005-catch-catalog, FR-017), any item. A tagged
-- item (spec 020) gets the tag's explanation after them, unless the addon's own row tooltip already holds it.
local function AddCatchLines(tooltip, itemID)
    if not ns.db.settings.tooltipChances then
        return
    end
    local lines, bonus = ns.Catalog.TooltipLines(itemID)
    if not lines then
        return
    end
    AddColored(tooltip, L["Caught in:"])
    for _, line in ipairs(lines) do
        tooltip:AddDoubleLine("  " .. line.zone, line.right, 1, 1, 1, 1, 1, 1)
    end
    if bonus and not ns.TooltipHasBonus(tooltip, itemID) then
        tooltip:AddLine(ns.Catalog.BonusTip(bonus.key, bonus.several), 1, 1, 1, true)
    end
end

-- The item post call fires for bags, the auction house, chat links and the addon's rows (V38, seen in game)
local function OnItemTooltip(tooltip, data)
    if (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) or not data or not data.id or not ns.charDB then
        return
    end
    local itemID = data.id
    AddCatchLines(tooltip, itemID)
    if tooltip ~= GameTooltip then
        return
    end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
    if not equipLoc or equipLoc == "" then
        return
    end
    if ns.Gear.IsFishingGear(itemID) then
        AddColored(tooltip, L["OneKeyFishing: fishing gear (Alt+Click to remove)"])
    elseif ns.IsFishingPole(itemID) or ns.GetFishingBonus(itemID) > 0 then
        AddColored(tooltip, L["OneKeyFishing: Alt+Click to add to fishing gear"])
    end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
end
