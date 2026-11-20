-- Percentages (specs/020-camp-buffs FR-029, FR-030, research R9): a whole number from 10% up, one decimal from 1%,
-- two decimals below, "<0.01%" for a share too small to show, "0%" only for nothing.

load_addon()

local cases = {
    { 0.374, "37%" }, { 0.0996, "10%" }, { 0.0995, "10%" }, { 0.0994, "9.9%" }, { 0.0344, "3.4%" },
    { 0.00996, "1.0%" }, { 0.00994, "0.99%" }, { 0.00468, "0.47%" }, { 0.00006, "0.01%" },
    { 0.00004, "<0.01%" }, { 1e-9, "<0.01%" }, { 0, "0%" }, { 1, "100%" },
}

for _, case in ipairs(cases) do
    test("Percent(" .. tostring(case[1]) .. ") is " .. case[2], function()
        eq(ns.Percent(case[1]), case[2], tostring(case[1]))
    end)
end
