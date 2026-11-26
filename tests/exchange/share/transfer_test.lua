-- ShareTransfer.lua: the export string and the import (specs/027-import-export, contracts/export-string.md): the
-- order and the format, the round trip, the answers, the refusals, the marks and the frame steps.
-- The tests run in order and share one login.

local FISH = 6291
local A, B, C, D, E = "aaaaaaaa", "baaaaaab", "caaaaaac", "daaaaaad", "eaaaaaae"

OneKeyFishingDB = { shareNotice = true, settings = { shareDB = true } }
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()

local Share, Store, P = ns.Share, ns.Share.Store, ns.Share.private
local shared = ns.db.shared
local ALL = { range = 3, source = "all" }

-- A record with one cell on map 1415 (as Share's store test makes them).
local function rec(id, epoch, seq, catches)
    local cells = { ["1415:3:47"] = catch_cell(math.max(2, catches or seq), 1, { [FISH] = { 2, 2 } }) }
    seq = math.max(seq, math.ceil(cells["1415:3:47"].t / ns.CatchDB.private.STEP_SECONDS))
    return prove({ id = id, epoch = epoch, seq = seq, builds = { ["1.60.1"] = cells } }, nil, 4096)
end

local function token(record)
    return Share.Encode(Store.ForSending(record))
end

local function tokensOf(text)
    local body = text:match("^OKF:%d+:%d+:%w+:(.*):END$")
    local list = {}
    for item in body:gmatch("[^,]+") do
        table.insert(list, item)
    end
    return list
end

-- Runs the frame steps until the transfer is idle (the exchange's own timers keep running, so no flush_timers).
local function settle()
    for _ = 1, 5000 do
        if Share.TransferState().state == "idle" then
            return
        end
        advance(0)
    end
    error("the transfer did not end")
end

local function export()
    assert(Share.Export(), "the export started")
    settle()
    return Share.TransferState().export
end

local function import(text, store)
    Share.Import(text, store)
    settle()
    return Share.TransferState().result
end

-- Deletes the other players' records (an empty store but for the own record).
local function dropOthers()
    local keys = {}
    for key in pairs(shared.records) do
        if key ~= shared.myID and ns.CatchDB.IsOtherKey(key) and ns.CatchDB.ParseUnit(key) ~= shared.myID then
            shared.records[key] = nil
            table.insert(keys, key)
        end
    end
    shared.imported = {}
    ns.Fire("SHARED_DATA_CHANGED", keys, shared)
end

fish_cast({ { FISH, 1 } })
advance(5)
eq(Store.Accept(shared, rec(A, 1, 3), 100), "new", "A stored")
eq(Store.Accept(shared, rec(B, 1, 3), 300), "new", "B stored")
eq(Store.Accept(shared, rec(C, 1, 3), 200), "new", "C stored")

local fullText

test("an export holds the own record first, then the others by seen, newest first", function()
    local result = export()
    assert(result and result.text, "a string")
    fullText = result.text
    eq(result.records, 4, "four records")
    eq(result.bytes, #fullText, "its size")
    assert(fullText:find("^OKF:1:4:%w+:"), "the header: format 1, four records")
    assert(fullText:find(":END$"), "the end marker")
    local ids = {}
    for _, item in ipairs(tokensOf(fullText)) do
        table.insert(ids, Share.Decode(item).id)
    end
    eq(table.concat(ids, " "), table.concat({ shared.myID, B, C, A }, " "), "the order")
    eq(Share.Decode(tokensOf(fullText)[2]).seen, nil, "seen is not exported")
    assert(#fullText <= Share.EXPORT_LIMIT, "under the limit")
end)

test("the check is Share.Hash over the tokens", function()
    local check, body = fullText:match("^OKF:1:4:(%w+):(.*):END$")
    eq(check, ns.Base32(Share.Hash(body), 7), "the checksum")
    eq(P.HashSlice(P.HashSlice(5381, body, 1, 100), body, 101, #body), Share.Hash(body), "in slices, the same")
end)

test("an import into a store without those records brings them back, field by field", function()
    local before = shared.records[B .. "@1"]
    dropOthers()
    eq(ns.CatchDB.Query(1415, "47", ALL).players, 1, "only the own catch left")
    local result = import(fullText)
    eq(result.new, 3, "three new")
    eq(result.own, 1, "the own record")
    eq(result.known + result.refused, 0, "nothing else")
    local after = shared.records[B .. "@1"]
    eq(after.seq, before.seq, "seq")
    eq(after.proof, before.proof, "proof")
    eq(ns.CatchDB.Query(1415, "47", ALL).players, 4, "the three players count again")
    assert(Share.IsImported(B .. "@1"), "marked as imported")
end)

test("the same string a second time brings nothing new", function()
    local result = import(fullText)
    eq(result.new, 0, "none new")
    eq(result.known, 3, "three known")
    eq(result.own, 1, "own")
end)

test("a record held before is marked by an import of it", function()
    eq(Store.Accept(shared, rec(D, 1, 3), 400), "new", "D from the exchange")
    assert(not Share.IsImported(D .. "@1"), "not marked")
    local result = import(P.ExportText({ token(rec(D, 1, 3)) }))
    eq(result.known, 1, "known")
    assert(Share.IsImported(D .. "@1"), "now marked")
end)

test("whitespace and text around the string are ignored", function()
    dropOthers()
    local wrapped = fullText:gsub("(" .. ("."):rep(60) .. ")", "%1\n  ")
    local result = import("Here is my data:\n" .. wrapped .. "\nthanks!")
    eq(result.new, 3, "read whole")
end)

test("a string without markers, cut, of another format or damaged stores nothing", function()
    dropOthers()
    eq(import("hello there").error, "empty", "no marker")
    eq(import(fullText:sub(1, -5)).error, "cut", "no end")
    local lastComma = #fullText - (fullText:reverse():find(",", 1, true) or 0) + 1
    eq(import(fullText:sub(1, lastComma - 1) .. ":END").error, "cut", "fewer tokens than the count")
    eq(import((fullText:gsub("^OKF:1:", "OKF:2:"))).error, "format", "a newer format")
    eq(import((fullText:gsub("^OKF:1", "OKF:one"))).error, "empty", "no format number: not a string of the addon")
    local at = #fullText - 40
    local changed = fullText:sub(1, at - 1) .. (fullText:sub(at, at) == "A" and "B" or "A") .. fullText:sub(at + 1)
    eq(import(changed).error, "damaged", "one changed character")
    eq(shared.records[A .. "@1"], nil, "nothing stored")
    eq(next(shared.imported), nil, "no mark")
end)

test("in a valid string, a forged record is refused and the rest imported", function()
    dropOthers()
    local bad = rec(E, 1, 3)
    bad.builds["1.60.1"]["1415:3:47"].c = 999 -- more casts than seconds of casting
    local broken = rec(D, 1, 3)
    broken.proof = "AAAAAAAAAAAAAAAA" -- not its chain
    local result = import(P.ExportText({ token(rec(A, 1, 3)), token(bad), "notbase64!", token(broken) }))
    eq(result.new, 1, "A")
    eq(result.refused, 3, "the impossible numbers, the junk and the broken proof")
    eq(shared.records[E .. "@1"], nil, "not stored")
    assert(not Share.IsImported(E .. "@1"), "no mark on a refused record")
end)

test("a newer version must continue the chain of the version held", function()
    dropOthers()
    eq(import(P.ExportText({ token(rec(A, 1, 3)) })).new, 1, "seq 3")
    local newer = rec(A, 1, 40, 40)
    eq(import(P.ExportText({ token(newer) })).new, 1, "seq 40 on the same chain")
    eq(shared.records[A .. "@1"].seq, newer.seq, "replaced")
    local forged = prove({ id = A, epoch = 1, seq = 80, builds = newer.builds }, "another secret", 4096)
    eq(import(P.ExportText({ token(forged) })).refused, 1, "another chain")
    eq(shared.records[A .. "@1"].seq, newer.seq, "kept")
end)

test("a second import while one runs is refused as busy", function()
    dropOthers()
    assert(Share.Import(fullText), "the first starts")
    eq(Share.TransferState().state, "importing", "running")
    local started, why = Share.Import(fullText)
    eq(started, false, "the second is refused")
    eq(why, "busy", "and says why")
    eq(Share.TransferState().result, nil, "the running import's result is not overwritten")
    settle()
    eq(Share.TransferState().result.new, 3, "the first finished")
end)

test("an import runs in frame steps, one record per step", function()
    dropOthers()
    local list = {}
    for i = 1, 12 do
        table.insert(list, token(rec(ns.BASE32:sub(i + 4, i + 4):rep(8), 1, 3)))
    end
    -- A scheduler of its own: each call of the queue's front is one frame step.
    local queue, after = {}, P.transferEnv.after
    P.transferEnv.after = function(_, fn) table.insert(queue, fn) end
    profile_ms, profile_step = 0, 5 -- every record takes 5 ms on the clock: one record per step within the 4 ms budget
    assert(Share.Import(P.ExportText(list)), "started")
    eq(Share.TransferState().progress.total, 12, "twelve records")
    local steps = 0
    while #queue > 0 do
        table.remove(queue, 1)()
        steps = steps + 1
        if steps == 3 then
            local done = Share.TransferState().progress.done
            assert(done >= 1 and done < 12, "a few records after three steps, not all: " .. tostring(done))
        end
    end
    P.transferEnv.after = after
    profile_ms, profile_step = nil, nil
    assert(steps >= 13, "the checksum and one step per record: " .. steps)
    eq(Share.TransferState().result.new, 12, "all in the end")
end)

test("with sharing off, an import still works and the export holds the own and the imported records", function()
    dropOthers()
    Store.Accept(shared, rec(C, 1, 3), 500) -- from the exchange
    ns.Share.SetEnabled(false)
    eq(ns.CatchDB.Query(1415, "47", ALL).players, 1, "with sharing off only the own catch counts")
    eq(import(P.ExportText({ token(rec(A, 1, 3)) })).new, 1, "imported with sharing off")
    eq(ns.CatchDB.Query(1415, "47", ALL).players, 2, "the imported record counts at once, C still does not")
    local result = export()
    local ids = {}
    for _, item in ipairs(tokensOf(result.text)) do
        table.insert(ids, Share.Decode(item).id)
    end
    eq(table.concat(ids, " "), shared.myID .. " " .. A, "the own record and the imported one, not C")
    ns.Share.SetEnabled(true)
end)

test("an export stops below the size limit", function()
    local tokens, size = {}, 0
    for _ = 1, 40 do
        local item = ("Q"):rep(8000)
        table.insert(tokens, item)
        size = size + #item
    end
    assert(size > Share.EXPORT_LIMIT, "the test's tokens are over the limit")
    -- The real export: a store whose records together pass the limit gives a string under it.
    dropOthers()
    for i = 1, 400 do
        local id = ("%08d"):format(i):gsub("%d", function(d) return ns.BASE32:sub(d + 1, d + 1) end)
        local record = rec(id, 1, 3)
        for j = 1, 30 do
            record.builds["1.60.1"][(3000 + j) .. ":0:x"] = catch_cell(1, 0)
        end
        record.seq = math.max(record.seq, 40)
        Store.Accept(shared, prove(record, nil, 4096), 600 + i)
    end
    local result = export()
    assert(result.text and #result.text <= Share.EXPORT_LIMIT, "under the limit: " .. tostring(result.bytes))
    assert(result.records < 401, "not every record: " .. result.records)
end)

test("the debug report has the transfer's line", function()
    local _, report = ns.Debug.Report()
    assert(report:find("transfer: idle; last export %d+ records"), "the transfer line")
    assert(report:find("session rules: gap 120 s, stranger chance default, offer others true", 1, true), "rules")
end)

test("a record whose version the bundled data holds whole is known, not stored", function()
    dropOthers()
    local held = rec(E, 1, 3)
    ns.SeedData.absorbed[E] = { [1] = held.seq } -- the seed holds this version whole (data-model: absorbed)
    local result = import(P.ExportText({ token(held) }))
    eq(result.known, 1, "known")
    eq(result.new, 0, "not new")
    eq(shared.records[E .. "@1"], nil, "not stored")
    eq(shared.imported[E .. "@1"], nil, "no mark")
    ns.SeedData.absorbed[E] = nil
end)

test("a token over the record limit or outside Base64 is refused before anything is decoded", function()
    dropOthers()
    local decodeCalls, decode = 0, Share.Decode
    Share.Decode = function(text)
        decodeCalls = decodeCalls + 1
        return decode(text)
    end
    local result = import(P.ExportText({ ("A"):rep(P.MAX_RECORD_BYTES + 4), "no~base64", token(rec(A, 1, 3)) }))
    Share.Decode = decode
    eq(result.refused, 2, "the oversized and the junk token")
    eq(result.new, 1, "the valid record")
    eq(decodeCalls, 1, "only the valid token was decoded")
end)

test("text that only mentions OKF before the string is not taken for a newer format", function()
    dropOthers()
    local result = import("my OKF: export is below, " .. fullText)
    eq(result.error, nil, "read")
    eq(result.new, 3, "the records")
end)

test("a mark goes with its record, whoever deletes it", function()
    dropOthers()
    eq(import(P.ExportText({ token(rec(A, 1, 3)) })).new, 1, "imported")
    assert(Share.IsImported(A .. "@1"), "marked")
    shared.records[A .. "@1"] = nil -- as Store.Evict, CleanUp or a failed chain delete it
    P.Changed(shared, { A .. "@1" })
    eq(shared.imported[A .. "@1"], nil, "the mark went with it")
    Store.Accept(shared, rec(A, 1, 3), 900) -- the same record again, now through the exchange
    assert(not Share.IsImported(A .. "@1"), "not counted as imported")
end)

test("cheap records go several per step: a string of many tiny tokens does not hold the import for minutes", function()
    dropOthers()
    local list = {}
    for i = 1, 300 do
        list[i] = "QQ" .. i % 10 -- Base64 junk, refused at once
    end
    local queue, after = {}, P.transferEnv.after
    P.transferEnv.after = function(_, fn) table.insert(queue, fn) end
    profile_ms = 0 -- a clock that does not move: the cheap records stay within the budget
    assert(Share.Import(P.ExportText(list)), "started")
    local steps = 0
    while #queue > 0 do
        table.remove(queue, 1)()
        steps = steps + 1
    end
    P.transferEnv.after, profile_ms = after, nil
    eq(Share.TransferState().result.refused, 300, "all refused")
    assert(steps < 10, "in a few steps, not 300: " .. steps)
end)

test("a text longer than any export is refused whole", function()
    eq(import(P.ExportText({ ("A"):rep(Share.EXPORT_LIMIT + 10) })).error, "damaged", "too long")
end)

test("a string of another format is told to update, also when it is longer than format 1 allows", function()
    local long = P.ExportText({ ("A"):rep(Share.EXPORT_LIMIT + 10) }):gsub("^OKF:1:", "OKF:2:")
    eq(import(long).error, "format", "format before size")
end)

test("an error in an export step puts the transfer back to idle instead of leaving it busy", function()
    local forSending = Store.ForSending
    Store.ForSending = function() error("odd record") end
    local result = export()
    Store.ForSending = forSending
    take_errors() -- the error went to the error log and the game's handler
    eq(Share.TransferState().state, "idle", "idle again")
    eq(result.text, nil, "no string")
    assert(export().text, "the next export works")
end)

test("eviction takes records the player did not import first", function()
    dropOthers()
    -- 20 exchange records of 1,000 places each (the most one record may hold) fill the 20,000 the store keeps; one
    -- small imported record puts it over.
    local function big(i)
        local id = ns.BASE32:sub(i, i) .. ns.BASE32:sub(i + 1, i + 1):rep(7)
        local record = rec(id, 1, 3)
        for j = 1, 999 do
            record.builds["1.60.1"][(3000 + j) .. ":0:x"] = catch_cell(1, 0)
        end
        record.seq = 1000
        return prove(record, nil, 4096), id
    end
    -- Seen after the import's time: by class and seen alone, the imported record would be the one to go.
    for i = 1, 20 do
        eq(Store.Accept(shared, (big(i)), time() + 1000 + i), "new", "exchange record " .. i)
    end
    local id = "zzzzzzz2"
    eq(import(P.ExportText({ token(rec(id, 1, 3)) })).new, 1, "imported and kept")
    assert(shared.records[id .. "@1"], "the imported record stayed")
    local others = 0
    for key in pairs(shared.records) do
        if ns.CatchDB.IsOtherKey(key) and key ~= id .. "@1" then
            others = others + 1
        end
    end
    eq(others, 19, "an exchange record went instead")
end)

test("an export while the own record's proof is still being built says so, not that nothing was caught", function()
    dropOthers()
    local own = shared.records[shared.myID]
    local proof = own.proof
    own.proof = nil -- the chain's marks still being built, as right after a roll
    local result = export()
    own.proof = proof
    eq(result.ownPending, true, "the own record was left out for now")
    eq(result.text, nil, "nothing else to export")
    eq(export().ownPending, false, "once the proof is ready it goes again")
end)

