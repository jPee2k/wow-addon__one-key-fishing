-- Catalog.lua: after a /reload (a fresh Lua state whose first loading screen is not a login) the default index is
-- built 10 s later too.

load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("the default index is built 10 s after the first loading screen of a /reload", function()
    advance(9)
    eq(ns.Catalog.Describe()[1], "no index yet", "not before")
    advance(1)
    assert(ns.Catalog.Describe()[1]:find("^index all|all|all: ready"), ns.Catalog.Describe()[1])
end)
