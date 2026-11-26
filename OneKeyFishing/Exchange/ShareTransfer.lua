-- ShareTransfer: the import and export of catch records (specs/027-import-export), part of ns.Share. An export
-- turns the player's records into one string to copy (the own units first, then others' by freshness); an import
-- reads a pasted string, checks every record as a record received through the exchange is checked and stores those
-- that pass. Both run in frame steps within the merge's budget. A record once imported keeps a mark
-- (shared.imported), so it counts in the views with sharing off too (CatchDB/Index.lua CountedOthers).
-- Format and answers: specs/027-import-export/contracts/export-string.md.
local _, ns = ...
local Share = ns.Share
local P = Share.private
local Store = Share.Store
local UnitOf, Changed, Pending, OwnRecord = P.UnitOf, P.Changed, P.Pending, P.OwnRecord
local WithinBudget, PROOF_CHUNK, MAX_RECORD_BYTES = P.WithinBudget, P.PROOF_CHUNK, P.MAX_RECORD_BYTES
local HashSlice, HASH_START, OwnSendable = P.HashSlice, P.HASH_START, P.OwnSendable

local FORMAT = 1
-- The longest string an export makes. The settings page's edit box showed and copied 149 KB and took a 138 KB paste
-- whole in game; a string near this limit is accepted without a check (V78): a cut paste loses its ":END" and is
-- refused as incomplete, so nothing is lost. A lower limit also refuses older strings above it (as damaged).
local EXPORT_LIMIT = 256 * 1024
local HASH_SLICE = 16 * 1024 -- characters of the checksum per frame step
local HEADER_ROOM = 32 -- "OKF:1:<count>:<check>:" and ":END"
Share.EXPORT_LIMIT = EXPORT_LIMIT

-- The transfer's state (data-model.md "Transfer state"); the page polls Share.TransferState().
local transfer = { state = "idle" }

-- The scheduler and the clock; the tests replace them through Share.private.transferEnv.
local env = {
    after = function(delay, fn) C_Timer.After(delay, fn) end,
    clock = function()
        local ms = debugprofilestop and debugprofilestop()
        return type(ms) == "number" and ms or nil
    end,
    time = function() return time() end,
}
P.transferEnv = env

-- The import marks of `store` (the game's when nil): "<id>@<epoch>" -> true.
local function Marks(store)
    store = store or ns.db.shared
    store.imported = type(store.imported) == "table" and store.imported or {}
    return store.imported
end

-- True for a unit "<id>@<epoch>" that came in by an import.
function Share.IsImported(unit)
    local marks = ns.db and ns.db.shared and ns.db.shared.imported
    return type(marks) == "table" and marks[unit] == true
end

-- A copy of the state: state ("idle", "exporting", "importing"), export { text, records, bytes }, result
-- { new, known, own, refused } or { error = "empty" | "cut" | "format" | "damaged" }, resultSeq (one more per
-- result), progress { done, total }.
function Share.TransferState()
    local copy = {}
    for key, value in pairs(transfer) do
        if type(value) == "table" then
            local inner = {}
            for k, v in pairs(value) do
                inner[k] = v
            end
            copy[key] = inner
        else
            copy[key] = value
        end
    end
    return copy
end

local function CheckText(hash)
    return ns.Base32(hash, 7)
end

-- A frame step that cannot leave the transfer stuck: an error goes to the error log (ns.Safe) and fail() puts the
-- transfer back to idle with an answer, so the next import or export is not refused as busy until a /reload.
local function Guarded(context, fn, fail)
    return function()
        if not ns.Safe(context, fn) then
            fail()
        end
    end
end

---------------------------------------------------------------------------
-- Export (research R3)
---------------------------------------------------------------------------
-- The encoded record as the exchange would send it, or nil when a peer would refuse it: the own one by the node's
-- own rule (ShareNode.lua OwnSendable), another player's checked again as Node:SendRecords does.
local function Encoded(store, unit, record)
    if record.id == store.myID then
        if ns.CatchDB.IsBlocked(record.id) then
            return nil
        end
        local data, problem = OwnSendable(record, Share.Encode)
        return data or nil, problem
    end
    local outgoing = Store.ForSending(record)
    if Pending(store, unit, record) or not ns.CatchDB.CheckRecord(outgoing) then
        return nil
    end
    local data = Share.Encode(outgoing)
    return data and #data <= MAX_RECORD_BYTES and data or nil
end

-- The units to export, in order: the own ones (the live record and those a roll kept), then others' by seen, newest
-- first; with sharing off only the imported ones of others.
local function ExportOrder(store)
    local own, others, seen = {}, {}, {}
    local sharing = Share.IsEnabled()
    for unit in pairs(Store.Units(store)) do
        local record = Store.Get(store, unit)
        if record and record.id == store.myID then
            table.insert(own, unit)
        elseif record and (sharing or Marks(store)[unit]) then
            table.insert(others, unit)
            seen[unit] = tonumber(record.seen) or 0
        end
    end
    table.sort(own)
    table.sort(others, function(a, b)
        if seen[a] ~= seen[b] then
            return seen[a] > seen[b]
        end
        return a < b
    end)
    for _, unit in ipairs(others) do
        table.insert(own, unit)
    end
    return own
end

-- Builds the string from the encoded records; `hash` is their checksum when the caller kept it while adding them.
local function ExportText(tokens, hash)
    local body = table.concat(tokens, ",")
    hash = hash or HashSlice(HASH_START, body, 1, #body)
    return ("OKF:%d:%d:%s:%s:END"):format(FORMAT, #tokens, CheckText(hash), body)
end
P.ExportText = ExportText

-- Starts an export of `store` (the game's when nil) in frame steps; false when a transfer runs. When it ends,
-- TransferState().export holds { text, records, bytes } (text nil when there is nothing to export).
function Share.Export(store)
    if transfer.state ~= "idle" then
        return false
    end
    store = store or ns.db.shared
    local function Failed()
        transfer.state, transfer.export = "idle", { text = nil, records = 0, bytes = 0 }
    end
    transfer.state, transfer.export = "exporting", nil
    local ok, order = ns.Safe("Share.Export", function()
        ns.CatchDB.FlushSeq()
        return ExportOrder(store)
    end)
    if not ok then
        Failed()
        return true
    end
    -- The checksum is kept while the records are added, one record per step, so no step hashes the whole text.
    local index, tokens, size, hash = 1, {}, HEADER_ROOM, HASH_START
    local ownPending = false -- the own record left out: its proof is still being built (a roll just now)
    local step
    local function Step()
        local clock = env.clock
        local started = clock and clock()
        local full = false
        local more = WithinBudget(clock, started, function()
            local unit = order[index]
            if not unit or full then
                return false
            end
            index = index + 1
            local record = Store.Get(store, unit)
            local data, problem = nil, nil
            if record then
                data, problem = Encoded(store, unit, record)
            end
            if problem == "proof not ready" then
                ownPending = true
            end
            if data then
                if size + #data + 1 > EXPORT_LIMIT then
                    full = true
                    return false
                end
                if #tokens > 0 then
                    hash = HashSlice(hash, ",", 1, 1)
                end
                hash = HashSlice(hash, data, 1, #data)
                table.insert(tokens, data)
                size = size + #data + 1
            end
            return order[index] ~= nil
        end)
        if more and not full then
            env.after(0, step)
            return
        end
        local text = #tokens > 0 and ExportText(tokens, hash) or nil
        transfer.state = "idle"
        transfer.export = { text = text, records = #tokens, bytes = text and #text or 0, ownPending = ownPending }
    end
    step = Guarded("Share.Export", Step, Failed)
    env.after(0, step)
    return true
end

---------------------------------------------------------------------------
-- Import (research R2, R4, R5)
---------------------------------------------------------------------------
-- The string's parts, or nil and the error ("empty", "cut", "format").
local function Parse(text)
    text = type(text) == "string" and text:gsub("%s+", "") or ""
    -- The string's start: "OKF:" and a format number, so text that only mentions OKF is not taken for one.
    local start = text:find("OKF:%d+:")
    if not start then
        return nil, "empty"
    end
    local finish = text:find(":END", start + 4, true)
    if not finish then
        return nil, "cut"
    end
    local body = text:sub(start + 4, finish - 1)
    -- The format first: a string of another version is told to update, whatever its size.
    local format, rest = body:match("^(%d+):(.*)$")
    if not format or tonumber(format) ~= FORMAT then
        return nil, "format"
    end
    if #body > EXPORT_LIMIT then
        return nil, "damaged" -- longer than any format 1 export: not a string of the addon
    end
    local count, check, tokenText = rest:match("^(%d+):(%w+):(.+)$")
    if not count then
        return nil, "cut"
    end
    local tokens = {}
    for token in tokenText:gmatch("[^,]+") do
        table.insert(tokens, token)
    end
    if tonumber(count) ~= #tokens or #tokens == 0 then
        return nil, "cut"
    end
    return { check = check, body = tokenText, tokens = tokens }
end
P.ParseTransfer = Parse

local function Finish(result)
    transfer.state, transfer.result, transfer.progress = "idle", result, nil
    transfer.resultSeq = (transfer.resultSeq or 0) + 1 -- the page tells a new result from one it already cleared
end

-- Stores one checked record and counts its answer. The mark is set first, so the index update the store's change
-- message runs sees it, and taken back when the record did not stay (research R5).
local function StoreRecord(store, record, tally)
    local marks = Marks(store)
    local unit = UnitOf(record)
    local hadMark = marks[unit] == true
    marks[unit] = true
    -- The same version held: the import confirms it without making it look fresh (seen orders eviction and export).
    local stored = store.records[unit]
    local seen = type(stored) == "table" and stored.seq == record.seq and tonumber(stored.seen) or env.time()
    local result, reason = Store.Accept(store, record, seen, nil, true)
    local kept
    if result == "new" or result == "newer" then
        Store.Evict(store)
        kept = store.records[unit] ~= nil
        if kept then
            tally.new = tally.new + 1
        else
            tally.refused = tally.refused + 1
        end
    elseif result == "same" or result == "older" then
        kept = true
        tally.known = tally.known + 1
        if not hadMark then
            Changed(store, { unit }) -- the record held before counts with sharing off from now on
        end
    elseif result == "refused" and reason == "already in the bundled data" then
        tally.known = tally.known + 1
    else
        tally.refused = tally.refused + 1
    end
    if not kept and not hadMark then
        marks[unit] = nil
    end
end

-- One record's work within the step budget: its decode and checks, or chunks of its chain walk. True when the record
-- is done (stored or counted), false while its chain still has links to walk.
local function ImportOne(store, item, tally, clock, started)
    if not item.verify then
        -- The exchange's own limits before anything is decoded (ShareProtocol.lua, the REC handler): one record's
        -- size and the Base64 alphabet, so a pasted token cannot inflate to a huge table in one frame.
        if #item.data > MAX_RECORD_BYTES or not item.data:find("^[A-Za-z0-9+/=]+$") then
            tally.refused = tally.refused + 1
            return true
        end
        local record = Share.Decode(item.data)
        local unit = UnitOf(record)
        if not unit then
            tally.refused = tally.refused + 1
            return true
        end
        if record.id == store.myID then
            tally.own = tally.own + 1
            return true
        end
        if ns.CatchDB.IsBlocked(record.id) or not ns.CatchDB.CheckRecord(record) then
            tally.refused = tally.refused + 1
            return true
        end
        local held = Store.HeldFor(store, record)
        if not (held and record.seq > held.seq) then
            StoreRecord(store, record, tally)
            return true
        end
        item.verify = { held = held, record = record }
    end
    local verify = item.verify
    local result
    WithinBudget(clock, started, function()
        local state
        result, state = ns.CatchDB.CheckVersion(verify.held, verify.record, PROOF_CHUNK, verify.state)
        verify.state = state
        return result == "more"
    end)
    if result == "more" then
        return false
    end
    if result == "ok" then
        StoreRecord(store, verify.record, tally)
    else
        tally.refused = tally.refused + 1
    end
    return true
end

-- Starts an import of `text` into `store` (the game's when nil) in frame steps; false and "busy" while a transfer
-- runs (the last result stays). A string that fails its parse or checksum stores nothing. Works whatever the sharing
-- switch says.
function Share.Import(text, store)
    if transfer.state ~= "idle" then
        return false, "busy"
    end
    store = store or ns.db.shared
    local parts, problem = Parse(text)
    if not parts then
        Finish({ error = problem })
        return true
    end
    transfer.state, transfer.result = "importing", nil
    transfer.progress = { done = 0, total = #parts.tokens }
    local tally = { new = 0, known = 0, own = 0, refused = 0 }
    local hash, at, index, item = HASH_START, 1, 1, nil
    local body = parts.body
    local recordStep, hashStep -- the guarded steps (Guarded), set below
    -- Records within the step budget: cheap ones (refused at once, already known) go several per step, so a string
    -- of many tiny tokens cannot hold the import for minutes; a record whose chain is walked keeps its own steps.
    local function RecordStep()
        local clock = env.clock
        local started = clock and clock()
        WithinBudget(clock, started, function()
            item = item or { data = parts.tokens[index] }
            -- Data no check foresaw must not stop the import or reach the player as a Lua error.
            local ok, done = pcall(ImportOne, store, item, tally, clock, started)
            if not ok then
                tally.refused, done = tally.refused + 1, true
            end
            if not done then
                return false -- the chain walk spent the step
            end
            item, index = nil, index + 1
            transfer.progress.done = index - 1
            return index <= #parts.tokens
        end)
        if index > #parts.tokens then
            Finish(tally)
        else
            env.after(0, recordStep)
        end
    end
    local function Failed()
        Finish({ error = "damaged" })
    end
    local function HashStep()
        local to = math.min(#body, at + HASH_SLICE - 1)
        hash = HashSlice(hash, body, at, to)
        at = to + 1
        if at <= #body then
            env.after(0, hashStep)
        elseif CheckText(hash) ~= parts.check then
            Finish({ error = "damaged" })
        else
            env.after(0, recordStep)
        end
    end
    recordStep, hashStep = Guarded("Share.Import", RecordStep, Failed), Guarded("Share.Import", HashStep, Failed)
    env.after(0, hashStep)
    return true
end

-- The transfer's state for /okf debug (English): the state, the last export's size and the last import's answer.
function Share.TransferLine()
    local export, result = transfer.export, transfer.result
    local exportText = export and ("%d records, %d bytes"):format(export.records, export.bytes) or "none"
    local resultText = "none"
    if result and result.error then
        resultText = result.error
    elseif result then
        resultText = ("new %d, known %d, own %d, refused %d"):format(result.new, result.known, result.own,
            result.refused)
    end
    local marks = 0
    for _ in pairs(Marks()) do
        marks = marks + 1
    end
    return ("transfer: %s; last export %s; last import %s; imported marks %d"):format(transfer.state, exportText,
        resultText, marks)
end
