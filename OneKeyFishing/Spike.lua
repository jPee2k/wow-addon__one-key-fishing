-- VERIFY(spike): temporary; remove this file, its TOC line, its Commands.lua entry and tests/spike_test.lua
-- Spike: /okf spike prints the game facts the catch database was built on before the game could be played
-- (specs/002-local-catch-db/verification.md, V1-V7). Read-only; English like the debug report.
local _, ns = ...

local lastLoot -- lines about the last fishing loot window

local lastSearch -- lines about the last auction search result

-- Collecting runs on every fishing loot and auction result; an error in this temporary code must not show up
-- there. The failure goes into the section the handler fills (`report` sets it).
local function Safe(fn, report)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            report({ "  !! spike handler failed: " .. tostring(err) })
        end
    end
end

local function ReportLoot(lines)
    lastLoot = lines
end

local function ReportSearch(lines)
    lastSearch = lines
end

-- Debug.lua's report section; fn(out) adds its lines to out.
local function Section(lines, title, fn)
    ns.ReportSection(lines, title, function() fn(lines) end)
end

-- A GUID with the object ID the addon compares (ns.GameObjectID, as ns.IsPoolLoot does).
local function GuidText(guid)
    return ("%s (game object %s)"):format(tostring(guid), tostring(ns.GameObjectID(guid)))
end

local probeTab -- one PanelTabButtonTemplate button for the V6 check, made on the first report

ns.RegisterEvent("LOOT_READY", Safe(function()
    if not IsFishingLoot() then
        return
    end
    lastLoot = {}
    for slot = 1, GetNumLootItems() do
        local sources = { GetLootSourceInfo(slot) }
        local guids = {}
        for i = 1, #sources, 2 do
            table.insert(guids, GuidText(sources[i]))
        end
        table.insert(lastLoot, ("  slot %d: %s from %s"):format(slot, tostring(GetLootSlotLink(slot)),
            #guids > 0 and table.concat(guids, ", ") or "no source"))
    end
    table.insert(lastLoot, "  ns.IsPoolLoot(): " .. tostring(ns.IsPoolLoot()))
end, ReportLoot))

local function DescribeResults(kind, count, read)
    local lines, last, ascending = {}, nil, true
    for i = 1, math.min(count or 0, 5) do
        local price, quantity = read(i)
        table.insert(lines, ("    %d: price %s, quantity %s"):format(i, tostring(price), tostring(quantity)))
        if price and last and price < last then
            ascending = false
        end
        last = price or last
    end
    table.insert(lines, 1, ("  %s results loaded: %s, first five ascending: %s"):format(kind, tostring(count),
        tostring(ascending)))
    return lines
end

ns.RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", Safe(function(_, itemID)
    local count = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
    lastSearch = DescribeResults("commodity " .. tostring(itemID), count, function(i)
        local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        return info and info.unitPrice, info and info.quantity
    end)
    table.insert(lastSearch, ("  total quantity %s, full results %s"):format(
        tostring(C_AuctionHouse.GetCommoditySearchResultsQuantity(itemID)),
        tostring(C_AuctionHouse.HasFullCommoditySearchResults(itemID))))
end, ReportSearch))

ns.RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", Safe(function(_, itemKey)
    if not itemKey then
        return
    end
    local count = C_AuctionHouse.GetNumItemSearchResults(itemKey)
    lastSearch = DescribeResults("item " .. tostring(itemKey.itemID), count, function(i)
        local info = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        return info and info.buyoutAmount, info and info.quantity
    end)
end, ReportSearch))

local function BuildReport()
    local lines = { "OneKeyFishing spike report " .. tostring(ns.version) }
    Section(lines, "Build (V7)", function(out)
        local version, build, date, interface = GetBuildInfo()
        table.insert(out, ("  %s | %s | %s | %s"):format(tostring(version), tostring(build), tostring(date),
            tostring(interface)))
    end)
    Section(lines, "Channel", function(out)
        local _, _, _, startMS, _, _, _, spellID = UnitChannelInfo("player")
        table.insert(out, ("  channel spell %s, start %s"):format(tostring(spellID), tostring(startMS)))
    end)
    Section(lines, "Map (V1, V2)", function(out)
        local mapID = C_Map.GetBestMapForUnit("player")
        table.insert(out, "  best map: " .. tostring(mapID))
        local id, depth = mapID, 0
        while id and id ~= 0 and depth < 10 do
            local info = C_Map.GetMapInfo(id)
            table.insert(out, ("    %s: %s, type %s, parent %s"):format(tostring(id), tostring(info and info.name),
                tostring(info and info.mapType), tostring(info and info.parentMapID)))
            id, depth = info and info.parentMapID, depth + 1
        end
        local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        if position then
            local x, y = position:GetXY()
            table.insert(out, ("  position: %s, %s"):format(tostring(x), tostring(y)))
        else
            table.insert(out, "  position: nil")
        end
        if C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState and Enum.AddOnRestrictionType then
            table.insert(out, "  map restriction state: " ..
                tostring(C_RestrictedActions.GetAddOnRestrictionState(Enum.AddOnRestrictionType.Map)))
        end
    end)
    Section(lines, "Last fishing loot (V3)", function(out)
        for _, line in ipairs(lastLoot or { "  none yet" }) do
            table.insert(out, line)
        end
    end)
    Section(lines, "Last auction search (V4, V5)", function(out)
        for _, line in ipairs(lastSearch or { "  none yet" }) do
            table.insert(out, line)
        end
    end)
    Section(lines, "Tabs (V6)", function(out)
        if probeTab == nil then
            local ok, tab = pcall(CreateFrame, "Button", nil, UIParent, "PanelTabButtonTemplate")
            probeTab = ok and tab or false
            if probeTab then
                probeTab:Hide()
            end
        end
        table.insert(out, ("  PanelTabButtonTemplate: %s, PanelTemplates_SetTab: %s"):format(
            probeTab and "created" or "failed", tostring(PanelTemplates_SetTab ~= nil)))
    end)
    return table.concat(lines, "\n")
end

function ns.ShowSpikeReport()
    ns.ShowCopyWindow("OneKeyFishing - spike report", BuildReport())
end
