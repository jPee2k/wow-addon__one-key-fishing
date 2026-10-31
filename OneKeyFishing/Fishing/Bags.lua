-- Bags: lures to apply and fished containers (clams) to open.
local _, ns = ...
local L = ns.L

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

-- An open attempt counts as failed when the same stack is still unchanged this long after it
-- and no loot window came from it. Generous: the item is used on key up and the loot may lag.
local OPEN_FAIL_DELAY = 3
-- After a container's loot window closes, the emptied container leaves the bag a moment later.
local LOOT_CLOSE_SETTLE = 1

local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local GetItemCooldown = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown

-- A cooldown this short is the global cooldown, not the lure's own.
local GLOBAL_COOLDOWN = 1.5

-- A lure attempt counts as failed when the pole still has no lure this long after it
-- (longer than the lure's own cast time).
local LURE_FAIL_DELAY = 8

local skippedItems = {} -- itemID -> true for containers that failed to open (e.g. locked) this session
-- itemID -> true for lures that failed to apply (e.g. skill too low); cleared when fishing mode is entered.
local skippedLures = {}
-- itemID -> free bag slots when its loot could not be taken; skipped until more slots are free.
local skippedForSpace = {}
-- The current open attempt: { bag, slot, itemID, count, guid, time, looted, closed }.
-- `looted`: a loot window came from this container. `closed`: when that window closed.
local lastOpen
local lootOpen = false -- any loot window is open
local lastLure -- { itemID, time } of the first attempt with the current lure

function Bags.NeedsLure()
    return ns.IsFishingPoleEquipped() and not GetWeaponEnchantInfo()
end

-- The lure landed: when it wears off later, that is not a failed attempt.
ns.RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unit)
    if unit == "player" and lastLure and GetWeaponEnchantInfo() then
        lastLure = nil
    end
end)

-- Seconds until the lure's own cooldown ends; 0 when it can be used.
local function LureCooldown(itemID)
    if not GetItemCooldown then
        return 0
    end
    local start, duration = GetItemCooldown(itemID)
    if not (start and duration) or start == 0 or duration <= GLOBAL_COOLDOWN then
        return 0
    end
    return math.max(0, start + duration - GetTime())
end

local function CheckLastLure()
    if not lastLure then
        return
    end
    if GetWeaponEnchantInfo() or LureCooldown(lastLure.itemID) > 0 then
        -- It landed, or the game put it on cooldown: either way not a failure.
        lastLure = nil
    elseif GetTime() - lastLure.time >= LURE_FAIL_DELAY then
        skippedLures[lastLure.itemID] = true
        ns.Print(L["Cannot apply %s, skipping it until fishing mode is turned on again."],
            select(2, C_Item.GetItemInfo(lastLure.itemID)) or lastLure.itemID)
        lastLure = nil
    end
end

-- One pending timer that tells the indicator when the next lure comes off cooldown.
local lureTimerPending = false
local function NotifyWhenReady(seconds)
    if lureTimerPending then
        return
    end
    lureTimerPending = true
    C_Timer.After(seconds + 0.1, function()
        lureTimerPending = false
        ns.Fire("LURE_READY")
    end)
end

-- The best lure that can be applied now. Lures on cooldown are passed over; when one of them is ready the
-- indicator is told (LURE_READY).
function Bags.FindLure()
    CheckLastLure()
    local soonest
    for _, itemID in ipairs(LURES) do
        if not skippedLures[itemID] and GetItemCount(itemID) > 0
            and (not C_Item.IsUsableItem or C_Item.IsUsableItem(itemID)) then
            local cooldown = LureCooldown(itemID)
            if cooldown == 0 then
                return itemID
            end
            soonest = math.min(soonest or cooldown, cooldown)
        end
    end
    if soonest then
        NotifyWhenReady(soonest)
    end
end

-- One line per lure in the bags, for the debug report.
function Bags.DescribeLures()
    local lines = {}
    for _, itemID in ipairs(LURES) do
        local count = GetItemCount(itemID)
        if count > 0 then
            table.insert(lines, ("%d x%d, usable: %s, cooldown: %.0f s, skipped: %s"):format(itemID, count,
                tostring(not C_Item.IsUsableItem or C_Item.IsUsableItem(itemID)), LureCooldown(itemID),
                tostring(skippedLures[itemID] == true)))
        end
    end
    if lastLure then
        table.insert(lines, ("pending attempt: %d, %.0f s ago"):format(lastLure.itemID, GetTime() - lastLure.time))
    end
    return lines
end

-- A lure skipped by mistake gets another chance with every new fishing mode session.
ns.On("MODE_CHANGED", function(isActive)
    if isActive then
        wipe(skippedLures)
    end
end)

-- Repeated presses with the same lure keep the first attempt's time, like NoteOpenAttempt.
function Bags.NoteLureAttempt(itemID)
    if not (lastLure and lastLure.itemID == itemID) then
        lastLure = { itemID = itemID, time = GetTime() }
    end
end

local function FreeBagSlots()
    local free = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local count, bagType = C_Container.GetContainerNumFreeSlots(bag)
        if bagType == 0 then
            free = free + count
        end
    end
    return free
end

-- Called only while no loot window is open.
local function CheckLastOpen()
    if not lastOpen then
        return
    end
    local info = C_Container.GetContainerItemInfo(lastOpen.bag, lastOpen.slot)
    if not (info and info.itemID == lastOpen.itemID and info.stackCount == lastOpen.count) then
        lastOpen = nil -- opened and emptied
        return
    end
    local now = GetTime()
    if lastOpen.looted then
        -- Its loot window was closed with loot left in it (full bags): wait until bag space frees up.
        if lastOpen.closed and now - lastOpen.closed >= LOOT_CLOSE_SETTLE then
            skippedForSpace[info.itemID] = FreeBagSlots()
            ns.Print(L["Not enough bag space to loot %s. It will be opened again when you free a bag slot."],
                info.hyperlink or info.itemID)
            lastOpen = nil
        end
    elseif now - lastOpen.time >= OPEN_FAIL_DELAY then
        skippedItems[info.itemID] = true
        ns.Print(L["Cannot open %s, skipping it for this session."], info.hyperlink or info.itemID)
        lastOpen = nil
    end
end

local function IsFishedContainer(itemID)
    return CONTAINERS[itemID] or ns.db.fishedItems[itemID]
end

local function IsOpenable(info)
    if skippedItems[info.itemID] or info.isLocked or not IsFishedContainer(info.itemID) then
        return false
    end
    if skippedForSpace[info.itemID] then
        if FreeBagSlots() <= skippedForSpace[info.itemID] then
            return false
        end
        skippedForSpace[info.itemID] = nil
    end
    -- hasLoot marks right-click-to-open items; fall back to the known list if the field is missing.
    if info.hasLoot == nil then
        return CONTAINERS[info.itemID] == true
    end
    return info.hasLoot
end

-- Returns bag, slot of the first container to open, or nil.
-- Nothing is opened over an open loot window: that would replace the loot being taken.
function Bags.FindContainer()
    if lootOpen then
        return nil
    end
    CheckLastOpen()
    return ns.ForEachBagItem(IsOpenable)
end

function Bags.NoteOpenAttempt(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then
        return
    end
    -- Keep the first attempt's time: repeated presses (and PreClick runs on both key down and up)
    -- on the same unchanged stack must not keep postponing the failure check.
    if lastOpen and lastOpen.bag == bag and lastOpen.slot == slot and lastOpen.itemID == info.itemID
        and lastOpen.count == info.stackCount then
        return
    end
    local guid
    if C_Item.GetItemGUID and ItemLocation then
        guid = C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot))
    end
    lastOpen = { bag = bag, slot = slot, itemID = info.itemID, count = info.stackCount, guid = guid,
        time = GetTime() }
end

-- Whether the loot window that just opened comes from the container of the current attempt.
local function IsFromLastOpen()
    local knownSource = false
    if lastOpen.guid and GetLootSourceInfo then
        for i = 1, GetNumLootItems() do
            local source = GetLootSourceInfo(i)
            if source == lastOpen.guid then
                return true
            end
            knownSource = knownSource or source ~= nil
        end
    end
    if knownSource then
        return false -- a corpse, a herb or another container
    end
    -- No source GUIDs: assume loot right after the attempt is its loot.
    return GetTime() - lastOpen.time < OPEN_FAIL_DELAY
end

-- One line per item in the bags that was caught while fishing or is a known container (for /okf debug).
function Bags.Describe()
    local lines = {}
    ns.ForEachBagItem(function(info, bag, slot)
        if IsFishedContainer(info.itemID) then
            table.insert(lines, ("%d/%d %s x%d: hasLoot %s, isLocked %s, skipped %s, waiting for space %s"):format(
                bag, slot, info.hyperlink or info.itemID, info.stackCount, tostring(info.hasLoot),
                tostring(info.isLocked), tostring(skippedItems[info.itemID] == true),
                tostring(skippedForSpace[info.itemID] ~= nil)))
        end
    end)
    return lines
end

ns.RegisterEvent("LOOT_CLOSED", function()
    lootOpen = false
    if lastOpen and lastOpen.looted then
        lastOpen.closed = GetTime()
    end
end)

ns.RegisterEvent("PLAYER_ENTERING_WORLD", function()
    lootOpen = false
end)

-- Remember everything caught, so new Forever containers are picked up without updating the list.
ns.RegisterEvent("LOOT_READY", function()
    lootOpen = true
    if not IsFishingLoot() then
        if lastOpen and IsFromLastOpen() then
            lastOpen.looted, lastOpen.closed = true, nil
        end
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
