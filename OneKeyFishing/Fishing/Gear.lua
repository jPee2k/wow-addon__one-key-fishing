-- Gear: equip a fishing pole and the player's chosen fishing items, then put back only what was replaced.
--   pole:  the pole chosen in settings, otherwise the best pole in bags (by fishing bonus, then item level)
--   items: extra fishing items (hat, boots...) added in settings, stored by itemID
-- For every slot it changes, the previous item is remembered in the character DB (survives /reload and
-- crashes). On exit a slot is restored only if it still holds what the addon put there.
local _, ns = ...
local L = ns.L

local Gear = {}
ns.Gear = Gear

-- The slots, the equip locations and the pole's item class are game data (GameData/EquipSlots.lua,
-- GameData/FishingPoles.lua).
local EQUIP_SLOTS = ns.GameData.EquipSlots
local FIRST_SLOT, LAST_SLOT = EQUIP_SLOTS.first, EQUIP_SLOTS.last
local MAINHAND_SLOT, OFFHAND_SLOT = EQUIP_SLOTS.mainHand, EQUIP_SLOTS.offHand
local WEAPON_SLOTS = {
    [EQUIP_SLOTS.mainHand] = true,
    [EQUIP_SLOTS.offHand] = true,
    [EQUIP_SLOTS.ranged] = true,
}
-- Slots an extra item can go to, by its equip location. Weapons are left out: the pole takes both hands.
local BY_EQUIP_LOC = EQUIP_SLOTS.byEquipLoc
local POLE_CLASS = ns.GameData.FishingPoleClass

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
    return classID == POLE_CLASS.classID and subclassID == POLE_CLASS.subclassID
end

function ns.IsFishingPoleEquipped()
    return ns.IsFishingPole(GetInventoryItemID("player", MAINHAND_SLOT))
end

---------------------------------------------------------------------------
-- Fishing bonus from the tooltip, locale independent.
-- The skill name comes from the client in its own language; its first letter is dropped because
-- tooltips may write it in lower case and string.lower only handles ASCII letters.
---------------------------------------------------------------------------
local fishingNameKey
local function FishingNameKey()
    if not fishingNameKey then
        local name = C_Spell.GetSpellName(ns.GameData.FishingSpells[1].spellID)
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
    local pole = ns.GameData.FishingPoles[itemID]
    bonus = bonus or (pole and pole.bonus) or 0
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
    -- A pole above the Fishing skill cannot be equipped: passed over; an unknown skill, or a pole the addon does not
    -- list, holds nothing back.
    -- Assumed (V44, accepted): the game compares the base skill (GetProfessionInfo rank), as for lures
    local rank = ns.Skill.Get()
    local function Consider(itemID, equipped)
        if not ns.IsFishingPole(itemID) then
            return
        end
        local pole = ns.GameData.FishingPoles[itemID]
        if not equipped and rank and pole and pole.skill > rank then
            return -- a pole in the main hand is usable already
        end
        local bonus = ns.GetFishingBonus(itemID)
        local _, _, _, itemLevel = C_Item.GetItemInfo(itemID)
        local score = bonus * 1000 + (itemLevel or 0)
        if not bestScore or score > bestScore then
            bestID, bestScore, bestBonus = itemID, score, bonus
        end
    end
    Consider(GetInventoryItemID("player", MAINHAND_SLOT), true)
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
-- True when the item is in the list of extra fishing gear.
local function HasItem(itemID)
    for _, existing in ipairs(ns.charDB.gear.items) do
        if existing == itemID then
            return true
        end
    end
    return false
end

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
        return true, L["Fishing pole set."]
    end
    if not BY_EQUIP_LOC[GetEquipLoc(itemID) or ""] then
        return false, L["This item cannot be used as fishing gear."]
    end
    if HasItem(itemID) then
        return false, L["Already in the list."]
    end
    table.insert(ns.charDB.gear.items, itemID)
    ns.Fire("GEAR_LIST_CHANGED")
    return true, L["Added."]
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
    return itemID == ns.charDB.gear.pole or HasItem(itemID)
end

-- Alt+Click: add the item, or remove it if it is already fishing gear. Returns ok, message.
function Gear.ToggleItem(itemID)
    if itemID == ns.charDB.gear.pole then
        Gear.ClearPole()
        return true, L["Fishing pole: automatic (best in bags)."]
    end
    if HasItem(itemID) then
        Gear.RemoveItem(itemID)
        return true, L["Removed from fishing gear."]
    end
    return Gear.AddItem(itemID)
end

-- Adds every non-weapon item with a fishing bonus that is worn or in the bags. Returns the number added.
function Gear.AddFishingItemsFromBags()
    local added = 0
    local function Consider(itemID)
        if itemID and not ns.IsFishingPole(itemID) and not Gear.IsFishingGear(itemID)
            and BY_EQUIP_LOC[GetEquipLoc(itemID) or ""] and ns.GetFishingBonus(itemID) > 0 then
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
-- Swaps on their way to the server (specs/030-gear-in-flight)
---------------------------------------------------------------------------
-- The server answers a swap 150 to 250 ms after the call, and until then the slot still shows the old item (seen in
-- game on 2026-11-27): a restore judged in that window took the old weapon for the player's own choice and forgot
-- the records, leaving the pole in hand and the weapons in the bags. A slot the addon asked to change waits for its
-- PLAYER_EQUIPMENT_CHANGED, or SWAP_WAIT seconds when the game refused the swap (no event then). While one waits,
-- Equip and the restore neither judge nor change a slot; the last one asked for runs after the answers.
local SWAP_WAIT = 5
local waiting = {} -- slot -> GetTime() at which its wait ends
local queued -- nil, { kind = "equip" } or { kind = "restore", slots = nil (all) or a set of slots }
local runScheduled = false
local RestoreSlots, RunQueued -- defined below

-- True while a slot of `slots` (a set; nil: any slot) waits for the game's answer; a wait past its time (a refused
-- swap) ends here. A restore of the weapons waits only for the weapons: a hat the game refused must not keep them in
-- the bags as a fight starts.
local function IsWaiting(slots)
    local now = GetTime()
    local any = false
    for slot, untilTime in pairs(waiting) do
        if untilTime <= now then
            waiting[slot] = nil
        elseif not slots or slots[slot] then
            any = true
        end
    end
    return any
end

-- The slots the queued action judges: a restore its own, an equip every slot.
local function QueuedScope()
    return queued and queued.kind == "restore" and queued.slots or nil
end

-- Runs the queued action on the next frame once none of its slots waits: the answers for the main hand and the off
-- hand come in one frame, and the off hand's must land before anything is judged.
local function Settle()
    if queued and not runScheduled and not IsWaiting(QueuedScope()) then
        runScheduled = true
        C_Timer.After(0, RunQueued)
    end
end

local function Wait(slot)
    waiting[slot] = GetTime() + SWAP_WAIT
    -- A little past the wait's end: a timer that fires a hair before it would find the slot still waiting, and no
    -- other timer would run the queued action.
    C_Timer.After(SWAP_WAIT + 0.1, Settle)
end

local function Ask(item, slot)
    Wait(slot)
    C_Item.EquipItemByName(item, slot)
end

-- The last action asked for wins, except that a restore of the weapons keeps a full restore full: a fight that starts
-- while the exit's restore waits must not shrink it to the weapons.
local function Queue(kind, slots)
    if kind == "restore" and slots and queued and queued.kind == "restore" and not queued.slots then
        return
    end
    queued = { kind = kind, slots = slots }
end

-- Fishing mode on and not leaving: the gear it wants is the fishing gear.
local function Staying()
    return ns.Mode.IsActive() and not ns.Mode.IsExiting()
end

local function IsCasting()
    return UnitChannelInfo("player") ~= nil or UnitCastingInfo("player") ~= nil
end

RunQueued = function()
    runScheduled = false
    if not queued or IsWaiting(QueuedScope()) then
        return
    end
    -- Equipping is protected in the lockdown: a queued equip stays queued until the fight ends (PLAYER_REGEN_ENABLED
    -- below). A queued restore runs, and RestoreSlots keeps it for the fight's end. Equipping also fails silently
    -- while casting (a fishing key pressed before the answers): the equip stays queued until the cast ends (OnCastEnd).
    if queued.kind == "equip" and (InCombatLockdown() or IsCasting()) then
        return
    end
    local action = queued
    queued = nil
    if action.kind == "equip" then
        if Staying() and ns.db.settings.gear then
            -- The room check of Mode.Enter read the slots before this wait (and maybe a fight) ended: ask again. The
            -- mode stays on (only a key press ends it), without the pole, and says why.
            local room, offhand = Gear.HasRoomForPole()
            if room then
                Gear.Equip()
            else
                ns.Print(L["Fishing mode needs a free bag slot for %s."], offhand or L["an item"])
            end
        end
    elseif not Staying() then
        RestoreSlots(action.slots)
    end
end

-- For /okf debug: the waiting slots (sorted) and the queued action.
function Gear.DebugState()
    IsWaiting()
    local slots = {}
    for slot in pairs(waiting) do
        table.insert(slots, slot)
    end
    table.sort(slots)
    local action
    if queued then
        action = queued.kind == "equip" and "equip" or (queued.slots and "restore weapons" or "restore all")
    end
    return slots, action
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
        local slots = BY_EQUIP_LOC[GetEquipLoc(itemID) or ""]
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
    -- A swap still on its way (a quick enter after an exit): the slots would show the old items. Equipping also
    -- fails silently while casting (an entry during a mount's cast): the equip waits for the cast's end (OnCastEnd).
    if IsWaiting() or IsCasting() then
        Queue("equip")
        return
    end
    queued = nil
    local plan, missing = BuildPlan()
    if not plan[MAINHAND_SLOT] then
        ns.Print(L["No fishing pole found in your bags."])
    end
    if missing > 0 then
        ns.Print(L["%d fishing item(s) are not in your bags."], missing)
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
                if offhand then
                    Wait(OFFHAND_SLOT) -- the game empties it in the same answer
                end
            end
            Ask(itemID, slot)
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
            -- Before the move, as in Ask: an entry right after must not see the item still in the slot.
            Wait(slot)
            PickupInventoryItem(slot)
            if bag == 0 then
                PutItemInBackpack()
            else
                PutItemInBag(C_Container.ContainerIDToInventoryID(bag))
            end
            return true
        end
    end
    ns.Print(L["No free bag space to take off %s."], GetInventoryItemLink("player", slot) or L["an item"])
    return false
end

-- Slots waiting for the current cast to end: true (all) or a set of slots.
local deferredSlots
-- A restore the combat lockdown refused: it is done when the fight ends. Only that one: gear owed for another reason
-- (full bags, an item gone) waits for the next exit or login, not for every fight (spec 009 review).
local restoreAfterCombat = false

-- `onlySlots` limits restoring to a subset (the weapons as a fight starts).
function RestoreSlots(onlySlots)
    local swap = ns.charDB.gearSwap
    -- Equipping is protected in combat, weapons too (constitution III): in the lockdown nothing is equipped, and the
    -- whole restore waits for the fight's end. Only the moment the fight starts (PLAYER_REGEN_DISABLED) comes before
    -- the lockdown.
    if InCombatLockdown() then
        restoreAfterCombat = restoreAfterCombat or swap ~= nil
        return
    end
    -- A full restore settles the wait, also when nothing is left to restore.
    if not onlySlots then
        restoreAfterCombat = false
    end
    -- Leaving cancels a put-on still waiting for the answers (spec 030 FR-004), also with nothing recorded to put back.
    if queued and queued.kind == "equip" then
        queued = nil
    end
    if not swap then
        return
    end
    -- A swap still on its way (a quick exit after an entry): the slots would show the old items, and the records
    -- would be dropped as "not ours" (spec 030, B1). The restore runs after the answers of its own slots.
    if IsWaiting(onlySlots) then
        Queue("restore", onlySlots)
        return
    end
    -- This run replaces a queued action, unless that one is a full restore and this one only the weapons.
    if not (queued and queued.kind == "restore" and not queued.slots and onlySlots) then
        queued = nil
    end
    -- Equipping fails while casting (e.g. leaving the mode with the bobber still out): retry after the cast.
    if IsCasting() then
        if deferredSlots ~= true then
            deferredSlots = onlySlots or true
        end
        return
    end
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
                Ask(entry.previous, slot)
            elseif not current then
                swap[slot] = nil
            elseif UnequipToBags(slot, reserved) then
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
    RestoreSlots(nil)
end

function Gear.HasPendingRestore()
    return ns.charDB.gearSwap ~= nil
end

-- False (and the off-hand item's link) when the gear swap cannot work: the two-handed pole to equip would push the
-- off-hand item into bags with no free regular slot, and the game refuses the whole swap ("Inventory is full.", seen
-- 2026-11-27; one free slot is enough). Fishing mode then stays off (spec 030, B3).
function Gear.HasRoomForPole()
    if not ns.db.settings.gear then
        return true
    end
    local pole = Gear.GetPole()
    if not pole or GetEquipLoc(pole) ~= "INVTYPE_2HWEAPON" or GetInventoryItemID("player", MAINHAND_SLOT) == pole
        or not GetInventoryItemID("player", OFFHAND_SLOT) then
        return true
    end
    -- With the main hand empty the game would take the pole (the off-hand item goes into the pole's freed bag slot,
    -- V83); the rule stays this strict on purpose: the way back would first find no bag slot for the pole.
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local free, bagType = C_Container.GetContainerNumFreeSlots(bag)
        if (free or 0) > 0 and bagType == 0 then
            return true
        end
    end
    return false, GetInventoryItemLink("player", OFFHAND_SLOT)
end

ns.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
    local swap = ns.charDB.gearSwap
    local entry = swap and swap[slot]
    -- `equipped == false` means we left the slot empty, so an empty slot is still ours.
    if entry and entry.restoring and (GetInventoryItemID("player", slot) or false) ~= entry.equipped then
        swap[slot] = nil
        ns.charDB.gearSwap = next(swap) and swap or nil
    end
    -- The game's answer: the slot no longer waits (spec 030).
    waiting[slot] = nil
    Settle()
end)

-- Finish a restore that waited for the cast to end.
local function OnCastEnd(_, unit)
    if unit ~= "player" then
        return
    end
    -- An equip that waited for the cast (RunQueued): the cast is still finishing on this frame.
    if queued and queued.kind == "equip" then
        C_Timer.After(0.2, Settle)
    end
    if not deferredSlots then
        return
    end
    local slots = deferredSlots
    deferredSlots = nil
    if Staying() then
        return -- back in fishing mode: nothing to restore
    end
    -- The cast is still finishing on this frame; equipping right away can still fail.
    C_Timer.After(0.2, function()
        if Staying() then
            return
        end
        RestoreSlots(slots ~= true and slots or nil) -- in the lockdown it waits for the fight's end
    end)
end
ns.RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", OnCastEnd)
ns.RegisterEvent("UNIT_SPELLCAST_STOP", OnCastEnd)
ns.RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", OnCastEnd)

-- A fight that starts while fishing mode is off and a full restore waits only for slots other than the weapons (a
-- refused hat): the weapons come back now, before the lockdown (constitution III); the rest after the answers. With
-- the mode on, Mode's own PLAYER_REGEN_DISABLED handler (it runs after this one) owns the weapons.
ns.RegisterEvent("PLAYER_REGEN_DISABLED", function()
    if queued and queued.kind == "restore" and not ns.Mode.IsActive() and not IsWaiting(WEAPON_SLOTS) then
        RestoreSlots(WEAPON_SLOTS)
    end
end)

-- The end of a fight finishes a restore the lockdown refused, unless fishing mode is on or leaving: then Mode's own
-- PLAYER_REGEN_ENABLED handler owns it (Mode.Exit, or the mode keeps its gear).
ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if restoreAfterCombat and not ns.Mode.IsActive() then
        RestoreSlots(nil)
    end
    -- An equip queued through the fight runs now (on the next frame, after Mode's own handler).
    Settle()
end)

-- Parses a link, an item ID or an item name typed by the player.
function ns.ParseItem(text)
    text = text and strtrim(text) or ""
    if text == "" then
        return nil
    end
    local itemID = ns.ItemIDFromLink(text) or tonumber(text:match("^(%d+)$"))
    if itemID then
        return itemID
    end
    local _, link = C_Item.GetItemInfo((text:gsub("^%[(.*)%]$", "%1")))
    return ns.ItemIDFromLink(link)
end
