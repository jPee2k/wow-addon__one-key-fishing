# Feature Specification: Local Catch Database

**Feature Branch**: `002-shared-db` (renamed from `002-local-catch-db`; all four parts are built on it)

**Created**: 2026-10-29

**Status**: Draft

**Release**: 1.2.0, together with parts 2 to 4 of the shared catch database (decided on
2026-10-29; 1.1.0 is the interface-language release). The release numbers in the input below are from the
earlier plan of one release per part.

**Input**: User description: "Catch database, part 1 of 4 (release 1.1.0): local catch data and bundled data, no
network. Players want to know what a fishing spot gives, and in what proportions, before spending time there. A
'What can be caught here' tab in the statistics window; data from the first login through a catch database bundled
with every release; places identified by numbers only; robust auction prices; one command for the author before a
release. Design and agreed decisions: docs/shared-db-plan.md (section 'Releases and specs' -> 'Part 1 (spec 002): local
catch data and bundled data')."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See what the current spot gives (Priority: P1)

A player stands at a fishing spot and opens the statistics window. Besides the familiar statistics, the window now
has a second tab, "What can be caught here". It lists the items caught at this spot: for each item its icon, name,
the chance that a catch contains it, the average number of pieces per catch and its price, plus how many catches
the numbers are based on and, on its own line, how often casts here end in a miss. When the spot itself has little
data, the tab uses the whole map; when that has little data too, it says so instead of showing a percentage. The
player can narrow the list to a skill range (their own by default, any other range or all ranges together) and to
their own catches only. The numbers follow the player when they move to another spot.

**Why this priority**: this is the value of the feature: the player decides where to fish from data instead of
guesswork. It works on the player's own catches alone, so it is useful even before any bundled data exists.

**Independent Test**: fish at one spot for a while in fishing mode, open the tab and check the items, chances,
counts and miss rate against what was caught; walk to a spot with no catches and check the whole-map fallback and
the "little data" and "no data" texts; switch the filters and check that the list changes accordingly.

**Acceptance Scenarios**:

1. **Given** the player has 60 catches at the current spot in their skill range, **When** they open "What can be
   caught here", **Then** each item caught there is listed with its chance (catches containing it / all catches at
   the spot), the average pieces per catch and its price, and the tab shows "60 catches" and the miss rate.
2. **Given** 20 catches at the current spot and 300 on the same map, **When** the tab is open, **Then** it shows the
   numbers for the whole map and says that it does.
3. **Given** 20 catches at the spot and 30 on the whole map, **When** the tab is open, **Then** the items are listed
   with "little data" in place of the percentage.
4. **Given** no catches at all for the spot or its map, **When** the tab is open, **Then** it explains that nothing
   has been caught here yet.
5. **Given** catches in two skill ranges at the spot, **When** the player switches the skill filter from their own
   range to "All", **Then** the list and counts include both ranges; no switch happens by itself when the own range
   has little data, only a hint to try "All".
6. **Given** the player closed the window on "What can be caught here", **When** they log in again and open it,
   **Then** it opens on that tab, with both filters back at their defaults.
7. **Given** two players on clients in different languages fish at the same spot, **When** their data is compared,
   **Then** it is recorded under the same place, and each sees the place named in their own language.

---

### User Story 2 - Data from the first login (Priority: P2)

A player installs or updates the addon. Without having fished anywhere yet, they open "What can be caught here" in
a zone that other addon users have fished, and the tab already shows items and chances from the catch database that
comes with the release. As they fish, their own catches are added to those numbers; nothing is counted twice, also
not for the author whose catches went into the bundled data. The source filter lets them look at their own catches
only.

**Why this priority**: a fresh install should not start empty; but it builds on the tab of Story 1 and on the
bundled data produced in Story 3.

**Independent Test**: install the addon with a bundled database on a character with no catches, open the tab in a
zone covered by it and check the numbers; fish there and check that the counts grow by exactly the own catches;
switch to "Only mine" and check that only the own catches remain.

**Acceptance Scenarios**:

1. **Given** a fresh install and bundled data for the current spot, **When** the player opens the tab, **Then** the
   items and chances from the bundled data are shown under the source filter "All".
2. **Given** bundled data with 1,000 catches at the spot, **When** the player catches 5 more there, **Then** the tab
   shows 1,005 catches.
3. **Given** the player's own catches already went into the bundled data of this release, **When** they open the
   tab, **Then** those catches are counted once.
4. **Given** "Only mine" is chosen, **When** the tab is open, **Then** only the player's own catches (all characters
   of the account) are counted.

---

### User Story 3 - The author refreshes the bundled data (Priority: P3)

Before a release, the author runs one command on their PC. It finds the addon's saved data of every game account on
that PC, also takes the saved files friends handed over, checks all of it, merges it into the previous bundled data
and writes the new bundled data file for the release. It prints a report: new places, new items, rejected data and
the file size. After a game patch that changed what a zone gives, the author can reset that zone so it is counted
again from new data only.

**Why this priority**: it is the only source of the bundled data in this release, but it is a tool for one person
and can be run before any player-facing release.

**Independent Test**: run the command on prepared saved files (several accounts, a friend's file, one broken file)
and check the written file and the report; run it again with the same input and check that nothing is counted
twice; run it with a zone reset and check that the zone's old numbers are gone.

**Acceptance Scenarios**:

1. **Given** saved data in two game accounts and one friend's file, **When** the author runs the command, **Then**
   the data of all three is merged into the new bundled data file and the report lists new places, new items and
   the file size.
2. **Given** a file with impossible numbers or a broken format, **When** the command runs, **Then** that data is
   left out and the report names it as rejected.
3. **Given** the same saved files as the previous run, **When** the command runs again, **Then** the numbers in the
   bundled data do not grow.
4. **Given** a zone reset is requested, **When** the command runs, **Then** the zone's earlier numbers are dropped
   and only data recorded in the current game version is kept for it.
5. **Given** the result would exceed the size limit, **When** the command runs, **Then** it stops with a clear
   message instead of writing an oversized file.

---

### User Story 4 - Trustworthy auction prices (Priority: P4)

A player scans auction prices. A single lot listed far below or far above everyone else no longer decides the price
of an item: the price reflects what the item really sells for. When only a handful of pieces are on sale, the price
is marked as based on few lots and the value of the catch uses the vendor price instead. This applies to the new tab
and to the existing statistics.

**Why this priority**: the new tab shows prices next to chances, so a misleading price would mislead the choice of
spot; the change is small and independent of the rest.

**Independent Test**: scan prices for items with a normal market, with one very cheap lot among many, and with only
a few pieces on sale; compare the shown prices and catch values with the expected ones.

**Acceptance Scenarios**:

1. **Given** 100 pieces on sale at about 2 gold and one piece at 1 copper, **When** prices are scanned, **Then** the
   item's price is about 2 gold.
2. **Given** 100 pieces at about 2 gold and one piece at 9,999 gold, **When** prices are scanned, **Then** the price
   is about 2 gold.
3. **Given** only 3 pieces on sale, **When** prices are scanned, **Then** the price is shown with a "few lots" mark
   and catch value totals use the vendor price for this item.
4. **Given** an auction price below the vendor price, **When** the value is shown, **Then** the vendor price is used,
   as today.

---

### Edge Cases

- The player's position on the map is not available (some caves or dungeons): the catch is recorded for the whole
  map, not for a spot.
- The game gives no map for the player at all (some instances, transitions): the tab says that the game does not
  show this place on the map.
- The player moves to another spot or map while the tab is open: the tab switches to the new spot.
- The player's fishing rank crosses into the next skill range while the tab is open: the filter follows the new
  range only if the player has not picked a range by hand since login; a hand-picked range stays until the next
  login.
- An item's name or icon is not yet known to the client: the row appears as soon as the game provides them, without
  reopening the window.
- Fishing outside fishing mode: not counted, as in today's statistics.
- A cast that runs across a reload is counted once, as in today's statistics.
- The game version changes: new catches are recorded under the new version, old ones are kept.
- The game cannot tell pool catches from open water: no pool data is recorded, nothing else changes.
- The interface language is switched: place names and item names show in the new language, the data is the same.
- The bundled data is missing or damaged: the tab works on the player's own catches and says nothing is bundled.
- A friend's file is from an older addon version: it is read if its data can be checked, otherwise rejected in the
  report.

## Requirements *(mandatory)*

### Functional Requirements

**Recording**

- **FR-001**: The addon MUST record every catch and miss made in fishing mode under a place made of numbers only:
  the map, a cell of a 10 by 10 grid over that map, and the skill range. Fishing outside fishing mode MUST NOT be
  recorded.
- **FR-002**: The map MUST be the one the game reports for the player's position, without combining it with parent
  maps. When the position on the map is not available, the catch MUST be recorded for the whole map.
- **FR-003**: The skill range MUST be the player's base fishing rank divided into steps of 75 points (0-74, 75-149,
  150-224, 225-299, 300 and above); bonuses from poles and lures MUST NOT change it.
- **FR-004**: For each place the addon MUST record the number of catches, misses and seconds spent casting; for each
  item, the number of catches that contained it and the number of pieces; and an average cast position within the
  cell.
- **FR-005**: The data MUST be kept once per game account, adding up all its characters, under a random anonymous
  identifier. It MUST NOT contain character names, guild, exact positions, session times or gear.
- **FR-006**: Every record MUST carry the game version it was collected in.
- **FR-007**: When the game can tell a pool from open water, pool catches MUST be counted apart; they are not shown in
  this release.
- **FR-008**: The existing statistics MUST keep working unchanged; they are not converted into the new data. Adding
  the new data MUST migrate saved data without losing anything.

**What can be caught here**

- **FR-009**: The statistics window MUST have two tabs: "Statistics" (today's content) and "What can be caught here".
  The window MUST reopen on the last open tab, also after a new login.
- **FR-010**: The tab MUST list the items of the player's current place: icon, name, chance, average pieces per
  catch and price; and show the number of catches the numbers are based on and the miss rate on its own line.
- **FR-011**: Chance MUST be the number of catches containing the item divided by all catches of the place; misses
  MUST NOT be part of it.
- **FR-012**: With fewer than 50 catches at the place, the tab MUST use all cells of the same map and say so; with
  fewer than 50 there too, it MUST show "little data" instead of percentages; with no catches it MUST say that
  nothing has been caught here yet.
- **FR-013**: A skill filter MUST offer each skill range and "All", with the player's own range as the default. The
  addon MUST NOT switch the filter by itself; with little data in the chosen range it MAY suggest "All".
- **FR-014**: A source filter MUST offer "All" (own and bundled data) and "Only mine", with "All" as the default.
- **FR-015**: Both filters MUST return to their defaults on the next login.
- **FR-016**: The tab MUST follow the player to a new place without being reopened.
- **FR-017**: Place and item names MUST be shown in the addon's interface language and the client's data; every new
  text MUST be translated into all supported interface languages.

**Bundled data**

- **FR-018**: Every release MUST be able to carry a bundled catch database that the tab merges with the player's own
  data from the first login.
- **FR-019**: Data MUST never be counted twice: the player's own catches that already went into the bundled data MUST
  count once, and merging the same data again MUST NOT change the numbers.
- **FR-020**: The bundled data MUST be readable text and MUST NOT exceed 1 MB.

**Author's command**

- **FR-021**: One command MUST find the addon's saved data of every game account on the author's PC and MUST also
  accept further saved files given to it.
- **FR-022**: The command MUST check the data (types, limits, plausible numbers such as no more catches than the time
  fished allows) and leave out data that fails, naming it in the report.
- **FR-023**: The command MUST merge the accepted data into the previous bundled data, write the new bundled data
  file and print a report with new places, new items, rejected data and the file size.
- **FR-024**: The command MUST be able to reset a zone, after which the zone counts only data of the current game
  version.

**Auction prices**

- **FR-025**: The auction price of an item MUST be the average unit price of the cheapest 20% of all pieces on sale,
  instead of the lowest lot.
- **FR-026**: With fewer than 5 pieces or fewer than 3 auctions on sale, the price MUST be marked as based on few
  lots, and catch value totals
  MUST use the vendor price for that item.
- **FR-027**: The shown value MUST stay the higher of the vendor and the auction price; this MUST apply to the new tab
  and to the existing statistics.

**Before the release**

- **FR-028**: Before the release, an in-game check MUST confirm: the position on the map while fishing, whether
  pools can be told apart, which maps caves and cities report, and how many auction results the game returns. The
  game opens on 2026-11-04, so the feature is built before that on marked assumptions; the release MUST NOT happen
  while any assumption is unchecked. The answers MUST be recorded with the other verified game facts.

### Key Entities

- **Place**: a map, a 10 by 10 grid cell on it (or the whole map) and a skill range; identified by numbers only and
  named for display in the player's language.
- **Place counts**: per place, catches, misses, seconds spent casting, an average cast position, and per item the
  catches containing it and its pieces; optionally split into pool and open water.
- **Contribution**: one account's place counts under a random anonymous identifier, with the game version and a
  version of the bundled data it was counted against.
- **Bundled database**: the merged counts per place shipped with a release, the list of contributions already in it,
  and its own version.
- **Auction price**: per item, the robust price, the number of pieces it is based on and the scan time.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A player with no catches of their own sees items and chances for every place covered by the bundled
  data on their first login.
- **SC-002**: For a place with known catches, the tab's counts equal the bundled counts plus the player's own
  catches, with no catch counted twice, in 100% of the tested cases.
- **SC-003**: Two clients in different languages record the same catch at the same spot under the same place.
- **SC-004**: Logging in, opening the window and fishing show no noticeable stutter with a bundled database covering
  the whole world (about 3,000 places); login time grows by no more than 1 second.
- **SC-005**: A single extreme lot (1 piece at 1 copper or at 9,999 gold among 100 normal pieces) changes an item's
  shown price by less than 5%.
- **SC-006**: The author prepares the bundled data for a release with one command and no manual steps, in under 1
  minute.
- **SC-007**: After the update, the existing statistics show the same numbers as before for all earlier catches.

## Assumptions

- Only fishing in fishing mode is counted, because misses are only known there.
- The first bundled data may be small (the author's and friends' catches, plus what the exchange of part 2
  collected); release 1.2.0 ships with whatever there is.
- Players who send their saved files to the author do so voluntarily, outside the game.
- The game cannot be played before 2026-11-04; game behaviour is assumed from public API dumps and checked in game
  before the release (FR-028).
- No new settings are added in part 1; sharing settings come with the in-game exchange (part 2).
- The skill range may turn out not to affect the catch; the data is recorded with it so this can be checked later.
- Item names come from the game client, so items unknown to the client show once the game provides their data.
- Network exchange, the catch catalog, map pins and tooltips are out of scope (parts 2 to 4 in
  `docs/shared-db-plan.md`).
