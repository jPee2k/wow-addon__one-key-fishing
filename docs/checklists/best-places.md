# In-game checklist: the best places to farm

**Feature**: the "Best places" tab (the top 10 zones by gold per hour, its filters, the zones opening into subzones
and spots with pins), the catalog's three levels, the minimap menu entries "Catalog" and "Best places", `/okf best`
(`specs/024-best-places`).
**Closes**: V75 and V76 ([verification.md](../../specs/024-best-places/verification.md)).
**Needs**: one character with Fishing and the bundled data, at level 30 or below for step 4; an auction scan or
Auctionator for real prices (else vendor prices only).

## Setup

1. Install the build (`npm run install-addon`). **New files in the TOC: restart the game** (a `/reload` is not enough).
2. Log in on the character with Fishing.

## Steps

### The game's map data

1. [x] V75 (the API): `C_Map.GetMapLevels` gave `0 0 0 0` for every zone (2026-11-23); the levels now come from
   `GameData/ZoneLevels.lua`. Check its ranges against the game where you can (Riverglades 35-45 matched): the tab
   showed the table's ranges, Safe for me at level 7 kept the zones of minimum 10 and hid higher ones (2026-11-23).
2. [x] V76 (2026-11-23: Kalimdor and Eastern Kingdoms each kept their own zones): type the `/run` line of V76; paste the six lines: ____. Kalimdor's zones print 1414, the Eastern
   Kingdoms' 1415.

### The tab

3. [x] The minimap menu lists **Statistics**, **Catalog**, **Best places**; **Best places** opens the fourth tab:
   up to ten zones, the richest first, with Skill, Level, Gold per hour and Catches; the texts fit the buttons.
4. [x] **Safe for me: On** hides zones more than 3 levels above the character; **Off** shows them, their level in
   red.
5. [x] **Continent**: Kalimdor and Eastern Kingdoms (in the client's language) keep their zones only.
6. [x] Hide **Containers** in **Kinds**: the gold changes at once.
7. [x] Open a zone: each subzone once, a lone spot as its row, "No subzone" for spots without one; open a subzone:
   its spots, each with a pin; the subzone's pin marks its best spot on the map.
8. [x] Hover a zone: up to five items with their share of the gold and the players; a "*" place says what share of
   its catch has no price.
9. [x] `/okf best` opens the tab.

### The catalog

10. [x] `/okf catalog`, Oily Blackmouth, Wetlands: Baradin Bay and Menethil Harbor once each, opening into their
    spots with pins (no subzone repeated).

## Results

- Date: 2026-11-23 Client language: enUS client, ukUA interface Build: 1.5.2 + spec 024 (`7512b90`, linked folder)
- Found in game and fixed before this run: `C_Map.GetMapLevels` gives 0 in Forever (V75): the levels moved to
  `GameData/ZoneLevels.lua`; the capitals and Moonglade read 1-60; the continent map Kalimdor (old records) is no
  longer ranked.
- Problems found: none. Step 8: no "*" place in the top 10 to hover (the unpriced line is covered by the tests).
