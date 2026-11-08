-- The error log (Core.lua): ns.Safe, the protected dispatchers, the log's cap and repeats, the report section.

load_addon()

-- The clock of the log in this file (its own Lua state): tests move it by setting `clock`.
local clock = 1800000000
time = function()
    return clock
end
local STAMP = "%Y-%m-%d %H:%M:%S"

local function ClearLog()
    wipe(ns.GetErrors())
end

-- One failure under `context` with the plain message `text`, taken from the handler's list.
local function FailAs(context, text)
    ns.Safe(context, error, text, 0)
    take_errors()
end

local function Lines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

test("ns.Safe passes every argument, trailing nils too, and returns the results", function()
    ClearLog()
    local seen
    local results = { ns.Safe("ctx", function(...)
        seen = { n = select("#", ...), ... }
        return "a", nil, "c"
    end, 1, nil, 3, nil) }
    eq(seen.n, 4, "argument count")
    eq(seen[1], 1)
    eq(seen[2], nil)
    eq(seen[3], 3)
    eq(results[1], true, "ok")
    eq(results[2], "a")
    eq(results[4], "c")
    eq(#ns.GetErrors(), 0, "nothing recorded")
end)

test("a failure is recorded once and handed to the game's error handler once", function()
    ClearLog()
    local ok, err = ns.Safe("ctx", function()
        error("boom")
    end)
    eq(ok, false)
    assert(tostring(err):find("boom", 1, true), "the error comes back: " .. tostring(err))
    local handled = take_errors()
    eq(#handled, 1, "handed on once")
    assert(handled[1]:find("errors_test.lua:%d+: boom"), "with its file and line: " .. handled[1])
    local log = ns.GetErrors()
    eq(#log, 1, "one entry")
    local entry = log[1]
    eq(entry.context, "ctx")
    eq(entry.message, handled[1])
    eq(entry.version, ns.version)
    eq(entry.count, 1)
    eq(entry.first, clock, "first")
    eq(entry.last, clock, "last")
    local stack = Lines(entry.stack:gsub("\n$", ""))
    assert(#stack >= 1 and #stack <= 10, "1 to 10 stack lines, got " .. #stack)
    assert(entry.stack:find("errors_test.lua", 1, true), "the stack holds the failing function: " .. entry.stack)
end)

test("the game's handler runs with the error stack height set, which is cleared afterwards", function()
    ClearLog()
    local seen
    local realHandler = geterrorhandler
    geterrorhandler = function()
        return function()
            seen = GetErrorCallstackHeight()
        end
    end
    ns.Safe("ctx", error, "x", 0)
    geterrorhandler = realHandler
    assert(type(seen) == "number" and seen > 0, "a height while the handler runs: " .. tostring(seen))
    eq(GetErrorCallstackHeight(), nil, "cleared afterwards")
end)

test("an error that is not text is recorded as its text form", function()
    ClearLog()
    ns.Safe("ctx", function()
        error({})
    end)
    take_errors()
    assert(ns.GetErrors()[1].message:find("^table:"), ns.GetErrors()[1].message)
end)

test("a failing recording still hands the error on", function()
    ClearLog()
    local clockStub = time
    time = function()
        error("no clock")
    end
    local ok = ns.Safe("ctx", function()
        error("boom")
    end)
    time = clockStub
    eq(ok, false)
    local handled = take_errors()
    eq(#handled, 1, "handed on once")
    assert(handled[1]:find("boom", 1, true), handled[1])
    eq(#ns.GetErrors(), 0, "nothing recorded")
end)

test("a failure after a nested ns.Safe is recorded under the outer context", function()
    ClearLog()
    ns.Safe("OUTER", function()
        ns.Safe("INNER", function() end)
        error("outer fails", 0)
    end)
    take_errors()
    eq(ns.GetErrors()[1].context, "OUTER")
end)

-- Three handlers, the second failing; returns the calls the others saw.
local function ThreeHandlers(register)
    local calls = {}
    register(function(...)
        table.insert(calls, { "first", select("#", ...), ... })
    end)
    register(function()
        error("second fails")
    end)
    register(function(...)
        table.insert(calls, { "third", select("#", ...), ... })
    end)
    return calls
end

test("a failing listener of a message does not keep the next ones from it", function()
    ClearLog()
    local calls = ThreeHandlers(function(fn)
        ns.On("TEST_ERRORS_MESSAGE", fn)
    end)
    ns.Fire("TEST_ERRORS_MESSAGE", "a", nil, "c")
    eq(#calls, 2, "first and third ran")
    eq(calls[1][1], "first")
    eq(calls[2][1], "third")
    for _, call in ipairs(calls) do
        eq(call[2], 3, "argument count")
        eq(call[3], "a")
        eq(call[4], nil)
        eq(call[5], "c")
    end
    eq(#take_errors(), 1, "handed on once")
    eq(#ns.GetErrors(), 1)
    eq(ns.GetErrors()[1].context, "TEST_ERRORS_MESSAGE")
end)

test("a failing handler of an event does not keep the next ones from it", function()
    ClearLog()
    local calls = ThreeHandlers(function(fn)
        ns.RegisterEvent("TEST_ERRORS_EVENT", fn)
    end)
    fire("TEST_ERRORS_EVENT", 1)
    eq(#calls, 2, "first and third ran")
    for _, call in ipairs(calls) do
        eq(call[2], 2, "argument count")
        eq(call[3], "TEST_ERRORS_EVENT")
        eq(call[4], 1)
    end
    eq(#take_errors(), 1, "handed on once")
    eq(ns.GetErrors()[1].context, "TEST_ERRORS_EVENT")
end)

test("a failing slash command is recorded under its name", function()
    ClearLog()
    local command = { name = "zzfail", description = "fails", run = function(rest)
        error("command fails with " .. rest)
    end }
    table.insert(ns.COMMANDS, command)
    SlashCmdList.ONEKEYFISHING("zzfail x")
    table.remove(ns.COMMANDS)
    local handled = take_errors()
    eq(#handled, 1, "handed on once")
    assert(handled[1]:find("command fails with x", 1, true), handled[1])
    eq(ns.GetErrors()[1].context, "/okf zzfail")
end)

test("a listener whose own message fails: the inner failure is recorded once, the outer listeners run", function()
    ClearLog()
    local ran = {}
    ns.On("TEST_ERRORS_INNER", function()
        error("inner fails")
    end)
    ns.On("TEST_ERRORS_OUTER", function()
        ns.Fire("TEST_ERRORS_INNER")
        table.insert(ran, "outer first")
    end)
    ns.On("TEST_ERRORS_OUTER", function()
        table.insert(ran, "outer second")
    end)
    ns.Fire("TEST_ERRORS_OUTER")
    eq(table.concat(ran, ", "), "outer first, outer second")
    eq(#take_errors(), 1, "handed on once")
    eq(#ns.GetErrors(), 1)
    eq(ns.GetErrors()[1].context, "TEST_ERRORS_INNER")
end)

-- The lines of the report's "Errors" section, without the header; it is the last section of the report.
local function ErrorsSection()
    local _, text = ns.Debug.Report()
    local lines, inside = {}, false
    for _, line in ipairs(Lines(text)) do
        assert(not (inside and line:find("^%-%- ")), "no section after Errors: " .. line)
        if inside and line ~= "" then
            table.insert(lines, line)
        end
        inside = inside or line == "-- Errors --"
    end
    assert(inside, "the report has an Errors section")
    return lines
end

test("the report's Errors section reads none on an empty log", function()
    ClearLog()
    local lines = ErrorsSection()
    eq(#lines, 1)
    eq(lines[1], "  none")
end)

test("the report's Errors section lists the newest entry first, with its count, times and stack", function()
    ClearLog()
    FailAs("TEST_REPORT", "older")
    clock = clock + 60
    FailAs("TEST_REPORT", "newer")
    FailAs("TEST_REPORT", "newer")
    local lines = ErrorsSection()
    eq(lines[1], ("  2x TEST_REPORT, %s, %s"):format(date(STAMP, clock), ns.version), "one time when first equals last")
    eq(lines[2], "    newer")
    assert(lines[3]:find("^    .*%S"), "a stack line, indented: " .. tostring(lines[3]))
    local olderAt
    for i, line in ipairs(lines) do
        if line:find("^  1x TEST_REPORT") then
            olderAt = i
        end
    end
    assert(olderAt and olderAt > 3, "the older entry after the newer one")
    eq(lines[olderAt + 1], "    older")
end)

test("the report shows both times when an error repeated later", function()
    ClearLog()
    FailAs("TEST_REPORT", "again")
    clock = clock + 5
    FailAs("TEST_REPORT", "again")
    eq(ErrorsSection()[1], ("  2x TEST_REPORT, %s to %s, %s"):format(date(STAMP, clock - 5), date(STAMP, clock),
        ns.version))
end)

test("a repeated error is counted into its entry, which becomes the newest", function()
    ClearLog()
    local start = clock
    FailAs("A", "same")
    clock = clock + 10
    FailAs("B", "other")
    FailAs("A", "same")
    local log = ns.GetErrors()
    eq(#log, 2)
    eq(log[2].context, "A", "the repeat is the newest")
    eq(log[2].count, 2)
    eq(log[2].first, start, "first stays")
    eq(log[2].last, clock, "last moves")
end)

test("the same message under two contexts is two entries", function()
    ClearLog()
    FailAs("A", "same")
    FailAs("B", "same")
    eq(#ns.GetErrors(), 2)
end)

test("the log keeps 30 entries; the least recently seen goes first", function()
    ClearLog()
    for i = 1, 35 do
        FailAs("CAP", "error " .. i)
    end
    local log = ns.GetErrors()
    eq(#log, 30, "capped")
    eq(log[1].message, "error 6", "the first five are gone")
    FailAs("CAP", "error 6") -- seen again: the newest now
    FailAs("CAP", "error 36")
    eq(#log, 30)
    eq(log[1].message, "error 8", "error 7 was the least recently seen")
    eq(log[29].message, "error 6")
    eq(log[30].message, "error 36")
end)

test("an error repeated many times stays one entry", function()
    ClearLog()
    for _ = 1, 1000 do
        FailAs("FLOOD", "every frame")
    end
    eq(#ns.GetErrors(), 1)
    eq(ns.GetErrors()[1].count, 1000)
end)

test("ForgetErrors removes only the entries its function accepts and returns their count (spec 010)", function()
    ClearLog()
    FailAs("spike", "OneKeyFishing spike test error")
    FailAs("LOOT_READY", "a real error")
    FailAs("spike", "another spike test")
    eq(ns.ForgetErrors(function(entry) return entry.context == "spike" end), 2, "two removed")
    local log = ns.GetErrors()
    eq(#log, 1, "one left")
    eq(log[1].context, "LOOT_READY", "the other context stays")
    eq(ns.ForgetErrors(function() return false end), 0, "none")
    ClearLog()
end)
