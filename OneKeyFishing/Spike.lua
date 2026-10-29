-- VERIFY(spike): temporary; remove this file, its TOC line, its Commands.lua entry and tests/spike_test.lua
-- Spike: /okf spike prints the game facts the catch database was built on before the game could be played
-- (specs/002-local-catch-db/verification.md, V1-V7) and the catch exchange (specs/003-guild-group-sync/
-- verification.md, V10-V15). English like the debug report; counts and patterns only, never names.
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

---------------------------------------------------------------------------
-- Network (V10-V15, specs/003-guild-group-sync/research.md R12): a test prefix, never the exchange's own
---------------------------------------------------------------------------
local SPIKE_PREFIX = "OKFSPIKE"
local registered -- the RegisterAddonMessagePrefix result, from the first report
local echoes = {} -- lines about the test messages that came back since the last report

local function ReportEcho(lines)
    echoes = lines
end

-- "Name-Realm" or "Name": the shape of a sender, not the name.
local function SenderShape(sender)
    if type(sender) ~= "string" then
        return tostring(sender)
    end
    return sender:find("-", 1, true) and "Name-Realm" or "Name"
end

ns.RegisterEvent("CHAT_MSG_ADDON", Safe(function(_, prefix, _, channel, sender)
    if prefix == SPIKE_PREFIX then
        table.insert(echoes, ("  echo on %s from a sender shaped %s"):format(tostring(channel), SenderShape(sender)))
    end
end, ReportEcho))

ns.RegisterEvent("BN_CHAT_MSG_ADDON", Safe(function(_, prefix, _, channel)
    if prefix == SPIKE_PREFIX then
        table.insert(echoes, "  Battle.net echo on " .. tostring(channel))
    end
end, ReportEcho))

-- The result of fn(...) as text, or the error it raised.
local function Try(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and tostring(result) or ("failed: " .. tostring(result))
end

local function DeepEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not DeepEqual(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

local SAMPLE = { id = "abcdefgh", epoch = 1, seq = 2, builds = { ["1.60.1"] = {
    ["1415:3:47"] = { c = 3, m = 1, t = 40, px = 1500, py = 900, i = { [6291] = { 2, 3 } } } } } }

-- Runs value through the steps; returns the result, or nil after adding the failing step to out.
local function Steps(out, value, steps)
    for _, step in ipairs(steps) do
        local ok, result = pcall(step[2], value)
        if not ok or result == nil then
            table.insert(out, ("  round trip: %s failed: %s"):format(step[1], tostring(result)))
            return nil
        end
        value = result
    end
    return value
end

-- The record chain of research R4, step by step.
local function RoundTrip(out)
    local util, deflate = C_EncodingUtil, Enum.CompressionMethod and Enum.CompressionMethod.Deflate
    local text = Steps(out, SAMPLE, {
        { "SerializeCBOR", function(v) return util.SerializeCBOR(v) end },
        { "CompressString", function(v) return util.CompressString(v, deflate) end },
        { "EncodeBase64", function(v) return util.EncodeBase64(v) end },
    })
    local back = text and Steps(out, text, {
        { "DecodeBase64", function(v) return util.DecodeBase64(v) end },
        { "DecompressString", function(v) return util.DecompressString(v, deflate) end },
        { "DeserializeCBOR", function(v) return util.DeserializeCBOR(v) end },
    })
    if back then
        table.insert(out, ("  round trip: %s, encoded length %d, Base64 characters only: %s"):format(
            DeepEqual(SAMPLE, back) and "equal" or "not equal", #text,
            tostring(text:find("^[A-Za-z0-9+/=]*$") ~= nil)))
    end
end

local function BattleNetLines(out)
    local online, wow, forever, first = 0, 0, 0, nil
    for i = 1, BNGetNumFriends() or 0 do
        for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
            local account = C_BattleNet.GetFriendGameAccountInfo(i, j)
            if account and account.isOnline then
                online = online + 1
                if account.clientProgram == BNET_CLIENT_WOW then
                    wow = wow + 1
                    if account.wowProjectID == WOW_PROJECT_ID then
                        forever = forever + 1
                        first = first or account.gameAccountID
                    end
                end
            end
        end
    end
    table.insert(out, ("  Battle.net game accounts online %d, on WoW %d, on this project %d"):format(online, wow,
        forever))
    table.insert(out, "  SendGameData to the first: "
        .. (first and Try(C_BattleNet.SendGameData, first, SPIKE_PREFIX, "spike") or "none"))
end

local function NetworkSection(out)
    registered = registered or Try(C_ChatInfo.RegisterAddonMessagePrefix, SPIKE_PREFIX)
    table.insert(out, "  RegisterAddonMessagePrefix: " .. registered)
    local send = C_ChatInfo.SendAddonMessage
    table.insert(out, "  GUILD: " .. (IsInGuild() and Try(send, SPIKE_PREFIX, "spike", "GUILD") or "not in a guild"))
    local group = IsInGroup() and (IsInRaid() and "RAID" or "PARTY")
    table.insert(out, "  group: " .. (group and (group .. " " .. Try(send, SPIKE_PREFIX, "spike", group))
        or "not in a group"))
    table.insert(out, "  WHISPER to self: " .. Try(send, SPIKE_PREFIX, "spike", "WHISPER", UnitName("player")))
    for _, line in ipairs(echoes) do
        table.insert(out, line)
    end
    if #echoes == 0 then
        table.insert(out, "  no echo since the last report (run the report again in a few seconds)")
    end
    echoes = {}
    table.insert(out, "  WHISPER to a made-up name: " .. Try(send, SPIKE_PREFIX, "spike", "WHISPER", "Okfspikenobody")
        .. "; check the chat for a 'No player named' line")
    BattleNetLines(out)
    local restrictions = {}
    for name, value in pairs(Enum.AddOnRestrictionType or {}) do
        table.insert(restrictions, ("%s=%s"):format(name, Try(C_RestrictedActions.IsAddOnRestrictionActive, value)))
    end
    table.sort(restrictions)
    table.insert(out, "  restrictions: " .. (#restrictions > 0 and table.concat(restrictions, " ") or "none known"))
    table.insert(out, ("  InChatMessagingLockdown %s, AreOutgoingAddonChatMessagesRestricted %s"):format(
        Try(C_ChatInfo.InChatMessagingLockdown), Try(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)))
    RoundTrip(out)
    table.insert(out, ("  BNET_CLIENT_WOW %s, WOW_PROJECT_ID %s"):format(tostring(BNET_CLIENT_WOW),
        tostring(WOW_PROJECT_ID)))
end

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
    Section(lines, "Network (V10-V15)", NetworkSection)
    return table.concat(lines, "\n")
end

function ns.ShowSpikeReport()
    ns.ShowCopyWindow("OneKeyFishing - spike report", BuildReport())
end
