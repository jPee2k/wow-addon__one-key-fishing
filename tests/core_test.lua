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
