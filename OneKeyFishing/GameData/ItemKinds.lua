-- GameData/ItemKinds: the kind of each item the addon knows, and class rules for the rest (specs/014-catch-filters,
-- docs/architecture/game-data.md). Data only: no logic and no L lookup; Catalog.ItemKind reads it.
-- Kinds: "fish", "containers", "trophies", "potions", "reagents", "quest", "other" (specs 014 and 023). The classes in
-- brackets were read in game on 2026-11-16 (class / subclass of C_Item.GetItemInfoInstant): the class cannot tell a
-- fish from a clam (both 7 / 11) nor a weighed fish from a chest (both 15 / 0), so every item of the bundled seed and
-- every fished container is listed here by ID (a test fails for a missing one).
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.ItemKinds = {
    -- itemID -> kind
    byItem = {
        -- Fish (the weighed "N Pound" fish are trophies and the quest fish are quest items since spec 023)
        [4603] = "fish", -- Raw Spotted Yellowtail
        [6289] = "fish", -- Raw Longjaw Mud Snapper
        [6291] = "fish", -- Raw Brilliant Smallfish (7 / 8)
        [6303] = "fish", -- Raw Slitherskin Mackerel
        [6308] = "fish", -- Raw Bristle Whisker Catfish
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
        [13754] = "fish", -- Raw Glossy Mightfish (7 / 8)
        [13755] = "fish", -- Winter Squid (0 / 5: the class rule would call it a drink)
        [13757] = "fish", -- Lightning Eel (7 / 11)
        [13758] = "fish", -- Raw Redgill
        [13759] = "fish", -- Raw Nightfin Snapper
        [13760] = "fish", -- Raw Sunscale Salmon
        [21153] = "fish", -- Raw Greater Sagefish (7 / 8)
        -- Fish of the seed of epoch 4 (names and classes read in game on 2026-11-17 with /okf debug)
        [6299] = "fish", -- Sickly Looking Fish (0 / 5: the class rule would call it a drink)
        [12238] = "fish", -- Darkshore Grouper (0 / 5)
        [251524] = "fish", -- Whimsyfin (7 / 11: a fish of Forever; the class rule would call it a reagent)
        -- Fish of the seed of epoch 5 (names and classes read in game on 2026-11-18 with /okf debug)
        [6317] = "fish", -- Raw Loch Frenzy (7 / 8)
        [13889] = "fish", -- Raw Whitescale Salmon (7 / 8)
        [13890] = "fish", -- Raw Plated Armorfish (12 / 0)
        -- Fish of the seed of epoch 7 (2026-11-20; the names of this epoch's items are read from Wowhead's classic
        -- database, and the eight with a class in brackets were checked in game the same day)
        [13888] = "fish", -- Darkclaw Lobster (7 / 8)
        [13893] = "fish", -- Large Raw Mightfish
        -- Trophies (spec 023): the 36 weighed "N Pound" fish, all 15 / 0 like the chests, so listed by ID; the
        -- names and classes are from the game's item tables (build 1.60.1.71037). Lobster and Yellowtail cannot be
        -- held in the off hand, the others can; all are trophies.
        [6292] = "trophies", -- 10 Pound Mud Snapper (15 / 0)
        [6294] = "trophies", -- 12 Pound Mud Snapper (15 / 0)
        [6295] = "trophies", -- 15 Pound Mud Snapper (15 / 0)
        [6309] = "trophies", -- 17 Pound Catfish
        [6310] = "trophies", -- 19 Pound Catfish (15 / 0)
        [6311] = "trophies", -- 22 Pound Catfish (15 / 0)
        [6363] = "trophies", -- 26 Pound Catfish (15 / 0)
        [6364] = "trophies", -- 32 Pound Catfish
        [13876] = "trophies", -- 40 Pound Yellowtail (15 / 0)
        [13877] = "trophies", -- 47 Pound Yellowtail
        [13878] = "trophies", -- 53 Pound Yellowtail (15 / 0)
        [13879] = "trophies", -- 59 Pound Yellowtail (15 / 0)
        [13880] = "trophies", -- 68 Pound Yellowtail
        [13882] = "trophies", -- 42 Pound Redgill (15 / 0)
        [13883] = "trophies", -- 45 Pound Redgill
        [13884] = "trophies", -- 49 Pound Redgill
        [13885] = "trophies", -- 34 Pound Redgill (15 / 0)
        [13886] = "trophies", -- 37 Pound Redgill
        [13887] = "trophies", -- 52 Pound Redgill
        [13901] = "trophies", -- 15 Pound Salmon (15 / 0)
        [13902] = "trophies", -- 18 Pound Salmon
        [13903] = "trophies", -- 22 Pound Salmon
        [13904] = "trophies", -- 25 Pound Salmon
        [13905] = "trophies", -- 29 Pound Salmon
        [13906] = "trophies", -- 32 Pound Salmon
        [13907] = "trophies", -- 7 Pound Lobster (15 / 0)
        [13908] = "trophies", -- 9 Pound Lobster (15 / 0)
        [13909] = "trophies", -- 12 Pound Lobster
        [13910] = "trophies", -- 15 Pound Lobster
        [13911] = "trophies", -- 19 Pound Lobster
        [13912] = "trophies", -- 21 Pound Lobster
        [13913] = "trophies", -- 22 Pound Lobster
        [13914] = "trophies", -- 70 Pound Mightfish (15 / 0)
        [13915] = "trophies", -- 85 Pound Mightfish
        [13916] = "trophies", -- 92 Pound Mightfish
        [13917] = "trophies", -- 103 Pound Mightfish
        -- Quest items (spec 023): handed in for a quest or the Stranglethorn Fishing Extravaganza; any other item
        -- of the quest class gets the kind by byClass
        [1467] = "quest", -- Spotted Sunfish (12 / 0: a quest fish of Redridge)
        [6717] = "quest", -- Gaffer Jack (12 / 0: a quest item fished in Darkshore)
        [6718] = "quest", -- Electropeller
        [16967] = "quest", -- Feralas Ahi (15 / 0)
        [16968] = "quest", -- Sar'theris Striker (12 / 0)
        [16969] = "quest", -- Savage Coast Blue Sailfin (12 / 0)
        [16970] = "quest", -- Misty Reed Mahi Mahi (12 / 0)
        [19803] = "quest", -- Brownell's Blue Striped Racer
        [19804] = "quest", -- Pale Ghoulfish
        [19805] = "quest", -- Keefer's Angelfish (15 / 0)
        [19806] = "quest", -- Dezian Queenfish (15 / 0)
        [19807] = "quest", -- Speckled Tastyfish (15 / 4)
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
        -- The rest of the camp bonuses' Bloated fish (GameData/CampBonuses.lua), not in the seed yet: 6647 was caught
        -- under the Fishing Hut on 2026-11-20 and listed under "other"
        [6644] = "containers", -- Bloated Mackerel
        [6646] = "containers", -- Bloated Albacore
        [6647] = "containers", -- Bloated Bristle Whisker Catfish
        [13891] = "containers", -- Bloated Whitescale Salmon
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
        -- Potions of the seed of epoch 7 (2026-11-20)
        [13443] = "potions", -- Superior Mana Potion
        [13446] = "potions", -- Major Healing Potion
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
        [16204] = "reagents", -- Illusion Dust (7 / 12; seed of epoch 9, 2026-11-23)
        [11137] = "reagents", -- Vision Dust (7 / 12; seed of epoch 10, 2026-11-23)
        -- Reagents of the seed of epoch 7 (2026-11-20): ore, bars, hides, cloth, herbs, dust and elemental water; some
        -- are the Fishing Hut's bonus catches
        [2772] = "reagents", -- Iron Ore
        [2776] = "reagents", -- Gold Ore
        [3860] = "reagents", -- Mithril Bar
        [4338] = "reagents", -- Mageweave Cloth
        [7070] = "reagents", -- Elemental Water (7 / 10)
        [7079] = "reagents", -- Globe of Water
        [7080] = "reagents", -- Essence of Water
        [7911] = "reagents", -- Truesilver Ore
        [8169] = "reagents", -- Thick Hide
        [10620] = "reagents", -- Thorium Ore
        [11176] = "reagents", -- Dream Dust
        [13465] = "reagents", -- Mountain Silversage
        [13467] = "reagents", -- Icecap
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
        -- Other of the seed of epoch 5 (2026-11-18)
        [766] = "other", -- Flanged Mace (2 / 4)
        [768] = "other", -- Lumberjack Axe (2 / 0)
        [2963] = "other", -- Burnt Leather Boots (4 / 2)
        [4666] = "other", -- Burnt Leather Belt (4 / 2)
        [6539] = "other", -- Willow Belt (4 / 1)
        [6541] = "other", -- Willow Gloves (4 / 1)
        [8350] = "other", -- The 1 Ring (4 / 0)
        -- Other of the seed of epoch 7 (2026-11-20): gear, bags and recipes
        [767] = "other", -- Long Bo Staff
        [804] = "other", -- Large Blue Sack (1 / 0: a bag, not a fished container)
        [2080] = "other", -- Hillborne Axe
        [2657] = "other", -- Red Leather Bag (1 / 0: a bag)
        [2960] = "other", -- Journeyman's Gloves
        [3609] = "other", -- Plans: Copper Chain Vest
        [4347] = "other", -- Pattern: Reinforced Woolen Shoulders
        [4658] = "other", -- Warrior's Cloak
        [4707] = "other", -- Lambent Scale Girdle
        [6360] = "other", -- Steelscale Crushfish (2 / 4: a one-hand mace, not a fish)
        [6378] = "other", -- Seer's Cape
        [6520] = "other", -- Pioneer Cloak
        [6536] = "other", -- Willow Vest
        [6551] = "other", -- Soldier's Boots
        [6591] = "other", -- Battleforge Wristguards
        [7092] = "other", -- Pattern: Hands of Darkness
        [7109] = "other", -- Pioneer Buckler
        [7459] = "other", -- Knight's Pauldrons
        [8179] = "other", -- Cadet's Bow
        [8181] = "other", -- Hunting Rifle
        [8182] = "other", -- Pellet Rifle
        [10225] = "other", -- Nightshade Gloves
        [10312] = "other", -- Pattern: Red Mageweave Gloves
        [15895] = "other", -- Burnt Buckler
        -- Other items of the seed of epoch 8 (2026-11-22; names and classes from the game's item tables, build
        -- 1.60.1.71037; three have no name row there and were read in game on 2026-11-22)
        [1640] = "other", -- Monstrous War Axe (2 / 1, read in game)
        [3200] = "other", -- Burnt Leather Bracers
        [4496] = "other", -- Small Brown Pouch (1 / 0)
        [4565] = "other", -- Simple Dagger
        [5574] = "other", -- White Leather Bag (1 / 0)
        [5974] = "other", -- Pattern: Guardian Cloak
        [7490] = "other", -- Captain's Boots (4 / 3, read in game)
        [9790] = "other", -- Raider's Shield (4 / 6, read in game)
        [286266] = "other", -- Antonidas' Silver Coin (15 / 4)
        -- Other of the seed of epoch 9 (2026-11-23; classes from the game's item tables, build 1.60.1.71037; three have
        -- no name row there and were read in game the same day)
        [2073] = "other", -- Dwarven Hatchet (2 / 0, read in game)
        [2966] = "other", -- Warrior's Pants (4 / 3, read in game)
        [3207] = "other", -- Hunting Bracers (4 / 2)
        [9785] = "other", -- Raider's Bracers (4 / 3, read in game)
        -- Other of the seed of epoch 10 (2026-11-23; names and classes from the game's item tables, build 1.60.1.71037)
        [3641] = "other", -- Journeyman's Bracers (4 / 1)
        [4659] = "other", -- Warrior's Girdle (4 / 3)
        -- Other of the seed of epoch 11 (2026-11-24; classes from the game's item tables, build 1.60.1.71037; the
        -- ten without a name row there were read in game the same day)
        [2406] = "other", -- Pattern: Fine Leather Boots (9 / 1)
        [7363] = "other", -- Pattern: Pilferer's Gloves (9 / 1)
        [8390] = "other", -- Pattern: Big Voodoo Cloak (9 / 1)
        [4662] = "other", -- Journeyman's Cloak (4 / 1)
        [2970] = "other", -- Spellbinder Pants (4 / 1)
        [4738] = "other", -- Imperial Leather Belt (4 / 2)
        [9949] = "other", -- Chieftain's Bracers (4 / 2)
        [10068] = "other", -- Righteous Boots (4 / 2)
        [9789] = "other", -- Raider's Legguards (4 / 3)
        [9810] = "other", -- Fortified Boots (4 / 3)
        [9968] = "other", -- Embossed Plate Girdle (4 / 4)
        [7108] = "other", -- Infantry Shield (4 / 6)
        [5071] = "other", -- Shadow Wand (2 / 19)
        [8180] = "other", -- Hunting Bow (2 / 2)
    },
    -- For an item not in byItem: "<classID>:<subClassID>" first, then "<classID>"; anything else is "other".
    byClass = {
        ["7:8"] = "fish", -- Trade Goods / Cooking: raw fish (Forever uses the Mainline classes)
        ["7"] = "reagents", -- every other Trade Goods: herbs, leather, parts
        ["0"] = "potions", -- Consumable: potions, food and drink
        ["12"] = "quest", -- Questitem (spec 023)
    },
}
