# Feature Specification: New Item Kinds (Trophies, Quest) and the Trophy Collection

**Feature Branch**: `023-item-kinds`

**Created**: 2026-11-23

**Status**: Draft

**Input**: User description: "new fishing types". The author's request (translated): "kinds: add a quest group, and a
kind for the fish you can hold in the hand: 10 Pound, 12, 15, 17 and so on". The design was agreed in a quiz on
2026-11-23; research and decisions: [docs/extravaganza-research.md](../../docs/extravaganza-research.md), sections 9
and 11.

## Clarifications

### Decisions of the author, 2026-11-23

- Two new kinds: **Trophies** (every weighed "N Pound" fish, 36 items) and **Quest** (every quest item).
- Trophies hold all 36, those the game lets the player hold in the off hand and the Lobster and Yellowtail series,
  which cannot be held, alike.
- Quest holds the Nat Pagle fish, the fish of the Stranglethorn Fishing Extravaganza, Spotted Sunfish, Electropeller,
  Gaffer Jack, and any item of the quest class.
- The order of the kinds: Fish, Containers, Trophies, Potions & drinks, Reagents & herbs, Quest, Other. Every kind is
  shown by default.
- A trophy collection in the catalog: a count ("12/36") with the Trophies kind, and a mark beside each trophy caught.
  "Caught" means caught by any character of the account.
- The first catch of a trophy gives a loud notice "New trophy (13/36)" with the rare loot sound, also with catch
  notifications off; a trophy caught again gives the ordinary catch notice.
- This spec comes before 024 (the Extravaganza helper), which uses the Quest kind.

### Facts from the game data (wago.tools, product `wowf`, build 1.60.1.71037)

- The 36 trophies are all class 15 / 0 (Miscellaneous / Junk), white, sold for 100 copper per pound. 24 can be held in
  the off hand (Mud Snapper 6292, 6294, 6295; Catfish 6309, 6310, 6311, 6363, 6364; Redgill 13882-13887; Salmon
  13901-13906; Mightfish 13914-13917); 12 cannot (Lobster 13907-13913; Yellowtail 13876-13880).
- 15 / 0 is also the class of chests and of the contest's rare fish, so the class cannot tell a trophy; every trophy is
  listed by ID, as the other kinds' items are (spec 014).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Trophies and quest items have their own kinds (Priority: P1)

A player opens "What can be caught here" or the catalog: the weighed fish (10 Pound Mud Snapper, 52 Pound Redgill ...)
are no longer mixed with the fish to cook but listed under "Trophies", and quest items (Nat Pagle's fish, Speckled
Tastyfish, Electropeller) under "Quest". Both kinds can be hidden in the kind menu like the others.

**Why this priority**: this is what the author asked for; the other stories build on the two kinds.

**Independent Test**: at a spot whose data holds a cooking fish, a weighed fish and a quest item, open "What can be
caught here": three headers (Fish, Trophies, Quest) in the fixed order; hide Trophies: the weighed fish leaves the
list, the others stay.

**Acceptance Scenarios**:

1. **Given** the defaults, **When** a list holds items of every kind, **Then** the headers come in the order Fish,
   Containers, Trophies, Potions & drinks, Reagents & herbs, Quest, Other.
2. **Given** any of the 36 weighed fish, **When** its kind is asked, **Then** it is Trophies.
3. **Given** a listed quest item or any item the client reports with the quest class, **When** its kind is asked,
   **Then** it is Quest.
4. **Given** a player who hid some kinds before this version, **When** they open a list, **Then** their choice is kept
   and the two new kinds are shown.
5. **Given** the kind menu, **When** the player unchecks Trophies or Quest, **Then** those items leave both lists at
   once and the choice is remembered, as for the other kinds.

---

### User Story 2 - The trophy collection in the catalog (Priority: P2)

A player curious which weighed fish they still lack opens the catalog: the Trophies header shows "12/36", and every
trophy the account has caught carries a mark. A trophy not caught yet is shown without the mark, with the places other
players caught it.

**Why this priority**: a goal to fish for; it needs the kind of story 1.

**Independent Test**: on an account whose own catches hold two trophies, open the catalog: the Trophies header reads
"2/36", those two rows carry the mark, a trophy known only from other players' data has none.

**Acceptance Scenarios**:

1. **Given** the account has caught some trophies on any of its characters, **When** the catalog list shows the
   Trophies kind, **Then** its header shows how many of the 36 the account has caught ("n/36").
2. **Given** a trophy row in the catalog, **When** the account has caught it, **Then** the row carries the mark;
   **When** it has not, **Then** the row has no mark.
3. **Given** a character of the same account catches a new trophy, **When** another character opens the catalog,
   **Then** the count and the mark include it.
4. **Given** the catalog's search or the other filters, **When** they hide trophy rows, **Then** the count still counts
   every trophy the account caught (it counts the collection, not the rows shown).

---

### User Story 3 - A notice for a new trophy (Priority: P2)

A player hooks a 15 Pound Salmon for the first time on the account: a loud notice "New trophy: 15 Pound Salmon
(13/36)" with the rare loot sound. The second 15 Pound Salmon gives the ordinary catch notice.

**Why this priority**: it makes the collection felt while fishing; it needs story 2's count.

**Independent Test**: catch a trophy the account has never caught: the loud notice with the new count; catch the same
trophy again: the ordinary notice only.

**Acceptance Scenarios**:

1. **Given** a trophy the account has never caught, **When** it is caught, **Then** a notice names it and the new count
   ("n/36"), shown also with catch notifications off, and the rare loot sound plays by the sound settings.
2. **Given** a trophy the account has caught before, **When** it is caught again, **Then** only the ordinary catch
   notice appears, by the notification settings.
3. **Given** two trophies new to the account in one loot, **When** it is looted, **Then** each gets its notice with the
   right count.

---

### Edge Cases

- A trophy caught before this version (in the account's own catch record) counts as caught: no notice for it later.
- A catch the catch database does not record (a cast without a place: an instance, no position) neither counts in
  the collection nor gives the trophy notice; the trophy counts, with its notice, at its next catch where a place is
  known.
- A trophy that no one's data holds yet is not in the catalog list (the list shows items with data), but it counts in
  the 36.
- A trophy the client does not know yet: it keeps its kind by ID; its row shows as the catalog shows any unknown item.
- An item of the quest class that is also listed under another kind: the list by ID wins (the Electropeller, the Nat
  Pagle fish and the contest's fish are listed as Quest).
- The camp bonus rules that leave fished quest items out of the bonus catches (spec 020) keep working: they do not
  depend on the kind.
- The ordinary catch notice and the trophy notice for the same item: the trophy notice replaces the ordinary one, so
  the player does not see the catch twice.
- Catches in a fight or outside fishing mode: the notice follows the toast's usual rules; the sound follows the sound
  rules (fishing mode on, no fight).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The addon MUST know seven item kinds, in this order: Fish, Containers, Trophies, Potions & drinks,
  Reagents & herbs, Quest, Other.
- **FR-002**: Every one of the 36 weighed fish MUST be Trophies, by item ID: 6292, 6294, 6295, 6309, 6310, 6311, 6363,
  6364, 13876-13880, 13882-13887, 13901-13917. A check MUST fail when one is missing or has another kind.
- **FR-003**: Quest MUST hold, by item ID, 1467, 6717, 6718, 16967, 16968, 16969, 16970, 19803, 19804, 19805, 19806,
  19807; an item not listed by ID whose client class is the quest class MUST be Quest.
- **FR-004**: Only the items of FR-002 and FR-003 change their kind; every other item MUST keep the kind it has today.
- **FR-005**: A player's saved kind choice MUST stay valid: a hidden kind stays hidden, the new kinds are shown until
  the player hides them.
- **FR-006**: The catalog list MUST show, with the Trophies header, how many of the 36 trophies the account has
  caught, and MUST mark each trophy row the account has caught.
- **FR-007**: "Caught by the account" MUST mean present in the account's own catch data (every character, every
  version), never other players' data or the bundled data.
- **FR-008**: The first catch of a trophy by the account MUST show a notice with the trophy's name and the new count,
  also when catch notifications are off, in place of the ordinary catch notice for that item, and MUST play the rare
  loot sound when the fishing sounds would play one.
- **FR-009**: A trophy caught again MUST show only the ordinary catch notice.
- **FR-010**: The new headers, the menu entries, the count and the notice MUST be shown in the addon's language, with
  a translation in every language the addon supports.
- **FR-011**: The change MUST be recorded in the changelog under "Unreleased" and in the player manual (the two kinds,
  the collection, the notice).

### Key Entities

- **Item kind**: now seven, with a fixed order and a display name in each language.
- **Trophy list**: the 36 weighed fish by item ID; game data. Its size is the collection's total.
- **Trophy collection**: the trophies present in the account's own catch data; derived, not stored on its own.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 36 trophies and all 12 listed quest items land in their kind (checked for every ID).
- **SC-002**: With the defaults, a list holding items of all seven kinds shows seven headers in the fixed order.
- **SC-003**: The collection count equals the number of distinct trophies in the account's own data, on every
  character of the account.
- **SC-004**: A trophy new to the account, caught where the catch database records it, gives exactly one loud notice;
  a repeated trophy gives none.
- **SC-005**: Every new visible text exists in all nine languages of the addon.

## Assumptions

- The 36 IDs and their classes come from the game's item tables of build 1.60.1.71037; no in-game check is needed
  for the kinds (the worst case is an item in a neighbouring kind, fixed by the list). No `VERIFY` marker is expected
  for the kinds.
- The account's own catch data (the lifetime record every catch goes into) already holds the items caught since the
  shared catch database (1.2.0); trophies caught before that are not known and count as new once.
- The kind choice and its storage stay as in spec 014; the new kinds need no data migration, since a kind the saved
  choice does not name is shown.
- The rare loot sound is the existing one of the "Sound effects" page; no new sound file.
- The mark and the count appear only in the catalog, not in "What can be caught here" (the author's choice).
