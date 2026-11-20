-- GameData/Lures: the fishing lures the addon knows (docs/architecture/game-data.md). Data only: no logic and no L
-- lookup. bonus: the Fishing bonus; order: 1 is the best, the key offers the lowest order it can use; skill: the
-- Fishing skill the lure needs (0: none). Source: the original game (Wowhead Classic tooltips, 2026-11-06) and, for
-- Camper's Lure, WoW Forever (seen in game 2026-11-19). The skill values match the items' tooltips in game (V43,
-- 2026-11-11).
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.Lures = {
    [6533] = { bonus = 100, order = 1, skill = 100 }, -- Aquadynamic Fish Attractor
    [7307] = { bonus = 75, order = 2, skill = 100 }, -- Flesh Eating Worm
    [6532] = { bonus = 75, order = 3, skill = 100 }, -- Bright Baubles
    -- Camper's Lure: from a placed Fishing Rack; +60 for 5 minutes, seen in game 2026-11-19
    [291005] = { bonus = 60, order = 4, skill = 50 },
    [6811] = { bonus = 50, order = 5, skill = 50 }, -- Aquadynamic Fish Lens
    [6530] = { bonus = 50, order = 6, skill = 50 }, -- Nightcrawlers
    [6529] = { bonus = 25, order = 7, skill = 0 }, -- Shiny Bauble
}
