# Feature Specification: Pin and Combat Fixes

**Feature Branch**: `002-shared-db` (spec 009 is built on the 1.2.0 branch itself, no branch of its own)

**Created**: 2026-11-07

**Status**: Draft

**Input**: User description (translated from Ukrainian): "Branch 002-shared-db, spec 009-pin-combat-fixes, release
1.2.0. Fix batches 3 and 4 of `docs/tech-debt.md` ("Fix batches"): the map pin does not open the world map (taint
in a fight, the toast under the map, R14/V32), the manual does not promise an arrow on screen (V31); leaving
fishing mode in a fight without EquipItemByName until the fight ends, the fishing key in a fight, a chat line on
an attack (the decision about the expectation is mine). Facts: `docs/forever-api.md` "Verified in game",
constitution 1.5.3 Principle III. In-game checklist: `interface-language.md` section 10, `fishing-mode.md`
section 1."

## Context

The in-game runs of release 1.1.0 and of the shared-db spike (2026-11-06/07) found five problems in two areas, all
recorded in `docs/tech-debt.md` with their `taint.log` evidence and grouped there as batches 3 and 4:

- **The map pin** (batch 3). Every pin of the addon (the next-rank Pin button and minimap menu entry, released in
  1.1.0; the catch catalog's pin buttons, not released yet) opens the world map after setting the pin. A world map
  opened from addon code is tainted, and the next time the player opens the map in a fight the game blocks the map's
  own quest pins: "Interface action failed because of an AddOn". The map also covers the toast that confirms the
  pin. Marker `VERIFY(R14)` (`specs/001-interface-language/verification.md`; the catalog's V32 was merged into it
  in spec 008). Separately, the manual promises "the game's navigation arrow" on screen; on Forever the on-screen
  arrow is off by a hidden game setting the addon must not touch, so only the minimap's edge arrow shows (V31,
  `specs/005-catch-catalog/verification.md`).
- **Fishing mode in a fight** (batch 4). Equipping is protected in combat, weapons too; only the moment the fight
  starts, before the combat lockdown, still allows it (`docs/forever-api.md` "Verified in game"; constitution
  1.5.3 Principle III, corrected on 2026-11-07). Leaving the mode with the toggle key during a fight tries to equip
  the weapons anyway and raises "Interface action failed because of an AddOn". With "Leave fishing mode when
  attacked" off, the fishing key pressed in a fight gives the game's "can't do that in combat" instead of the
  addon's "The fishing key is paused in combat." line. With the setting on, an attack swaps the weapons back
  without any chat line.

`docs/tech-debt.md` planned batches 3 and 4 as 1.1.x patches on `develop`; the author decided to build them on
`002-shared-db` and ship them with release 1.2.0. The pin and the combat behaviour were released in 1.1.0, so the
player-visible fixes get `CHANGELOG.md` lines under `[Unreleased]` ("Fixed"). Batches 1 and 2, which the
documents planned as "spec 009", move to the next spec number (010).

**Order of work** (the author, 2026-11-07): implement and fix first, then the in-game check. A step the author
already confirmed in game (the 1.1.0 and 1.2.0 test runs, the Results of the checklists) is cited, not repeated.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A map pin never breaks the map in a later fight (Priority: P1)

A player presses Pin in the statistics window (or "Pin: next Fishing rank" in the minimap menu, or a pin button of
the catch catalog). The pin and the minimap arrow are set, the world map stays closed, and a toast tells them the
pin is set and that the map shows it. Later, in a fight, they open the map with M and it works without any
"Interface action failed" line.

**Why this priority**: today every pin press leaves the map broken for the next fight, on a released feature; it is
the only item of the two batches that blocks a game window, and it hits every player who uses the next-rank advice.

**Independent Test**: press Pin, close nothing (no map opens), start a fight, open the map with M; then repeat with a
catalog pin button.

**Acceptance Scenarios**:

1. **Given** the next rank can be learned at a seller with a known place, **When** the player presses Pin in the
   statistics window, **Then** the game's pin is set at the seller, the minimap shows its arrow, the world map does
   not open, and a toast says the pin is set at that place and that the map shows it.
2. **Given** a pin was set through the addon this session, **When** the player opens the map by hand in a fight,
   **Then** the map and its quest pins work and no "Interface action failed because of an AddOn" line appears.
3. **Given** the player has a pin of their own, **When** they press Pin and confirm the replace question, **Then**
   the same happens as in scenario 1 (the map stays closed); Cancel keeps their pin as before.
4. **Given** the catch catalog, **When** the player presses a spot's pin button, **Then** the same rules apply: the
   pin is set, the map stays closed, the toast shows.
5. **Given** the game refuses the pin, **When** the player presses Pin, **Then** the toast says the game did not
   accept the pin, as before.
6. **Given** the map link at the end of a next-rank chat notice, **When** the player clicks it, **Then** the game's
   own link handler sets the pin and opens the map as before (verified in game: no blocked action afterwards).

---

### User Story 2 - Leaving fishing mode in a fight raises no error (Priority: P1)

A player in fishing mode is pulled into a fight and presses the toggle key to leave. The addon says it leaves the
mode after the fight and does nothing the game would block; when the fight ends, the mode ends and every piece of
gear, the weapons included, comes back.

**Why this priority**: an "Interface action failed" line in a fight is the most alarming thing an addon can show,
and pressing the toggle key in a fight is a natural reaction; the gear does come back today, so the fix removes the
error, not a loss.

**Independent Test**: with "Leave fishing mode when attacked" off, enter the mode, let a mob attack, press the toggle
key in the fight, finish the fight.

**Acceptance Scenarios**:

1. **Given** the mode is on, "Leave fishing mode when attacked" is off and a fight is under way, **When** the player
   presses the toggle key, **Then** the chat says "Leaving fishing mode after combat." once, nothing is equipped
   during the fight and no "Interface action failed" line appears.
2. **Given** that pending exit, **When** the fight ends, **Then** the mode turns off and the weapons and the rest of
   the gear, the camera and the game settings come back, with the usual "Fishing mode OFF." line.
3. **Given** the setting is on and the attack already swapped the weapons back at the start of the fight, **When**
   the player presses the toggle key during the fight, **Then** nothing more happens until the fight ends (no second
   line, no equip), and then the mode ends as in scenario 2.
4. **Given** the player logs in or reloads in a fight with gear still owed from an unfinished fishing session,
   **When** the addon finishes loading, **Then** it equips nothing during the fight and restores the gear once the
   fight ends.

---

### User Story 3 - An attack says that fishing mode ends (Priority: P2)

A player fishing with "Leave fishing mode when attacked" on is attacked. Their weapons come back at once, and the chat
says "Leaving fishing mode after combat." once, so they know why the pole is gone and what happens next.

**Why this priority**: nothing goes wrong today, the player only gets no explanation; the author chose the existing
line (already in all nine translations) as the expectation.

**Independent Test**: with the setting on, enter the mode, let a mob attack, read the chat; press the fishing key in
the fight.

**Acceptance Scenarios**:

1. **Given** the mode is on and the setting is on, **When** a fight starts, **Then** the weapons come back at once
   and the chat shows "Leaving fishing mode after combat." exactly once for that fight.
2. **Given** that line was just shown, **When** the player presses the fishing key or the toggle key within 5
   seconds, **Then** the line is not repeated (the key hint's 5-second pause between repeats also covers the
   attack line).
3. **Given** the setting is off, **When** a fight starts, **Then** no line appears on the attack (the mode stays on;
   the fishing key explains itself when pressed, User Story 4).
4. **Given** the mode is off, **When** a fight starts, **Then** no line appears.

---

### User Story 4 - The fishing key explains itself in a fight (Priority: P3)

A player keeps fishing mode on in a fight ("Leave fishing mode when attacked" off) and presses the fishing key. The
key does not try to cast; the chat says "The fishing key is paused in combat."; after the fight the key casts again.

**Why this priority**: nothing wrong happens today (the game refuses the cast and fishing goes on after the fight),
only the addon's explanation is missing. The cause is read from the client's own code (plan research R1); the
in-game check confirms it after the fix, before its marker is removed.

**Independent Test**: with the setting off, enter the mode, start a fight, press the fishing key; after the fight
press it again.

**Acceptance Scenarios**:

1. **Given** the mode is on, the setting is off and a fight is under way, **When** the player presses the fishing
   key, **Then** the chat says "The fishing key is paused in combat." and the game's "can't do that in combat" does
   not appear.
2. **Given** the fight ended, **When** the player presses the fishing key, **Then** it casts (or applies a lure, or
   opens a container) as before the fight.

---

### User Story 5 - The manual promises only what the pin shows (Priority: P3)

A player reads the manual about the next-rank pin and the catalog pin. It says the pin marks the place on the world
map and the minimap, with the minimap's arrow, that the map does not open by itself, and that an arrow on screen
depends on the game's own navigation setting.

**Why this priority**: wording only; the pin itself works.

**Independent Test**: read the next-rank and the catalog parts of `OneKeyFishing/README.md` after a pin in game.

**Acceptance Scenarios**:

1. **Given** the manual, **When** a player reads what a pin does, **Then** no sentence promises an arrow on screen or
   a map that opens by itself; the minimap arrow and the on-screen arrow's dependence on the game's setting are named.
2. **Given** the manual's "Safe in combat" feature line, **When** a player reads it, **Then** it matches the
   behaviour of User Stories 2 and 3 (the weapons come back at once on an attack with the setting on; otherwise
   everything comes back after the fight).

### Edge Cases

- **Attacked while channeling Fishing.** Equipping fails while casting, so the weapon swap waits for the cast to end,
  and that end may come after the combat lockdown began. The addon then equips nothing until the fight ends; the
  weapons come back with the rest of the gear (the only window for a weapon swap in a fight is before the lockdown).
  Constitution Principle III's "the weapons return when the fight starts" is what the game allows; this case is
  the game's limit, and the manual and `docs/architecture/fishing-mode.md` say so.
- **The toggle key pressed twice in one fight**: one line, one pending exit.
- **A pin pressed in a fight**: the pin and the minimap arrow are set as out of a fight; the map stays closed either
  way.
- **The pin toast** shows above the indicator; with the map closed it is no longer covered.
- **A fight that ends while the player is still channeling**: the restore after the fight waits for the cast to end,
  as it does today.
- **The fishing key's in-game check after the fix** can give two results other than the expected one:
  - the binding is still the click: a rebind between the state driver and the lockdown is the next suspect (plan
    research R1, alternatives), fixed with its own test;
  - the overrides were dropped, but the game still reports a refused cast: the press is taken by something
    outside the addon; the expectation in `fishing-mode.md` section 1 changes and the item is closed as "game
    behaviour".

## Requirements *(mandatory)*

### Functional Requirements

**Map pin (batch 3)**

- **FR-001**: Setting a map pin through the addon MUST NOT open the world map, in or out of a fight, for every pin of
  the addon (the next-rank Pin button, its minimap menu entry and the catch catalog's pin buttons), also after the
  replace question.
- **FR-002**: After a pin the addon set, opening the world map by hand in a later fight MUST NOT produce a blocked
  action caused by the addon.
- **FR-003**: The pin and the game's tracking of it (the minimap's arrow) MUST still be set as today; the refused-pin
  toast stays as it is.
- **FR-004**: The toast after a pin MUST name the place and tell the player to open the world map to see the pin.
  The text goes through the addon's translations with all nine translations in the same change.
- **FR-005**: The chat map link of the next-rank notice MUST keep working as today (the game's own handler sets the
  pin and opens the map).
- **FR-006**: The player manual MUST describe the pin as a mark on the world map and the minimap with the minimap's
  arrow, say the map does not open by itself, and say an arrow on screen depends on the game's navigation setting.
  The addon MUST NOT change that setting (constitution Principle III: only what the addon changed is restored).

**Fishing mode in a fight (batch 4)**

- **FR-007**: While the game's combat lockdown is on, the addon MUST NOT try to equip or unequip any item, on any
  path: leaving the mode with the toggle key, the end of a cast, a login or reload in a fight.
- **FR-008**: The weapon swap at the start of a fight (with "Leave fishing mode when attacked" on) MUST stay where it
  is, before the lockdown, as constitution 1.5.3 Principle III requires; whatever it could not swap there waits for
  the end of the fight.
- **FR-009**: Leaving the mode with the toggle key in a fight MUST set a pending exit, say "Leaving fishing mode after
  combat." once, and finish the exit (all gear, camera, game settings, the "OFF" line) when the fight ends.
- **FR-010**: With "Leave fishing mode when attacked" on, the start of a fight in fishing mode MUST print "Leaving
  fishing mode after combat." once (the existing text; no new translation). The key hint MUST NOT repeat the same
  line within 5 seconds after it (the hint's existing pause covers the attack line).
- **FR-011**: In a fight with fishing mode on, the fishing key MUST NOT reach the cast; it MUST give "The fishing key
  is paused in combat." (throttled as today) and work again after the fight. The cause is read from the client's
  own code (plan research R1); the fix carries its `VERIFY` marker until the in-game check of the binding the key
  holds in a fight confirms it (FR-015).

**Documents and checks**

- **FR-012**: The automated tests MUST cover: no pin path opens the world map; no equip call while the lockdown is on
  for each path of FR-007; the attack line once per fight (and none with the setting off or the mode off); the
  pending exit finishing after the fight. Each test fails without its fix.
- **FR-013**: The documents MUST follow the fix in the same change: `CHANGELOG.md` `[Unreleased]` "Fixed" (the map in
  a later fight, the error on leaving the mode in a fight, the attack line, the pin toast; the fishing key if fixed),
  the manual (FR-006 and its "Safe in combat" line), FR-022 of spec 001 and FR-011 of spec 005, the R14 row
  (`specs/001-interface-language/verification.md`) and the V31 row (`specs/005-catch-catalog/verification.md`),
  `docs/forever-api.md` and the "Forever API" part of `CLAUDE.md` (the pins no longer call the map),
  `docs/architecture/fishing-mode.md` ("Leaving in combat") and `docs/architecture/core.md` (the map pin),
  `docs/tech-debt.md` (the closed items and batches 3 and 4 removed), and `docs/release-plan.md` (batches 3 and 4
  ship in 1.2.0 through spec 009; batches 1 and 2 move to the next spec number).
- **FR-014**: The in-game re-checks MUST be handed to the author after the implementation, as checklist steps:
  `docs/checklists/interface-language.md` section 10 ("Map pin": Pin, a fight, the map opened by hand) and
  `docs/checklists/fishing-mode.md` section 1 ("Out of combat only": the fishing key's binding in a fight first, then
  the attack line, the toggle key in a fight). They cover only what this fix changes; what the author already
  confirmed in game (the pin and the minimap arrow, the replace question, the chat map link, the weapons back at
  once on an attack, fishing going on after a fight) is cited, not repeated. The author's 1.2.0 test page lists the
  same steps.
- **FR-015**: Code that rests on behaviour only the game can confirm MUST carry its `VERIFY` marker until the author
  confirms it: R14 stays on the pin path until the re-check of section 10 passes; the fishing key's fix carries
  V45 until the binding check passes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the re-check of `interface-language.md` section 10, zero "Interface action failed because of an
  AddOn" lines after a pin, a fight and the map opened by hand. One pin path is enough, because every pin of the
  addon goes through the one map pin module (the automated tests cover the rest).
- **SC-002**: In the re-check of `fishing-mode.md` section 1, zero "Interface action failed" lines for the toggle key
  in a fight, and after the fight 100% of the swapped slots hold the player's own gear again.
- **SC-003**: The pin toast is fully visible after every pin press (no window covers it) and names the place.
- **SC-004**: An attack with the setting on gives exactly one chat line per fight; with the setting off, none.
- **SC-005**: The fishing key pressed in a fight gives the addon's line, not the game's refusal, in every press of the
  re-check (or, if the cause turns out to be the game's, the checklist's expectation says so and the item is closed).
- **SC-006**: `npm run check` and `npm test` pass; every new test fails when its fix is reverted.

## Assumptions

- The facts of `docs/forever-api.md` "Verified in game" hold: the map opened from addon code is what taints the map
  (the pin and the tracking calls do not show in `taint.log`); equipping is blocked in the lockdown, weapons too, and
  the start-of-fight handler still runs before it; the game's own map link causes no blocked action.
- "Leave fishing mode when attacked" keeps its meaning; no new setting is added (constitution Principle VI).
- The released `CHANGELOG.md` 1.1.0 entry is not rewritten; the `[Unreleased]` "Fixed" lines correct what it
  promised (the arrow, the map).
- With the setting off and the toggle key pressed in a fight, the pole stays in hand until the fight ends; this
  follows from the lockdown rule and is described in the manual, not worked around.
- The fishing key item is confirmed by one in-game check by the author after the fix
  (`/run print(GetBindingAction("<key>", true))` in a fight, named in `docs/tech-debt.md`).
- The catch catalog's pins are not released, so they need no changelog line of their own; they share the fix through
  the addon's one map pin module.
