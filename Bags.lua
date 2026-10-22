-- Bags: lures to apply and fished containers (clams) to open.
local _, ns = ...

local Bags = {}
ns.Bags = Bags

-- Best first. IDs are from the original game; Forever may add more.
local LURES = {
    6533, -- Aquadynamic Fish Attractor (+100)
    7307, -- Flesh Eating Worm (+75)
    6532, -- Bright Baubles (+75)
    6811, -- Aquadynamic Fish Lens (+50)
    6530, -- Nightcrawlers (+50)
    6529, -- Shiny Bauble (+25)
}

-- Known fished containers. Anything else with loot that was caught while fishing is opened too.
local CONTAINERS = {
    [5523] = true, -- Small Barnacled Clam
    [5524] = true, -- Thick-shelled Clam
    [7973] = true, -- Big-mouth Clam
    [15874] = true, -- Soft-shelled Clam
}

-- An open attempt counts as failed when the same stack is still unchanged this long after it.
local OPEN_FAIL_DELAY = 1.5

local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

local skippedItems = {} -- itemID -> true for containers that failed to open (e.g. locked) this session
local lastOpen

function Bags.NeedsLure()
    return ns.IsFishingPoleEquipped() and not GetWeaponEnchantInfo()
end

function Bags.FindLure()
    for _, itemID in ipairs(LURES) do
        if GetItemCount(itemID) > 0 and (not C_Item.IsUsableItem or C_Item.IsUsableItem(itemID)) then
            return itemID
        end
    end
end

local function CheckLastOpen()
    if not lastOpen or GetTime() - lastOpen.time < OPEN_FAIL_DELAY then
        return
    end
    local info = C_Container.GetContainerItemInfo(lastOpen.bag, lastOpen.slot)
    if info and info.itemID == lastOpen.itemID and info.stackCount == lastOpen.count then
        skippedItems[info.itemID] = true
        ns.Print("Cannot open %s, skipping it for this session.", info.hyperlink or info.itemID)
    end
    lastOpen = nil
end

local function IsOpenable(info)
    if skippedItems[info.itemID] or info.isLocked then
        return false
    end
    if not (CONTAINERS[info.itemID] or ns.db.fishedItems[info.itemID]) then
        return false
    end
    -- hasLoot marks right-click-to-open items; fall back to the known list if the field is missing.
    if info.hasLoot == nil then
        return CONTAINERS[info.itemID] == true
    end
    return info.hasLoot
end

-- Returns bag, slot of the first container to open, or nil.
function Bags.FindContainer()
    CheckLastOpen()
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and IsOpenable(info) then
                return bag, slot
            end
        end
    end
end

function Bags.NoteOpenAttempt(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then
        lastOpen = { bag = bag, slot = slot, itemID = info.itemID, count = info.stackCount, time = GetTime() }
    end
end

-- Remember everything caught, so new Forever containers are picked up without updating the list.
ns.RegisterEvent("LOOT_READY", function()
    if not IsFishingLoot() then
        return
    end
    for i = 1, GetNumLootItems() do
        local link = GetLootSlotLink(i)
        local itemID = link and C_Item.GetItemInfoInstant(link)
        if itemID then
            ns.db.fishedItems[itemID] = true
        end
    end
end)
