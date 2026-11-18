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

test("a table setting is listed by its keys, not as a memory address (spec 014 hiddenKinds)", function()
    local text = made()
    assert(text:find("hiddenKinds = {}", 1, true), "an empty set:\n" .. text)
    ns.db.settings.hiddenKinds = { other = true, containers = true }
    text = made()
    assert(text:find("hiddenKinds = { containers, other }", 1, true), "the hidden kinds, sorted:\n" .. text)
    assert(not text:find("table: ", 1, true), "no address:\n" .. text)
    ns.db.settings.hiddenKinds = {}
end)

test("the Auction scan section holds the scan's lines; the Catch database section no longer does", function()
    local text = made()
    local section = text:match("%-%- Auction scan %-%-\n(.-)\n\n")
    assert(section, "an Auction scan section:\n" .. text)
    assert(section:find("auction: closed", 1, true), section)
    assert(section:find("auction guard", 1, true), section)
    assert(section:find("last price scan:", 1, true), section)
    local catchDB = assert(text:match("%-%- Catch database %-%-\n(.-)\n\n"), "the Catch database section")
    assert(not catchDB:find("last price scan", 1, true), catchDB)
end)

-- The "Auction prices" section (specs/019-auctionator-prices, FR-022). The stub is set after load_addon().
local function prices_section()
    local text = made()
    assert(text:find("%-%- Auction prices %-%-\n.-%-%- Auction scan %-%-"), "right before Auction scan:\n" .. text)
    return assert(text:match("%-%- Auction prices %-%-\n(.-)\n\n"), "an Auction prices section:\n" .. text)
end

test("the Auction prices section without Auctionator: the own scan, both functions missing", function()
    local section = prices_section()
    assert(section:find("source own scan", 1, true), section)
    assert(section:find("auctionPrices on, auctionatorPrices on", 1, true), section)
    assert(section:find("GetAuctionPriceByItemID missing", 1, true), section)
    assert(section:find("RegisterForDBUpdate missing", 1, true), section)
    assert(section:find("oldest Auctionator price: unknown", 1, true), section)
end)

local stub = { prices = { [6291] = 500, [6303] = 40 }, ages = { [6291] = 3, [6303] = 12 } }
stub.API = { v1 = {
    GetAuctionPriceByItemID = function(_, itemID) return stub.prices[itemID] end,
    GetAuctionAgeByItemID = function(_, itemID) return stub.ages[itemID] end,
    RegisterForDBUpdate = function() end,
} }

test("the Auction prices section with Auctionator: the source, the functions, the counts, the oldest age", function()
    Auctionator = stub
    local items = ns.Stats.GetTotal().items
    items[6291], items[6303], items[7974] = 1, 1, 1
    local section = prices_section()
    assert(section:find("source auctionator", 1, true), section)
    assert(section:find("GetAuctionPriceByItemID present", 1, true), section)
    assert(section:find("RegisterForDBUpdate present", 1, true), section)
    assert(section:find("own catches: 2 Auctionator, 0 own, 0 vendor, 1 none", 1, true), section)
    assert(section:find("oldest Auctionator price: 12 days", 1, true), section)
    stub.ages = {}
    assert(prices_section():find("oldest Auctionator price: unknown", 1, true), "past its history limit")
end)

test("the Auction prices section names a missing function and a failed call", function()
    local register = stub.API.v1.RegisterForDBUpdate
    stub.API.v1.RegisterForDBUpdate = nil
    local section = prices_section()
    assert(section:find("RegisterForDBUpdate missing", 1, true), section)
    assert(section:find("source own scan", 1, true), section)
    stub.API.v1.RegisterForDBUpdate = register
    stub.API.v1.GetAuctionPriceByItemID = function() error("broken") end
    ns.Prices.Get(6291)
    eq(#take_errors(), 1, "the failure, handed on once")
    section = prices_section()
    assert(section:find("failed: ", 1, true), section)
    assert(section:find("broken", 1, true), section)
    assert(section:find("source own scan", 1, true), section)
    advance(0.1)
end)
