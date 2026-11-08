-- Catch: turns casts and fishing loot into FISH_CAUGHT / FISH_MISSED messages.
-- Casts are numbered: FISH_CAUGHT (items, castID) and FISH_MISSED (castID) name the cast they settle, and every
-- earlier cast is settled with it (no message comes for those). Whether a catch came from a pool is not known: in
-- Forever a pool catch has the bobber (35591) as its loot source, like open water (V3, seen 2026-11-06).
local _, ns = ...

-- How long after the channel ends fishing loot may still arrive.
local LOOT_GRACE = 1

local castID = 0
local caughtCastID = 0 -- the last cast settled as caught or missed; casts up to it take no more loot

ns.On("FISHING_CAST_START", function()
    castID = castID + 1
end)

-- The number of the current (or last) cast. Catch.lua handles FISHING_CAST_START before later modules, so they
-- see the new number there.
function ns.GetFishingCastID()
    return castID
end

ns.RegisterEvent("LOOT_READY", function()
    if not IsFishingLoot() or caughtCastID >= castID then
        return
    end
    caughtCastID = castID
    local items = {}
    for i = 1, GetNumLootItems() do
        local link = GetLootSlotLink(i)
        if link then
            local _, _, quantity = GetLootSlotInfo(i)
            -- The ID comes from the link: GetItemInfoInstant has none for an item the client does not know yet.
            -- VERIFY(V27): the loot link of an item the client does not know yet carries its item ID
            table.insert(items, { link = link, itemID = ns.ItemIDFromLink(link), quantity = quantity or 1 })
        end
    end
    ns.Fire("FISH_CAUGHT", items, castID)
end)

ns.On("FISHING_CAST_STOP", function()
    local stoppedID = castID
    C_Timer.After(LOOT_GRACE, function()
        -- Also when the next cast already started: a quick recast must not hide the miss.
        if caughtCastID < stoppedID then
            -- Settled as a miss: later fishing loot (e.g. fishing outside the mode) must not count for it.
            caughtCastID = stoppedID
            ns.Fire("FISH_MISSED", stoppedID)
        end
    end)
end)
