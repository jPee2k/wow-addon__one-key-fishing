-- Core.lua: the saved-variable migrations.

load_files({ "Localization.lua", "Locales/enUS.lua", "Core.lua" })

-- Logs in with the given saved data; returns the chat lines printed while loading.
local function LoadWith(db, charDB)
    OneKeyFishingDB, OneKeyFishingCharDB = db, charDB
    chat = {}
    fire("ADDON_LOADED", "OneKeyFishing")
    return chat
end

test("migrations: a new player gets the current schema and the defaults", function()
    local printed = LoadWith(nil, nil)
    eq(OneKeyFishingDB.schema, 1, "account schema")
    eq(OneKeyFishingCharDB.schema, 1, "character schema")
    eq(OneKeyFishingDB.settings.autoLoot, true, "default setting")
    eq(#printed, 0, "chat lines")
end)

test("migrations: data from 0.2 keeps the user's values and gets new defaults", function()
    local printed = LoadWith(
        { schema = 1, settings = { autoLoot = false }, prices = { [123] = { price = 5, time = 1 } } },
        { schema = 1, gear = { pole = 6256, items = { 1, 2 } } })
    eq(OneKeyFishingDB.settings.autoLoot, false, "user setting")
    eq(OneKeyFishingDB.settings.camera, true, "new default")
    eq(OneKeyFishingDB.prices[123].price, 5, "auction price")
    eq(OneKeyFishingCharDB.gear.pole, 6256, "chosen pole")
    eq(#OneKeyFishingCharDB.gear.items, 2, "fishing items")
    eq(#printed, 0, "chat lines")
end)

test("migrations: data without a schema is upgraded to the current schema", function()
    local printed = LoadWith({ settings = {} }, {})
    eq(OneKeyFishingDB.schema, 1, "schema")
    eq(OneKeyFishingDB.settings.autoLoot, true, "defaults filled")
    eq(#printed, 0, "chat lines")
end)

test("upgrade from 1.0.0: statistics and prices stay as they were, new fields are added (schema stays 1)", function()
    local zone = { casts = 3, catches = 2, misses = 1, modeTime = 90, castTime = 40, items = { [6291] = 2 },
        name = "Test Zone" }
    LoadWith({ schema = 1, settings = {}, prices = { [6291] = { price = 500, time = 1 } },
        fishedItems = { [6291] = true } },
        { schema = 1, stats = { total = { casts = 7, catches = 5, misses = 2, modeTime = 300, castTime = 120,
            items = { [6291] = 6 } }, zones = { ["1:"] = zone } },
          session = { casts = 1, catches = 1, misses = 0, modeTime = 10, castTime = 5, items = { [6291] = 1 },
            started = 100 } })
    eq(OneKeyFishingDB.schema, 1, "account schema")
    eq(OneKeyFishingCharDB.schema, 1, "character schema")
    eq(OneKeyFishingDB.prices[6291].price, 500, "auction price")
    eq(OneKeyFishingDB.prices[6291].quantity, nil, "no quantity in a 1.0.0 price")
    eq(OneKeyFishingDB.fishedItems[6291], true, "fished items")
    local total = OneKeyFishingCharDB.stats.total
    eq(total.casts .. " " .. total.catches .. " " .. total.misses .. " " .. total.modeTime .. " " .. total.castTime,
        "7 5 2 300 120", "all-time bucket")
    eq(total.items[6291], 6, "all-time items")
    eq(OneKeyFishingCharDB.stats.zones["1:"], zone, "zone bucket")
    eq(zone.catches, 2, "zone catches")
    eq(OneKeyFishingCharDB.session.catches, 1, "session")
    eq(OneKeyFishingDB.statsTab, "stats", "new field: the last open tab")
    eq(type(OneKeyFishingDB.shared.mine), "table", "new field: own catch data")
    eq(type(OneKeyFishingDB.shared.records), "table", "new field: contribution records")
end)

test("migrations: data from a newer version is left alone, with a warning", function()
    local printed = LoadWith({ schema = 99, settings = {} }, { schema = 1 })
    eq(OneKeyFishingDB.schema, 99, "schema")
    eq(#printed, 1, "chat lines")
    assert(printed[1]:find("newer version", 1, true), printed[1])
end)

test("ADDON_LOADED of another addon is ignored", function()
    OneKeyFishingDB = { schema = 1, marker = true }
    fire("ADDON_LOADED", "SomeOtherAddon")
    eq(OneKeyFishingDB.settings, nil, "settings")
end)

test("upgrade from 1.1: sharing is on and the notice not yet shown, nothing else changes", function()
    LoadWith({ schema = 1, settings = { autoLoot = false }, statsTab = "here" }, { schema = 1 })
    eq(OneKeyFishingDB.settings.shareDB, true, "sharing on by default")
    eq(OneKeyFishingDB.shareNotice, false, "notice not shown yet")
    eq(OneKeyFishingDB.settings.autoLoot, false, "user setting")
    eq(OneKeyFishingDB.statsTab, "here", "last tab")
    eq(OneKeyFishingDB.schema, 1, "schema stays 1")
end)

test("part 3: the public channel is on and its notice not yet shown; a player's off is kept", function()
    LoadWith({ schema = 1, settings = { shareChannel = false }, shareNotice = true }, { schema = 1 })
    eq(OneKeyFishingDB.settings.shareChannel, false, "the player's choice kept")
    eq(OneKeyFishingDB.shareNotice, true, "part 2 notice kept")
    eq(OneKeyFishingDB.shareNoticeChannel, false, "the channel's notice not yet shown")
    LoadWith(nil, nil)
    eq(OneKeyFishingDB.settings.shareChannel, true, "on by default")
end)

test("a popup runs onCancel on its second button and onHide after either button", function()
    local log = {}
    ns.ShowPopup("OKF_TEST", "text", function() table.insert(log, "accept") end, "A", "B",
        function() table.insert(log, "cancel") end, function() table.insert(log, "hide") end)
    accept_popup()
    eq(table.concat(log, " "), "accept hide", "first button")
    log = {}
    ns.ShowPopup("OKF_TEST", "text", function() table.insert(log, "accept") end, "A", "B",
        function() table.insert(log, "cancel") end, function() table.insert(log, "hide") end)
    cancel_popup()
    eq(table.concat(log, " "), "cancel hide", "second button")
    eq(StaticPopupDialogs.OKF_TEST.noCancelOnEscape, true, "Escape does not press a second button that does more")
    ns.ShowPopup("OKF_TEST2", "text", function() end)
    eq(StaticPopupDialogs.OKF_TEST2.noCancelOnEscape, false, "a plain No keeps the game's Escape")
end)
