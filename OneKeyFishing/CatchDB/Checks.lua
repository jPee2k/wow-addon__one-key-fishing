-- CatchDB/Checks.lua: the checks of other players' records before they are stored or passed on (counts, items,
-- areas, the version chain). Pure functions over a record; nothing here keeps state.
local _, ns = ...
local CatchDB = ns.CatchDB
local P = CatchDB.private
local MAX_PIECES, MAX_AREAS = P.MAX_PIECES, P.MAX_AREAS
local ID_LENGTH, CHAIN_LENGTH = CatchDB.ID_LENGTH, CatchDB.CHAIN_LENGTH
local IsProof = CatchDB.IsProof

---------------------------------------------------------------------------
-- Checking other players' records
---------------------------------------------------------------------------
local MAX_RECORD_PLACES = 1000 -- distinct places of one received record
local MAX_COUNT = 1e12 -- any count above this is garbage (and keeps math.huge out)

local function IsCount(value)
    return type(value) == "number" and value >= 0 and value <= MAX_COUNT and value == math.floor(value)
end
CatchDB.IsCount = IsCount

-- Distinct places over all builds of a record (a place fished before and after a patch is one), as
-- CheckRecord and the harvest count them: the unit of the place limits. limit (optional): counting stops above
-- it, so a huge record costs no more than limit + 1 places.
function CatchDB.CountPlaces(record, limit)
    local seen, count = {}, 0
    if type(record) == "table" and type(record.builds) == "table" then
        -- One game version (almost every record): no place can repeat, so no set is needed.
        local multi = next(record.builds, (next(record.builds))) ~= nil
        for _, cells in pairs(record.builds) do
            if type(cells) == "table" then
                for key in pairs(cells) do
                    if not (multi and seen[key]) then
                        seen[key], count = multi or nil, count + 1
                        if limit and count > limit then
                            return count
                        end
                    end
                end
            end
        end
    end
    return count
end

local MAX_ITEM_ID = 2147483647 -- item IDs are 32-bit; an item the client does not know yet is no fault (FR-017a)

-- minus (optional): checked items to take off each entry first, as a pool part off its cell (open water).
local function CheckItems(items, catches, minus)
    if items == nil then
        return true
    end
    if type(items) ~= "table" then
        return false, "items are not a table"
    end
    for itemID, entry in pairs(items) do
        if not (IsCount(itemID) and itemID > 0 and itemID <= MAX_ITEM_ID) then
            return false, "item ID " .. tostring(itemID) .. " is not a positive 32-bit number"
        end
        local withItem, pieces = type(entry) == "table" and entry[1], type(entry) == "table" and entry[2]
        local taken = minus and minus[itemID]
        if taken and IsCount(withItem) and IsCount(pieces) then
            withItem, pieces = withItem - taken[1], pieces - taken[2]
        end
        if not (IsCount(withItem) and IsCount(pieces)) or withItem > catches or pieces < withItem
            or pieces > MAX_PIECES * withItem then
            return false, "item " .. itemID .. " has impossible counts"
        end
    end
    return true
end

-- The subzone counts a of a cell (data-model.md of specs/005-catch-catalog): absent or a table of at most 8
-- entries; every key is a whole number from 1 to 2,147,483,647; every count is a count, and their sum is at most
-- c + m.
local MAX_AREA_ID = 2147483647

local function CheckAreas(areas, casts)
    if areas == nil then
        return true
    end
    if type(areas) ~= "table" then
        return false, "the areas are not a table"
    end
    local count, total = 0, 0
    for areaID, n in pairs(areas) do
        count = count + 1
        if count > MAX_AREAS then
            return false, "more than " .. MAX_AREAS .. " areas"
        end
        if not (IsCount(areaID) and areaID >= 1 and areaID <= MAX_AREA_ID) then
            return false, "area ID " .. tostring(areaID) .. " is not a positive 32-bit number"
        end
        if not IsCount(n) then
            return false, "area " .. areaID .. " has no count"
        end
        total = total + n
    end
    if total > casts then
        return false, "more casts in areas than in the cell"
    end
    return true
end

local POSITION_FIELDS = { "px", "py" }

local function CheckCell(cell)
    if type(cell) ~= "table" or not (IsCount(cell.c) and IsCount(cell.m) and IsCount(cell.t)) then
        return false, "not a cell"
    end
    local casts = cell.c + cell.m
    if casts > cell.t then
        return false, "more casts than seconds of casting"
    end
    if (cell.px == nil) ~= (cell.py == nil) then
        return false, "px and py come together"
    end
    for _, name in ipairs(POSITION_FIELDS) do
        if cell[name] ~= nil and not (IsCount(cell[name]) and cell[name] <= 1000 * casts) then
            return false, name .. " is out of range"
        end
    end
    local ok, reason = CheckItems(cell.i, cell.c)
    if not ok then
        return false, reason
    end
    ok, reason = CheckAreas(cell.a, casts)
    if not ok then
        return false, reason
    end
    if cell.p ~= nil then
        if type(cell.p) ~= "table" or not IsCount(cell.p.c) or cell.p.c > cell.c then
            return false, "the pool part does not fit the totals"
        end
        ok, reason = CheckItems(cell.p.i, cell.p.c)
        if not ok then
            return false, reason
        end
        -- The pool part is counted in the cell too: open water, the rest (i - p.i out of c - p.c), must hold the
        -- same rules, so no count of it goes below 0 and no chance above 1.
        for itemID in pairs(cell.p.i or {}) do
            if not (cell.i and cell.i[itemID]) then
                return false, "open water: item " .. itemID .. " has impossible counts"
            end
        end
        ok, reason = CheckItems(cell.i, cell.c - cell.p.c, cell.p.i)
        if not ok then
            return false, "open water: " .. reason
        end
    end
    return true
end

-- Casting per seq step (specs/004-public-channel-sync, research.md R9): the seq is bumped at most once a minute, on
-- the first settled cast after it, so one step holds at most a minute plus two casts of casting. A record never holds
-- more than STEP_SECONDS per step of its seq, whoever sends it: a copy made up at a seq its owner published can add
-- only that much, and the limit needs no other version, so no copy can block the owner's next one.
-- VERIFY(V26): a fishing cast lasts at most about 30 s in Forever, so no honest step reaches STEP_SECONDS
local STEP_SECONDS = 180
CatchDB.STEP_SECONDS = STEP_SECONDS

-- True, or false and the reason, for a record received from another player (the store refuses the own ID). An item
-- this client does not know is accepted: WoW Forever reveals some items only when they are found (FR-017a).
-- Mirrors checkRecord / checkCell in tools/harvest.mjs, so what a client accepts the next seed accepts too, but
-- rejects the whole record on any bad cell: a peer's data is refused, not cleaned up. No side effects.
function CatchDB.CheckRecord(record)
    if type(record) ~= "table" then
        return false, "not a table"
    end
    local id = record.id
    if type(id) ~= "string" or #id ~= ID_LENGTH or not id:find("^[a-z2-7]+$") then
        return false, "the ID is not 8 base32 characters"
    end
    if not (IsCount(record.epoch) and IsCount(record.seq)) then
        return false, "epoch or seq is not a count"
    end
    if not IsProof(record.proof) then
        return false, "the proof is not 16 base32 characters"
    end
    if type(record.builds) ~= "table" then
        return false, "no builds"
    end
    if CatchDB.CountPlaces(record, MAX_RECORD_PLACES) > MAX_RECORD_PLACES then
        return false, "more than " .. MAX_RECORD_PLACES .. " places"
    end
    local casts, seconds = 0, 0
    for build, cells in pairs(record.builds) do
        if not CatchDB.IsBuild(build) or type(cells) ~= "table" then
            return false, "build " .. tostring(build) .. " is not a game version"
        end
        for key, cell in pairs(cells) do
            if type(key) ~= "string" or not (key:find("^%d+:[0-4]:%d%d$") or key:find("^%d+:[0-4]:x$")) then
                return false, "place key " .. tostring(key) .. " is not <mapID>:<range>:<cell>"
            end
            local ok, reason = CheckCell(cell)
            if not ok then
                return false, key .. ": " .. reason
            end
            casts, seconds = casts + cell.c + cell.m, seconds + cell.t
        end
    end
    -- The seq grows only after a settled cast, so it is never above the casts; a higher one is made up (it would
    -- make the owner's real updates look older everywhere).
    if record.seq > casts then
        return false, "seq " .. record.seq .. " is above the record's " .. casts .. " casts"
    end
    if seconds > STEP_SECONDS * record.seq then
        return false, "more casting than " .. record.seq .. " version steps allow"
    end
    return true
end

---------------------------------------------------------------------------
-- Newer versions (specs/004-public-channel-sync, research.md R9)
---------------------------------------------------------------------------
-- Checks that a newer version of a unit continues the version held (the stored record, or { seq, proof } of the
-- seed's absorbed version): its proof, stepped down to the held seq, must be the held proof, which only the owner
-- can make. Walks at most `steps` links per call (all when nil) and returns "ok", "invalid" and the reason, or "more"
-- and the state to pass to the next call. The incoming record passed CheckRecord (and so the casting limit).
function CatchDB.CheckVersion(held, incoming, steps, state)
    if not state then
        if incoming.seq <= held.seq then
            return "invalid", "not newer than the version held"
        end
        if incoming.seq - held.seq > CHAIN_LENGTH then
            return "invalid", "a jump over a whole chain"
        end
        state = { link = incoming.proof, left = incoming.seq - held.seq }
    end
    for _ = 1, math.min(steps or state.left, state.left) do
        state.link = ns.ProofStep(state.link)
        state.left = state.left - 1
    end
    if state.left > 0 then
        return "more", state
    end
    if state.link ~= held.proof then
        return "invalid", "the proof does not continue the version held"
    end
    return "ok"
end
