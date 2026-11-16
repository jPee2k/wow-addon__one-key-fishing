# Feature Specification: Catch Filters by Item Kind

**Feature Branch**: `014-catch-filters`

**Created**: 2026-11-16

**Status**: Draft

**Input**: User description: "Catch filters by item kind: today 'What can be caught here' and the catch catalog list
every caught item in one pile (fish, chests, clams, potions, herbs, rum). Add fishing-specific item categories: Fish,
Containers (chests, trunks, clams), Potions & drinks, Reagents & herbs, Other (also items the client does not know
yet). The category is decided by item ID first (a data table holding every item of the bundled seed and of the fished
containers); an item not in the table falls back to the item's class and subclass as the client reports them. Item
quality is not used. In both views a menu with a checkbox per category (all on by default), and the list grouped under
category headers, so even with everything on the list is not one pile. The chosen filter is remembered. New texts in
every language of the addon; the changelog and the player manual updated. The class fallback for new items is an
accepted assumption (worst case a new item lands in Other)." (Translated and shortened from the author's request.)

## Clarifications

### In-game facts, 2026-11-16

The author ran a `/run` line in game that printed each item's class, subclass and quality as the client reports them:

| Item | ID | Class / subclass | Quality |
|---|---|---|---|
| Raw Brilliant Smallfish | 6291 | 7 / 8 (Trade Goods / Cooking) | 1 |
| Oily Blackmouth | 6358 | 7 / 11 (Trade Goods / Other) | 1 |
| 10 Pound Mud Snapper | 6292 | 15 / 0 (Miscellaneous / Junk) | 1 |
| Sturdy Locked Chest | 6355 | 15 / 0 (Miscellaneous / Junk) | 1 |
| Watertight Trunk | 21113 | 15 / 0 (Miscellaneous / Junk) | 1 |
| Stranglekelp | 3820 | 7 / 9 (Trade Goods / Herb) | 1 |
| Lesser Healing Potion | 858 | 0 / 1 (Consumable / Potion) | 1 |
| Deviate Scale | 6470 | 7 / 6 (Trade Goods / Leather) | 1 |
| Rumsey Rum Light | 20709 | 0 / 5 (Consumable / Food & Drink) | 1 |
| Small Barnacled Clam | 5523 | 7 / 11 (Trade Goods / Other) | none (not cached) |

Consequences, taken as decisions:

- The class cannot tell a fish from a clam (Oily Blackmouth and the clam are both 7 / 11), nor a junk fish from a
  chest (both 15 / 0): the list of known items by ID is the main source of a kind.
- Quality is not used: the junk fish has quality 1 (Common), and an uncached item has no quality at all.
- Forever reports the Mainline classes (raw fish is Trade Goods / Cooking, not Consumable as in Classic), so the
  fallback rules follow them.

### Decisions of the author, 2026-11-16

- Five kinds, in this order: Fish, Containers, Potions & drinks, Reagents & herbs, Other.
- The fish whose names make them junk (10 Pound Mud Snapper, 17 Pound Catfish, Oil Covered Fish) are Fish: the player
  sees a fish.
- The chosen kinds are remembered between sessions (unlike the skill, source and water filters, which start at
  their defaults at every login).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the catch list grouped by kind (Priority: P1)

A player opens "What can be caught here" (or the catch catalog) and sees the items under headers: first the fish,
then the containers, the potions and drinks, the reagents and herbs, and last everything else. Within a group the
items keep the order the view already uses.

**Why this priority**: it removes the "one pile" with no choice to make; every player gets it at once.

**Independent Test**: at a spot whose data holds a fish, a chest, a potion and a herb, open "What can be caught here":
four headers in the fixed order, each item under its own header. The same items in the catalog list are grouped the
same way.

**Acceptance Scenarios**:

1. **Given** a spot whose data holds items of several kinds, **When** the player opens "What can be caught here",
   **Then** the items are shown under kind headers in the order Fish, Containers, Potions & drinks, Reagents &
   herbs, Other, each item under exactly one header.
2. **Given** a kind has no item in the current view, **When** the list is drawn, **Then** its header is not shown.
3. **Given** the catalog's item list (with or without a search), **When** it is drawn, **Then** it is grouped under the
   same headers in the same order.
4. **Given** an item the client does not know yet ("Unknown item" in "What can be caught here") and not in the list
   of known items, **When** the list is drawn, **Then** it is shown under Other (a listed one keeps its listed kind:
   its kind is known by its ID).
5. **Given** the grouping, **When** the player reads an item's chance, pieces per catch and price, **Then** they are
   the same values the view showed before this feature (grouping changes only the order and the headers).

---

### User Story 2 - Hide the kinds the player does not care about (Priority: P1)

A player who only wants to see the fish opens the kind menu next to the other filters and unchecks Containers,
Potions & drinks, Reagents & herbs and Other. The list now shows only fish. The choice applies to both views and is
still there after a relog.

**Why this priority**: this is what the author asked for ("filters, so that it is not all in one pile").

**Independent Test**: uncheck every kind but Fish in "What can be caught here": only fish are listed; switch to
the catalog: only fish in its list too; `/reload`: the choice is the same.

**Acceptance Scenarios**:

1. **Given** the defaults, **When** the player opens the kind menu, **Then** every kind is checked and the
   button reads that all kinds are shown.
2. **Given** the menu is open, **When** the player unchecks a kind, **Then** its items and header leave the list
   at once, and the menu stays open for the next choice (where the client's menu supports checkboxes, FR-007).
3. **Given** some kinds are unchecked, **When** the player looks at the button, **Then** it shows that a filter is
   on (for example "Kinds: 2 of 5"), so a short list is never mistaken for missing data.
4. **Given** a kind choice made in one view, **When** the player opens the other view, **Then** the same kinds
   are shown and hidden there.
5. **Given** a kind choice, **When** the player relogs or reloads the interface, **Then** the choice is unchanged.
6. **Given** every kind is unchecked, **When** the list is drawn, **Then** it is empty and the view says that the
   kind filter hides everything (not "no data").
7. **Given** a hidden kind, **When** the player reads the chance of a shown item, **Then** it is the same as with
   every kind shown (hiding a kind does not raise the others' chances).

---

### User Story 3 - The catalog still finds a hidden item on request (Priority: P3)

A player who hides Containers clicks a "Watertight Trunk" chat link (or uses the catalog command with that item):
the catalog still opens that item's zones and spots.

**Why this priority**: a direct request for one item must not be blocked by a list filter; it is rare, so P3.

**Independent Test**: hide Containers, then open the catalog for item 21113 by its link: its places are shown; the
list behind it still hides the containers.

**Acceptance Scenarios**:

1. **Given** Containers are hidden, **When** the catalog is opened for a container by its ID (a chat link, a row of
   "What can be caught here", a command with an item link), **Then** that item's zones and spots are shown.
2. **Given** Containers are hidden, **When** the player types a container's name into the catalog search, **Then** the
   list shows no container and the view says that the kind filter hides matches.

---

### Edge Cases

- An item caught for the first time that is in no list and whose class the client reports: it goes where its class
  points (FR-004); if the class is one the rules do not name, it goes to Other.
- An item the client does not know yet (no class): Other. If the client learns it later in the session, it may move
  to its own kind the next time the view is drawn.
- A kind added by a later version of the addon: a player's remembered choice does not mention it, so it is shown
  (FR-008).
- The view falls back from a spot with few catches to the whole map: the fallback rule counts every catch, whatever
  kinds are hidden (hiding kinds never switches the view between spot and map).
- The water filter, the skill filter and the source filter combine with the kind filter: an item is listed only if
  every filter lets it through.
- Item tooltips, the minimap tooltip and the statistics tab are not filtered: they are not lists of the catch by kind.
- An item listed in the bundled seed and also reported by other players keeps the kind of the list, whatever its
  class.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The addon MUST know five item kinds, in this fixed order: Fish, Containers, Potions & drinks, Reagents &
  herbs, Other.
- **FR-002**: Each item MUST belong to exactly one kind, decided by its item ID (Principle II), never by its name.
- **FR-003**: The addon MUST carry a list of known items by ID with their kind, covering every item of the bundled seed
  and every fished container the addon knows, at least:
  - Fish: 4603, 6289, 6291, 6292, 6303, 6308, 6309, 6358, 6359, 6361, 6362, 6458, 6522, 8365, 21071;
  - Containers: 5523, 5524, 6353, 6355, 6357, 7973, 15874, 20708, 21113, 21150;
  - Potions & drinks: 858, 2455, 20709, 21114;
  - Reagents & herbs: 3820, 6470.
  A check MUST fail when an item of the bundled seed or a fished container is missing from the list.
- **FR-004**: An item not in the list MUST get its kind from the class and subclass the client reports, by rules kept
  as data next to the list: Trade Goods / Cooking (7 / 8) is Fish; any other Trade Goods (7) is Reagents & herbs;
  Consumable (0) is Potions & drinks; anything else, and an item the client reports no class for, is Other.
- **FR-005**: Item quality MUST NOT decide a kind.
- **FR-006**: "What can be caught here" and the catalog's item list MUST show their items grouped under one header
  per kind, in the order of FR-001, leaving out a header with no item under it; within a group the items keep the
  view's present order.
- **FR-007**: Both views MUST offer a kind menu next to their other filters, with one checkbox per kind; checking or
  unchecking one MUST update the list at once, leave the menu open where the client's menu supports checkboxes
  (otherwise it closes after each click), and apply to both views.
- **FR-008**: The kind choice MUST be remembered per account between sessions; a player who never chose sees every
  kind, and a kind the remembered choice does not name is shown.
- **FR-009**: The kind menu's button MUST tell whether every kind is shown or how many are (for example "Kinds: all",
  "Kinds: 2 of 5").
- **FR-010**: Hiding kinds MUST NOT change any shown item's chance, pieces per catch, price or count of players, nor
  the choice between the spot and the whole map.
- **FR-011**: When the kind filter hides every item of a view that has data, the view MUST say so ("The kind filter
  hides every item." or similar), distinct from the texts for no data and for a search without a match.
- **FR-012**: Opening the catalog for one item by its ID (a chat link, a row of "What can be caught here", a
  command with an item link) MUST show that item's places whatever its kind and the kind filter.
- **FR-013**: The kind headers, the menu's entries, the button text and the empty-list text MUST be shown in the
  addon's language, with a translation for every language the addon supports.
- **FR-014**: The change MUST be recorded in the changelog under "Unreleased" and described in the player manual
  (the kind menu, the grouping, that the choice is remembered).

### Key Entities

- **Item kind**: one of the five kinds of FR-001; has a fixed position in the order and a display name in each
  language.
- **Known item list**: item ID to kind, for the items the addon knows (the bundled seed and the fished containers);
  game data, kept by ID.
- **Class rules**: client-reported class (and optional subclass) to kind, for every item outside the list; game data.
- **Kind choice**: the kinds a player has hidden, per account, remembered between sessions; empty by default (all
  shown).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every item of the bundled seed and every known fished container lands in the kind of FR-003 (checked
  for all 31 items).
- **SC-002**: With the defaults, a view holding items of all five kinds shows five headers in the fixed order and no
  item outside its header.
- **SC-003**: A player can reduce either view to fish only in at most five clicks, and the choice survives a reload
  and a relog.
- **SC-004**: For the same place and other filters, every shown item's chance and pieces per catch are identical with
  and without hidden kinds.
- **SC-005**: Every new visible text exists in all nine languages of the addon.

## Assumptions

- The class fallback (FR-004) is accepted without an in-game check of every possible item: it rests on the ten items
  read in game on 2026-11-16, and its worst case is a new item listed under Other or under a neighbouring kind; the
  list (FR-003) can then be extended in a later version. No `VERIFY` marker is expected.
- The kind choice is account-wide, like the addon's other settings; a new saved setting is filled by the existing
  defaults, so no data migration is needed.
- One choice serves both views (FR-007): a player filters "kinds of catch", not "this window".
- The skill, source and water filters keep their present behaviour (reset at login); only the kind choice is
  remembered, as the author asked.
- Containers that the addon opens from the bags are still opened whatever the kind filter: the filter changes only what
  is listed.
- The order inside a group stays the one each view uses today (the catch view by catches, the catalog by name); only
  the grouping and the headers are new.
- The catalog's present list rules stay: it lists the items the client can name, and without a search it leaves out
  Poor-quality items. The kind filter applies on top of them.
