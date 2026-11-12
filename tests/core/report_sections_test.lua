-- Debug.lua, /okf debug: every section completes when a value is missing (spec 007, User Story 2).
-- The stubs' defaults: no lure in the bags, no fishing pole, no Fishing profession.

load_addon()

local function made()
    local _, report = ns.Debug.Report()
    return assert(report, "the report was made")
end

test("no section fails on a character without lure, pole or Fishing", function()
    local text = made()
    assert(not text:find("!! failed", 1, true), "a section failed:\n" .. text)
end)

test("the Gear section is complete without a lure", function()
    local text = made()
    assert(text:find("next lure: nil", 1, true), "the next lure line:\n" .. text)
    assert(text:find("best pole: none", 1, true), "the best pole line:\n" .. text)
    assert(text:find("pending restore: none", 1, true), "the pending restore line:\n" .. text)
end)

test("the Fishing section shows the missing skill plainly", function()
    local text = made()
    assert(text:find("spell: nil (nil)", 1, true), "the spell line:\n" .. text)
    assert(text:find("next rank: none", 1, true), "the next rank line:\n" .. text)
end)

test("the report lists the L lookups made before the language was set", function()
    local text = made()
    assert(text:find("early L lookups: none", 1, true), "none after a clean load:\n" .. text)
    table.insert(ns.earlyLookups, "Apprentice")
    text = made()
    table.remove(ns.earlyLookups)
    assert(text:find("early L lookups: Apprentice", 1, true), "the early key:\n" .. text)
end)
