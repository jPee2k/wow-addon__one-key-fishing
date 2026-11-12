-- Fishing/Mode.lua: Mode.CVAR_NAMES lists the CVars fishing mode may change, and the debug report shows each of
-- them from that one list (specs/008-architecture-alignment research R8).

load_addon()

test("the debug report's Game settings show every CVar of Mode.CVAR_NAMES", function()
    local names = ns.Mode.CVAR_NAMES
    eq(#names, 4, "the soft-target interact, auto loot and the two interact icons")
    local _, report = ns.Debug.Report()
    for _, name in ipairs(names) do
        assert(report:find(name .. " = ", 1, true), name .. " in the report:\n" .. report)
    end
end)
