-- Bags: lures to apply and fished containers (clams) to open.
local _, ns = ...
local L = ns.L

local Bags = {}
ns.Bags = Bags

-- The lures and the fished containers are game data (GameData/Lures.lua, GameData/FishedContainers.lua). The lure
-- IDs best first, by their order.
local LURE_ORDER = {}
for itemID in pairs(ns.GameData.Lures) do
    table.insert(LURE_ORDER, itemID)
end
table.sort(LURE_ORDER, function(a, b)
    return ns.GameData.Lures[a].order < ns.GameData.Lures[b].order
end)
local CONTAINER_IDS = ns.GameData.FishedContainers

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
-- itemID -> the Fishing skill when the lure failed to apply (0 when not known); cleared when fishing mode is entered,
-- or when the skill rose past that value and meets the lure's requirement (spec 012 R4).
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
        skippedLures[lastLure.itemID] = ns.Skill.Get() or 0
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

-- True when the character's Fishing skill reaches the lure's requirement, or the skill is not known yet (nothing is
-- held back on an unknown skill). Skill.lua loads later: read at runtime only.
local function SkillAllows(itemID, rank)
    -- VERIFY(V44): the game compares the base skill (GetProfessionInfo rank), not the skill with bonuses
    return rank == nil or ns.GameData.Lures[itemID].skill <= rank
end

-- The best lure that can be applied now. Lures above the Fishing skill and lures on cooldown are passed over; when
-- one on cooldown is ready the indicator is told (LURE_READY).
function Bags.FindLure()
    CheckLastLure()
    local rank, rankRead -- the Fishing skill, read once and only when a lure is in the bags
    local soonest
    for _, itemID in ipairs(LURE_ORDER) do
        local held = not skippedLures[itemID] and GetItemCount(itemID) > 0
        if held and not rankRead then
            rank, rankRead = ns.Skill.Get(), true
        end
        if held and SkillAllows(itemID, rank)
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
    for _, itemID in ipairs(LURE_ORDER) do
        local count = GetItemCount(itemID)
        if count > 0 then
            table.insert(lines, ("%d x%d, needs: %d, usable: %s, cooldown: %.0f s, skipped: %s"):format(itemID, count,
                ns.GameData.Lures[itemID].skill, tostring(not C_Item.IsUsableItem or C_Item.IsUsableItem(itemID)),
                LureCooldown(itemID), tostring(skippedLures[itemID] ~= nil)))
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

-- And once the Fishing skill reaches a requirement that it did not meet at the refusal (a lure offered while the skill
-- was not known yet). A lure refused with its requirement met was refused for another reason: it stays skipped, so it
-- is not tried again on every skill-up.
ns.RegisterEvent("SKILL_LINES_CHANGED", function()
    if not next(skippedLures) then
        return
    end
    local rank = ns.Skill.Get()
    if not rank then
        return
    end
    local cleared = false
    for itemID, skillAtRefusal in pairs(skippedLures) do
        if not SkillAllows(itemID, skillAtRefusal) and SkillAllows(itemID, rank) then
            skippedLures[itemID] = nil
            cleared = true
        end
    end
    if cleared then
        ns.Fire("LURE_READY")
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
    return CONTAINER_IDS[itemID] or ns.db.fishedItems[itemID]
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
        return CONTAINER_IDS[info.itemID] == true
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
            -- A secret source (an instance, spec 012) cannot be compared: it is neither this container nor another.
            if not ns.IsSecret(source) then
                if source == lastOpen.guid then
                    return true
                end
                knownSource = knownSource or source ~= nil
            end
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
        -- From the link, also for an item the client does not know yet.
        -- VERIFY(V27): the loot link of an item the client does not know yet carries its item ID
        local itemID = ns.ItemIDFromLink(GetLootSlotLink(i))
        if itemID then
            ns.db.fishedItems[itemID] = true
        end
    end
end)
