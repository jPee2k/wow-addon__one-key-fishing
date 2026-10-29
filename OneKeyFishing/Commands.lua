-- Commands: every /okf slash command, in one place (constitution, Principles II and VI). The names, the
-- descriptions and the /okf help are English on every client: players type the commands in English.
-- Each command calls its module at runtime, so this file loads last and modules register no commands.
local _, ns = ...

ns.COMMANDS = {
    { name = "config", description = "open the settings", run = function() ns.SettingsUI.Open() end },
    { name = "debug", description = "show a report to copy into a bug report", run = function() ns.ShowReport() end },
    { name = "scan", description = "scan auction prices of caught items (auction house must be open)",
        run = function() ns.Auction.Scan() end },
    -- VERIFY(spike): temporary, with Spike.lua
    { name = "spike", description = "print API facts for the verification checklist",
        run = function() ns.ShowSpikeReport() end },
    { name = "stats", description = "show the fishing statistics", run = function() ns.StatsFrame.Toggle() end },
    { name = "toggle", description = "enter or leave fishing mode", run = function() ns.Mode.Toggle() end },
}
