-- VERIFY(spike): temporary; remove this file, its TOC line, its Commands.lua entry and tests/ui/spike_test.lua (and
-- ns.ForgetErrors in Core.lua with its test, which only this file uses)
-- Spike: /okf spike prints the game facts still open (spec 010 trimmed the answered ones): the network of the catch
-- exchange (specs/003-guild-group-sync/verification.md, V10-V15), the proof step timing (specs/004-public-channel-
-- sync/verification.md, V26), the areas at the position and the game's text folding (specs/005-catch-catalog/
-- verification.md, V34, V36) and the last auction search (specs/002-local-catch-db/verification.md, V5).
-- English like the debug report; counts and patterns only, never names.
local _, ns = ...

local Spike = {}
ns.Spike = Spike

local lastSearch -- lines about the last auction search result

-- Collecting runs on every auction result and addon message; an error in this temporary code must not show up
-- there. The failure goes into the section the handler fills (`report` sets it).
local function Safe(fn, report)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            report({ "  !! spike handler failed: " .. tostring(err) })
        end
    end
end

local function ReportSearch(lines)
    lastSearch = lines
end

-- Debug.lua's report section; fn(out) adds its lines to out.
local function Section(lines, title, fn)
    ns.ReportSection(lines, title, function() fn(lines) end)
end

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
    table.insert(out, "  WHISPER to self: " .. Try(send, SPIKE_PREFIX, "spike", "WHISPER", ns.PlayerName()))
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
-- Proof steps (V26): the hash and the time of 64 proof steps
---------------------------------------------------------------------------
local HASH_ABC = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

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

---------------------------------------------------------------------------
-- Areas and folding (specs/005-catch-catalog/research.md R13): reads only; each part runs on its own, so one
-- failing call leaves the others.
---------------------------------------------------------------------------
-- The result of api[name](...) as text: "missing" without the function, or the error it raised.
local function TryApi(api, name, ...)
    local fn = type(api) == "table" and api[name] or nil
    if fn == nil then
        return "missing"
    end
    return Try(fn, ...)
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
        .. Try(ns.CatchDB.GetArea, mapID, x, y))
end

local FOLD_SAMPLE = "Ab\195\137 \208\169" -- A, b, E acute, a space, Cyrillic Shcha

local function FoldLines(out)
    local parse = CaseAccentInsensitiveParse
    table.insert(out, ("  CaseAccentInsensitiveParse %s: %s"):format(tostring(parse ~= nil),
        parse and Try(parse, FOLD_SAMPLE) or "-"))
    table.insert(out, "  strcmputf8i(b, A): " .. (strcmputf8i and Try(strcmputf8i, "b", "A") or "missing"))
end

-- One part, protected: a failure becomes a line.
local function Part(fn)
    return function(out)
        local ok, err = pcall(fn, out)
        if not ok then
            table.insert(out, "  failed: " .. tostring(err))
        end
    end
end

local function BuildReport()
    local lines = { "OneKeyFishing spike report " .. tostring(ns.version) }
    Section(lines, "Network (V10-V15)", NetworkSection)
    Section(lines, "Proof steps (V26)", Part(HashLines))
    Section(lines, "Areas (V34)", Part(AreaLines))
    Section(lines, "Folding (V36)", Part(FoldLines))
    Section(lines, "Last auction search (V5)", function(out)
        for _, line in ipairs(lastSearch or { "  none yet" }) do
            table.insert(out, line)
        end
    end)
    return table.concat(lines, "\n")
end

-- The spike's error log check (V42, closed) ran a deliberate error; its saved entries are dropped once the saved
-- variables are there. Real errors of the spike stay.
ns.RegisterEvent("PLAYER_LOGIN", function()
    ns.ForgetErrors(function(entry)
        return entry.context == "spike" and type(entry.message) == "string"
            and entry.message:find("OneKeyFishing spike test error", 1, true) ~= nil
    end)
end)

-- The window title and the report; Commands.lua shows them in the copy window.
function Spike.Report()
    return "OneKeyFishing - spike report", BuildReport()
end
