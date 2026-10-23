-- Data: static game data. The client may be localized (e.g. ruRU), so everything is matched by ID, never by name.
local _, ns = ...

-- Fishing spell ranks, lowest to highest: Apprentice, Journeyman, Expert, Artisan.
ns.FISHING_SPELL_IDS = { 7620, 7731, 7732, 18248 }

ns.FISHING_SKILL_LINE = 356

-- Game object entry of the fishing bobber, as seen in the "softinteract" unit's GUID.
local BOBBER_OBJECT_ID = "35591"

-- True when the interact key would hit the bobber (not some other object nearby).
-- The bobber has no nameplate and UnitExists is false for it, but its name and GUID are readable.
function ns.IsBobberTargeted()
    local guid = UnitGUID("softinteract")
    if not guid then
        return false
    end
    local unitType, _, _, _, _, objectID = strsplit("-", guid)
    return unitType == "GameObject" and objectID == BOBBER_OBJECT_ID
end

local fishingSpellLookup = {}
for _, id in ipairs(ns.FISHING_SPELL_IDS) do
    fishingSpellLookup[id] = true
end

function ns.IsFishingSpell(spellID)
    return fishingSpellLookup[spellID] == true
end

local function IsSpellKnown(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    end
    return IsPlayerSpell(spellID)
end

-- Highest known Fishing rank, or nil if Fishing is not learned.
function ns.GetFishingSpellID()
    for i = #ns.FISHING_SPELL_IDS, 1, -1 do
        local id = ns.FISHING_SPELL_IDS[i]
        if IsSpellKnown(id) then
            return id
        end
    end
end

-- Calls fn(info, bag, slot) for every item in the regular bags. Stops when fn returns true
-- and returns that bag, slot.
function ns.ForEachBagItem(fn)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and fn(info, bag, slot) then
                return bag, slot
            end
        end
    end
end
