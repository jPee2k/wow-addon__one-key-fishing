# Feature Specification: The Best Places to Farm, and the Three-Level Place List

**Feature Branch**: `024-best-places`

**Created**: 2026-11-23

**Status**: Draft

**Input**: User description: "best farming places". The author's request (translated): "the best farming place by
skill, level and auction price"; and "a three-level list: today the catalog shows Wetlands, then Baradin Bay, Baradin
Bay, Baradin Bay; the subzones should be grouped so there are no duplicates, and they open into the list with pins".
The design was agreed in a quiz on 2026-11-23: [docs/best-places-research.md](../../docs/best-places-research.md).

## Clarifications

### Decisions of the author, 2026-11-23

- "Best" means **gold per hour** of fishing at a place: the value of its catch over its casting time.
- Prices are the statistics' values (the higher of vendor and auction); an item without a price counts 0.
- The tab lists the **top 10 zones** that pass the filters; inside a zone, every subzone and spot.
- A zone with fewer than 50 catches is left out of the top 10; a subzone or a spot with little data goes to the end of
  its group with "Little data".
- Filters: **Skill** (a menu, the own range by default), **Safe for me** (hides zones above the character's level
  plus 3, on by default), **Kinds** (the shared choice; hidden kinds do not count in the gold), **Source**, **Water**,
  **Camp bonus** (as on the other tabs), **Continent** (All, Kalimdor, Eastern Kingdoms).
- Remembered as on the other tabs: Skill, Source, Water and Camp bonus start at their defaults at every login; the
  kinds stay shared and saved; "Safe for me" and Continent are saved per character.
- A **three-level list** (zone, subzone, spot) in this tab **and in the catalog**: a subzone row shows the sum of its
  spots and has its own map pin, by default on its spot with the best chance; each spot keeps its own numbers and pin.
- Columns: Place, Skill, Level (zone rows, red when unsafe), Gold per hour, Catches; hovering a row shows the five
  items that bring the most gold there and how many players the numbers come from.
- Where: a fourth tab **"Best places"** after the catalog; the minimap menu gets **"Catalog"** and **"Best places"**
  next to "Statistics"; a command `/okf best`. These parts were first planned for the Extravaganza helper, now spec
  025.

### Session 2026-11-23

- Q: When is a zone unsafe for "Safe for me"? → A: when its lowest level is above the character's level plus 3; its
  level shows in red as soon as its lowest level is above the character's level.
- Q: Does a subzone with one spot open into a third level? → A: no; it shows as that spot's row ("Subzone (x, y)"
  with its numbers and pin), as the catalog shows spots today.
- Q: When does a place say its gold leaves something out, and how? → A: when at least 25 % of its catch (pieces)
  has no price (neither vendor nor auction); the gold carries a "*" and the tooltip says "N % of the catch here has
  no price: the gold may be higher." (not "the gold is incomplete", which reads unclear).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Where to fish for gold (Priority: P1)

A level 35 character with Fishing 180 wants gold. They open "Best places" from the minimap menu: ten zones are listed,
the one bringing the most gold per hour first, each with its skill span, its level range, its gold per hour and its
catches. Zones too dangerous for a level 35 character are not listed.

**Why this priority**: it is the feature's purpose; everything else refines it.

**Independent Test**: with data for twelve zones, open the tab: ten zones, ordered by gold per hour, none above the
character's level; switch "Safe for me" off: a zone above the level shows, its level in red.

**Acceptance Scenarios**:

1. **Given** catch data for many zones, **When** the player opens "Best places", **Then** at most ten zones are
   listed, ordered by gold per hour, highest first.
2. **Given** a zone's catches and casting time, **When** its gold per hour is shown, **Then** it equals the value of
   its catch (pieces of each item times its price) divided by its hours of casting.
3. **Given** "Safe for me" is on, **When** a zone's lowest level is above the character's level plus 3, **Then** the
   zone is not listed; **When** it is off, **Then** the zone is listed with its level range in red; a zone up to 3
   levels above is listed, its level in red.
4. **Given** a zone with fewer than 50 catches, **When** the list is built, **Then** that zone is not in the top 10.
5. **Given** no zone passes the filters, **When** the tab is drawn, **Then** it says that nothing matches, not that
   there is no data.

---

### User Story 2 - Narrow the list (Priority: P1)

The player sets Skill to "Up to 300" to see what they will earn later, picks Kalimdor only, and hides Containers so
the gold counts fish alone. The list and the numbers follow each choice at once.

**Why this priority**: without the filters the ranking does not fit the player's situation.

**Independent Test**: change each filter in turn: the list and the gold follow at once; relog: Skill, Source, Water
and Camp bonus are back at their defaults, "Safe for me" and Continent kept for that character, the kinds kept.

**Acceptance Scenarios**:

1. **Given** the Skill menu, **When** the player picks a range, **Then** the gold and the ranking use the catches up
   to that range, as the Skill filter of the other tabs does.
2. **Given** a kind is hidden, **When** the gold per hour is computed, **Then** that kind's items count nothing.
3. **Given** Continent is Kalimdor, **When** the list is built, **Then** only zones of Kalimdor are ranked.
4. **Given** Source, Water or Camp bonus, **When** chosen, **Then** they act as on "What can be caught here".
5. **Given** a relog, **When** the tab opens, **Then** Skill (own range), Source, Water and Camp bonus are at their
   defaults, "Safe for me" and Continent are as this character left them, and the kinds as the account left them.

---

### User Story 3 - Go there: subzones and spots with pins (Priority: P1)

The player opens the best zone: its subzones are listed once each ("Baradin Bay", "Menethil Harbor"), each with its
sum and a pin; opening a subzone shows its spots, each with its own numbers and pin. A click on the subzone's pin
marks its best spot on the map.

**Why this priority**: a zone alone does not tell where to stand; the duplicate subzones of the catalog were the
author's complaint.

**Independent Test**: a zone with six spots in Baradin Bay and three in Menethil Harbor: two subzone rows; Baradin
Bay opens into six spots; its pin marks the spot with the best chance.

**Acceptance Scenarios**:

1. **Given** spots of one subzone, **When** their zone is opened, **Then** the subzone appears once, with the sum of
   its spots' catches and its own gold per hour (its catch value over its casting time).
2. **Given** a subzone row, **When** its pin is clicked, **Then** the map pin is set on its spot with the best chance.
3. **Given** a subzone is opened, **When** its spots are listed, **Then** each shows its own numbers and its own pin.
4. **Given** spots without a known subzone, **When** the zone is opened, **Then** they are grouped under "No
   subzone".
5. **Given** a subzone or spot with little data, **When** listed, **Then** it goes to the end of its group with
   "Little data".

---

### User Story 4 - The same three levels in the catalog (Priority: P2)

In the catalog, an item's zones open into subzones and then spots, with the catalog's own columns (skill, chance,
catches); no subzone is listed twice.

**Why this priority**: it fixes the duplicates the author saw; it reuses story 3's list.

**Independent Test**: Oily Blackmouth in Wetlands (the author's screenshot of 2026-11-23): Wetlands opens into
Baradin Bay and Menethil Harbor, each opening into its spots.

**Acceptance Scenarios**:

1. **Given** an item's zone in the catalog, **When** opened, **Then** its subzones are listed once each, with the
   item's chance and catches summed over their spots, and a pin on the spot with the best chance.
2. **Given** a subzone, **When** opened, **Then** its spots show the item's chance and catches and their pins, as
   the spot rows do today.

---

### User Story 5 - What earns the gold (Priority: P3)

Hovering a zone, subzone or spot shows the five items that bring the most gold there, with each one's chance, price
and share of the gold, and how many players the numbers come from.

**Independent Test**: hover the top zone: five items, their shares adding up to at most 100 %, and a player count.

**Acceptance Scenarios**:

1. **Given** a row, **When** hovered, **Then** the tooltip lists up to five items by the gold they bring, each with
   chance, price and share, and the number of players behind the numbers.

---

### User Story 6 - Ways in (Priority: P2)

The minimap button's menu has "Catalog" and "Best places" next to "Statistics", each opening its tab; `/okf best`
opens "Best places".

**Acceptance Scenarios**:

1. **Given** the minimap menu, **When** opened, **Then** it lists "Statistics", "Catalog" and "Best places", each
   opening the window on its tab.
2. **Given** `/okf best`, **When** typed, **Then** the window opens on "Best places".

---

### Edge Cases

- A zone the game gives no level range for (a city, a map without levels): it is never hidden by "Safe for me" and
  shows no level.
- A zone whose continent cannot be told: it is listed under All only.
- Items without a price: they count 0; a place where at least 25 % of the catch (pieces) has no price shows a "*"
  after its gold, and its tooltip says what share has no price and that the gold may be higher (FR-015).
- Prices change (an auction scan, Auctionator): the ranking follows at the next draw.
- A spot fished in two subzones belongs to the one with the most casts there.
- Fewer than ten zones pass the filters: only those are listed.
- The character's level or skill changes while the tab is open: the defaults follow at the next draw.
- Casts the database does not record (an instance, no position) are not in any place.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The addon MUST compute a place's gold per hour as the value of its catch (each item's pieces times its
  price, the price as the statistics use it) divided by its hours of casting, for a zone, a subzone and a spot alike
  (a group sums its catch value and its casting time, never averages its members' rates). Under a Water or Camp
  bonus filter the value of a catch comes from the filtered catches and the pace (catches per hour) from the whole
  place, since those parts keep no casting time (research R1).
- **FR-002**: "Best places" MUST list at most ten zones, the ones with the most gold per hour among those that pass
  the filters and have at least 50 catches, highest first.
- **FR-003**: Each zone MUST open into its subzones, each subzone into its spots; a subzone MUST appear once per zone;
  a subzone with a single spot MUST show as that spot's row (no third level); spots without a known subzone MUST form
  one group "No subzone".
- **FR-004**: A subzone row MUST show the sum of its spots and a map pin set on its spot with the best chance; a spot
  row MUST show its own numbers and pin.
- **FR-005**: Within a zone, subzones and spots MUST be ordered by gold per hour (in the catalog: by chance), those
  with little data last with "Little data".
- **FR-006**: The tab MUST offer the filters Skill (the cumulative ranges, the own range by default), Safe for me (on
  by default), Kinds (shared with the other tabs; hidden kinds count nothing), Source, Water, Camp bonus (each as on
  the other tabs, Water and Camp bonus only when their data exists) and Continent (All, Kalimdor, Eastern Kingdoms).
- **FR-007**: "Safe for me" MUST hide a zone whose lowest level is above the character's level plus 3; the Level
  column MUST show a zone's level range, in red when its lowest level is above the character's level.
- **FR-008**: Skill, Source, Water and Camp bonus MUST start at their defaults at every login; "Safe for me" and
  Continent MUST be saved per character; the kind choice stays as it is.
- **FR-009**: The columns MUST be Place, Skill, Level, Gold per hour and Catches; a row's tooltip MUST list up to five
  items by the gold they bring (chance, price, share) and the number of players behind the numbers.
- **FR-010**: The catalog's item places MUST use the same three levels, with its own columns and order.
- **FR-011**: The window MUST have a fourth tab "Best places" after the catalog; the minimap menu MUST have "Catalog"
  and "Best places" entries opening their tabs; `/okf best` MUST open "Best places".
- **FR-012**: Zones, subzones and items MUST be told by their IDs (map, area, item), never by their names; the level
  and continent come from the game's map data.
- **FR-013**: Every new text MUST be shown in the addon's language, with a translation in every supported language.
- **FR-014**: The change MUST be recorded in the changelog and the player manual (the tab, its filters, the three
  levels in both tabs, the menu entries, the command).
- **FR-015**: A place where at least 25 % of the catch (pieces) has no price MUST show a "*" after its gold per hour,
  and its tooltip MUST say that share ("N % of the catch here has no price: the gold may be higher."); the mark MUST
  NOT change the ranking.

### Key Entities

- **Place group**: a zone, a subzone of a zone, or a spot; has catches, casting time, catch value, players, and for a
  zone a level range and a continent.
- **Gold per hour**: catch value over casting hours of a place group.
- **Filter state**: the six filters; Safe for me and Continent saved per character.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For a set of test places, the gold per hour of every zone, subzone and spot equals the hand-computed
  value of FR-001.
- **SC-002**: The list never shows more than ten zones, never a zone under 50 catches, and is ordered by gold per
  hour.
- **SC-003**: No subzone name appears twice under one zone, in either tab.
- **SC-004**: A player reaches the best spot's map pin in at most three clicks from the minimap menu.
- **SC-005**: Every new text exists in all nine languages.

## Assumptions

- The game's map data gives a zone's level range and its continent on Forever's maps; both are checked in game
  (`VERIFY`) before the release. Without a level range a zone is never hidden.
- The data needed (catches, casting time, items, subzones, positions) is already in the catch database; no saved data
  changes shape except two new per-character settings.
- Prices are those of the statistics; their quality (an old scan) is the player's concern, as for the catch value.
- Travel time to a zone is not counted.
