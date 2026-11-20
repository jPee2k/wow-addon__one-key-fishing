# Feature Specification: Cumulative Skill Filter

**Feature Branch**: `021-cumulative-skill-filter` (off `develop`, after spec 020 was merged)

**Created**: 2026-11-20

**Status**: Implemented, checked in game on 2026-11-20 (`docs/checklists/skill-filter.md`)

**Input**: User description: "Cumulative skill filter". The Skill filter of "What can be caught here" and of the
catalog shows, for a skill range, the catches of that range and of every lower one, so a player whose own range has
no data yet still sees what was caught at the place with less skill. Planned for release 1.5.0, together with spec 020.

## Clarifications

### Decisions of the author, 2026-11-20

The design interview (grilling session); the numbers are referred to below as "decision N".

1. **Cumulative ranges**: the range "Up to N" shows the catches of every range from 0-74 up to the one ending at N;
   "All (300+)" shows every range. Higher skill never undoes what lower skill catches. One rule for every list the
   filter drives: "What can be caught here", the catalog's list, its zone and spot rows, and the minimap's tooltip
   lines. The item tooltips (which use the default "all") read the same as before.
2. **Chances and catches** of the lists are summed over the cumulative ranges.
3. **The miss rate comes from the chosen range only**, at the same scope as the list (the spot, or the whole map when
   the list falls back to it); below 50 casts in that range it says "Little data". For "All (300+)" the misses come
   from 300+ only. Reason: in the collected data lower skill misses more in the same zone (map 1413: 35 % / 24 % /
   15 % for 0-74 / 75-149 / 150-224; map 1454: 38 % / 17 % for 0-74 / 75-149), so a summed miss rate would show a
   skilled player the misses of beginners.
4. **Labels (variant A)**: the menu offers "Up to 74", "Up to 149", "Up to 224", "Up to 299", "All (300+)"; the player's
   own range is marked "(yours)" in both tabs' menus, with no mark when Fishing is not learned. The button reads
   "Skill: Up to N" or "Skill: All". Each text is a whole translated string with the number in it.
5. **The button's tooltip** has two lines: "Catches with skill up to N." and "Misses only with skill A-B."; for "all":
   "Catches with any skill." and "Misses only with skill 300+.".
6. **Defaults**: "What can be caught here" opens on the player's own range and follows the rank as it grows until a
   value is picked by hand; the catalog opens on "all". A value picked by hand lasts until the interface reloads
   (not saved), as today.
7. **Removed**: the separate value "All skill levels" (its place is taken by "All (300+)") and the hint "Try "All skill
   levels": little data for your skill.", with their texts in every language.
8. **The catalog's Skill column** (the ranges an item was actually caught in at a place) stays as it is.
9. **Delivery**: own spec 021 on a branch off `develop` (spec 020 is merged there), released with 1.5.0; tests for the sums, the miss rate
   and its threshold; a short in-game checklist (the menu, the labels in German and French within the button, the
   miss rate, the minimap tooltip); changelog and player manual.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A place is never empty for lack of my exact skill (Priority: P1)

A player with Fishing 180 opens "What can be caught here" at a place where others caught fish with 75-149 skill but
nobody yet with 150-224. Today the list is empty and the player concludes nobody fished there. With this feature the
list shows the catches of 0-224 with their chances, and the button reads "Skill: Up to 224".

**Why this priority**: this is the problem the author raised: an empty page makes players skip good places.

**Independent Test**: build data with catches only in 75-149 at a place, set the own rank to 180 and open the tab; the
list shows those items.

**Acceptance Scenarios**:

1. **Given** catches at a place only in 75-149 and a player with 180 skill, **When** the player opens "What can be
   caught here", **Then** the list shows those items with chances computed from them and the button reads "Skill: up
   to 224".
2. **Given** catches in 0-74, 75-149 and 150-224 at a place, **When** "Up to 149" is chosen, **Then** the list sums 0-74
   and 75-149 and leaves 150-224 out.
3. **Given** catches only in 225-299 at a place and a player with 100 skill, **When** the tab opens on "Up to 149",
   **Then** the list is empty, as these catches need more skill than the player has.
4. **Given** any place, **When** "All (300+)" is chosen, **Then** the list equals what "All skill levels" showed before
   this feature, apart from the miss rate (story 2).

---

### User Story 2 - An honest miss rate for my skill (Priority: P1)

A skilled player sees the miss rate of players of their own skill range, not one inflated by beginners' misses.

**Why this priority**: summing the lists without this would make the miss rate misleading for every skilled player;
the two ship together.

**Independent Test**: build a place with many misses in 0-74 and few in 150-224; under "Up to 224" the miss rate is
that of 150-224 alone.

**Acceptance Scenarios**:

1. **Given** a place with 35 % misses in 0-74 and 15 % in 150-224, each over at least 50 casts, **When** "Up to 224"
   is chosen, **Then** the miss rate reads 15 %.
2. **Given** fewer than 50 casts in the chosen range at the list's scope, **When** the list is shown, **Then** the miss
   rate says "Little data", while the list itself still shows the summed items.
3. **Given** the list falls back to the whole map (the spot has too few summed catches), **When** the miss rate is
   computed, **Then** it uses the chosen range's casts on the whole map.
4. **Given** "All (300+)", **When** the miss rate is computed, **Then** it uses the 300+ casts only.

---

### User Story 3 - Clear labels and a menu that marks my range (Priority: P2)

The player understands at a glance what the filter includes and which range is their own.

**Why this priority**: the meaning of the filter changes; without the new labels a returning player would read
"150-224" in the old sense.

**Independent Test**: open the Skill menu in both tabs with a 180 skill character and with a character without
Fishing; read the button and its tooltip.

**Acceptance Scenarios**:

1. **Given** a player with 180 skill, **When** the Skill menu opens in either tab, **Then** it lists "Up to 74", "Up to
   149", "Up to 224 (yours)", "Up to 299", "All (300+)", with the chosen value marked.
2. **Given** a character without Fishing, **When** the menu opens, **Then** no value carries "(yours)".
3. **Given** "Up to 224" chosen, **When** the player hovers the button, **Then** the tooltip reads "Catches with skill up
   to 224." and "Misses only with skill 150-224.".
4. **Given** "All (300+)" chosen, **When** the player hovers the button, **Then** the tooltip reads "Catches with any
   skill." and "Misses only with skill 300+.".
5. **Given** any of the ten languages, **When** the button shows its longest value, **Then** the text fits the button.

---

### User Story 4 - The catalog and the minimap follow the same rule (Priority: P2)

The catalog's lists and the minimap's tooltip lines read the same way as "What can be caught here".

**Why this priority**: one rule everywhere; without it the same place would show different items in two windows.

**Independent Test**: choose "Up to 149" in the catalog and open an item and a zone; enter fishing mode at a place and
hover the minimap button.

**Acceptance Scenarios**:

1. **Given** the catalog opened for the first time in a session, **When** it shows, **Then** the button reads "Skill:
   all".
2. **Given** "Up to 149" in the catalog, **When** the list, an item's zones and a zone's spots are shown, **Then** each
   sums 0-74 and 75-149.
3. **Given** fishing mode on, **When** the player hovers the minimap button, **Then** the lines sum the ranges up to the
   player's own.
4. **Given** an item tooltip anywhere in the game, **When** it shows the addon's lines, **Then** they are the same as
   before this feature.

---

### Edge Cases

- **A rank that grows** into the next range moves the default of "What can be caught here" to the new range at once,
  unless a value was picked by hand this session.
- **No Fishing learned**: "What can be caught here" behaves as today without a rank (no own place); the catalog works
  on "all"; the menu shows no "(yours)".
- **Only higher-skill data**: a player below every recorded range sees an empty list; this is true information (the
  catches need more skill), and the empty list's existing message stays.
- **Spot or map**: the list chooses the spot when the summed catches there reach 50, else the whole map, as today but on
  the summed numbers; the miss rate follows the same choice (decision 3).
- **Little data for the list** is judged on the summed catches; the removed hint leaves nothing in its place.
- **Water filter**: no miss rate is shown under a water filter, as today.
- **Camp bonus filter (spec 020)**: a bonus part's catches are summed over the cumulative ranges like the totals; its
  miss rate comes from the chosen range's part only; the tag from the data and the 50-catch threshold of a bonus
  chance are computed over the cumulative ranges.
- **Players and reporters**: the number of players and the rule for an item new to a map count the cumulative ranges
  like the catches.
- **The catalog's Skill column** still shows the item's actual ranges ("75-224", "300+"), whatever the filter.

## Requirements *(mandatory)*

### Functional Requirements

**The sums**

- **FR-001**: A chosen range "Up to N" MUST include the catches, items and players of every skill range from 0-74 up to
  the range ending at N; "All (300+)" MUST include every range.
- **FR-002**: The rule MUST apply to "What can be caught here", the catalog's item list, its zone and spot rows, the
  catalog's item pages, and the minimap's tooltip lines alike.
- **FR-003**: The addon's lines in item tooltips MUST read the same as before this feature.
- **FR-004**: The recorded data, the shared records, the bundled database and the catch exchange MUST stay unchanged;
  the change is in how the lists read the data.

**The miss rate**

- **FR-005**: The miss rate MUST come from the casts and misses of the chosen range alone, at the same scope (spot or
  whole map) as the list it is shown with.
- **FR-006**: With fewer than 50 casts in the chosen range at that scope, the miss rate MUST say "Little data".
- **FR-007**: Under "All (300+)" the miss rate MUST come from 300+ alone.
- **FR-008**: Under a camp bonus filter the miss rate MUST come from the chosen range's part of that bonus alone; under a
  water filter no miss rate is shown, as before.

**The control**

- **FR-009**: The Skill menu MUST offer exactly "Up to 74", "Up to 149", "Up to 224", "Up to 299" and "All (300+)", in
  this order; the value "All skill levels" MUST be gone.
- **FR-010**: The value matching the player's own skill range MUST carry "(yours)" in the menus of both tabs; without
  Fishing learned, no value carries it.
- **FR-011**: The button MUST read "Skill: Up to N" for a range and "Skill: All" for "All (300+)".
- **FR-012**: The button's tooltip MUST hold two lines: what the list includes ("Catches with skill up to N." or
  "Catches with any skill.") and where the misses come from ("Misses only with skill A-B." or "Misses only with skill
  300+.").
- **FR-013**: "What can be caught here" MUST open on the player's own range and follow the rank as it grows until a
  value is picked by hand; the catalog MUST open on "All (300+)". A value picked by hand MUST last until the interface
  reloads and MUST NOT be saved.
- **FR-014**: The hint "Try "All skill levels": little data for your skill." MUST be removed.
- **FR-015**: The catalog's Skill column MUST keep showing the ranges an item was actually caught in.

**Texts and documents**

- **FR-016**: Every new visible text MUST be a whole translated string with its number inside, in all nine translated
  languages; the removed texts MUST leave every language.
- **FR-017**: The longest button text in every language MUST fit the button.
- **FR-018**: The change MUST be recorded in the changelog under "Unreleased" and described in the player manual.

### Key Entities

- **Skill range**: one of five steps of 75 skill points (0-74, 75-149, 150-224, 225-299, 300+); every catch is recorded
  under the range of the catcher's skill. Unchanged.
- **Skill filter value**: "Up to N" (one of the four lower ranges) or "All (300+)"; reads the ranges from 0-74 up to it
  for items and catches, and its own range alone for misses.
- **Own range**: the range of the player's current Fishing rank; the default of "What can be caught here" and the
  "(yours)" mark.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At every place with catches in a range at or below the player's own, "What can be caught here" opened
  with its default shows a non-empty list.
- **SC-002**: Under "All (300+)" every list shows the same items, catches and chances as "All skill levels" did before
  this feature.
- **SC-003**: The miss rate shown under any value equals the misses divided by the casts of that value's own range at the
  list's scope, or says "Little data" below 50 casts.
- **SC-004**: The Skill menu in both tabs has five values and marks the own range in 100 % of opens with Fishing learned.
- **SC-005**: Every new text exists in all nine translated languages, and no Skill button text overflows its button in
  any language.
- **SC-006**: The item tooltips' addon lines are identical before and after this feature for the same data.

## Assumptions

- In Forever, as in the original game, a zone's catch table does not depend on the fisher's skill beyond being able to
  fish there; skill changes how often a fish gets away. So summing lower ranges keeps the items' chances right and
  only the miss rate needs its own range. If the game ever ties an item to a minimum skill, such an item would show
  rarer in a summed list, not vanish; the catalog's Skill column still shows its actual range.
- The 50-cast threshold for the miss rate is the same number as the existing "little data" threshold for catches.
- Data at 300+ is scarce today (29 catches on 4 maps in the collected data), so the miss rate under "All (300+)" will
  mostly say "Little data" until skilled players fish more; this is preferred to a rate inflated by beginners.
- The button keeps its present width; the new texts are expected to be no longer than "All skill levels" was. The
  in-game checklist confirms German and French and then every other language (FR-017).
- Depends on spec 020 (the camp bonus filter and the button rows it introduced); both release in 1.5.0.
