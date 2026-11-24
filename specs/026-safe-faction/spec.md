# Feature Specification: "Safe for me" Keeps the Other Faction's Zones Out of the Best Places

**Feature Branch**: `026-safe-faction`

**Created**: 2026-11-24

**Status**: Draft

**Input**: User description: "Best farming places separated by fraction (Horde \ Alliance) when selected filter
'Safe for me'." The author's request (translated): "Safe for me ignores factions. On a PvP server that matters: an
Alliance character should see Alliance and contested zones, a Horde character Horde and contested zones." The
research and the decisions of the author's quiz of 2026-11-24 are in
[docs/best-places-research.md](../../docs/best-places-research.md), section 4.

## Clarifications

### Decisions of the author, 2026-11-24

- The faction rule is **part of "Safe for me"**: the one switch hides zones too high for the character and zones of
  the other faction. No new button, no new text.
- It applies on **every game mode** (Normal, PvP, Roleplay, Hardcore): the other faction's home zones flag the
  character and have hostile guards everywhere. **Contested zones stay listed** on every mode.
- The other faction's **capitals are hidden** too.
- The rule works on **zones only**: hostile towns inside contested zones (Tarren Mill, Southshore, Astranaar,
  Dalaran...) are not filtered; a known limit.
- A zone's faction comes from the **game's own area data** (the faction of each zone's area), kept as a small table by
  map ID; a zone not in it is contested; a cave or a building inside a zone takes its zone's faction.
- With "Safe for me" **off**, an enemy zone is listed with its **Level column in red**, as a zone too high is.
- A character **without a faction** (none known yet, or neutral): only the level rule applies.
- One in-game check (a VERIFY row), not accepted without a check.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The other faction's zones stay out (Priority: P1)

A level 8 Horde character on a PvP mode opens "Best places" with "Safe for me" on. Durotar, Mulgore, Tirisfal and the
Barrens may be listed; Elwynn Forest, Westfall, Dun Morogh, Teldrassil and Stormwind are not, even with the best gold
per hour for that level. An Alliance character sees the mirror image. Contested zones (Ashenvale, Wetlands,
Stranglethorn, Riverglades...) are listed for both, as long as their level fits.

**Why this priority**: it is the feature: the tab must not send a character to fish where the other faction's guards
and players kill it.

**Independent Test**: with catch data in Elwynn Forest, Durotar and Wetlands (all within the level), a Horde
character with "Safe for me" on sees Durotar and Wetlands, not Elwynn; an Alliance character sees Elwynn and Wetlands,
not Durotar.

**Acceptance Scenarios**:

1. **Given** "Safe for me" is on and the character is of the Horde, **When** the list is built, **Then** no Alliance
   zone and no Alliance capital is listed, whatever its gold per hour and level.
2. **Given** "Safe for me" is on and the character is of the Alliance, **When** the list is built, **Then** no Horde
   zone and no Horde capital is listed.
3. **Given** "Safe for me" is on, **When** a contested zone's lowest level is at most the character's level plus 3,
   **Then** it is listed for either faction.
4. **Given** "Safe for me" is on, **When** a zone of the character's own faction is too high (lowest level above the
   character's level plus 3), **Then** it is hidden, as today.
5. **Given** the other faction's zones are hidden, **When** fewer than ten zones remain, **Then** only those are
   listed; **When** none remains, **Then** the tab says that nothing matches, as today.

---

### User Story 2 - Seeing everything, with a warning (Priority: P2)

The same Horde character switches "Safe for me" off to see where the gold is anyway: Elwynn Forest and Stormwind are
listed again, their Level column in red, like a zone too high.

**Why this priority**: the player keeps the full picture on demand and still sees at a glance which zones are
dangerous.

**Independent Test**: with "Safe for me" off, the Horde character sees Elwynn's row with its level in red, Durotar's
in the normal colour (when within the level).

**Acceptance Scenarios**:

1. **Given** "Safe for me" is off, **When** the list is built, **Then** zones of both factions are ranked.
2. **Given** "Safe for me" is off, **When** a listed zone belongs to the other faction, **Then** its Level
   column is red; a zone of the own faction or contested keeps the rule of today (red only when its lowest level is
   above the character's).

---

### Edge Cases

- The character's faction is not known (for a moment at login) or is neutral: only the level rule applies; once the
  faction is known, the list follows when the tab is next opened or a filter changes (the game knows the faction
  before the world loads, so in play this does not happen).
- A cave, a building or a dungeon entrance map inside a faction zone: it counts as that zone's faction.
- A zone the faction table does not list (every contested zone, a new zone of a later patch): contested, never hidden
  for its faction.
- Forever's new zones (Riverglades, Shen'dralas, Mount Hyjal, Zephras Isle) are contested in the game's data and stay
  listed for both factions (Zephras Isle is a sanctuary, phased by faction).
- A hostile town or Dalaran inside a contested zone: its spots are listed (zones only; known limit).
- The same account plays both factions on different modes: "Safe for me" follows each character's own faction.
- Catches of the other faction's zones still count everywhere else (statistics, catalog, what can be caught here);
  only the best places' list changes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: With "Safe for me" on, the best places MUST NOT list a zone or a capital that belongs to the other
  faction than the character's (Alliance zones for a Horde character, Horde zones for an Alliance character).
- **FR-002**: Contested zones MUST stay subject to the level rule only (hidden when their lowest level is above the
  character's level plus 3), on every game mode.
- **FR-003**: The faction rule MUST apply on every game mode; it MUST NOT depend on the mode.
- **FR-004**: A zone's faction MUST come from the game's own area data, recorded by map ID; a zone without a recorded
  faction MUST count as contested; a map inside a zone MUST take that zone's faction.
- **FR-005**: When the character's faction is unknown or neutral, only the level rule MUST apply.
- **FR-006**: When a zone of the other faction is listed ("Safe for me" off), its Level column MUST be red; the
  existing level colour rule stays for every other zone.
- **FR-007**: The rule MUST work on zones only; subzones and spots inside a listed zone MUST NOT be filtered by
  faction.
- **FR-008**: The change MUST add no button, no setting and no visible text; "Safe for me" stays one per-character
  switch, on by default.
- **FR-009**: Zones MUST be told by their map IDs, never by their names.
- **FR-010**: The change MUST be recorded in the changelog and in the player manual's description of "Safe for me".

### Key Entities

- **Zone faction**: for a zone or capital map, Alliance or Horde; absent means contested. Taken from the game's area
  data; seventeen entries (six Alliance zones and three capitals, five Horde zones and three capitals).
- **Character faction**: Alliance, Horde, or none (unknown, neutral).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With "Safe for me" on, a Horde character's list never contains any of the nine Alliance zones and
  capitals, and an Alliance character's never any of the eight Horde ones, in every test case.
- **SC-002**: Every contested zone that passes the level rule is listed for both factions (no contested zone is lost).
- **SC-003**: In game, standing in at least two zones of each faction and one contested zone, the game's own
  territory label (friendly, hostile, contested) agrees with the table for every zone checked.
- **SC-004**: No new text is added: every language stays complete without new translations.

## Assumptions

- The faction of each zone as the game's area data gives it (build 1.60.1.71037) matches the territory the game shows
  in play; checked in game (SC-003, one VERIFY row). The data marks six Alliance zones (Elwynn Forest, Westfall, Dun
  Morogh, Loch Modan, Teldrassil, Darkshore), five Horde zones (Durotar, Mulgore, The Barrens, Tirisfal Glades,
  Silverpine Forest) and the six capitals; Redridge, Duskwood, Wetlands, Ashenvale, Stonetalon and Hillsbrad are
  contested, as in the original game.
- Forever characters always have Alliance or Horde in play (the Skyborne choose at creation); the neutral case is a
  safety net.
- Community guides say enemy territory flags a character on every mode and contested territory on PvP modes; the
  author decided contested zones stay listed.
- Hostile towns inside contested zones are not marked in the game's data; filtering them would need a hand-made list
  by name, which the project's rules forbid: left out.
- No saved data changes shape; "Safe for me" keeps its per-character value.
