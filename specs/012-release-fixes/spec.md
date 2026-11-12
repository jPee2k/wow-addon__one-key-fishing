# Feature Specification: Release Fixes for 1.2.0

**Feature Branch**: `002-shared-db` (spec 012 is built on the 1.2.0 branch itself, no branch of its own)

**Created**: 2026-11-11

**Status**: Draft

**Input**: User description (translated from Ukrainian): "Now let's fix the instance bug and the rest of the
technical debt: clear out what is left in the tech debt and the in-game errors that must be fixed in patch 1.2.0, and
everything that can be taken as a group goes here too."

## Context

The in-game run of 2026-11-10/11 (`docs/checklists/`, the 1.2.0 test page) left every open item of
`docs/tech-debt.md` "Fix batches" in one of five batches. This spec takes all of them, so the tech debt is empty
before the release:

- **Batch 10 (high).** Fishing in a dungeon with water raises the game's error window on every update of the
  action indicator: in an instance the game gives the bobber's identity (the soft-interact target's GUID) as a
  secret value, and the bobber check splits it as a string (seen 2026-11-11, `docs/forever-api.md`). Casting,
  hooking and looting still work. The released 1.1.0 has the same code, so players meet it today.
- **Batch 9 (low).** Two status texts are wrong once the exchange brought other players' records: the hint
  "No bundled data in this version: only your own catches are shown." shows next to "51 catches from 2 players",
  and the status line reads "Exchange: 1 players" (seen 2026-11-10).
- **Batch 5 (low).** A lure the game refused stays skipped until fishing mode is entered again, also after the
  skill rose past its requirement. Seen only in the code. V43 (the lures' requirements) was confirmed in game
  2026-11-11; V44 (the base skill is compared) is still open.
- **Batch 7 (low).** The minimap button's tooltip sometimes draws every line white (seen 2026-11-08, and in spec
  007 research R9). The colour codes written inside a line's text survived; the colours passed with each line were
  lost. The cause is not known.
- **Batch 8 (low, tooling).** The repository check that no file reads another folder's private module table sees
  only the plain form `<Module>.private`; an alias or a bracketed name slips through, and a line is cut at `--`
  even inside a string.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fishing in a dungeon without an error (Priority: P1)

A player fishes at water inside a dungeon. Casting, hooking and looting work as in the open world, and no error
window appears. The action indicator does not claim "No bobber" when it cannot tell.

**Why this priority**: players of the released version see an error window on every cast in a dungeon today.

**Independent Test**: the automated tests give the soft-interact target a secret identity while the player
channels; the bobber check gives "unknown", no error comes, and the indicator shows the hook state without "No
bobber".

**Acceptance Scenarios**:

1. **Given** the game gives the soft-interact target's identity as a secret value, **When** the indicator updates
   while the player channels Fishing, **Then** no error is raised and "No bobber" is not shown.
2. **Given** the identity is secret, **When** the player presses the fishing key while channeling, **Then** the key
   still interacts with the target, as today.
3. **Given** the identity is readable (the open world), **When** the target is not the bobber, **Then** "No bobber"
   shows as today.
4. **Given** a loot window opens in an instance and the game gives a loot source as a secret value, **When** the
   addon checks whether the loot came from the container it just opened, **Then** no error is raised and the loot is
   treated as of unknown source.

---

### User Story 2 - Status texts that match the data (Priority: P2)

A player whose addon received another player's records opens "What can be caught here" with no bundled data in
the build. The hint no longer says only their own catches are shown. The status line reads "Exchange: 1 player, 3m
ago" for one player and "Exchange: 2 players, 3m ago" for two.

**Why this priority**: wrong texts mislead, but no data is wrong.

**Independent Test**: the automated tests build the hint list with no seed and with or without another player's
record, and the status text for one and for two players.

**Acceptance Scenarios**:

1. **Given** no bundled data and no other player's record, **When** the tab shows the hints, **Then** the full line
   "No bundled data in this version: only your own catches are shown." shows, as today.
2. **Given** no bundled data and at least one other player's record held, **When** the tab shows the hints, **Then**
   a hint says only that the version has no bundled data, without "only your own catches".
3. **Given** the exchange was with one player, **When** the status line is shown (the tab, the settings page,
   `/okf share`), **Then** it uses the singular text; with two or more players, the plural.
4. **Given** any of the nine languages, **When** these texts show, **Then** they are translated.

---

### User Story 3 - A refused lure comes back after a skill-up (Priority: P3)

A player's lure was refused by the game. After the Fishing skill rises past the lure's requirement, the key offers
the lure again without the player leaving fishing mode.

**Why this priority**: only possible if a recorded requirement or the base-skill rule (V44) is wrong; not seen in
game.

**Independent Test**: the automated tests mark a lure skipped after a refusal, raise the skill past its requirement
and fire the skill event; the lure is offered again.

**Acceptance Scenarios**:

1. **Given** a lure skipped after a refusal, **When** the Fishing skill rises to or past its requirement, **Then**
   the lure is no longer skipped and the key offers it.
2. **Given** a skipped lure whose requirement is still above the skill, **When** the skill changes, **Then** it
   stays skipped.
3. **Given** the player enters fishing mode again, **When** the mode starts, **Then** every skipped lure gets
   another chance, as today.

---

### User Story 4 - The minimap tooltip keeps its colours (Priority: P3)

A player hovers the minimap button, also right after hovering item rows of the statistics window. The gold, grey,
green and white lines keep their colours on every hover.

**Why this priority**: cosmetic; no data is wrong.

**Independent Test**: the automated tests read the lines the tooltip receives; every coloured line carries its
colour inside its text, and the tooltip is cleared before the lines are added.

**Acceptance Scenarios**:

1. **Given** any hover of the minimap button, **When** the tooltip is built, **Then** each line's colour is written
   inside its text, so a reset of the line colours does not turn it white.
2. **Given** a tooltip with lines from an earlier owner, **When** the minimap tooltip is built, **Then** the old
   lines and data are cleared first.
3. **Given** the addon compartment entry, **When** it shows the same tooltip, **Then** it looks the same.

---

### User Story 5 - The private-table check sees every form (Priority: P3)

A developer reads another folder's private module table through an alias or a bracketed name, or after a string
that contains `--`. `npm run check` reports it.

**Why this priority**: no file does this today; it keeps the layer rule honest.

**Independent Test**: the tooling tests feed the check a file of another folder with an aliased read, a bracketed
read and a read after a string with `--`; each is reported, and the module's own folder is not.

**Acceptance Scenarios**:

1. **Given** `local C = ns.CatchDB` and `C.private` in a file outside `CatchDB/`, **When** the check runs, **Then**
   it is reported.
2. **Given** `ns["CatchDB"].private` outside `CatchDB/`, **When** the check runs, **Then** it is reported.
3. **Given** a string with `--` before a private read on the same line, **When** the check runs, **Then** the read is
   reported.
4. **Given** the same reads inside `CatchDB/` or in the tests, **When** the check runs, **Then** nothing is reported.

### Edge Cases

- **The bobber identity becomes readable mid-cast** (leaving an instance during a cast is not possible; a loading
  screen ends the cast): no special handling.
- **A secret identity in the open world** (should the game ever do it there): the same "unknown" answer.
- **The player's own GUID** is read for the anonymous ID outside instances only at first use; no change.
- **A received record removed later** (the exchange forgets a player): the hint goes back to the full line.
- **The bundled data exists**: no "No bundled data" hint at all, as today.
- **Several refused lures**: each comes back on its own requirement.
- **A tooltip line with a colour code already in its text** (the green "ON"): kept as written.
- **Korean and Chinese**: the tooltip's tall-glyph wrapping stays as today (spec 007 R9).

## Requirements *(mandatory)*

### Functional Requirements

**Dungeon (batch 10)**

- **FR-001**: Every place that reads a game identity or name that may be secret in an instance (the soft-interact
  target, loot sources) MUST check for a secret value before using it, and MUST NOT raise an error.
- **FR-002**: The bobber check MUST have three answers: the bobber, not the bobber, unknown. A secret identity
  gives "unknown".
- **FR-003**: The indicator MUST NOT show "No bobber" when the answer is "unknown"; it shows the hook state.
- **FR-004**: The fishing key's behaviour while channeling MUST NOT change.

**Status texts (batch 9)**

- **FR-005**: The hint about missing bundled data MUST say "only your own catches are shown" only when no other
  player's record is held with sharing on (with sharing off others' records are not shown); otherwise a shorter hint
  names only the missing bundled data.
- **FR-006**: The exchange status line MUST use a singular text for one player and the plural for more, wherever
  it shows.
- **FR-007**: Every new or changed text MUST come with its nine translations in the same change.

**Lures (batch 5)**

- **FR-008**: On a change of the Fishing skill, a skipped lure MUST stop being skipped once the skill meets the
  lure's requirement that the skill at the refusal did not meet (a lure refused with its requirement already met is
  not retried on any skill-up; research R4).
- **FR-009**: A skipped lure whose requirement is not met MUST stay skipped until the next fishing mode session.

**Minimap tooltip (batch 7)**

- **FR-010**: The minimap tooltip MUST write each line's colour inside the line's text, not only as a colour
  argument.
- **FR-011**: The tooltip MUST be cleared of earlier lines before its lines are added (whether the game's tooltip
  data plays a part is not known; research R5).

**Tooling (batch 8)**

- **FR-012**: The private-table check MUST find a read of `<Module>.private` through a local alias of the module,
  through a bracketed module name, and after a string that contains `--`.
- **FR-013**: The check MUST NOT report the module's own folder or the tests, as today.

**Documents and checks**

- **FR-014**: Each fix MUST come with a test that fails without it.
- **FR-015**: The documents MUST follow in the same change: `CHANGELOG.md` (`[Unreleased]` "Fixed": the dungeon
  error and the minimap tooltip as fixes of the released version; the status texts and the lure belong to the
  unreleased shared database or are not seen, CLAUDE.md "Definition of done"), the manual where a player sees it,
  `docs/forever-api.md` and the `CLAUDE.md` Forever API part, the architecture pages that change, `docs/tech-debt.md`
  (every item fixed here removed, the batches section emptied, a history line), `docs/release-plan.md`, and the
  checklists.
- **FR-016**: The author's 1.2.0 test page MUST list this spec's in-game steps after the implementation.
- **FR-017**: Code that rests on behaviour only the game can confirm MUST carry its `VERIFY` marker until the author
  confirms it in game.

### Key Entities

- **Bobber answer**: the bobber, not the bobber, or unknown (the identity is secret).
- **Skipped lure**: a lure the game refused, with its skill requirement; cleared by a new mode session or a skill
  that meets the requirement.
- **Status counts**: the number of players exchanged with, and whether any other player's record is held.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ten casts in a dungeon with water raise no error from the addon, and every catch is looted as usual.
- **SC-002**: The "What can be caught here" tab with another player's data held shows no "only your own catches"
  text; with one exchange partner every status text reads "1 player".
- **SC-003**: A lure refused once is offered again within one skill event after its requirement is met.
- **SC-004**: In the tests every coloured line of the minimap tooltip carries its colour in its text; in game, over a
  session of hovers alternating with item rows, no white tooltip is seen (the cause cannot be triggered on purpose).
- **SC-005**: `npm run check` reports every one of the three hidden forms of a private read in a test file.
- **SC-006**: `docs/tech-debt.md` has no open item left after this spec; `npm run check` and `npm test` pass; every
  new test fails when its fix is reverted.

## Assumptions

- The secret value seen 2026-11-11 is the soft-interact target's GUID; the target's name may be secret too, and the
  addon treats both alike. Whether loot sources are secret in an instance is not seen; they are guarded anyway.
- The game's `issecretvalue` exists in Forever (used since spec 010); when it is missing, no value is secret.
- The "unknown" answer only affects the indicator's "No bobber" warning: the key already interacts with any soft
  target while channeling, so hooking works without knowing the bobber (seen in the dungeon 2026-11-11).
- Colour codes inside text survive what reset the line colours (seen 2026-11-08), so FR-010 fixes batch 7 even
  without knowing its cause; the in-game check confirms it over time, not on one hover.
- The repository's Lua parser (luaparse, already a dependency of the checks) can read every addon file.
- Batches 9, 5, 7 and 8 need no game to verify their logic; batch 10 is checked in a dungeon with water after the
  implementation.
