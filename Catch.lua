-- Catch: turns casts and fishing loot into FISH_CAUGHT / FISH_MISSED messages.
local _, ns = ...

-- How long after the channel ends fishing loot may still arrive.
local LOOT_GRACE = 1

local castID = 0
local caughtCastID = 0

ns.On("FISHING_CAST_START", function()
    castID = castID + 1
end)

ns.RegisterEvent("LOOT_READY", function()
    if not IsFishingLoot() or caughtCastID == castID or castID == 0 then
        return
    end
    caughtCastID = castID
    local items = {}
    for i = 1, GetNumLootItems() do
        local link = GetLootSlotLink(i)
        if link then
            local icon, _, quantity = GetLootSlotInfo(i)
            table.insert(items, { link = link, quantity = quantity or 1, icon = icon })
        end
    end
    ns.Fire("FISH_CAUGHT", items)
end)

ns.On("FISHING_CAST_STOP", function()
    local stoppedID = castID
    C_Timer.After(LOOT_GRACE, function()
        if caughtCastID ~= stoppedID and castID == stoppedID then
            ns.Fire("FISH_MISSED")
        end
    end)
end)
