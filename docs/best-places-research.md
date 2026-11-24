# Research: the best places to farm, and the three-level place list

Pre-spec research (2026-11-23) for spec **024**, and (section 4, 2026-11-24) for the faction rule of "Safe for me": the places worth fishing for a character, ranked by the gold an
hour of fishing brings there, and a place list in three levels (zone, subzone, spot) for this tab and the catalog. It
takes over part of the UI first planned for the Stranglethorn Fishing Extravaganza helper (now spec 025,
[extravaganza-research.md](extravaganza-research.md)). No code is written yet; the decisions below come from the
author's quiz of 2026-11-23.

## 1. What the addon already has

- **The catch database** ([architecture/catch-db.md](architecture/catch-db.md)): every place is
  `<mapID>:<range>:<cell>` (the map, the Fishing skill range in steps of 75, a 10x10 grid cell); a cell keeps catches
  `c`, misses `m`, **seconds of casting `t`**, the items `i` (catches and pieces), the subzone counts `a` (area ID ->
  casts), the average position and the camp bonus parts `q`. The seed, the own record and other players' records all
  have the same cells, so an hour's catch can be computed for any place without new data: the value of the cell's
  items divided by its `t` (misses are in `t`, so they lower the rate as they should).
- **Prices** ([architecture/catch-and-stats.md](architecture/catch-and-stats.md)): `Prices.Get(itemID)` is the
  statistics' value, the higher of the vendor price and the auction price (the own scan or Auctionator).
- **Views and filters**: `CatchDB.QueryMap` / `QueryCells` with the filters Skill (cumulative "Up to N", spec 021),
  Source (All, Only mine), Water (open, pools) and Camp bonus (spec 020); the kind choice (specs 014, 023) applies to
  finished lists.
- **The catalog** ([architecture/catalog.md](architecture/catalog.md)): an item's zones with their chance, skill span
  and catches, and its spots (`Catalog.Spots`: each spot named by its subzone through the area ID with the most
  casts, or its coordinates) with a map pin (`Core/MapPin.lua`). Today a zone opens straight into its spots, so a
  subzone repeats ("Baradin Bay" six times in Wetlands for Oily Blackmouth, seen 2026-11-23).
- **The window**: three tabs (Statistics, What can be caught here, Catalog) from the `pages` table of
  `UI/StatsFrame.lua`; the minimap menu has "Statistics" but no entry of its own for the catalog.
- **Zone levels**: `C_Map.GetMapLevels(uiMapID)` exists in the client export but gives `0 0 0 0` in Forever (seen
  2026-11-23; the client has no zone levels at all), so the levels come from a table, `GameData/ZoneLevels.lua`. Before
  that check: `C_Map.GetMapLevels(uiMapID)` returns `playerMinLevel, playerMaxLevel` (client
  export, `MapDocumentation.lua`, `MayReturnNothing`); `C_Map.GetMapInfo` walks up to the continent (`mapType`
  Continent), as `Catalog.ZoneName` already does for Micro maps. Confirmed in game on 2026-11-23 (V76).

## 2. Decisions agreed with the author (2026-11-23)

### What "best" means

- **Gold per hour**: the value of the catch per hour of casting at the place (the sum over its items of pieces x
  price, divided by its casting time). One number, the list ordered by it, highest first.
- **Prices as they are**: the statistics' value (`Prices.Get`, the higher of vendor and auction); an item without a
  price counts 0, a container by its own price. A place where at least 25 % of the catch has no price shows a "*" after its gold and says so in its tooltip
  ("N % of the catch here has no price: the gold may be higher.").
- **Top 10 zones**: the tab lists the ten zones with the most gold per hour that pass the filters, a short list
  without scrolling (asked on 2026-11-23); inside a zone every subzone and spot is listed.
- **Little data**: a zone with fewer than 50 catches is not in the top 10 (its rate is chance); a subzone or a spot
  with little data goes to the end of its group with "Little data", as in the catalog.

### Filters (a row of buttons, as on the other tabs)

- **Skill**: the cumulative "Up to N" menu of spec 021, by default the character's own range; the player can look at
  another range ("what will I get at 300").
- **Safe for me**: hides zones whose minimum level (`GameData.ZoneLevels`) is above the character's level plus 3; on
  by default. The zone's level range is shown in its row, red when above the character.
- **Kinds**: the shared kind choice also changes the gold: hidden kinds do not count in the gold per hour ("what do I
  earn on fish alone").
- **Source** (All, Only mine), **Water** (open, pools; when pool data exists) and **Camp bonus** (all casts by
  default; "Bonus catches only" shows the gold under a bonus; when bonus data exists), as on the other tabs.
- **Continent**: All, Kalimdor, Eastern Kingdoms.
- Remembered as on the other tabs: Skill, Source, Water and Camp bonus reset at login (Skill to the own range); the
  kinds stay shared and saved; "Safe for me" and Continent are saved per character (level and faction differ).

### The list: three levels

- **Zone -> subzone -> spot**: a zone row opens its subzones, a subzone its spots. A subzone groups every spot whose
  area is that subzone, so a name appears once. Spots without a known subzone (coordinates only) form a group of their
  own ("No subzone").
- A subzone with a single spot shows as that spot's row (no third level).
- A **subzone row** shows the sum of its spots and has its own map pin, by default on its spot with the best chance;
  each **spot row** shows its own numbers and its own pin.
- The same three-level list in the **catalog** (an item's zones), with the catalog's columns (skill, chance,
  catches); one shared list code for both tabs, no duplicate subzones anywhere.

### Columns and tooltip (the new tab)

- Place | Skill | Level (zone rows; red when unsafe) | Gold per hour | Catches.
- Hovering a row: a tooltip with the five items that bring the most gold there (chance, price, share of the gold) and
  how many players the numbers come from.

### Where it lives (taken over from the Extravaganza helper)

- A fourth tab of the statistics window, **"Best places"**, after the catalog.
- The minimap menu gets two entries next to "Statistics": **"Catalog"** and **"Best places"**, each opening its tab.
- A command `/okf best` opens the tab (`/okf catalog` exists).
- Spec 025 (the Extravaganza helper) then only adds its own tab and its own menu entry to this.

### Numbering

- Spec **024** `024-best-places` (released first), spec **025** `025-fishing-extravaganza`.

## 3. Open, to settle in the spec or check in game

1. Zone levels: `C_Map.GetMapLevels` gives 0 in Forever (2026-11-23); the table's ranges were confirmed in game (V75).
2. The continent of a zone through `C_Map.GetMapInfo`'s parents (Kalimdor 1414, Eastern Kingdoms 1415): confirmed
   in game on 2026-11-23 (V76).
3. The subzone of a spot comes from its area counts `a`; a cell fished in two subzones goes to the one with the most
   casts (as the catalog names it today).
4. How the gold per hour of a zone and of a subzone is summed: the value of all their cells over all their casting
   time (not an average of the spots' rates), so a busy spot weighs more.
5. The tab's performance: one view per map with data (as the catalog index), built in frame steps.

## 4. Faction territory for "Safe for me" (research of 2026-11-24, no code yet)

The author plays on a PvP mode: "Safe for me" looks only at the zone's level today and keeps the other faction's
home zones and capitals in the list. The wish: an Alliance character sees Alliance and contested zones, a Horde
character Horde and contested zones. This section is what the code, the client and the web say; the details are
settled with the author after it.

### What the code does today

- `BestPlaces.Passes` (`Catalog/BestPlaces.lua`) hides a zone when Safe for me is on and the zone's lowest level
  (`GameData.ZoneLevels`) is above the character's level plus `LEVEL_MARGIN` (3). Nothing else; a zone with no listed
  range is never hidden. `ZoneLevels(mapID)` walks up the map parents, so a cave or a building takes its zone's range.
- `Safe for me` is saved per character (`charDB.bestPlaces.safe`, default on) and switched by `BestPlaces.SetSafe`,
  which fires `SETTINGS_CHANGED("bestPlaces")`; the list is filtered when read, without a recount (only `Bump`).
- The Level column is red when the zone's minimum is above the character's level (`BestPlaces.Unsafe`).
- The research above already noted that Safe for me and Continent are per character "(level and faction differ)",
  but faction was never part of the rule.

### The client: what tells a zone's faction

- **No map API gives the faction of an arbitrary zone.** `UiMapDetails` (`C_Map.GetMapInfo`) has `mapID`, `name`,
  `mapType`, `parentMapID`, flags; nothing about territory. `C_Map.GetMapLevels` is 0 in Forever (V75).
- `C_PvP.GetZonePVPInfo()` (client export, `PvpInfoDocumentation.lua`, `MayReturnNothing`) returns `pvpType`,
  `isSubZonePvP`, `factionName` for **the zone the player stands in only**: `"friendly"`, `"hostile"`,
  `"contested"`, `"sanctuary"`, `"arena"`, `"combat"` (Blizzard's `ZoneText.lua` colours the zone text by it). Usable
  as an in-game check of the table below, not as the source of a list of zones.
- `UnitFactionGroup("player")` gives `"Alliance"`, `"Horde"` or `"Neutral"` (`UnitDocumentation.lua`). The Skyborne,
  Forever's new race, choose a faction at character creation (High Order: Alliance, Windshaper: Horde), so a Forever
  character should never be `"Neutral"` in play; the code must still treat `"Neutral"` and nil as "no faction".
- The game mode: Auctionator 347 tells it by `C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset)` (also
  `RPRuleset`, `HardcoreRuleset`), and gave `PvP` on the author's character (forever-api.md, Auctionator). The
  `GameRule` enum itself is not in the export's documentation; the call works in game through Auctionator.
  `GetNormalizedRealmName()` gives `CAMWOWEU4Realm4PvP` there too. Forever has no War Mode.

### The game data: `AreaTable.FactionGroupMask`

Read from wago.tools, product `wowf`, build 1.60.1.71037 (the author's client; 71091 is the latest on 2026-11-24),
tables `AreaTable`, `UiMapAssignment` (UiMap -> area) and `UiMap`:

- Every zone of `GameData.ZoneLevels` maps to exactly one top-level area (`ParentAreaID` 0), and its
  `FactionGroupMask` is **2 = Alliance, 4 = Horde, 0 = contested** (the classic bits: 2 Alliance, 4 Horde).
- **Alliance (2)**: Elwynn Forest 1429, Westfall 1436, Dun Morogh 1426, Loch Modan 1432, Teldrassil 1438,
  Darkshore 1439; capitals Stormwind 1453, Ironforge 1455, Darnassus 1457.
- **Horde (4)**: Durotar 1411, Mulgore 1412, The Barrens 1413, Tirisfal Glades 1420, Silverpine Forest 1421;
  capitals Orgrimmar 1454, Thunder Bluff 1456, Undercity 1458.
- **Contested (0)**: every other zone of the table, Forever's new ones too: Riverglades 2548, Shen'dralas 2652,
  Mount Hyjal 2482, Zephras Isle 2521 (2665 has no area assignment; same isle). Also Redridge, Duskwood, Wetlands,
  Ashenvale, Stonetalon, Hillsbrad (contested in vanilla; Alliance or Horde only since Cataclysm). Moonglade is 0
  without a sanctuary flag.
- **Subzones** mostly inherit (mask 0 under a faction zone means "the zone's"). The only top-level zones' subzone with
  its own mask is **Dalaran in Alterac Mountains (2, Alliance)**. The faction towns inside contested zones (Southshore
  and Tarren Mill, Astranaar and Splintertree Post, Theramore and Brackenwall, Menethil Harbor) are 0: the data does
  not mark them; their guards do. Booty Bay, Ratchet, Gadgetzan, Everlook are 0 too (neutral towns, no sanctuary flag).
- **Sanctuary** (`Flags_0` bit `0x800`): Zephras Isle and all its subzones, the City of Dalaran (a separate map). No
  classic zone has it.

### The web (community guides, not Blizzard)

- On the **PvP** ruleset (and RP-PvP) a character is flagged on entering contested or enemy territory; friendly
  territory keeps it unflagged. On **Normal and RP**, only enemy territory flags automatically
  ([wowforevertierlist](https://wowforevertierlist.com/rulesets/pvp),
  [world PvP](https://wowforevertierlist.com/pvp/world-pvp),
  [wow4ever](https://wow4ever.quest/en/articles/jcj-mundo-abierto-wow-forever)). So the other faction's home zone is
  a danger on every mode (flag and guards), contested zones only on PvP.
- "Contested zones start above roughly level 15" (Icy Veins, quoted by the guides): this matches the classic bands
  (the home zones are 1-25, the first contested ones Redridge and Stonetalon 15-25), not a new rule.
- Blizzard has published no list of contested zones; the guides call Riverglades and Shen'dralas contested, Zephras
  Isle faction-phased with no world PvP. All match the DB2 above.
- The game prints the territory under the zone name ("(Alliance Territory)", "(Contested Territory)",
  "(Sanctuary)"), from `GetZonePVPInfo`.

### Decisions agreed with the author (quiz of 2026-11-24)

Built by spec 026 ([specs/026-safe-faction](../specs/026-safe-faction/spec.md)); the in-game check V77 passed on 2026-11-24 (a Horde and an Alliance character, the tab with Safe for me on and off).

1. **Part of "Safe for me"**: one switch hides both the zones too high for the character and the other faction's
   zones. No new button, no new text.
2. **Every game mode**: the other faction's home zones flag the character and have hostile guards on Normal too; no
   mode check (`C_GameRules`) is needed. Contested zones stay listed on every mode.
3. **The other faction's capitals are hidden** like its zones (their 1-60 range only means "safe by level").
4. **Zones only**: the hostile towns inside contested zones (Tarren Mill, Southshore, Astranaar, Dalaran...) are not
   filtered; the game data marks only Dalaran, and a hand-made list by name would break Principle II. Noted as a
   known limit.
5. **The data**: a new `GameData/ZoneFactions.lua`, `[UiMapID] = "Alliance" | "Horde"`, the 17 zones and capitals
   above, written by hand with its source in the header comment (`AreaTable.FactionGroupMask` through
   `UiMapAssignment`, build 1.60.1.71037), as `ZoneLevels` cites its own. A zone not listed is contested. A cave or a
   building takes its zone's faction by the same parent walk as `BestPlaces.ZoneLevels`.
6. **With "Safe for me" off** an enemy zone stays in the list with its Level column red, as a zone too high is (no
   new text).
7. **No faction** (`UnitFactionGroup("player")` gives `"Neutral"` or nil, e.g. for a moment at login): only the level
   rule applies; the list is filtered when read, so it follows when the tab is next opened or a filter changes (the
   game knows the faction before the world loads).
8. **Spec 026** (025 stays reserved for the Extravaganza helper): spec, plan, tasks and a `verification.md` with one
   V row, checked in game (not accepted): standing in a few zones, `/run print(C_PvP.GetZonePVPInfo())` and the zone
   text agree with the table, and the tab's list on a Horde and an Alliance character hides the other side's zones
   and capitals.
