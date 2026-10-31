-- CatchDB/Events.lua: the game's events into the catch database: ADDON_LOADED (repair, roll and the chain of
-- the own record), casts and their catches or misses, the index upkeep on SHARED_DATA_CHANGED, the logout.
local _, ns = ...
local CatchDB = ns.CatchDB
local P = CatchDB.private
local ID_LENGTH, CHAIN_LENGTH = CatchDB.ID_LENGTH, CatchDB.CHAIN_LENGTH
local BumpMap, BumpAll, OwnChain, StartMarks = P.BumpMap, P.BumpAll, P.OwnChain, P.StartMarks
local NewChain, Roll, CatchItems, Settle = P.NewChain, P.Roll, P.CatchItems, P.Settle
local IsOwnKey, IndexRecord, UnindexRecord = P.IsOwnKey, P.IndexRecord, P.UnindexRecord
local casts = {} -- cast ID (Catch.lua) -> { key, x, y, start, stop } until its catch or miss settles it

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ns.RegisterEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= "OneKeyFishing" or not ns.db then
        return
    end
    local shared = ns.db.shared
    if type(shared.myID) ~= "string" or shared.myID == "" then
        shared.myID = ns.RandomBase32(ID_LENGTH)
    end
    local record = shared.records[shared.myID]
    if type(record) == "table" and record.id == nil then
        record.id = shared.myID -- the one field that can be put back: the catches under this key are the account's
    end
    -- A damaged record (edited by hand, an interrupted write) would break every catch, or every HELLO when its ID
    -- is another account's: it starts over.
    if type(record) ~= "table" or type(record.builds) ~= "table" or type(record.seq) ~= "number"
        or type(record.epoch) ~= "number" or record.id ~= shared.myID then
        shared.records[shared.myID] = nil
        Roll()
    -- A record the seed holds (in part or whole) rolls, so it does not count twice next to the seed; what the seed
    -- lacks goes on to the next harvest. shared.mine keeps the lifetime counts either way.
    elseif CatchDB.AbsorbedSeq(shared.myID, record.epoch) then
        Roll()
    else
        -- The version chain of the live record (specs/004-public-channel-sync, data-model.md): resumed, or made for
        -- a record from before part 3 (no proof published yet, so a chain can start at its seq); a record whose
        -- published proofs lost their chain, or whose seq is past a chain's top, starts over.
        if OwnChain(record) then
            StartMarks()
        elseif record.proof == nil and record.seq < CHAIN_LENGTH then
            NewChain(record.epoch)
        else
            Roll()
        end
    end
    P.version = P.version + 1 -- the seed or the record may be new
    P.others, P.frozen, P.ownItems, P.ownIndex, P.poolData = nil, nil, nil, nil, nil
    BumpAll()
end)

-- The place is read at every cast start, also for a cast picked up after a /reload: nothing is counted here,
-- so nothing can count twice; its time runs from the pickup.
ns.On("FISHING_CAST_START", function()
    local mapID, range, cell, x, y = CatchDB.GetCurrentPlace()
    if mapID then
        casts[ns.GetFishingCastID()] = { key = CatchDB.PlaceKey(mapID, range, cell), x = x, y = y,
            area = x and CatchDB.GetArea(mapID, x, y), start = GetTime() }
    end
end)

ns.On("FISHING_CAST_STOP", function()
    local cast = casts[ns.GetFishingCastID()]
    if cast then
        cast.stop = GetTime()
    end
end)

-- Catch.lua settles a cast and every earlier one with it; only the named cast is counted.
local function TakeCast(castID)
    local cast = casts[castID]
    for id in pairs(casts) do
        if id <= castID then
            casts[id] = nil
        end
    end
    return cast
end

ns.On("FISH_CAUGHT", function(items, fromPool, castID)
    P.lastPool = fromPool
    local cast = TakeCast(castID)
    if cast then
        Settle(cast, CatchItems(items), fromPool)
    end
end)

ns.On("FISH_MISSED", function(castID)
    local cast = TakeCast(castID)
    if cast then
        Settle(cast, nil)
    end
end)

-- The maps of a record's indexed entries move.
local function BumpEntries(entries)
    for _, entry in ipairs(entries or {}) do
        BumpMap(entry.mapID)
    end
end

-- Records under "<id>@<epoch>" came or went (other players', Share.lua, or the own one a roll kept), or sharing
-- was switched: the views and their index change. A change in another store (a protocol node of the tests) is not
-- this player's data. Named records move the stamps of their maps, before and after the change; anything else,
-- or an own record, moves every stamp.
ns.On("SHARED_DATA_CHANGED", function(keys, store)
    if store ~= nil and ns.db and store ~= ns.db.shared then
        return
    end
    P.version = P.version + 1
    P.frozen = nil
    if P.poolData == false then
        P.poolData = nil
    end
    local own = keys == nil
    for _, key in ipairs(keys or {}) do
        own = own or IsOwnKey(key)
    end
    if own then
        P.ownIndex = nil
    end
    if P.others and keys then
        for _, key in ipairs(keys) do
            BumpEntries(P.others.byRecord[key])
            UnindexRecord(key)
            IndexRecord(key)
            BumpEntries(P.others.byRecord[key])
        end
    else
        P.others = nil
    end
    if own or not P.others then
        BumpAll()
    end
end)

ns.RegisterEvent("PLAYER_LOGOUT", CatchDB.FlushSeq)
