-- Catch: turns casts and fishing loot into FISH_CAUGHT / FISH_MISSED messages, and the game's fish lines into
-- FISH_ESCAPED (castID: the fish got away or none was hooked, the answer of a hook press without a catch).
-- FISH_CAUGHT items are { link, itemID, quantity, quality }; quality is the loot slot's (or the item's) quality.
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
            local _, _, quantity, _, quality = GetLootSlotInfo(i)
            -- The ID comes from the link: GetItemInfoInstant has none for an item the client does not know yet.
            -- Assumed (V27, accepted): the loot link of an item the client does not know yet carries its item ID
            local itemID = ns.ItemIDFromLink(link)
            -- The slot knows the quality also for an item the client has not cached (spec 013 research R2).
            -- GetLootSlotInfo's 5th value is the item quality of fishing loot (green = 2; V51, accepted 2026-11-17)
            if quality == nil and itemID and C_Item.GetItemQualityByID then
                quality = C_Item.GetItemQualityByID(itemID)
            end
            table.insert(items, { link = link, itemID = itemID, quantity = quantity or 1, quality = quality })
        end
    end
    ns.Fire("FISH_CAUGHT", items, castID)
end)

-- The game's own lines for a fish that got away or was not hooked, while the line is out or just after it: the
-- answer of a hook press that caught nothing. FISH_ESCAPED (castID), once per cast; the cast is still settled as a
-- miss by FISH_MISSED as before. The lines are compared with the client's own strings, so every client language
-- works (constitution Principle II).
local lineOut = false
local stoppedAt -- GetTime() of the last FISHING_CAST_STOP
local escapedCastID = 0

ns.On("FISHING_CAST_START", function()
    lineOut = true
end)

-- Seen in game 2026-11-16 (V47): "No fish are hooked." comes as UI_INFO_MESSAGE (417, the text as 2nd argument) and
-- ends the line. UI_ERROR_MESSAGE is read as well, as ForeverFishing does, in case a client sends a line that way.
local function OnGameLine(_, _, message)
    if ns.IsSecret(message) or (message ~= ERR_FISH_ESCAPED and message ~= ERR_FISH_NOT_HOOKED) then
        return
    end
    local recent = lineOut or (stoppedAt and GetTime() - stoppedAt <= LOOT_GRACE)
    -- caughtCastID: the loot of this cast already came (within LOOT_GRACE no miss is settled yet), so the line does
    -- not answer a press without a catch.
    if recent and escapedCastID < castID and caughtCastID < castID then
        escapedCastID = castID
        ns.Fire("FISH_ESCAPED", castID)
    end
end
ns.RegisterEvent("UI_INFO_MESSAGE", OnGameLine)
ns.RegisterEvent("UI_ERROR_MESSAGE", OnGameLine)

ns.On("FISHING_CAST_STOP", function()
    lineOut = false
    stoppedAt = GetTime()
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
