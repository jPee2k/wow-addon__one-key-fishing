-- An addon loaded straight from the repository (not built) shows its version as "dev".

addon_version = "@project-version@"
load_files({ "Core/Localization.lua", "Locales/enUS.lua", "Core/Core.lua" })

test("an unbuilt addon shows the version dev", function()
    eq(ns.version, "dev")
end)
