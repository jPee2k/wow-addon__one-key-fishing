-- Catalog.TrophyIDs and Catalog.TrophyCount (specs/023-item-kinds US2, FR-006, FR-007): the 36 weighed fish, and how
-- many of them the account's own catch holds; other players' data, the seed and the kind choice do not change it.

local MINE, OWN_OLD, OTHERS, SEEDED = 6292, 13917, 6294, 6295
OneKeyFishingDB = { shareNotice = true, shared = {
    myID = "aaaaaaa2",
    mine = { ["3999:0:x"] = { c = 2, m = 0, t = 20, i = { [MINE] = { 1, 1 }, [6291] = { 1, 1 } } } },
    records = {
        ["aaaaaaa2@0"] = { id = "aaaaaaa2", epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
            builds = { ["1.13.0"] = { ["3999:0:x"] = { c = 1, m = 0, t = 10, i = { [OWN_OLD] = { 1, 1 } } } } } },
        ["baaaaaa2@0"] = { id = "baaaaaa2", epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
            builds = { ["1.60.1"] = { ["3999:0:x"] = { c = 1, m = 0, t = 10, i = { [OTHERS] = { 1, 1 } } } } } },
    } } }
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {},
        cells = { ["3999:0:x"] = { c = 1, m = 0, t = 10, k = 1, i = { [SEEDED] = { 1, 1 } } } } }
end)

local Catalog = ns.Catalog

test("TrophyIDs: the 36 trophies, ascending, the same table every time", function()
    local ids = Catalog.TrophyIDs()
    eq(#ids, 36, "36")
    eq(ids[1], 6292, "first")
    eq(ids[36], 13917, "last")
    for index = 2, #ids do
        assert(ids[index - 1] < ids[index], "ascending")
        eq(Catalog.ItemKind(ids[index]), "trophies", "each is a trophy")
    end
    eq(Catalog.TrophyIDs(), ids, "the same table")
end)

test("TrophyCount counts the own catch of every version, not others' data, the seed or a fish", function()
    eq(table.concat({ Catalog.TrophyCount() }, "/"), "2/36", "mine and an older own record")
end)

test("the kind choice does not change the count", function()
    Catalog.SetKindShown("trophies", false)
    eq(table.concat({ Catalog.TrophyCount() }, "/"), "2/36", "hidden kind")
    Catalog.SetKindShown("trophies", true)
end)
