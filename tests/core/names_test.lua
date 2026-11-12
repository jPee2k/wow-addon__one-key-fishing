-- Character names on Forever (Core/Data.lua, specs/010-exchange-forever-fixes US1, contracts N1-N2): the own full
-- name, and the same character with or without the own realm suffix. The stub realm is "Realm".

load_addon()

test("the own name is the full name the game gives", function()
    eq(ns.PlayerName(), "First Last", "the default stub")
    player_full_name = "Ann Lee"
    eq(ns.PlayerName(), "Ann Lee", "another player")
    player_full_name = nil
end)

test("the same character with or without the own realm suffix; another realm is somebody else", function()
    eq(ns.SameCharacter("First Last", "First Last"), true, "equal")
    eq(ns.SameCharacter("First Last", "First Last-Realm"), true, "own realm on the right")
    eq(ns.SameCharacter("First Last-Realm", "First Last"), true, "own realm on the left")
    eq(ns.SameCharacter("First Last", "First Last-OtherRealm"), false, "another realm")
    eq(ns.SameCharacter("First Last-RealmA", "First Last-RealmB"), false, "two other realms")
    eq(ns.SameCharacter("First Last", "First Other"), false, "another name")
    eq(ns.SameCharacter("First", "First Last"), false, "a space is no realm separator")
end)

test("no realm is added to a name", function()
    eq(ns.WithRealm, nil, "WithRealm is gone")
end)
