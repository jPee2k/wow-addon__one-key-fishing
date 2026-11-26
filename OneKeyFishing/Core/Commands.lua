-- Commands: every /okf slash command, in one place (constitution, Principles II and VI). The names, the
-- descriptions and the /okf help are English on every client: players type the commands in English.
-- Each command calls its module at runtime, so this file loads last and modules register no commands.
local _, ns = ...

ns.COMMANDS = {
    { name = "best", description = "open the best places to fish", run = function() ns.StatsFrame.OpenBest() end },
    { name = "catalog", description = "open the catch catalog (optionally with an item name or link)",
        run = function(rest) ns.StatsFrame.OpenCatalog(ns.Catalog.CommandArg(rest)) end },
    { name = "config", description = "open the settings", run = function() ns.SettingsUI.Open() end },
    { name = "debug", description = "show a report to copy into a bug report",
        run = function() ns.ShowDebugReport() end },
    { name = "scan", description = "scan auction prices of the catch catalog's items (auction house must be open; " ..
        "not while prices come from Auctionator)",
        run = function() ns.Auction.Scan() end },
    { name = "share", description = "show the state of the shared catch database; \"share import\" or " ..
        "\"share export\" opens the import and export page",
        run = function(rest)
            local word = (rest or ""):lower():match("^%s*(%a+)")
            if word == "import" or word == "export" then
                ns.SettingsUI.OpenTransfer(word)
            else
                ns.Share.PrintStatus()
            end
        end },
    { name = "sound", description = "open the sound effects settings",
        run = function() ns.SettingsUI.OpenSounds() end },
    { name = "stats", description = "show the fishing statistics", run = function() ns.StatsFrame.Toggle() end },
    { name = "toggle", description = "enter or leave fishing mode", run = function() ns.Mode.Toggle() end },
}
