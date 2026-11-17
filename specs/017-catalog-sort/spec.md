# Feature Specification: Catalog Sorting

**Feature Branch**: `017-catalog-sort`

**Created**: 2026-11-17

**Status**: Implemented

**Input**: User description: "catalog sorting". The catch catalog's item list has filters but no choice of order;
the author wants to sort it by price, so the list shows what is worth catching for gold. Agreed with the author in a
question round on 2026-11-17 (translated and summarized below).

## Clarifications

### Decisions of the author, 2026-11-17

- Three orders: by name (as today, the default), by price (highest first) and by chance (highest first). No
  ascending direction, no other orders.
- The catalog's buttons move into three rows: row 1 the search box alone; row 2 Skill, Source and Water (Water only
  where pool data exists, as today); row 3 the new Sort button and, after it, the Kinds button (moved from the top
  right). "What can be caught here" keeps its layout.
- The price is the same value the statistics use: the higher of the vendor price and the last scanned auction price,
  an auction price resting on few lots not counted.
- An item's chance in the list is the chance of its best zone (the first zone of its own page). Items with little
  data in every zone come after the others.
- The kind headers stay: the order applies inside each kind's group.
- The right column of an item row shows what the list is ordered by: the price per piece, the best zone's chance, or
  (by name) the number of zones as today.
- By price, an item without a price comes last in its group and its row reads "No price", in grey.
- Choosing an order shows the list from its top.
- The chosen order is remembered per account between sessions.
- Release 1.3.1; the full Spec Kit flow.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sort the catalog by price (Priority: P1)

A player farming gold opens the catch catalog, chooses "Price" in the Sort menu and sees, under each kind header, the
most valuable items first, each row showing its price per piece. Items whose value is unknown come last, marked
"No price".

**Why this priority**: this is what the author asked for: see at a glance what is worth catching for gold.

**Independent Test**: with items of known prices in the catalog, choose Sort: Price: inside each kind the items run
from the highest price to the lowest, each row shows its price, items without one are last with "No price".

**Acceptance Scenarios**:

1. **Given** the catalog list, **When** the player chooses "Price" in the Sort menu, **Then** inside each kind group
   the items are ordered by their price, highest first, and the button reads "Sort: Price".
2. **Given** the order by price, **When** the list is drawn, **Then** each item row's right column shows the item's
   price per piece (the value the statistics use).
3. **Given** an item whose auction price rests on few lots and whose vendor price is lower, **When** the list is
   ordered by price, **Then** the item is placed by its vendor price, as the statistics value it.
4. **Given** an item without any price (no vendor price, no trusted auction price), **When** the list is ordered by
   price, **Then** it comes after every priced item of its group and its row reads "No price" in grey.
5. **Given** two items of the same price, **When** the list is ordered by price, **Then** they keep their order by
   name.
6. **Given** the order by price, **When** an auction scan finishes and prices change, **Then** the list follows the
   new prices the next time it is drawn.

---

### User Story 2 - Sort the catalog by chance (Priority: P2)

A player who wants items that come often chooses "Chance": inside each kind group the items with the highest chance in
their best zone come first, each row showing that chance; items with little data everywhere come after them.

**Why this priority**: the second order the author asked for; useful but not the gold question itself.

**Independent Test**: choose Sort: Chance: inside each kind, items run from the highest best-zone chance down; an item
seen only in zones with little data is after all the others and its row reads "Little data".

**Acceptance Scenarios**:

1. **Given** the catalog list, **When** the player chooses "Chance", **Then** inside each kind group the items are
   ordered by the chance of their best zone, highest first.
2. **Given** an item caught only in zones with little data, **When** the list is ordered by chance, **Then** it comes
   after every item of its group that has a zone with enough data, and its row reads "Little data".
3. **Given** the order by chance, **When** the list is drawn, **Then** each row's right column shows the best zone's
   chance, the same value the item's own page shows for its first zone under the same filters.
4. **Given** the skill, source or water filter changes, **When** the list is ordered by chance, **Then** the chances
   and the order follow the filtered data.

---

### User Story 3 - Back to the order by name, and the choice remembered (Priority: P2)

A player chooses "Name" to get the familiar alphabetical list with "Zones: N" in each row. Whatever order was chosen
last is still chosen after a reload or a relog.

**Why this priority**: the order must be reversible and must not have to be chosen again at every login.

**Independent Test**: choose Sort: Price, `/reload`: the catalog is still by price; choose Name: the list is
alphabetical with "Zones: N", as before this feature.

**Acceptance Scenarios**:

1. **Given** a player who never chose an order, **When** the catalog opens, **Then** it is ordered by name with
   "Zones: N" in each row, exactly as before this feature, and the button reads "Sort: Name".
2. **Given** a chosen order, **When** the player reloads the interface, relogs or logs in on another character of the
   same account, **Then** the same order is chosen.
3. **Given** the list scrolled down, **When** the player chooses another order, **Then** the list is shown from its
   top.

---

### User Story 4 - The new button layout (Priority: P3)

The catalog shows its buttons in three rows: the search box; Skill, Source and Water; Sort and Kinds. Every button's
text fits in every language of the addon without covering another button.

**Why this priority**: needed to make room for the Sort button; it carries no value of its own.

**Independent Test**: open the catalog in English and in the language with the longest labels: no two buttons overlap,
the list starts below the third row.

**Acceptance Scenarios**:

1. **Given** the catalog list, **When** it is shown, **Then** row 1 holds the search box, row 2 Skill, Source and
   (with pool data) Water, row 3 Sort and then Kinds, and the item list starts below row 3.
2. **Given** any language of the addon and any filter value, **When** the catalog list is shown, **Then** no button
   covers another one.
3. **Given** "What can be caught here", **When** it is shown, **Then** its layout is unchanged (the Kinds button stays
   where it is).

---

### Edge Cases

- The Sort choice applies to the item list only: an item's page (its zones and spots) keeps its order by chance.
- Searching: the matches are ordered by the chosen order too; grey items shown by a search are ordered with the others.
- The kind filter hides a kind: the order inside the shown kinds is unchanged.
- Auction prices turned off in the settings: the price is the vendor price only, as in the statistics.
- An item the game has not loaded yet is not listed (as today), so it needs no price or chance.
- A saved order the addon does not know (written by a later version): the list is ordered by name.
- An item whose best zone is a little-data one but which has another zone with enough data: its best zone is the one
  with enough data (the item's own page already puts such zones first), so it is not counted as little data.
- While the catalog is still counting the catch, the Sort button can be used; the order applies once the list shows.
- Item tooltips, the minimap tooltip and "What can be caught here" do not follow the catalog's order.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The catalog's item list MUST offer three orders: Name (alphabetical, the present order), Price (highest
  first) and Chance (highest first). Name is the default.
- **FR-002**: A Sort button MUST open a menu with the three orders, the chosen one marked; choosing one MUST reorder the
  list at once and show it from its top.
- **FR-003**: The button MUST show the chosen order ("Sort: Price" and the like).
- **FR-004**: The price of an item MUST be the value the addon's statistics use for it: the higher of its vendor price
  and its last scanned auction price, an auction price resting on few lots not counted, and no auction price while
  auction prices are off.
- **FR-005**: The chance of an item MUST be the chance of its best zone under the list's filters, the same zone its
  own page lists first. An item whose every zone has little data MUST come after the items of its group that have a
  zone with enough data, ordered among themselves by that chance.
- **FR-006**: Ties MUST keep the order by name.
- **FR-007**: The list MUST stay grouped under the kind headers; the order applies inside each group.
- **FR-008**: The right column of an item row MUST show, by Price, the item's price per piece, or "No price" in grey
  for an item without a price (such items last in their group); by Chance, the best zone's chance or "Little data";
  by Name, the number of zones as today.
- **FR-009**: A change of the prices (an auction scan, the auction price setting) MUST reach the order and the shown
  prices without reopening the window.
- **FR-010**: The chosen order MUST be remembered per account between sessions; an unknown remembered value MUST
  read as Name.
- **FR-011**: The catalog's buttons MUST be laid out in three rows: the search box; Skill, Source and Water; Sort and
  Kinds. No button may cover another in any language of the addon. "What can be caught here" keeps its layout.
- **FR-012**: Every new visible text (the button's label, the order names, "No price") MUST be shown in the addon's
  language, with a translation for each of its nine translated languages.
- **FR-013**: The change MUST be recorded in the changelog under "Unreleased" and described in the player manual.

### Key Entities

- **List order**: one of Name, Price, Chance; per account, remembered between sessions; Name by default.
- **Item price**: the value the statistics give an item (vendor price or a trusted auction price, the higher); may
  be missing.
- **Item best chance**: the chance of an item's first zone in its own page's order under the current filters, and
  whether that zone has little data.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A player gets the most valuable catch of each kind to the top of the catalog in two clicks (the Sort
  button, then Price).
- **SC-002**: For every pair of adjacent items in a group, the order matches the chosen order's rule (price or chance
  not increasing; ties by name), checked on a list of at least ten items.
- **SC-003**: Every price shown in the list equals the value the statistics use for that item.
- **SC-004**: The chosen order survives a reload and a relog in 100 % of tries.
- **SC-005**: With no order ever chosen, the list is identical to the list before this feature.
- **SC-006**: Every new visible text exists in all nine translated languages, and no button overlaps another in any
  of the ten languages.

## Assumptions

- The price per piece is the measure; value per cast (chance x pieces x price) and a "best zones for gold" view are
  out of scope (a later feature).
- The skill, source and water filters keep their behaviour (reset at login); only the order and the kind choice are
  remembered.
- The setting is account-wide, like the other settings; a new setting is filled by the existing defaults, so no data
  migration is needed.
- Prices change without changing the catch data, so the order by price is computed when the list is drawn rather
  than kept with the counted catch.
- The layout fits every language by putting at most three buttons in a row: the longest present labels (French) take
  about 551 of the 560 pixels of row 2; this is checked in game with the checklist, no `VERIFY` marker is expected.
