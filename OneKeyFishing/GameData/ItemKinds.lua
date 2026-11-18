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
        -- Fish of the seed of epoch 2 (names and classes read in game on 2026-11-17)
        [6310] = "fish", -- 19 Pound Catfish (15 / 0)
        [13754] = "fish", -- Raw Glossy Mightfish (7 / 8)
        [13755] = "fish", -- Winter Squid (0 / 5: the class rule would call it a drink)
        [13757] = "fish", -- Lightning Eel (7 / 11)
        [13758] = "fish", -- Raw Redgill
        [13759] = "fish", -- Raw Nightfin Snapper
        [13760] = "fish", -- Raw Sunscale Salmon
        [13876] = "fish", -- 40 Pound Yellowtail (15 / 0)
        [13877] = "fish", -- 47 Pound Yellowtail
        [13885] = "fish", -- 34 Pound Redgill (15 / 0)
        [13886] = "fish", -- 37 Pound Redgill
        [19806] = "fish", -- Dezian Queenfish (15 / 0)
        [19807] = "fish", -- Speckled Tastyfish (15 / 4)
        [21153] = "fish", -- Raw Greater Sagefish (7 / 8)
        -- Fish of the seed of epoch 4 (names and classes read in game on 2026-11-17 with /okf debug)
        [6294] = "fish", -- 12 Pound Mud Snapper (15 / 0)
        [6295] = "fish", -- 15 Pound Mud Snapper (15 / 0)
        [6299] = "fish", -- Sickly Looking Fish (0 / 5: the class rule would call it a drink)
        [6311] = "fish", -- 22 Pound Catfish (15 / 0)
        [12238] = "fish", -- Darkshore Grouper (0 / 5)
        [13878] = "fish", -- 53 Pound Yellowtail (15 / 0)
        [16967] = "fish", -- Feralas Ahi (15 / 0)
        [16968] = "fish", -- Sar'theris Striker (12 / 0)
        [16969] = "fish", -- Savage Coast Blue Sailfin (12 / 0)
        [16970] = "fish", -- Misty Reed Mahi Mahi (12 / 0)
        [251524] = "fish", -- Whimsyfin (7 / 11: a fish of Forever; the class rule would call it a reagent)
        -- Fish of the seed of epoch 5 (names and classes read in game on 2026-11-18 with /okf debug)
        [6317] = "fish", -- Raw Loch Frenzy (7 / 8)
        [6363] = "fish", -- 26 Pound Catfish (15 / 0)
        [13879] = "fish", -- 59 Pound Yellowtail (15 / 0)
        [13889] = "fish", -- Raw Whitescale Salmon (7 / 8)
        [13890] = "fish", -- Raw Plated Armorfish (12 / 0)
        [13901] = "fish", -- 15 Pound Salmon (15 / 0)
        [19805] = "fish", -- Keefer's Angelfish (15 / 0)
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
        [21228] = "containers", -- Mithril Bound Trunk (15 / 0)
        -- Bloated fish of the seed of epoch 4: opened like a clam for what is inside (15 / 4)
        [6643] = "containers", -- Bloated Brilliant Smallfish
        [8366] = "containers", -- Bloated Mithril Head Trout
        [13881] = "containers", -- Bloated Redgill
        [21162] = "containers", -- Bloated Oily Blackmouth
        -- Bloated fish of the seed of epoch 5 (15 / 4)
        [6645] = "containers", -- Bloated Mud Snapper
        [21163] = "containers", -- Bloated Firefin Snapper
        [21164] = "containers", -- Bloated Rockscale Cod
        [21243] = "containers", -- Bloated Glossy Mightfish (one player's report, not in the seed yet)
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
        [1710] = "potions", -- Greater Healing Potion (0 / 1)
        [3385] = "potions", -- Lesser Mana Potion (0 / 1)
        [3928] = "potions", -- Superior Healing Potion (0 / 1)
        [21151] = "potions", -- Rumsey Rum Black Label (0 / 5)
        [118] = "potions", -- Minor Healing Potion (0 / 1)
        [929] = "potions", -- Healing Potion (0 / 1)
        [3827] = "potions", -- Mana Potion (0 / 1)
        [6149] = "potions", -- Greater Mana Potion (0 / 1)
        -- Reagents & herbs
        [3820] = "reagents", -- Stranglekelp (7 / 9)
        [6470] = "reagents", -- Deviate Scale (7 / 6)
        [4363] = "reagents", -- Copper Modulator (7 / 1: an Engineering part)
        -- Reagents of the seed of epoch 5 (2026-11-18)
        [3858] = "reagents", -- Mithril Ore (7 / 7)
        [4234] = "reagents", -- Heavy Leather (7 / 6)
        [4235] = "reagents", -- Heavy Hide (7 / 6)
        [4304] = "reagents", -- Thick Leather (7 / 6)
        [4377] = "reagents", -- Heavy Blasting Powder (7 / 1)
        [6371] = "reagents", -- Fire Oil (7 / 11)
        [8839] = "reagents", -- Blindweed (7 / 9)
        [8925] = "reagents", -- Crystal Vial (7 / 11)
        [10285] = "reagents", -- Shadow Silk (7 / 5)
        [10286] = "reagents", -- Heart of the Wild (7 / 10)
        [13466] = "reagents", -- Plaguebloom (7 / 9)
        [14047] = "reagents", -- Runecloth (7 / 5)
        -- Other
        [6457] = "other", -- Rusted Engineering Parts (15 / 0)
        [9754] = "other", -- Nomad Cloak (4 / 1)
        [2977] = "other", -- Veteran Armor (4 / 3)
        [3870] = "other", -- Plans: Green Iron Shoulders (9 / 4)
        [6297] = "other", -- Old Skull (15 / 0)
        [6301] = "other", -- Old Teamster's Skull (15 / 0)
        [6307] = "other", -- Message in a Bottle (15 / 0)
        [6456] = "other", -- Acidic Slime (15 / 0)
        -- Other of the seed of epoch 6 (2026-11-18)
        [3873] = "other", -- Plans: Golden Scale Cuirass (a recipe, like 3870)
        [6718] = "other", -- Electropeller (a quest item fished in Darkshore)
        -- Other of the seed of epoch 5 (2026-11-18)
        [766] = "other", -- Flanged Mace (2 / 4)
        [768] = "other", -- Lumberjack Axe (2 / 0)
        [2963] = "other", -- Burnt Leather Boots (4 / 2)
        [4666] = "other", -- Burnt Leather Belt (4 / 2)
        [6539] = "other", -- Willow Belt (4 / 1)
        [6541] = "other", -- Willow Gloves (4 / 1)
        [6717] = "other", -- Gaffer Jack (12 / 0)
        [8350] = "other", -- The 1 Ring (4 / 0)
    },
    -- For an item not in byItem: "<classID>:<subClassID>" first, then "<classID>"; anything else is "other".
    byClass = {
        ["7:8"] = "fish", -- Trade Goods / Cooking: raw fish (Forever uses the Mainline classes)
        ["7"] = "reagents", -- every other Trade Goods: herbs, leather, parts
        ["0"] = "potions", -- Consumable: potions, food and drink
    },
}
