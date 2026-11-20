-- The check of a received record's bonus parts (specs/020-camp-buffs FR-009, FR-012, data-model.md "Validation"):
-- a part keyed by a mask's text, within the totals, its items in the cell; the rest (the cell minus the parts) holds
-- the item rules. A mask with bits this version does not know is valid.

local FISH, BLOATED = 6291, 6643
local RACK = 1280341

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()
local CatchDB = ns.CatchDB

-- A record of one cell at 1415:3:47: 10 catches (8 with the fish, 2 with a Bloated fish), 4 misses, and q.
local function record(q, cell)
    cell = cell or catch_cell(10, 4, { [FISH] = { 8, 8 }, [BLOATED] = { 2, 2 } })
    cell.q = q
    return prove({ id = "rrrrrrrr", epoch = 0, seq = 1, builds = { ["1.60.1"] = { ["1415:3:47"] = cell } } })
end

local function check(q, cell)
    return CatchDB.CheckRecord(record(q, cell))
end

local function part(c, m, items)
    return { c = c, m = m, i = items or {} }
end

test("valid parts pass; a cell without q passes", function()
    eq((check(nil)), true, "no q")
    eq((check({ ["1"] = part(3, 1, { [BLOATED] = { 2, 2 }, [FISH] = { 1, 1 } }) })), true, "one part")
    eq((check({ ["1"] = part(2, 1), ["3"] = part(1, 1, { [FISH] = { 1, 1 } }) })), true, "two parts")
    eq((check({ ["4"] = part(1, 0), ["255"] = part(1, 0) })), true, "unknown bits")
end)

test("each broken rule is refused with its reason", function()
    local cases = {
        { "x", "the bonus parts are not a table" },
        { { ["1"] = part(1, 0), ["2"] = part(1, 0), ["3"] = part(1, 0), ["4"] = part(1, 0), ["5"] = part(1, 0),
            ["6"] = part(1, 0), ["7"] = part(1, 0), ["8"] = part(1, 0), ["9"] = part(1, 0) }, "too many bonus parts" },
        { { [1] = part(1, 0) }, "bonus part 1: not a mask" },
        { { ["0"] = part(1, 0) }, "bonus part 0: not a mask" },
        { { ["256"] = part(1, 0) }, "bonus part 256: not a mask" },
        { { ["01"] = part(1, 0) }, "bonus part 01: not a mask" },
        { { ["1.5"] = part(1, 0) }, "bonus part 1.5: not a mask" },
        { { ["x"] = part(1, 0) }, "bonus part x: not a mask" },
        { { ["1"] = 5 }, "bonus part 1: not a part" },
        { { ["1"] = part(-1, 0) }, "bonus part 1: not a part" },
        { { ["1"] = part(1, 0.5) }, "bonus part 1: not a part" },
        { { ["1"] = part(11, 0) }, "the bonus parts do not fit the totals" },
        { { ["1"] = part(6, 0), ["2"] = part(5, 0) }, "the bonus parts do not fit the totals" },
        { { ["1"] = part(0, 3), ["3"] = part(0, 2) }, "the bonus parts do not fit the totals" },
        { { ["1"] = part(2, 0, { [6303] = { 1, 1 } }) }, "no bonus: item 6303 has impossible counts" },
        { { ["1"] = part(2, 0, { [BLOATED] = { 3, 3 } }) }, "bonus part 1: item 6643 has impossible counts" },
        -- More catches of the Bloated fish in the part than in the cell.
        { { ["1"] = part(3, 0, { [BLOATED] = { 3, 3 }, [FISH] = { 1, 1 } }) },
            "no bonus: item 6643 has impossible counts" },
        -- The rest: 2 catches outside the parts, but 3 of them with the fish.
        { { ["1"] = part(8, 0, { [FISH] = { 5, 5 } }) }, "no bonus: item 6291 has impossible counts" },
    }
    for i, case in ipairs(cases) do
        local ok, reason = check(case[1])
        eq(ok, false, "case " .. i)
        eq(reason, "1415:3:47: " .. case[2], "reason " .. i)
    end
end)

test("the own record written under a bonus passes the check", function()
    auras[RACK] = { expirationTime = GetTime() + 3000, duration = 3600 }
    fire("UNIT_AURA", "player")
    fish_cast({ { BLOATED, 1 }, { FISH, 1 } })
    fish_cast(nil)
    auras[1280342] = { expirationTime = GetTime() + 3000, duration = 3600 }
    fire("UNIT_AURA", "player")
    fish_cast({ { FISH, 2 } })
    local shared = ns.db.shared
    local own = shared.records[shared.myID]
    local copy = { id = "wwwwwwww", epoch = own.epoch, seq = 1, builds = own.builds }
    local ok, reason = CatchDB.CheckRecord(prove(copy))
    eq(ok, true, tostring(reason))
    assert(own.builds["1.60.1"]["1415:3:47"].q["3"], "the part of both")
end)
