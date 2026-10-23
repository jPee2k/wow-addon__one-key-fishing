-- An addon loaded straight from the repository (not built) shows its version as "dev".

addon_version = "@project-version@"
load_files({ "Locales/enUS.lua", "Core.lua" })

test("an unbuilt addon shows the version dev", function()
    eq(ns.version, "dev")
end)
