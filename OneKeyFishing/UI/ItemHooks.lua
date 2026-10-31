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

local TOOLTIP_COLOR = { 0.2, 0.8, 1 }

-- "Caught in:" and up to three zones with the item's chance (specs/005-catch-catalog, FR-017), any item.
local function AddCatchLines(tooltip, itemID)
    if not ns.db.settings.tooltipChances then
        return
    end
    local lines = ns.Catalog.TooltipLines(itemID)
    if not lines then
        return
    end
    tooltip:AddLine(L["Caught in:"], unpack(TOOLTIP_COLOR))
    for _, line in ipairs(lines) do
        tooltip:AddDoubleLine("  " .. line.zone, line.right, 1, 1, 1, 1, 1, 1)
    end
end

-- VERIFY(V38): the item post call fires for bags, the auction house, chat links and the addon's rows
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
        tooltip:AddLine(L["OneKeyFishing: fishing gear (Alt+Click to remove)"], unpack(TOOLTIP_COLOR))
    elseif ns.IsFishingPole(itemID) or ns.GetFishingBonus(itemID) > 0 then
        tooltip:AddLine(L["OneKeyFishing: Alt+Click to add to fishing gear"], unpack(TOOLTIP_COLOR))
    end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
end
