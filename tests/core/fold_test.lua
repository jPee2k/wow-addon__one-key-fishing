-- Data.lua: ns.FoldCase, ns.SearchKey and ns.CompareText (specs/005-catch-catalog, research R7). This file runs
-- without the game's folding functions; tests/core/fold_game_test.lua runs with them.

load_addon()

local function codepoint(n)
    -- UTF-8 of a code point below U+0800 (two bytes from U+0080).
    if n < 128 then
        return string.char(n)
    end
    return string.char(192 + math.floor(n / 64), 128 + n % 64)
end

test("ASCII capitals are lowered, other ASCII stays", function()
    eq(ns.FoldCase("Deviate FISH 12-a"), "deviate fish 12-a")
end)

test("Latin-1 capitals U+00C0-U+00DE are lowered, except the multiplication sign", function()
    for n = 0xC0, 0xDE do
        local expected = n == 0xD7 and codepoint(n) or codepoint(n + 32)
        eq(ns.FoldCase(codepoint(n)), expected, ("U+%04X"):format(n))
    end
    eq(ns.FoldCase("Truite \195\137"), "truite \195\169", "E acute")
    eq(ns.FoldCase("\195\159"), "\195\159", "the sharp s has no capital in this block")
end)

test("Cyrillic U+0410-U+042F goes to U+0430-U+044F, and U+0400-U+040F to U+0450-U+045F", function()
    for n = 0x0410, 0x042F do
        eq(ns.FoldCase(codepoint(n)), codepoint(n + 32), ("U+%04X"):format(n))
    end
    for n = 0x0400, 0x040F do
        eq(ns.FoldCase(codepoint(n)), codepoint(n + 80), ("U+%04X"):format(n))
    end
    eq(ns.FoldCase("\208\169\209\131\208\186\208\176"), "\209\137\209\131\208\186\208\176", "Shchuka")
end)

test("lower case, Korean and Chinese text stay as they are", function()
    local samples = { "deviate fish", "\209\137\209\131\208\186\208\176", "\235\172\188\234\179\160\234\184\176",
        "\233\177\188", "\195\169t\195\169" }
    for _, text in ipairs(samples) do
        eq(ns.FoldCase(text), text, text)
    end
end)

test("without the game's functions, SearchKey is FoldCase and CompareText the byte order of the keys", function()
    eq(CaseAccentInsensitiveParse, nil, "no game fold here")
    eq(ns.SearchKey("Truite \195\137"), "truite \195\169", "case only")
    eq(ns.CompareText("b", "A"), false, "a before b")
    eq(ns.CompareText("Apple", "banana"), true, "case does not matter")
    eq(ns.CompareText("same", "SAME"), false, "equal keys")
end)
