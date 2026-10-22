-- Data: static game data. The client may be localized (e.g. ruRU), so everything is matched by ID, never by name.
local _, ns = ...

-- Fishing spell ranks, lowest to highest: Apprentice, Journeyman, Expert, Artisan.
ns.FISHING_SPELL_IDS = { 7620, 7731, 7732, 18248 }

ns.FISHING_SKILL_LINE = 356

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
