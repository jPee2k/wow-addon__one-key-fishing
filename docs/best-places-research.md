# Research: the best places to farm, and the three-level place list

Pre-spec research (2026-11-23) for spec **024**: the places worth fishing for a character, ranked by the gold an
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
