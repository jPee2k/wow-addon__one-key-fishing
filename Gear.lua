-- Gear: equip a fishing pole and the player's chosen fishing items, then put back only what was replaced.
--   pole:  the pole chosen in settings, otherwise the best pole in bags (by fishing bonus, then item level)
--   items: extra fishing items (hat, boots...) added in settings, stored by itemID
-- For every slot it changes, the previous item is remembered in the character DB (survives /reload and
-- crashes). On exit a slot is restored only if it still holds what the addon put there.
local _, ns = ...

local Gear = {}
ns.Gear = Gear

local FIRST_SLOT = INVSLOT_FIRST_EQUIPPED or 1
local LAST_SLOT = INVSLOT_LAST_EQUIPPED or 19
local MAINHAND_SLOT = INVSLOT_MAINHAND or 16
local OFFHAND_SLOT = INVSLOT_OFFHAND or 17
local WEAPON_SLOTS = {
    [MAINHAND_SLOT] = true,
    [OFFHAND_SLOT] = true,
    [INVSLOT_RANGED or 18] = true,
}

local FISHING_POLE_CLASS = 2 -- Enum.ItemClass.Weapon
local FISHING_POLE_SUBCLASS = 20 -- Enum.ItemWeaponSubclass.Fishingpole

-- Fallback bonuses for when the tooltip cannot be read.
local KNOWN_POLE_BONUS = {
    [6256] = 0, -- Fishing Pole
    [12225] = 3, -- Blump Family Fishing Pole
    [6365] = 5, -- Strong Fishing Pole
    [6366] = 15, -- Darkwood Fishing Pole
    [6367] = 20, -- Big Iron Fishing Pole
    [19022] = 25, -- Nat Pagle's Extreme Angler FC-5000
    [19970] = 35, -- Arcanite Fishing Pole
}

-- Slots an extra item can go to. Weapons are excluded: the pole takes both hands.
local SLOTS_BY_EQUIP_LOC = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_TABARD = { 19 },
}

local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

local function GetEquipLoc(itemID)
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
    return equipLoc
end

function ns.IsFishingPole(itemID)
    if not itemID then
        return false
    end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    return classID == FISHING_POLE_CLASS and subclassID == FISHING_POLE_SUBCLASS
end

function ns.IsFishingPoleEquipped()
    return ns.IsFishingPole(GetInventoryItemID("player", MAINHAND_SLOT))
end

---------------------------------------------------------------------------
-- Fishing bonus from the tooltip, locale independent.
-- The skill name comes from the client ("Fishing" / "Рыбная ловля"); its first letter is dropped
-- because tooltips may write it in lower case and string.lower does not handle Cyrillic.
---------------------------------------------------------------------------
local fishingNameKey
local function FishingNameKey()
    if not fishingNameKey then
        local name = C_Spell.GetSpellName(ns.FISHING_SPELL_IDS[1])
        if name then
            fishingNameKey = name:match("^[%z\1-\127\194-\244][\128-\191]*(.+)$")
        end
    end
    return fishingNameKey
end

local scanTooltip
local function TooltipLines(itemID)
    local lines = {}
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local data = C_TooltipInfo.GetItemByID(itemID)
        for _, line in ipairs(data and data.lines or {}) do
            table.insert(lines, line.leftText)
        end
        return lines
    end
    scanTooltip = scanTooltip or CreateFrame("GameTooltip", "OneKeyFishingScanTooltip", nil, "GameTooltipTemplate")
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:SetItemByID(itemID)
    for i = 1, scanTooltip:NumLines() do
        local fontString = _G["OneKeyFishingScanTooltipTextLeft" .. i]
        table.insert(lines, fontString and fontString:GetText())
    end
    return lines
end

local bonusCache = {}

function ns.GetFishingBonus(itemID)
    if bonusCache[itemID] then
        return bonusCache[itemID]
    end
    local key = FishingNameKey()
    local lines = TooltipLines(itemID)
    local bonus
    if key then
        for _, text in ipairs(lines) do
            -- Skip requirement lines such as "Requires Fishing (100)".
            if text and text:find(key, 1, true) and not text:find("%(%d+%)") then
                bonus = tonumber(text:match("%+%s*(%d+)") or text:match("(%d+)"))
                if bonus then
                    break
                end
            end
        end
    end
    bonus = bonus or KNOWN_POLE_BONUS[itemID] or 0
    -- An uncached item gives an empty or "Retrieving item information" tooltip; do not remember that result.
    local cached = not C_Item.IsItemDataCachedByID or C_Item.IsItemDataCachedByID(itemID)
    if cached and #lines > 0 then
        bonusCache[itemID] = bonus
    end
    return bonus
end

---------------------------------------------------------------------------
-- Pole choice
---------------------------------------------------------------------------
-- Best pole in bags or in hand: itemID, fishing bonus.
function Gear.FindBestPole()
    local bestID, bestScore, bestBonus
    local function Consider(itemID)
        if not ns.IsFishingPole(itemID) then
            return
        end
        local bonus = ns.GetFishingBonus(itemID)
        local _, _, _, itemLevel = C_Item.GetItemInfo(itemID)
        local score = bonus * 1000 + (itemLevel or 0)
        if not bestScore or score > bestScore then
            bestID, bestScore, bestBonus = itemID, score, bonus
        end
    end
    Consider(GetInventoryItemID("player", MAINHAND_SLOT))
    ns.ForEachBagItem(function(info)
        Consider(info.itemID)
    end)
    return bestID, bestBonus
end

-- The pole to use now: the chosen one if the player still has it, otherwise the best one.
function Gear.GetPole()
    local chosen = ns.charDB.gear.pole
    if chosen and GetItemCount(chosen) > 0 then
        return chosen
    end
    return (Gear.FindBestPole())
end

---------------------------------------------------------------------------
-- Gear list (used by the settings panel)
---------------------------------------------------------------------------
function Gear.GetItems()
    return ns.charDB.gear.items
end

function Gear.GetChosenPole()
    return ns.charDB.gear.pole
end

function Gear.ClearPole()
    ns.charDB.gear.pole = nil
    ns.Fire("GEAR_LIST_CHANGED")
end

-- Returns ok, message.
function Gear.AddItem(itemID)
    if ns.IsFishingPole(itemID) then
        ns.charDB.gear.pole = itemID
        ns.Fire("GEAR_LIST_CHANGED")
        return true, "Fishing pole set."
    end
    if not SLOTS_BY_EQUIP_LOC[GetEquipLoc(itemID) or ""] then
        return false, "This item cannot be used as fishing gear."
    end
    for _, existing in ipairs(ns.charDB.gear.items) do
        if existing == itemID then
            return false, "Already in the list."
        end
    end
    table.insert(ns.charDB.gear.items, itemID)
    ns.Fire("GEAR_LIST_CHANGED")
    return true, "Added."
end

function Gear.RemoveItem(itemID)
    local items = ns.charDB.gear.items
    for i = #items, 1, -1 do
        if items[i] == itemID then
            table.remove(items, i)
        end
    end
    ns.Fire("GEAR_LIST_CHANGED")
end

function Gear.IsFishingGear(itemID)
    if itemID == ns.charDB.gear.pole then
        return true
    end
    for _, existing in ipairs(ns.charDB.gear.items) do
        if existing == itemID then
            return true
        end
    end
    return false
end

-- Alt+Click: add the item, or remove it if it is already fishing gear. Returns ok, message.
function Gear.ToggleItem(itemID)
    if itemID == ns.charDB.gear.pole then
        Gear.ClearPole()
        return true, "Fishing pole: automatic (best in bags)."
    end
    for _, existing in ipairs(ns.charDB.gear.items) do
        if existing == itemID then
            Gear.RemoveItem(itemID)
            return true, "Removed from fishing gear."
        end
    end
    return Gear.AddItem(itemID)
end

-- Adds every non-weapon item with a fishing bonus that is worn or in the bags. Returns the number added.
function Gear.AddFishingItemsFromBags()
    local added = 0
    local function Consider(itemID)
        if itemID and not ns.IsFishingPole(itemID) and not Gear.IsFishingGear(itemID)
            and SLOTS_BY_EQUIP_LOC[GetEquipLoc(itemID) or ""] and ns.GetFishingBonus(itemID) > 0 then
            table.insert(ns.charDB.gear.items, itemID)
            added = added + 1
        end
    end
    for slot = FIRST_SLOT, LAST_SLOT do
        if not WEAPON_SLOTS[slot] then
            Consider(GetInventoryItemID("player", slot))
        end
    end
    ns.ForEachBagItem(function(info)
        Consider(info.itemID)
    end)
    if added > 0 then
        ns.Fire("GEAR_LIST_CHANGED")
    end
    return added
end

function Gear.GetSlotName(itemID)
    local equipLoc = GetEquipLoc(itemID)
    return equipLoc and _G[equipLoc] or ""
end

---------------------------------------------------------------------------
-- Equip / restore
---------------------------------------------------------------------------

-- slot -> itemID that should be worn while fishing.
local function BuildPlan()
    local plan = {}
    local pole = Gear.GetPole()
    if pole then
        plan[MAINHAND_SLOT] = pole
    end
    local missing = 0
    for _, itemID in ipairs(ns.charDB.gear.items) do
        local slots = SLOTS_BY_EQUIP_LOC[GetEquipLoc(itemID) or ""]
        if not slots or GetItemCount(itemID) == 0 then
            missing = missing + 1
        else
            local target
            -- Keep a ring or trinket in the slot it is already worn in.
            for _, slot in ipairs(slots) do
                if not plan[slot] and GetInventoryItemID("player", slot) == itemID then
                    target = slot
                    break
                end
            end
            if not target then
                for _, slot in ipairs(slots) do
                    if not plan[slot] then
                        target = slot
                        break
                    end
                end
            end
            if target then
                plan[target] = itemID
            end
        end
    end
    return plan, missing
end

function Gear.Equip()
    local plan, missing = BuildPlan()
    if not plan[MAINHAND_SLOT] then
        ns.Print("No fishing pole found in your bags.")
    end
    if missing > 0 then
        ns.Print("%d fishing item(s) are not in your bags.", missing)
    end
    local swap = ns.charDB.gearSwap or {}
    -- A restore that never landed is live again: the slot still holds the fishing item.
    for _, entry in pairs(swap) do
        entry.restoring = nil
    end
    -- Ascending order: the main hand goes on before anything that depends on it.
    for slot = FIRST_SLOT, LAST_SLOT do
        local itemID = plan[slot]
        local current = GetInventoryItemID("player", slot)
        if itemID and current ~= itemID then
            -- Keep the oldest "previous": after /reload the fishing item is what is worn now.
            swap[slot] = swap[slot] or { previous = GetInventoryItemLink("player", slot) or false }
            swap[slot].equipped = itemID
            if slot == MAINHAND_SLOT and GetEquipLoc(itemID) == "INVTYPE_2HWEAPON" then
                local offhand = GetInventoryItemLink("player", OFFHAND_SLOT)
                if offhand and not swap[OFFHAND_SLOT] then
                    -- A two-handed pole pushes the off hand into the bags.
                    swap[OFFHAND_SLOT] = { previous = offhand, equipped = false }
                end
            end
            C_Item.EquipItemByName(itemID, slot)
        end
    end
    ns.charDB.gearSwap = next(swap) and swap or nil
end

-- Moves the item in an equipment slot to the first regular bag with free space.
-- `reserved` counts slots already promised this frame: free space only updates after the move lands.
local function UnequipToBags(slot, reserved)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local free, bagType = C_Container.GetContainerNumFreeSlots(bag)
        if free - (reserved[bag] or 0) > 0 and bagType == 0 then
            reserved[bag] = (reserved[bag] or 0) + 1
            PickupInventoryItem(slot)
            if bag == 0 then
                PutItemInBackpack()
            else
                PutItemInBag(C_Container.ContainerIDToInventoryID(bag))
            end
            return true
        end
    end
    ns.Print("No free bag space to take off %s.", GetInventoryItemLink("player", slot) or "an item")
    return false
end

-- Slots waiting for the current cast to end: true (all) or a set of slots.
local deferredSlots

local function IsCasting()
    return UnitChannelInfo("player") ~= nil or UnitCastingInfo("player") ~= nil
end

-- `onlySlots` limits restoring to a subset (weapons during combat).
local function RestoreSlots(onlySlots)
    local swap = ns.charDB.gearSwap
    if not swap then
        return
    end
    -- Equipping fails while casting (e.g. leaving the mode with the bobber still out): retry after the cast.
    if IsCasting() then
        if deferredSlots ~= true then
            deferredSlots = onlySlots or true
        end
        return
    end
    local inCombat = InCombatLockdown()
    local reserved = {}
    for slot = FIRST_SLOT, LAST_SLOT do
        local entry = swap[slot]
        if entry and (not onlySlots or onlySlots[slot]) then
            local current = GetInventoryItemID("player", slot)
            local stillOurs
            if entry.equipped == false then
                stillOurs = current == nil
            else
                stillOurs = current == entry.equipped
            end
            if not stillOurs then
                -- The player put something else here while fishing: leave it alone.
                swap[slot] = nil
            elseif entry.previous then
                -- Keep the entry until the swap lands (PLAYER_EQUIPMENT_CHANGED): equipping can fail silently.
                entry.restoring = true
                C_Item.EquipItemByName(entry.previous, slot)
            elseif not current then
                swap[slot] = nil
            elseif not inCombat and UnequipToBags(slot, reserved) then
                swap[slot] = nil
            end
        end
    end
    ns.charDB.gearSwap = next(swap) and swap or nil
end

function Gear.RestoreWeapons()
    RestoreSlots(WEAPON_SLOTS)
end

function Gear.Restore()
    if not InCombatLockdown() then
        RestoreSlots(nil)
    end
end

function Gear.HasPendingRestore()
    return ns.charDB.gearSwap ~= nil
end

ns.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
    local swap = ns.charDB.gearSwap
    local entry = swap and swap[slot]
    if entry and entry.restoring and GetInventoryItemID("player", slot) ~= entry.equipped then
        swap[slot] = nil
        ns.charDB.gearSwap = next(swap) and swap or nil
    end
end)

-- Finish a restore that waited for the cast to end.
local function OnCastEnd(_, unit)
    if unit ~= "player" or not deferredSlots then
        return
    end
    local slots = deferredSlots
    deferredSlots = nil
    local function Staying()
        return ns.Mode.IsActive() and not ns.Mode.IsExiting()
    end
    if Staying() then
        return -- back in fishing mode: nothing to restore
    end
    -- The cast is still finishing on this frame; equipping right away can still fail.
    C_Timer.After(0.2, function()
        if Staying() then
            return
        end
        if InCombatLockdown() then
            RestoreSlots(WEAPON_SLOTS) -- the rest follows when the pending exit finishes after combat
        else
            RestoreSlots(slots ~= true and slots or nil)
        end
    end)
end
ns.RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", OnCastEnd)
ns.RegisterEvent("UNIT_SPELLCAST_STOP", OnCastEnd)
ns.RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", OnCastEnd)

-- Parses a link, an item ID or an item name typed by the player.
function ns.ParseItem(text)
    text = text and strtrim(text) or ""
    if text == "" then
        return nil
    end
    local itemID = tonumber(text:match("|Hitem:(%d+)") or text:match("^(%d+)$"))
    if itemID then
        return itemID
    end
    local _, link = C_Item.GetItemInfo((text:gsub("^%[(.*)%]$", "%1")))
    return link and tonumber(link:match("|Hitem:(%d+)"))
end

-- Version 0.1 stored a whole outfit; convert a leftover snapshot so the player is not stuck in it.
-- PLAYER_LOGIN: equipped items are not known yet on ADDON_LOADED.
ns.RegisterEvent("PLAYER_LOGIN", function()
    local charDB = ns.charDB
    charDB.fishingSet = nil
    if charDB.gearSnapshot then
        local swap = {}
        for slot, previous in pairs(charDB.gearSnapshot) do
            local current = GetInventoryItemID("player", slot)
            local previousID = previous and C_Item.GetItemInfoInstant(previous)
            if current ~= previousID then
                swap[slot] = { previous = previous, equipped = current or false }
            end
        end
        charDB.gearSwap = next(swap) and swap or nil
        charDB.gearSnapshot = nil
    end
end)
