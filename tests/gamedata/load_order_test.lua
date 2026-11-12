-- The game data loads first after the locales (specs/008-architecture-alignment research R3): Core/Data.lua reads
-- the Fishing spells while the files load.

test("the GameData files come after the locales and before Core/Core.lua, the spells first", function()
    local lastLocale, core, first, last
    for i, file in ipairs(TOC_FILES) do
        if file:find("^Locales/") then
            lastLocale = i
        elseif file == "Core/Core.lua" then
            core = i
        elseif file:find("^GameData/") then
            first = first or i
            last = i
        end
    end
    assert(first, "GameData files in the TOC")
    assert(first > lastLocale, "after the locales")
    assert(last < core, "before Core/Core.lua")
    eq(TOC_FILES[first], "GameData/FishingSpells.lua", "the first GameData file")
end)

test("Core/Data.lua built its spell lookup from the model while loading", function()
    load_addon()
    eq(ns.IsFishingSpell(7620), true, "Apprentice")
    eq(ns.IsFishingSpell(18248), true, "Artisan")
    eq(ns.IsFishingSpell(1), false, "another spell")
end)
