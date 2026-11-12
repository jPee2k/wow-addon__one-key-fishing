-- CatchDB/Index.lua: the indexes the views read (CatchDB/Views.lua), kept up by CatchDB/Events.lua: the seed's keys
-- per "<mapID>:<range>", every cell of the other players' records, the own records a roll froze, the places and the
-- items of the own catch. Part of the module ns.CatchDB (CatchDB.private).
local _, ns = ...
local CatchDB = ns.CatchDB
local P = CatchDB.private
local KeyMapRange, KeyMapID, AddToOwnIndex, Seed = P.KeyMapRange, P.KeyMapID, P.AddToOwnIndex, P.Seed
-- P.others: { byKey = { place -> { entry -> true } }, byPrefix = { prefix -> { entry -> true } }, byRecord }
-- P.frozen: the frozen own records; P.ownIndex: the places of the own catch; P.ownItems: its items

-- The seed's keys per "<mapID>:<range>", built once per seed (the seed is large and never changes in place).
local seedIndex, indexedSeed

local function SeedIndex(cells)
    if indexedSeed ~= cells then
        seedIndex, indexedSeed = {}, cells
        for key in pairs(cells) do
            local prefix = KeyMapRange(key)
            if prefix then
                seedIndex[prefix] = seedIndex[prefix] or {}
                table.insert(seedIndex[prefix], key)
            end
        end
    end
    return seedIndex
end

-- Every cell of the other players' records (Share.lua) as an entry { cell, id, build, place, prefix }, in sets by
-- place key and by "<mapID>:<range>": one index for all of them, so a query does not walk every record. Built on
-- the first query; SHARED_DATA_CHANGED with the changed keys updates only those records, without the keys it is
-- built anew; an own catch leaves it alone.

local function AddToSet(sets, name, entry)
    sets[name] = sets[name] or {}
    sets[name][entry] = true
end

-- Which records under "<id>@<epoch>" count: "own" for one the own record left on a roll (Sources counts those
-- with sharing off too), "other" for another player's, nil for a unit the seed holds in part (its first part is in
-- the seed; the store deletes those it holds whole) or anything malformed.
local function CountedUnit(key, record)
    if CatchDB.IsOtherKey(key) and type(record) == "table" and type(record.builds) == "table"
        and not CatchDB.AbsorbedSeq(record.id, record.epoch) then
        return record.id == ns.db.shared.myID and "own" or "other"
    end
end

local function IndexRecord(key)
    local record = ns.db.shared.records[key]
    if CountedUnit(key, record) ~= "other" then
        return
    end
    local entries = {}
    for build, cells in pairs(record.builds) do
        for place, cell in pairs(type(cells) == "table" and cells or {}) do
            local prefix = KeyMapRange(place)
            if prefix then
                local entry = { cell = cell, id = record.id, build = build, place = place, prefix = prefix,
                    other = true, mapID = KeyMapID(prefix), range = tonumber(prefix:match(":(%d)$")) }
                AddToSet(P.others.byKey, place, entry)
                AddToSet(P.others.byPrefix, prefix, entry)
                table.insert(entries, entry)
            end
        end
    end
    P.others.byRecord[key] = entries
end

local function RemoveFromSet(sets, name, entry)
    local set = sets[name]
    set[entry] = nil
    if next(set) == nil then
        sets[name] = nil
    end
end

local function UnindexRecord(key)
    for _, entry in ipairs(P.others.byRecord[key] or {}) do
        RemoveFromSet(P.others.byKey, entry.place, entry)
        RemoveFromSet(P.others.byPrefix, entry.prefix, entry)
    end
    P.others.byRecord[key] = nil
end

-- The own records frozen by a roll that the seed does not hold yet: they count like the live one.

local function Frozen()
    if not P.frozen then
        P.frozen = {}
        for key, record in pairs(ns.db.shared.records) do
            if CountedUnit(key, record) == "own" then
                table.insert(P.frozen, record)
            end
        end
    end
    return P.frozen
end

local function Others()
    if not P.others then
        P.others = { byKey = {}, byPrefix = {}, byRecord = {} }
        for key in pairs(ns.db.shared.records) do
            IndexRecord(key)
        end
    end
    return P.others
end

-- True for a record key of the own ID: the live record, or one a roll froze under "<myID>@<epoch>".
local function IsOwnKey(key)
    local myID = ns.db.shared.myID
    return key == myID or (CatchDB.IsOtherKey(key) and CatchDB.ParseUnit(key) == myID)
end

local function OwnIndex()
    if not P.ownIndex then
        P.ownIndex = {}
        for key in pairs(ns.db.shared.mine) do
            AddToOwnIndex(key)
        end
        for key, record in pairs(ns.db.shared.records) do
            if IsOwnKey(key) and type(record) == "table" and type(record.builds) == "table" then
                for _, cells in pairs(record.builds) do
                    for place in pairs(type(cells) == "table" and cells or {}) do
                        AddToOwnIndex(place)
                    end
                end
            end
        end
    end
    return P.ownIndex
end

-- Adds the item IDs of every cell to `set` (item ID -> true).
local function AddItemsOf(set, cells)
    for _, cell in pairs(type(cells) == "table" and cells or {}) do
        if type(cell) == "table" and type(cell.i) == "table" then
            for itemID in pairs(cell.i) do
                set[itemID] = true
            end
        end
    end
end

-- Item ID -> true for every item of the seed, built once per seed.
local seedItems, seedItemsOf

local function SeedItems()
    local cells = Seed().cells
    if seedItemsOf ~= cells then
        seedItems, seedItemsOf = {}, cells
        AddItemsOf(seedItems, cells)
    end
    return seedItems
end

-- Item ID -> true for every item of the own catch (shared.mine and the records of the own ID), built once and grown
-- by catches (P.ownItems: Settle in CatchDB.lua grows it).
local function OwnItems()
    if not P.ownItems then
        P.ownItems = {}
        AddItemsOf(P.ownItems, ns.db.shared.mine)
        for key, record in pairs(ns.db.shared.records) do
            if type(record) == "table" and record.id == ns.db.shared.myID and type(record.builds) == "table"
                and (key == record.id or CatchDB.IsOtherKey(key)) then
                for _, cells in pairs(record.builds) do
                    AddItemsOf(P.ownItems, cells)
                end
            end
        end
    end
    return P.ownItems
end

-- Shared with CatchDB/Views.lua and CatchDB/Events.lua through CatchDB.private.
P.SeedIndex, P.Others, P.Frozen, P.OwnIndex = SeedIndex, Others, Frozen, OwnIndex
P.SeedItems, P.OwnItems = SeedItems, OwnItems
P.IsOwnKey, P.IndexRecord, P.UnindexRecord = IsOwnKey, IndexRecord, UnindexRecord
