-- VERIFY(spike): temporary; remove this file, its TOC line, its Commands.lua entry and tests/spike_test.lua
-- Spike: /okf spike prints the game facts the catch database was built on before the game could be played
-- (specs/002-local-catch-db/verification.md, V1-V7), the catch exchange (specs/003-guild-group-sync/
-- verification.md, V10-V15), the public channel (specs/004-public-channel-sync/verification.md, V19-V27) and the
-- catch catalog (specs/005-catch-catalog/verification.md, V30-V36).
-- English like the debug report; counts and patterns only, never names.
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

---------------------------------------------------------------------------
-- Chat channel (specs/004-public-channel-sync/research.md R13): a test channel, never the real one. The first
-- report joins it; the next one runs the checks and leaves it again. Later events (notices, echoes, the password
-- request, item loads) are collected here and shown on the next report.
---------------------------------------------------------------------------
local HASH_ABC = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
local testChannel -- "OKFSpike" and four random digits, once per session (channel names may not hold "-")
local channelEvents = {} -- lines since the last report
local numbersBefore -- the channel numbers before the last test join
local loadRequested -- the item asked for with RequestLoadItemDataByID

local function ReportChannelEvent(lines)
    channelEvents = lines
end

-- What a notice or echo argument looks like: empty, the test channel's name, a number, a player-like name.
local function ArgShape(value)
    if value == nil or value == "" then
        return "empty"
    elseif value == testChannel then
        return "the test channel name"
    elseif tonumber(value) then
        return "a number"
    end
    return SenderShape(value)
end

local function ChannelNumbers()
    local list, numbers = { GetChannelList() }, {}
    for i = 1, #list, 3 do
        table.insert(numbers, tostring(list[i]))
    end
    return table.concat(numbers, ",")
end

for _, event in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER" }) do
    ns.RegisterEvent(event, Safe(function(_, token, player, _, _, actor, _, _, _, name)
        if testChannel and name == testChannel then
            table.insert(channelEvents, ("  %s %s (player %s, actor %s)"):format(event, tostring(token),
                ArgShape(player), ArgShape(actor)))
        end
    end, ReportChannelEvent))
end

ns.RegisterEvent("CHAT_MSG_ADDON", Safe(function(_, prefix, _, chatType, sender, target, _, localID, name)
    if prefix == SPIKE_PREFIX and chatType == "CHANNEL" then
        table.insert(channelEvents, ("  channel echo: sender %s, target %s, localID %s, name %s"):format(
            SenderShape(sender), ArgShape(target), tostring(localID), ArgShape(name)))
    end
end, ReportChannelEvent))

ns.RegisterEvent("CHANNEL_PASSWORD_REQUEST", Safe(function(_, channel)
    if testChannel and channel == testChannel then
        StaticPopup_Hide("CHAT_CHANNEL_PASSWORD")
        table.insert(channelEvents, "  CHANNEL_PASSWORD_REQUEST for the test channel: popup hidden (note any flash)")
    end
end, ReportChannelEvent))

ns.RegisterEvent("ITEM_DATA_LOAD_RESULT", Safe(function(_, itemID, success)
    if itemID == loadRequested then
        table.insert(channelEvents, ("  ITEM_DATA_LOAD_RESULT for the asked item: %s"):format(tostring(success)))
    end
end, ReportChannelEvent))

-- Joined: the chat windows, a send, the owner and a password set and cleared, then the leave.
local function ChannelChecks(out, name, number)
    table.insert(out, "  channel number " .. tostring(number))
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local window = _G["ChatFrame" .. i]
        local listed = false
        local ok, values = pcall(function() return { GetChatWindowChannels(i) } end) -- name, zone, name, zone, ...
        for _, value in ipairs(ok and values or {}) do
            listed = listed or value == name
        end
        if window and window.ContainsChannel and window:ContainsChannel(name) then
            pcall(window.RemoveChannel, window, name)
            table.insert(out, ("  chat window %d listed it (GetChatWindowChannels %s); removed, now %s"):format(i,
                tostring(listed), tostring(window:ContainsChannel(name))))
        elseif listed then
            table.insert(out, ("  chat window %d: GetChatWindowChannels lists it, the window does not"):format(i))
        end
    end
    table.insert(out, "  SendAddonMessage CHANNEL: "
        .. Try(C_ChatInfo.SendAddonMessage, SPIKE_PREFIX, "ping", "CHANNEL", number))
    table.insert(out, "  IsDisplayChannelOwner: " .. Try(IsDisplayChannelOwner))
    table.insert(out, "  DisplayChannelOwner (its CHANNEL_OWNER notice comes later): "
        .. Try(DisplayChannelOwner, name))
    table.insert(out, "  SetChannelPassword x: " .. Try(SetChannelPassword, name, "x")
        .. ", cleared: " .. Try(SetChannelPassword, name, ""))
    table.insert(out, "  LeaveChannelByName: " .. Try(LeaveChannelByName, name))
end

local function HashLines(out)
    table.insert(out, ("  bit %s, bnot(0) %s, band(-1, 4294967295) %s"):format(tostring(bit ~= nil),
        bit and Try(bit.bnot, 0) or "-", bit and Try(bit.band, -1, 4294967295) or "-"))
    if not ns.SHA256 then
        table.insert(out, "  SHA-256: not built yet")
        return
    end
    local ok, digest = pcall(ns.SHA256, "abc")
    table.insert(out, "  SHA256(abc) known digest: " .. (ok and tostring(digest == HASH_ABC) or ("failed: "
        .. tostring(digest))))
    local clock, link = debugprofilestop, "abcdefghijklmnop"
    local started = clock and clock()
    for _ = 1, 64 do
        link = ns.ProofStep(link)
    end
    local finished = clock and clock()
    table.insert(out, ("  64 proof steps: %s ms"):format(started and finished
        and ("%.2f"):format(finished - started) or "no clock"))
end

local function ItemLines(out)
    local seen, unknown, missing, first = {}, 0, 0, nil
    for _, cell in pairs(ns.SeedData and ns.SeedData.cells or {}) do
        for itemID in pairs(type(cell) == "table" and cell.i or {}) do
            if not seen[itemID] then
                seen[itemID] = true
                if C_Item.GetItemInfoInstant(itemID) == nil then
                    unknown, first = unknown + 1, first or itemID
                end
                if C_Item.DoesItemExistByID and not C_Item.DoesItemExistByID(itemID) then
                    missing = missing + 1
                end
            end
        end
    end
    table.insert(out, ("  bundled items unknown to GetItemInfoInstant %d, not existing (DoesItemExistByID) %d"):format(
        unknown, missing))
    if first and not loadRequested then
        loadRequested = first
        table.insert(out, "  RequestLoadItemDataByID on the first: " .. Try(C_Item.RequestLoadItemDataByID, first))
    end
end

local function ChatChannelSection(out)
    local max = Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatChannels
    table.insert(out, ("  MaxChatChannels %s, active channels %s"):format(tostring(max),
        Try(C_ChatInfo.GetNumActiveChannels)))
    table.insert(out, "  too many channels text: " .. ((ERR_TOO_MANY_CHAT_CHANNELS and max)
        and ERR_TOO_MANY_CHAT_CHANNELS:format(max) or "unknown"))
    testChannel = testChannel or ("OKFSpike%04d"):format(math.random(0, 9999))
    local number = GetChannelName(testChannel)
    if not number or number == 0 then
        if numbersBefore then
            table.insert(out, "  channel numbers back as before the last join: " .. tostring(ChannelNumbers()
                == numbersBefore))
        end
        numbersBefore = ChannelNumbers()
        local ok, kind, joined = pcall(JoinTemporaryChannel, testChannel)
        table.insert(out, "  JoinTemporaryChannel: " .. (ok and (tostring(kind) .. ", " .. ArgShape(joined))
            or ("failed: " .. tostring(kind))))
        table.insert(out, "  joined the test channel " .. testChannel .. ": run the report again in a few seconds")
    else
        ChannelChecks(out, testChannel, number)
    end
    for _, line in ipairs(channelEvents) do
        table.insert(out, line)
    end
    channelEvents = {}
    HashLines(out)
    ItemLines(out)
end

---------------------------------------------------------------------------
-- Map pins and areas (specs/005-catch-catalog/research.md R13): reads only; no pin is set and no map is opened.
-- Each part runs on its own, so one failing call leaves the others.
---------------------------------------------------------------------------
-- The result of api[name](...) as text: "missing" without the function, or the error it raised.
local function TryApi(api, name, ...)
    local fn = type(api) == "table" and api[name] or nil
    if fn == nil then
        return "missing"
    end
    return Try(fn, ...)
end

local function PointText(point)
    if type(point) ~= "table" then
        return tostring(point)
    end
    return ("%s, %s"):format(tostring(point.x), tostring(point.y))
end

-- The player's map and position (x, y in 0..1), or nil.
local function PlayerPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if position then
        local x, y = position:GetXY()
        return mapID, x, y
    end
    return mapID
end

local function PinLines(out)
    local mapID, x, y = PlayerPosition()
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    info = ok and type(info) == "table" and info or nil
    local parent = info and info.parentMapID
    table.insert(out, ("  map %s, type %s, parent %s"):format(tostring(mapID), tostring(info and info.mapType),
        tostring(parent)))
    table.insert(out, ("  CanSetUserWaypointOnMap: map %s, parent %s"):format(
        TryApi(C_Map, "CanSetUserWaypointOnMap", mapID), TryApi(C_Map, "CanSetUserWaypointOnMap", parent)))
    local rule = Enum.GameRule and Enum.GameRule.WorldMapTrackingPinDisabled
    table.insert(out, "  game rule WorldMapTrackingPinDisabled active: "
        .. (rule and TryApi(C_GameRules, "IsGameRuleActive", rule) or "no such rule"))
    table.insert(out, "  showInGameNavigation: " .. TryApi(C_CVar, "GetCVar", "showInGameNavigation"))
    table.insert(out, "  HasUserWaypoint: " .. TryApi(C_Map, "HasUserWaypoint"))
    local okPoint, point = pcall(C_Map.GetUserWaypoint)
    table.insert(out, "  GetUserWaypoint: " .. (not okPoint and ("failed: " .. tostring(point))
        or (type(point) == "table" and ("map %s at %s"):format(tostring(point.uiMapID), PointText(point.position)))
        or tostring(point)))
    if info and Enum.UIMapType and info.mapType == Enum.UIMapType.Micro and x then
        local okWorld, continent, world = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
        local okBack, backMap, back = pcall(C_Map.GetMapPosFromWorldPos, continent, world, parent)
        table.insert(out, ("  a Micro map: world position %s (continent %s), on the parent %s at %s"):format(
            okWorld and PointText(world) or ("failed: " .. tostring(continent)), tostring(continent),
            okBack and tostring(backMap) or "failed", okBack and PointText(back) or tostring(backMap)))
    end
end

local function AreaLines(out)
    local mapID, x, y = PlayerPosition()
    if not x then
        table.insert(out, "  no position")
        return
    end
    local ok, ids = pcall(function()
        return C_MapExplorationInfo.GetExploredAreaIDsAtPosition(mapID, CreateVector2D(x, y))
    end)
    if not ok then
        table.insert(out, "  GetExploredAreaIDsAtPosition failed: " .. tostring(ids))
    elseif type(ids) ~= "table" or #ids == 0 then
        table.insert(out, "  GetExploredAreaIDsAtPosition: none")
    else
        for _, areaID in ipairs(ids) do
            table.insert(out, ("  area %s: %s"):format(tostring(areaID), TryApi(C_Map, "GetAreaInfo", areaID)))
        end
    end
    table.insert(out, "  GetSubZoneText: " .. Try(GetSubZoneText))
    table.insert(out, "  the area the addon keeps: "
        .. (ns.CatchDB.GetArea and Try(ns.CatchDB.GetArea, mapID, x, y) or "not built yet"))
end

local itemsAsked -- the seed's items were asked for on an earlier report

-- The lowest `count` item IDs of the bundled seed.
local function SeedItemIDs(count)
    local set, ids = {}, {}
    for _, cell in pairs(ns.SeedData and ns.SeedData.cells or {}) do
        for itemID in pairs(type(cell) == "table" and type(cell.i) == "table" and cell.i or {}) do
            set[itemID] = true
        end
    end
    for itemID in pairs(set) do
        table.insert(ids, itemID)
    end
    table.sort(ids)
    return { unpack(ids, 1, math.min(count, #ids)) }
end

local function ItemNameLines(out)
    local ids = SeedItemIDs(3)
    if #ids == 0 then
        table.insert(out, "  no bundled items")
        return
    end
    for _, itemID in ipairs(ids) do
        table.insert(out, ("  item %d %s: name %s, quality %s, GetItemInfoInstant %s"):format(itemID,
            itemsAsked and "after a request" or "before a request", TryApi(C_Item, "GetItemNameByID", itemID),
            TryApi(C_Item, "GetItemQualityByID", itemID), TryApi(C_Item, "GetItemInfoInstant", itemID)))
    end
    if not itemsAsked then
        itemsAsked = true
        for _, itemID in ipairs(ids) do
            TryApi(C_Item, "RequestLoadItemDataByID", itemID)
        end
        table.insert(out, "  asked the game for each once: run the report again in a few seconds")
    end
end

local FOLD_SAMPLE = "Ab\195\137 \208\169" -- A, b, E acute, a space, Cyrillic Shcha

local function FoldLines(out)
    local parse = CaseAccentInsensitiveParse
    table.insert(out, ("  CaseAccentInsensitiveParse %s: %s"):format(tostring(parse ~= nil),
        parse and Try(parse, FOLD_SAMPLE) or "-"))
    table.insert(out, "  strcmputf8i(b, A): " .. (strcmputf8i and Try(strcmputf8i, "b", "A") or "missing"))
end

local templateProbes -- template -> what CreateFrame did, made on the first report

local function TemplateLines(out)
    table.insert(out, ("  CreateScrollBoxListLinearView %s, ScrollUtil.InitScrollBoxListWithScrollBar %s, "
        .. "CreateDataProvider %s"):format(tostring(CreateScrollBoxListLinearView ~= nil),
        tostring(ScrollUtil ~= nil and ScrollUtil.InitScrollBoxListWithScrollBar ~= nil),
        tostring(CreateDataProvider ~= nil)))
    if not templateProbes then
        templateProbes = {}
        for _, probe in ipairs({ { "Frame", "WowScrollBoxList" }, { "EventFrame", "MinimalScrollBar" },
            { "EditBox", "SearchBoxTemplate" } }) do
            local ok, made = pcall(CreateFrame, probe[1], nil, UIParent, probe[2])
            if ok and made then
                made:Hide()
            end
            table.insert(templateProbes, ("%s %s"):format(probe[2], ok and "created" or ("failed: " .. tostring(made))))
        end
    end
    table.insert(out, "  " .. table.concat(templateProbes, ", "))
    local ok, atlas = pcall(function() return C_Texture.GetAtlasInfo("Waypoint-MapPin-Untracked") end)
    table.insert(out, "  atlas Waypoint-MapPin-Untracked: " .. (ok and tostring(atlas ~= nil)
        or ("failed: " .. tostring(atlas))))
end

local function MapPinSection(out)
    for _, part in ipairs({ { "pins", PinLines }, { "areas", AreaLines }, { "items", ItemNameLines },
        { "folding", FoldLines }, { "templates", TemplateLines } }) do
        table.insert(out, "  " .. part[1] .. ":")
        local ok, err = pcall(part[2], out)
        if not ok then
            table.insert(out, "  " .. part[1] .. " failed: " .. tostring(err))
        end
    end
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
    Section(lines, "Chat channel (V19-V27)", ChatChannelSection)
    Section(lines, "Map pins and areas (V30-V36)", MapPinSection)
    return table.concat(lines, "\n")
end

function ns.ShowSpikeReport()
    ns.ShowCopyWindow("OneKeyFishing - spike report", BuildReport())
end
