# Feature Specification: Tech Debt Fixes for 1.3.0

**Feature Branch**: `015-tech-debt-fixes`

**Created**: 2026-11-16

**Status**: Draft

**Input**: User description (translated from Ukrainian): "We fix every finding of the tech debt in one bugfix
commit."

## Context

`docs/tech-debt.md` holds three open items in two fix batches. This spec takes all of them, so the tech debt is
empty before release 1.3.0 (the fishing sounds of spec 013, the catch kinds of spec 014 and these fixes, released
together). None of them needs the game for its fix or its test; the whole change lands as one bugfix commit.

- **Batch 12 (medium).** The record of the game settings fishing mode changed (the "Sound effects" page's splash
  focus, background sound and the older rows) is kept per character, but the game keeps those settings for the whole
  computer. After a crash or a disconnect in fishing mode, music, ambience and dialog stay silenced until that same
  character logs in again; another character plays without them, and if it enters fishing mode it records the
  silenced values as its own and never brings the sound back.
- **Batch 12 (low).** A setting the player changed by hand while fishing keeps the player's value when the mode
  ends (spec 013). A `/reload` while fishing forgets which settings those were: the mode resumes and the splash
  focus silences the music the player had turned up again.
- **Batch 11 (low).** After an exchange partner logs in again (or reloads), the exchange counts that partner twice
  for an hour ("Exchange: N players", `/okf share`, the debug report): once under the address it was heard on
  before and once under the address it is heard on now. Sessions and cooldowns already treat it as one player; only
  the counts are wrong. Seen in game on 2026-11-12.

> **Revision, review 4 (2026-11-16): User Story 1 withdrawn.** The game writes saved variables only at a logout,
> a `/reload` or the exit, never at a crash, and `PLAYER_LOGOUT` restores the CVars (emptying the record) before that
> write, so a crash leaves no record on disk on any character; a disconnect logs out and restores as before. The
> account-wide record (US1, FR-001 to FR-004, SC-001, the schema 2 migration, V52) was built and reverted at the
> author's choice; the CVar record stays per character as in 1.2.0. US2 and US3 stand. `docs/tech-debt.md` "History"
> records the dropped item.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Game sound comes back on any character after a crash (Priority: P1)

A player fishes on character A with the splash focus on, and the game crashes (or the connection drops). The player
logs in on character B. Music, ambience and dialog play again at the values the player had before fishing, and the
chat says the game settings were restored from an unfinished fishing session.

**Why this priority**: a player who switches characters after a crash loses the game's music and ambience with no
way to tell why; it is the only medium item.

**Independent Test**: the automated tests leave a record of changed settings behind as character A, log in as
character B, and check that every setting still holding the addon's value is put back and the record is gone.

**Acceptance Scenarios**:

1. **Given** a crash in fishing mode on character A left the settings changed, **When** character B logs in,
   **Then** every setting that still holds the value fishing mode put there is restored to the player's earlier
   value, and the "Restored game settings" line shows once.
2. **Given** the same record, **When** a setting no longer holds the value fishing mode put there (the player
   changed it in the game's options meanwhile), **Then** that setting keeps its current value and leaves the record.
3. **Given** the record was restored on character B, **When** character A logs in later, **Then** nothing is restored
   again and no line shows.
4. **Given** a record left in a character's own record by an earlier version of the addon, **When** that character
   logs in with the new version, **Then** the settings are restored as before and the old record is gone.
5. **Given** character B enters fishing mode after the restore, **When** the mode ends, **Then** the player's real
   values come back (not the silenced ones of the crash).
6. **Given** the gear and the camera of character A, **When** character B logs in, **Then** they are not touched:
   gear stays per character, as today.

---

### User Story 2 - A /reload keeps the settings the player changed while fishing (Priority: P2)

A player in fishing mode with the splash focus on turns the music back up in the game's options. Later they type
`/reload`. Fishing mode resumes, and the music stays at the player's value; when the mode ends, the music is still
the player's value.

**Why this priority**: the player's own choice is undone by a `/reload`, but only for players who fish with the
splash focus and change a setting by hand.

**Independent Test**: the automated tests change a setting by hand while fishing, run the logout and resume of a
`/reload`, and check the setting keeps the player's value through the resume and the exit.

**Acceptance Scenarios**:

1. **Given** the player raised the music volume by hand while fishing, **When** `/reload` resumes fishing mode,
   **Then** the music volume is not set again by the mode and keeps the player's value.
2. **Given** the same, **When** the mode ends after the `/reload`, **Then** the music volume is not restored over
   the player's value.
3. **Given** a setting the player did not touch, **When** `/reload` resumes the mode, **Then** fishing mode applies
   it again and restores it on exit, as today.
4. **Given** a real login (not a `/reload`) or an exit from fishing mode, **When** the next session starts, **Then**
   the remembered hand-changed settings are forgotten and every setting is the mode's again.

---

### User Story 3 - A partner who relogs counts once (Priority: P3)

A player exchanges catches with a partner who is both in the group and a Battle.net friend. The partner logs in
again from another computer. The exchange status keeps saying the same number of players, not one more for the
next hour.

**Why this priority**: a count shown to the player is wrong for an hour; no data is wrong and nothing else changes.

**Independent Test**: the automated tests hear a partner by Battle.net, then the same partner by the group with a
new login identity, and check the counts of players heard and players exchanged with each count the partner once.

**Acceptance Scenarios**:

1. **Given** a partner heard by Battle.net, **When** the same partner is heard by the group after a new login,
   **Then** the partner counts once in "heard in the last hour" (under the path whose greeting was taken) and once in "exchanged
   with".
2. **Given** two different partners on two paths, **When** the counts are read, **Then** each counts once, as today.
3. **Given** the partner relogs and is heard on the same path as before, **When** the counts are read, **Then** the
   partner counts once, as today.
4. **Given** the counts, **When** shown in "Exchange: N players", `/okf share` and `/okf debug`, **Then** they all
   agree.

### Edge Cases

- **Two game accounts on one computer**: the game's settings are shared by the computer, the addon's account-wide
  record by the game account; a crash on one account is restored at the next login of that account, not the other.
  Accepted limit, noted in the plan.
- **Two clients of one game account at once**: the game does not allow it (a second login ends the first session),
  so only one client writes the account-wide record at a time.
- **A crash during the first fishing session after the update**, with an older character record still present: both
  records are restored, and a setting found in both is restored once, to the player's earlier value.
- **A record whose setting is unknown to the game** (removed in a patch): skipped without an error, and dropped.
- **Fishing mode entered while a restore is still pending** (a fight at login): unchanged from today; the restore
  runs first at login, before the mode can start.
- **A `/reload` in a fight**: the mode does not resume (as today), which counts as the mode's end: the remembered
  hand-changed settings are dropped, and the next entry is a fresh one.
- **A partner heard on three paths** (guild, group and Battle.net) with a new login identity on one of them: counts
  once, under the path whose greeting was taken.
- **The public channel** stays off (spec 010); channel addresses are not part of the per-player count, as today.

## Requirements *(mandatory)*

### Functional Requirements

**Game settings after a crash (batch 12, medium)**

- **FR-001**: The record of the game settings fishing mode changed MUST be kept account-wide, not per character,
  and MUST still be written before a setting is changed (constitution Principle III).
- **FR-002**: At the login of any character, every setting in that record that still holds the value fishing mode
  put there MUST be restored to the player's earlier value; every other entry MUST be dropped without changing the
  setting. The chat line "Restored game settings from an unfinished fishing session." MUST show only when at least
  one setting was restored.
- **FR-003**: A record left in a character's own record by an earlier version MUST be moved into the account-wide
  record at that character's login (and then restored by FR-002); the saved-data schema version MUST be raised with a migration, and
  no player value may be lost by the move.
- **FR-004**: The gear and the camera records MUST stay per character and keep today's behaviour.

**Hand-changed settings across a /reload (batch 12, low)**

- **FR-005**: The list of "Sound effects" settings (the ones their switch applies at once) the player changed by
  hand while fishing MUST be kept across a `/reload` that resumes fishing mode, and the resumed mode MUST neither
  apply nor restore those settings. The other settings (auto loot, the soft target the hook key needs) are applied
  again by the resume, as before (review 2).
- **FR-006**: That list MUST be dropped on a real login, when fishing mode ends, and when a `/reload` cannot resume
  the mode.

**Exchange counts (batch 11, low)**

- **FR-007**: The exchange's activity counts ("heard in the last hour", "exchanged with") MUST count each partner
  client once, by the client's current login identity, under the path whose greeting was taken (the first to greet
  with that identity); an address
  whose identity another address has taken over therefore stops counting on its own at once.
- **FR-008**: The messages and the data exchanged MUST NOT change. Sessions and cooldowns keep their rules; a
  relogged client's addresses are one client for them too, as they already were for its addresses of one session.

**For all**

- **FR-009**: Every fix MUST come with an automated test that fails without the fix.
- **FR-010**: The three items MUST leave `docs/tech-debt.md` (its "Fix batches" and "Open items"), with a line in its
  "History"; the change MUST land as one commit on this branch.
- **FR-011**: No new visible text is expected; if one is needed, it MUST come with its nine translations.

### Key Entities

- **Changed-settings record**: per game setting, the player's value before fishing mode and the value the mode put
  there; account-wide; written before the change, dropped entry by entry when restored or no longer the mode's.
- **Hand-changed settings list**: the settings the player changed while fishing; per character; survives a `/reload`
  with the resume flag, gone on a real login and on exit.
- **Exchange partner**: one client of another player, known by its login identity (new at every login or `/reload`)
  and reachable by one or more addresses (guild, group, Battle.net); the unit the activity counts count.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After a crash in fishing mode, the first login of any character on the same game account brings back
  100 % of the game settings that still hold fishing mode's values, and the player's sound plays at their earlier
  volumes on that character.
- **SC-002**: A setting the player changed by hand while fishing keeps the player's value through any number of
  `/reload`s and the end of the mode (0 settings overwritten).
- **SC-003**: A partner who relogs counts once from their first greeting with the new login identity, whichever path
  it comes by (an hour of double counting today).
- **SC-004**: `docs/tech-debt.md` lists 0 open items after the change; the full check and test suite pass.

## Assumptions

- The game keeps none of the changed settings per character: auto loot and the soft-target settings per game
  account, the sound settings for the whole installation (`Config.wtf`), while the addon's account-wide saved data is
  per game account on that installation; one game account per computer is the common case. Read from the client's
  CVar table, not seen in game (V52 in `verification.md`).
- The existing rule stays: a setting is restored only while it still holds the value fishing mode put there.
- The fixes ship in release 1.3.0 with specs 013 and 014; the changelog line covers only what a player of 1.2.0 can
  notice (sound settings restored on any character after a crash, the exchange count); the `/reload` fix belongs to
  the unreleased spec 013 and needs no line.
- The exchange fix touches only the counts; the protocol and the messages stay as they are, so older addon versions
  are not affected.
- No in-game check is required: each fix is proven by an automated test; the crash case can be checked in game
  later as an optional step of the fishing-mode checklist.
