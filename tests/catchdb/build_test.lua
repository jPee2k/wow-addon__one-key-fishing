-- CatchDB.lua: the order of game versions that a reset of a map counts by (OlderBuild).

load_addon()

local Older = ns.CatchDB.private.OlderBuild

test("a game version is older than a higher major, minor or patch number", function()
    eq(Older("1.60.1", "2.0.0"), true, "major")
    eq(Older("1.59.9", "1.60.0"), true, "minor")
    eq(Older("1.60.1", "1.60.2"), true, "patch")
    eq(Older("1.60.10", "1.60.9"), false, "numbers, not text")
end)

test("equal or newer versions are not older", function()
    eq(Older("1.60.1", "1.60.1"), false, "equal")
    eq(Older("2.0.0", "1.99.99"), false, "newer")
end)

test("unknown is older than any version; text that is no version is not older", function()
    eq(Older("unknown", "1.0.0"), true, "unknown")
    eq(Older("garbage", "1.0.0"), false, "no version")
    eq(Older("1.0.0", "garbage"), false, "no reset version")
end)
