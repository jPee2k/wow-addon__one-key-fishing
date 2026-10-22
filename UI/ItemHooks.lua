-- ItemHooks: Alt+Click an item (bags, character panel) to add it to or remove it from the fishing gear,
-- and a line in item tooltips showing its fishing gear status.
local _, ns = ...

local function ItemIDFromLink(link)
    return type(link) == "string" and tonumber(link:match("|Hitem:(%d+)"))
end

local function IsOnlyAltDown()
    return IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown()
end

-- Bag and character panel buttons pass every modified click through HandleModifiedItemClick.
local function OnModifiedItemClick(link)
    if not IsOnlyAltDown() then
        return
    end
    local itemID = ItemIDFromLink(link)
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

local function OnItemTooltip(tooltip, data)
    if tooltip ~= GameTooltip or not data or not data.id or not ns.charDB then
        return
    end
    local itemID = data.id
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
    if not equipLoc or equipLoc == "" then
        return
    end
    if ns.Gear.IsFishingGear(itemID) then
        tooltip:AddLine("OneKeyFishing: fishing gear (Alt+Click to remove)", unpack(TOOLTIP_COLOR))
    elseif ns.IsFishingPole(itemID) or ns.GetFishingBonus(itemID) > 0 then
        tooltip:AddLine("OneKeyFishing: Alt+Click to add to fishing gear", unpack(TOOLTIP_COLOR))
    end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
end
