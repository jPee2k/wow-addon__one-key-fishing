-- Pieces per catch (specs/020-camp-buffs, decision 27): one decimal, written whole when the rounded value is whole,
-- with the game client's decimal separator.

load_addon()

test("whole values have no decimals; others one, rounded", function()
    eq(ns.FormatCount(1), "1", "1")
    eq(ns.FormatCount(1.04), "1", "1.04")
    eq(ns.FormatCount(1.25), "1.3", "1.25")
    eq(ns.FormatCount(1.5), "1.5", "1.5")
    eq(ns.FormatCount(12.96), "13", "12.96")
end)

test("the client's decimal separator", function()
    DECIMAL_SEPERATOR = ","
    eq(ns.FormatCount(1.5), "1,5", "German client")
    eq(ns.FormatCount(2), "2", "whole")
    DECIMAL_SEPERATOR = "."
end)
