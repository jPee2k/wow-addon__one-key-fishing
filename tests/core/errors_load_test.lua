-- The error log across the load (Core.lua): an error before the saved variables load is kept, and entries of
-- another addon version are dropped. Its own file: these need the addon before ADDON_LOADED.

load_files(TOC_FILES)
ns.Safe("EARLY", function()
    error("before the saved variables")
end)
local early = take_errors()
fire("ADDON_LOADED", "OneKeyFishing")

local function Entry(version, context, count)
    return { context = context, message = context .. " failed", stack = "", version = version, first = 1, last = 2,
        count = count }
end

test("an error before ADDON_LOADED is handed on and kept in the saved log", function()
    eq(#early, 1, "handed on once")
    eq(ns.GetErrors(), OneKeyFishingDB.errors, "the log is the saved field")
    eq(#OneKeyFishingDB.errors, 1)
    eq(OneKeyFishingDB.errors[1].context, "EARLY")
end)

test("entries of another version are dropped on load; the ones in memory join the saved ones", function()
    local memory = ns.GetErrors() -- the log of the last load stands for errors recorded before this one
    wipe(memory)
    table.insert(memory, Entry(ns.version, "SAME", 2))
    table.insert(memory, Entry(ns.version, "NEW", 1))
    OneKeyFishingDB = { schema = 1, errors = { Entry("0.9.0", "OLD", 5), Entry(ns.version, "SAME", 3) } }
    fire("ADDON_LOADED", "OneKeyFishing")
    local log = ns.GetErrors()
    eq(log, OneKeyFishingDB.errors, "the log is the new saved field")
    eq(#log, 2, "the old version's entry is gone")
    eq(log[1].context, "SAME")
    eq(log[1].count, 5, "the counts are added")
    eq(log[2].context, "NEW")
end)
