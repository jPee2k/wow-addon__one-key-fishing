# Data Model: Architecture Alignment

The game data model `ns.GameData` (layer 0, `OneKeyFishing/GameData/`, data only), and the private tables the
alignment adds. No saved field changes ([research.md](research.md) R14).

## Game data (`ns.GameData`)

Every file starts with the same two lines and then holds only table constructors:

```lua
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData
```

Values come from the original game (Wowhead Classic) unless a line says otherwise; a value only the game can
confirm carries `-- VERIFY(<id>)`. Comments name each ID (English names, ASCII).

| File (TOC order) | Table | Shape | Replaces | Readers |
|---|---|---|---|---|
| `FishingSpells.lua` | `GameData.FishingSpells` | array in rank order: `{ spellID, cap }` (Apprentice 7620 / 75, Journeyman 7731 / 150, Expert 7732 / 225, Artisan 18248 / 300) | `ns.FISHING_SPELL_IDS` (Core/Data.lua), `ns.FishingRankSpells`, the spell IDs of Skill.lua's fallback names | Core/Data.lua (spell lookup at load, `GetFishingSpellID`), Fishing/Gear.lua, Fishing/Skill.lua, UI/Indicator.lua, UI/StatsFrame.lua |
| `FishingRanks.lua` | `GameData.FishingRanks` | `[cap] = { next = spellID, learnAt, level, source = { kind, itemID?, questID?, npcID?, area, zone, maps, x, y }, fallback = { ... } }`, as today | `ns.FishingRanks` | Fishing/Skill.lua, UI/StatsFrame.lua |
| `NpcNames.lua` | `GameData.NpcNames` | `[npcID] = { [clientLocale] = name }` (UTF-8 inside the strings) | `ns.NpcNames` (was in FishingRanks.lua) | Fishing/Skill.lua |
| `Bobber.lua` | `GameData.Bobber` | `{ objectID = "35591" }` (a string: it is compared with a GUID part) | `ns.BOBBER_OBJECT_ID` | Core/Data.lua (`IsBobberTargeted`), Catch/Catch.lua (pool loot) |
| `Lures.lua` | `GameData.Lures` | `[itemID] = { bonus, order, skill }`; `order` 1 is the best; `skill` is the Fishing skill needed, 0 for none | `LURES` (Fishing/Bags.lua) | Fishing/Bags.lua (`FindLure`, `DescribeLures`) |
| `FishedContainers.lua` | `GameData.FishedContainers` | set `[itemID] = true` (5523, 5524, 7973, 15874) | `CONTAINERS` (Fishing/Bags.lua) | Fishing/Bags.lua |
| `FishingPoles.lua` | `GameData.FishingPoles`, `GameData.FishingPoleClass` | `[itemID] = { bonus, skill }`; `{ classID = 2, subclassID = 20 }` | `KNOWN_POLE_BONUS`, `FISHING_POLE_CLASS`, `FISHING_POLE_SUBCLASS` (Fishing/Gear.lua) | Fishing/Gear.lua (`GetFishingBonus`, `IsFishingPole`) |
| `EquipSlots.lua` | `GameData.EquipSlots` | `{ mainHand = 16, offHand = 17, ranged = 18, byEquipLoc = { INVTYPE_HEAD = { 1 }, ... } }` | `MAINHAND_SLOT`, `OFFHAND_SLOT`, `WEAPON_SLOTS`, `SLOTS_BY_EQUIP_LOC` (Fishing/Gear.lua) | Fishing/Gear.lua |
| `Icons.lua` | `GameData.Icons` | `{ unknownItem = 134400 }` (INV_Misc_QuestionMark) | `UNKNOWN_ICON` (UI/CatchHere.lua) | UI/CatchHere.lua, UI/CatalogTab.lua if it shows item icons |

### Lures

| itemID | Lure | bonus | order | skill |
|---|---|---|---|---|
| 6533 | Aquadynamic Fish Attractor | 100 | 1 | 100 |
| 7307 | Flesh Eating Worm | 75 | 2 | 100 |
| 6532 | Bright Baubles | 75 | 3 | 100 |
| 6811 | Aquadynamic Fish Lens | 50 | 4 | 50 |
| 6530 | Nightcrawlers | 50 | 5 | 50 |
| 6529 | Shiny Bauble | 25 | 6 | 0 |

The order is the order of today's `LURES` list, best first; `Bags.FindLure` walks the lures by `order`. Each `skill`
carries `-- VERIFY(V43)`.

### Fishing poles

| itemID | Pole | bonus | skill |
|---|---|---|---|
| 6256 | Fishing Pole | 0 | 0 |
| 12225 | Blump Family Fishing Pole | 3 | 1 |
| 6365 | Strong Fishing Pole | 5 | 10 |
| 6366 | Darkwood Fishing Pole | 15 | 50 |
| 6367 | Big Iron Fishing Pole | 20 | 100 |
| 19022 | Nat Pagle's Extreme Angler FC-5000 | 25 | 100 |
| 19970 | Arcanite Fishing Pole | 35 | 300 |

`bonus` stays the fallback for an unreadable tooltip; `skill` is recorded for later use (tech-debt, low) and read
by nothing yet except the shape test. It has no `VERIFY` marker, because no code builds on it.

### Rules

- Shape (tested in `tests/gamedata/shape_test.lua`): IDs are positive whole numbers (the bobber's is a string of
  digits). `bonus`, `skill`, `cap`, `learnAt` and `level` are whole numbers of 0 or more. `order` runs 1..n without
  a gap. The spells' caps are 75, 150, 225, 300. Every `FishingRanks` key is a cap of a spell, and its `next` is
  the spell of the following rank.
- Not game data (spec 008 review): the catch database's range step (75) and highest range (4) stay literals in
  `CatchDB/CatchDB.lua`, since they are part of the saved format; `tests/gamedata/shape_test.lua` holds them equal
  to `FishingSpells[1].cap` and `#FishingSpells`.
- Not in the model: the CVars of fishing mode, chat types, restriction enum names, popup names, GUID templates,
  textures and atlases (research R1).

## Private tables

| Table | New entries | Was |
|---|---|---|
| `CatchDB.private` | `OwnProofReady`, `STEP_SECONDS`; from the split: `SeedIndex`, `Others`, `Frozen`, `OwnIndex`, `SeedItems`, `OwnItems` (and `IsOwnKey`, `IndexRecord`, `UnindexRecord`, now from Index.lua) | `CatchDB.OwnProofReady`, `CatchDB.STEP_SECONDS`; locals of Views.lua |
| `Comm.private` (new) | `GetPaths`, `PREFIX`, `MAX_MESSAGE`, `MAX_PARTS`, `Enabled`, `buffers`, `flooded` | `Comm.GetPaths`; locals of Comm.lua |

The tables are never reassigned after load, so a later file can bind their entries to locals.

## Module functions that change

| Function | Change |
|---|---|
| `MapPin.Target(maps, x, y)` | Falls back to the parent map through the world position when no candidate allows a pin (from `Catalog.PinTarget`) |
| `Catalog.PinTarget` | Removed; `Catalog.Spots` calls `MapPin.Target` after its own rules |
| `CatalogTab.Pin` | Calls `MapPin.Set` (no own body) |
| `Bags.FindLure` | Skips a known lure whose `skill` is above `Skill.Get()` |
| `Bags.DescribeLures` | Adds `needs: <skill>` to each line |
| `CatchDB.OwnRecord(store)` | New public, with Share's checks; replaces both local `OwnRecord`s |
| `CatchDB.LITTLE_DATA` | New export (50); Share's `RARE_CATCHES` goes |
| `Catalog.DefaultFilter()` | New: a fresh copy of the default filter |
| `Mode.CVAR_NAMES` | New: every CVar fishing mode may change |
| `ns.RangeLabel(min, max)`, `ns.UpdateScanButton(button, hint)` | New in UI/Widgets.lua |
| `ns.FISHING_SKILL_LINE`, `ns.Minimap` | Removed |
| The debug report | Lists `ns.earlyLookups` (the keys looked up before the language was set) |
