-- A 1.4.0 client and the camp bonus parts (specs/020-camp-buffs FR-011, research R5): it rebuilds a received cell
-- from its own field list, so q is dropped; the totals stay, and the stripped record still passes the check under
-- the same seq, because the parts are inclusive.

local FISH, BLOATED = 6291, 6643
load_addon()

-- 1.4.0's CleanCell (Exchange/Share.lua of release 1.4.0), its field list copied: c, m, t, px, py, i, p, a.
local function CleanItems140(items)
    local out = {}
    for itemID, entry in pairs(items or {}) do
        out[itemID] = { entry[1], entry[2] }
    end
    return out
end

local function CleanCell140(cell)
    local out = { c = cell.c, m = cell.m, t = cell.t, px = cell.px, py = cell.py, i = CleanItems140(cell.i) }
    if cell.p then
        out.p = { c = cell.p.c, i = CleanItems140(cell.p.i) }
    end
    if cell.a then
        out.a = {}
        for areaID, count in pairs(cell.a) do
            out.a[areaID] = count
        end
    end
    return out
end

test("a cell with parts, cleaned by 1.4.0, keeps its totals and passes the check under the same seq", function()
    local cell = catch_cell(10, 4, { [FISH] = { 8, 8 }, [BLOATED] = { 2, 2 } })
    cell.q = { ["1"] = { c = 3, m = 1, i = { [BLOATED] = { 2, 2 }, [FISH] = { 1, 1 } } } }
    local record = prove({ id = "qqqqqqqq", epoch = 0, seq = 14, builds = { ["1.60.1"] = { ["1415:3:47"] = cell } } })
    eq((ns.CatchDB.CheckRecord(record)), true, "the record with parts")
    local old = CleanCell140(cell)
    eq(old.q, nil, "q dropped")
    eq(old.c, 10, "catches")
    eq(old.m, 4, "misses")
    eq(old.i[BLOATED][1], 2, "items")
    local stripped = prove({ id = "qqqqqqqq", epoch = 0, seq = 14, builds = { ["1.60.1"] = { ["1415:3:47"] = old } } })
    local ok, reason = ns.CatchDB.CheckRecord(stripped)
    eq(ok, true, tostring(reason))
    eq(stripped.seq, 14, "seq unchanged")
end)
