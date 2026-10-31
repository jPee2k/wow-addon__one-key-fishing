-- Data.lua with the game's folding functions (CaseAccentInsensitiveParse, strcmputf8i): tests/core/fold_test.lua runs
-- without them.

game_fold = true
load_addon()

test("SearchKey uses CaseAccentInsensitiveParse, then FoldCase", function()
    eq(ns.SearchKey("Truite \195\137"), "truite e", "the game folds the accent")
    eq(ns.SearchKey("\208\169\209\131\208\186\208\176"), "\209\137\209\131\208\186\208\176", "FoldCase after it")
end)

test("CompareText uses strcmputf8i", function()
    eq(ns.CompareText("b", "A"), false, "A before b")
    eq(ns.CompareText("\195\137cu", "f"), true, "E acute as e")
end)
