-- GameData/ItemKinds: the kind of each item the addon knows, and class rules for the rest (specs/014-catch-filters,
-- docs/architecture/game-data.md). Data only: no logic and no L lookup; Catalog.ItemKind reads it.
-- Kinds: "fish", "containers", "potions", "reagents", "other". The classes in brackets were read in game on
-- 2026-11-16 (class / subclass of C_Item.GetItemInfoInstant): the class cannot tell a fish from a clam (both 7 / 11)
-- nor a junk fish from a chest (both 15 / 0), so every item of the bundled seed and every fished container is listed
-- here by ID (a test fails for a missing one).
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.ItemKinds = {
    -- itemID -> kind
    byItem = {
        -- Fish (the junk-named ones too: the player sees a fish)
        [4603] = "fish", -- Raw Spotted Yellowtail
        [6289] = "fish", -- Raw Longjaw Mud Snapper
        [6291] = "fish", -- Raw Brilliant Smallfish (7 / 8)
        [6292] = "fish", -- 10 Pound Mud Snapper (15 / 0)
        [6303] = "fish", -- Raw Slitherskin Mackerel
        [6308] = "fish", -- Raw Bristle Whisker Catfish
        [6309] = "fish", -- 17 Pound Catfish
        [6358] = "fish", -- Oily Blackmouth (7 / 11)
        [6359] = "fish", -- Firefin Snapper
        [6361] = "fish", -- Raw Rainbow Fin Albacore
        [6362] = "fish", -- Raw Rockscale Cod
        [6458] = "fish", -- Oil Covered Fish
        [6522] = "fish", -- Deviate Fish
        [8365] = "fish", -- Raw Mithril Head Trout
        [21071] = "fish", -- Raw Sagefish
        [13422] = "fish", -- Stonescale Eel (not in the seed yet: a fish the class rule would call a reagent)
        -- Containers: chests, crates, trunks, clams
        [5523] = "containers", -- Small Barnacled Clam (7 / 11)
        [5524] = "containers", -- Thick-shelled Clam
        [6353] = "containers", -- Small Chest
        [6355] = "containers", -- Sturdy Locked Chest (15 / 0)
        [6357] = "containers", -- Sealed Crate
        [7973] = "containers", -- Big-mouth Clam
        [15874] = "containers", -- Soft-shelled Clam
        [20708] = "containers", -- Tightly Sealed Trunk
        [21113] = "containers", -- Watertight Trunk (15 / 0)
        [21150] = "containers", -- Iron Bound Trunk
        -- Fished containers of higher waters, not in the seed yet (their class, like the chests above, is no help)
        [6351] = "containers", -- Dented Crate
        [6352] = "containers", -- Waterlogged Crate
        [6354] = "containers", -- Small Locked Chest
        [6356] = "containers", -- Battered Chest
        [13874] = "containers", -- Heavy Crate
        [13875] = "containers", -- Ironbound Locked Chest
        [13918] = "containers", -- Reinforced Locked Chest
        -- Potions & drinks
        [858] = "potions", -- Lesser Healing Potion (0 / 1)
        [2455] = "potions", -- Minor Mana Potion
        [20709] = "potions", -- Rumsey Rum Light (0 / 5)
        [21114] = "potions", -- Rumsey Rum Dark
        -- Reagents & herbs
        [3820] = "reagents", -- Stranglekelp (7 / 9)
        [6470] = "reagents", -- Deviate Scale (7 / 6)
    },
    -- For an item not in byItem: "<classID>:<subClassID>" first, then "<classID>"; anything else is "other".
    byClass = {
        ["7:8"] = "fish", -- Trade Goods / Cooking: raw fish (Forever uses the Mainline classes)
        ["7"] = "reagents", -- every other Trade Goods: herbs, leather, parts
        ["0"] = "potions", -- Consumable: potions, food and drink
    },
}
