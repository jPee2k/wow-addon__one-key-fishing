-- GameData/FishingPoles: the fishing poles and the item class of any pole (docs/architecture/game-data.md). Data
-- only: no logic and no L lookup. bonus: the Fishing bonus, the fallback when the tooltip cannot be read (Gear.lua);
-- skill: the Fishing skill the pole needs (recorded, not used yet: docs/tech-debt.md). Source: the original game
-- (Wowhead Classic tooltips, 2026-11-06).
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.FishingPoles = {
    [6256] = { bonus = 0, skill = 0 }, -- Fishing Pole
    [12225] = { bonus = 3, skill = 1 }, -- Blump Family Fishing Pole
    [6365] = { bonus = 5, skill = 10 }, -- Strong Fishing Pole
    [6366] = { bonus = 15, skill = 50 }, -- Darkwood Fishing Pole
    [6367] = { bonus = 20, skill = 100 }, -- Big Iron Fishing Pole
    [19022] = { bonus = 25, skill = 100 }, -- Nat Pagle's Extreme Angler FC-5000
    [19970] = { bonus = 35, skill = 300 }, -- Arcanite Fishing Pole
}

-- Every fishing pole is a weapon (Enum.ItemClass.Weapon) of the subclass Fishingpole (Enum.ItemWeaponSubclass).
GameData.FishingPoleClass = { classID = 2, subclassID = 20 }
