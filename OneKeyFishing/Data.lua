-- Data: static game data. The client can run in any language, so everything is matched by ID, never by name.
local _, ns = ...

-- Fishing spell ranks, lowest to highest: Apprentice, Journeyman, Expert, Artisan.
ns.FISHING_SPELL_IDS = { 7620, 7731, 7732, 18248 }

ns.FISHING_SKILL_LINE = 356

-- Game object entry of the fishing bobber, as seen in its GUID (the "softinteract" unit, fishing loot sources).
ns.BOBBER_OBJECT_ID = "35591"

-- The object ID (entry) of a game object GUID, or nil for any other GUID. Forever scrambles the spawn part of
-- GUIDs, so the object ID is the part to compare.
function ns.GameObjectID(guid)
    if not guid then
        return nil
    end
    local unitType, _, _, _, _, objectID = strsplit("-", guid)
    return unitType == "GameObject" and objectID or nil
end

-- Base32 in lower case without padding: anonymous contribution IDs, node tags, session IDs and hashes of the
-- catch exchange (CatchDB.lua, Comm.lua, Share.lua).
ns.BASE32 = "abcdefghijklmnopqrstuvwxyz234567"

-- value (a whole number >= 0) in `width` base32 characters, the most significant first.
function ns.Base32(value, width)
    local chars = {}
    for i = width, 1, -1 do
        local digit = value % 32
        chars[i] = ns.BASE32:sub(digit + 1, digit + 1)
        value = math.floor(value / 32)
    end
    return table.concat(chars)
end

-- `length` random base32 characters; `random` (default math.random) for deterministic tests.
function ns.RandomBase32(length, random)
    random = random or math.random
    local chars = {}
    for i = 1, length do
        local index = random(32)
        chars[i] = ns.BASE32:sub(index, index)
    end
    return table.concat(chars)
end

-- A rolling sum over the last `minutes` minutes, kept per minute in `counts` (minute -> sum): adds `weight` at
-- `now` (seconds; a weight of 0 only reads), drops the minutes outside the window and returns the sum. The traffic
-- budget (Comm.lua) and the per-sender limits (Share.lua) count with it, so their window ends at the same edge.
function ns.CountRecent(counts, now, weight, minutes)
    local minute, total = math.floor(now / 60), 0
    if weight ~= 0 then
        counts[minute] = (counts[minute] or 0) + weight
    end
    for at, count in pairs(counts) do
        if at > minute - minutes then
            total = total + count
        else
            counts[at] = nil
        end
    end
    return total
end

-- True when the interact key would hit the bobber (not some other object nearby).
-- The bobber has no nameplate and UnitExists is false for it, but its name and GUID are readable.
function ns.IsBobberTargeted()
    return ns.GameObjectID(UnitGUID("softinteract")) == ns.BOBBER_OBJECT_ID
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
