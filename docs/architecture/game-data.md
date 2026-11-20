# Architecture: game data

`OneKeyFishing/GameData/` is the model of the game's entities that the addon needs: items, spells, objects, NPCs,
places, inventory slots and icons, each matched by ID (constitution Principle II). It is layer 0 beside `Core/` and
`Locales/` ([core.md](core.md), "Layers"). Every module of every layer may read it, and none writes it. The module
map is in `CLAUDE.md`; the design is in `specs/008-architecture-alignment` (research R1-R3, data-model.md).

## The rule

- One table, `ns.GameData`, and one file per entity. Each file starts with the same two lines and then holds only
  table constructors:

  ```lua
  local _, ns = ...
  local GameData = ns.GameData or {}
  ns.GameData = GameData
  ```

- Data only: no `function`, no call, no `L[...]` / `ns.L`, no other `ns.<Name>`. `npm run check` reads the code without
  its strings and comments and reports a break (`tools/addon.mjs` `gameDataProblems`, tested by
  `tests/tools/gamedata_check_test.mjs`). A table may read an earlier GameData table (`FishingRanks.lua` reads the
  spells).
- Records are keyed by ID with named fields where an entity has more than one fact, a set (`[id] = true`) where it
  has one, and an array where the order is the fact (the ranks).
- Each file names the source of its values (the original game on Wowhead Classic, or seen in game) and marks a
  value only the game can confirm with `-- VERIFY(<id>)`.
- String literals may hold UTF-8 official names per client language (constitution, Technical Constraints); code,
  keys and comments stay ASCII.
- What is not game data stays with its module:
  - addon tuning: timeouts, limits, grid sizes, delays;
  - API vocabulary that one module talks to the client in: chat types and restriction enum names (`Comm.lua`),
    popup names (`Channel.lua`), the creature GUID template (`Skill.lua`), UI textures and atlases, and the CVars
    fishing mode sets (`Mode.lua` `Mode.CVAR_NAMES`).

## Load order

The GameData files come in the TOC right after the locales and before `Core/Core.lua`, `FishingSpells.lua` first.
`Core/Data.lua` builds its spell lookup from the spells while the files load, and `GameData/FishingRanks.lua` reads
them, so a module may read `ns.GameData` at file load time. `tests/gamedata/load_order_test.lua` checks the order.

## The entities

| File | Table | Shape | Source and VERIFY | Readers |
|---|---|---|---|---|
| `FishingSpells.lua` | `GameData.FishingSpells` | array in rank order of `{ spellID, cap }`: Apprentice 7620 / 75, Journeyman 7731 / 150, Expert 7732 / 225, Artisan 18248 / 300 | seen in game | `Core/Data.lua` (`IsFishingSpell`, `GetFishingSpellID`), `Fishing/Gear.lua`, `Fishing/Skill.lua` (rank names, `SpellOfCap`), `UI/Indicator.lua`, `UI/StatsFrame.lua` (through `IsFishingSpell`) |
| `FishingRanks.lua` | `GameData.FishingRanks` | `[cap] = { next, learnAt, level, source = { kind, itemID?, questID?, npcID?, areaID, zoneAreaID, maps, x, y }, fallback }` | Wowhead Classic; R11 ([spec 001 verification](../../specs/001-interface-language/verification.md)) | `Fishing/Skill.lua`, `UI/StatsFrame.lua` |
| `NpcNames.lua` | `GameData.NpcNames` | `[npcID] = { [clientLocale] = name }` | Wowhead's localized pages; R12 | `Fishing/Skill.lua` (after the creature tooltip) |
| `Bobber.lua` | `GameData.Bobber` | `{ objectID = "35591" }`, a string compared with a GUID part | seen in game | `Core/Data.lua` (`IsBobberTargeted`), `Catch/Catch.lua` (pool loot) |
| `Lures.lua` | `GameData.Lures` | `[itemID] = { bonus, order, skill }`; `order` 1 is the best; `skill` 0 for none; Camper's Lure 291005 (+60, Fishing 50, from a placed Fishing Rack) is order 4, the three weaker lures 5 to 7 (spec 020) | Wowhead Classic tooltips; V43 per `skill` ([spec 008 verification](../../specs/008-architecture-alignment/verification.md)); Camper's Lure seen in game 2026-11-19 | `Fishing/Bags.lua` (`FindLure`, `DescribeLures`) |
| `FishedContainers.lua` | `GameData.FishedContainers` | set `[itemID] = true` (the four clams) | the original game | `Fishing/Bags.lua` |
| `AuctionUnanswered.lua` | `GameData.AuctionUnanswered` | set `[itemID] = true`; empty today (Plated Armorfish 13890 is searched and answered: V58) | items measured in game whose search is never answered and jams the auction house ([forever-api.md](../forever-api.md)); Winter Squid 13755, measured so on 2026-11-17, was answered on 2026-11-18 and left the list | `Catch/Auction.lua` (never searched) |
| `ItemKinds.lua` | `GameData.ItemKinds` | `{ byItem = { [itemID] = kind }, byClass = { ["<class>:<subclass>"] or ["<class>"] = kind } }`, kinds `fish`, `containers`, `potions`, `reagents`, `other`; every item of the bundled seed and every fished container is in `byItem` (`tests/catalog/kinds_test.lua` fails for a missing one) | classes read in game 2026-11-16 (`specs/014-catch-filters` spec, clarifications); the class rules are an accepted assumption, no VERIFY | `Catalog/Catalog.lua` (`ItemKind`) |
| `FishingPoles.lua` | `GameData.FishingPoles`, `GameData.FishingPoleClass` | `[itemID] = { bonus, skill }`; `{ classID = 2, subclassID = 20 }` | Wowhead Classic tooltips; `skill` is recorded, not used yet (`docs/tech-debt.md`) | `Fishing/Gear.lua` (`GetFishingBonus`, `IsFishingPole`) |
| `EquipSlots.lua` | `GameData.EquipSlots` | `{ first, last, mainHand, offHand, ranged, byEquipLoc = { INVTYPE_* = { slots } } }` | the client's `INVSLOT_*` IDs | `Fishing/Gear.lua`, `Fishing/Action.lua` (the lure's target slot), `Core/Debug.lua` |
| `CampBonuses.lua` | `GameData.CampBonuses` | array in rank order (a later entry is the higher bonus: the Hut over the Rack) of `{ key, bit, aura, item, items }`: `key` the bonus's name in filters and code (`"rack"`, `"hut"`), `bit` its bit in a cast's mask (1, 2; the next takes 4), `aura` the player aura's spell ID (1280341 "Uncommon Fishing", 1280342 "Rare Fishing"), `item` the camp feature's item ID for the tag's icon (Fishing Rack 279965, Fishing Hut 279966), `items` the known bonus items (`[itemID] = true`: the twelve Bloated fish for the Rack, none yet for the Hut) | the client's game data and the session of 2026-11-19 ([fishing-investigation.md](../fishing-investigation.md)); V60 (the Hut's aura), V61 (the Bloated fish only under a buff) ([spec 020 verification](../../specs/020-camp-buffs/verification.md)) | `Fishing/Camp.lua`, `CatchDB/Views.lua` (the filter, the tag), `Catalog/Catalog.lua` (`BonusIcon`) |
| `Icons.lua` | `GameData.Icons` | `{ unknownItem = 134400 }` | the client's file ID | `UI/CatchHere.lua` |

Not game data: the catch database's skill range step (75) and highest range (4) stay literals in `CatchDB/CatchDB.lua`,
because they are part of the saved format (place keys, the seed, records, the harvest). `tests/gamedata/shape_test.lua`
holds them equal to the Fishing ranks (`FishingSpells[1].cap`, `#FishingSpells`).

## Adding an entity

1. A new file `GameData/<Entity>.lua` with the two lines, the table, its source and its VERIFY marks.
2. Its TOC line in the GameData block, after the files it reads.
3. A shape test in `tests/gamedata/shape_test.lua`.
4. A row in the table above and in `CLAUDE.md`.

## Tests

`tests/gamedata/shape_test.lua` checks the fields and kinds of every entity. `tests/gamedata/load_order_test.lua`
checks the TOC order and the load-time read of `Core/Data.lua`. `tests/gamedata/camp_bonuses_test.lua` checks the
camp bonuses. The behaviour that reads the data is tested with its module: lures (`tests/fishing/lures_test.lua`,
`lure_skill_test.lua`), gear, the next rank (`tests/fishing/next_rank_test.lua`) and catches.
