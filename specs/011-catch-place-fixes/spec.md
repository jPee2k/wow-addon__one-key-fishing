# Feature Specification: Catch Place Fixes

**Feature Branch**: `002-shared-db` (spec 011 is built on the 1.2.0 branch itself, no branch of its own)

**Created**: 2026-11-08

**Status**: Draft

**Input**: User description (translated from Ukrainian): "We work on the same branch. Batch 2 (pool, cave,
subzone): the direction of each item is already written. One condition: the subzone (V34) first needs a `/run` in
the game to check an ID-based source of the subzone; if there is none, the spec takes the coordinate fallback that
already works, so V34 can be the spec's first step. Batch 6 (the secret name in a fight): a small fix in one file
(`Fishing/Skill.lua`), tested through `secret_values` in the stubs, nothing needed in game. The pole from batch 5
can be added: the choice of a pole by skill is small, tested without the game, and the data is already in
`GameData/FishingPoles.lua`. Tell what has to be checked in game; ask questions as a quiz."

**Decisions** (quiz, 2026-11-08):

- Subzone: look the subzone name the game shows up among the game's area names and keep the area's ID. A `/run`
  in game confirms it first; if it fails, the spot keeps today's behaviour (a name where the explored region
  matches, else coordinates).
- Cave: a cast on a continent map is recorded on the zone map under that point. A `/run` in the cave confirms it
  first; if it fails, such casts are not recorded. The author already confirmed in the cave before Wailing Caverns
  that the game reports the continent, not an instance or a cave map.
- Data recorded before the fix (continent cells, pool catches written as open water) stays as it is: only the
  author's two accounts have it, before the first harvest.
- Pool: the pool part stays in the record format as an optional part that is no longer written; the exchange
  format, the record checks and the "Water" filter do not change.

**In-game checks before the plan** (the author, 2026-11-08):

- Cave before Wailing Caverns: the reported map is 1414 (Kalimdor) at (0.519, 0.551), and
  `C_Map.GetMapInfoAtPosition(1414, x, y)` gives 1413 "The Barrens", type 3 (Zone). The zone under the point is
  found: FR-004 applies, FR-007 does not. `C_Map.GetPlayerMapPosition(1413, "player")` gives a position inside the
  cave (x 0.461), so the cell is read on the zone map.
- Ratchet: the subzone text "Ratchet" matches exactly one area name among the IDs 1 to 20000, area 392 (the one the
  explored regions gave too); walking the 20000 IDs took 4.3 ms.
- The highest area ID with a name is 17853.
- Thunder Bluff (the pond, as on 2026-11-06): `GetSubZoneText()` is empty, so no area is looked up (4.5 ms for the
  walk). The game names no subzone there; the spot keeps coordinates (FR-010), which is right.
- Stonebull Lake, where the explored regions failed although the game shows "Stonebull Lake": the name matches
  exactly one area, 223 (4.7 ms for the walk). The lookup by name finds the subzone the old search missed; V34's
  question is answered, and the in-game step after the implementation only checks the spot names.

## Context

The solo spike of 2026-11-06/07 showed three ways the catch database records the wrong place
(`docs/tech-debt.md`, batch 2; `docs/forever-api.md` "Verified in game"):

- **Pools (V3).** In Forever a catch from a fishing pool comes from the bobber, like open water; the addon expected
  the pool's own object as the loot source. Every pool catch is written as open water, so the pool and open-water
  split shown by the "Water" filter would be wrong once it appears.
- **Caves (V2, V33).** In the cave before Wailing Caverns the game reports the continent (Kalimdor) as the player's
  map, not The Barrens or a cave map. Such catches become a place named "Kalimdor" with cells spread over the whole
  continent.
- **Subzones (V34).** The addon names a spot after the subzone ("Stonebull Lake (46, 58)") only when one of the
  map's explored regions at the player's position is named as the game's subzone text. That holds at Ratchet but
  not at Stonebull Lake (no region, or a nearby village's region) or in Thunder Bluff, so most spots show only
  coordinates.

Every catch recorded before the fix keeps its place, so this goes in before `npm run harvest` builds the first
seed (`docs/release-plan.md`).

Two smaller items go with it:

- **Batch 6.** In a fight in an instance the trainer's name in the next-rank advice comes from the game as a
  secret value; comparing it raised a Lua error (seen 2026-11-08, twice in one fight). The released 1.1.0 has the
  same code, so players meet it today.
- **The pole from batch 5.** The best pole is chosen by its Fishing bonus alone, whatever skill it needs, so a
  player could be offered a pole the game does not let them equip. Not seen in game; the data is already recorded.

This spec is built on `002-shared-db` and ships in 1.2.0.

**Order of work** (the author): the two `/run` checks first (they choose between a fix and its fallback), then
implement and fix, then the in-game check. A step already confirmed in game is cited, not repeated.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - No Lua error in a fight (Priority: P1)

A player with the addon fights in an instance while their Fishing skill waits for a character level (or sits at
the cap). Weapon and defense skill-ups in the fight do not raise an error, and the next-rank advice still names the
trainer when it is shown.

**Why this priority**: players of the released version see this error today, during fights, where an error window
hurts most.

**Independent Test**: the automated tests give the advice a secret trainer name and a skill event in a fight; no
error comes and the advice uses its fallback name.

**Acceptance Scenarios**:

1. **Given** the game gives the trainer's name as a secret value, **When** the next-rank advice is built, **Then**
   no error is raised and the advice names the trainer from the addon's own name table.
2. **Given** a fight is on and a skill-up fires, **When** the addon checks the next rank, **Then** it reads no
   tooltip and shows no notice during the fight.
3. **Given** the fight is over, **When** the next skill event or the end of the fight comes, **Then** a notice owed
   during the fight is shown once.
4. **Given** the name was a secret value once, **When** the advice is built again outside a fight, **Then** the
   game's name is read and used.

---

### User Story 2 - Catches in a cave belong to the zone (Priority: P1)

A player fishes in a cave whose map the game reports as the continent. The catch is recorded on the zone the cave
lies in (The Barrens), at the cave's point, and "What can be caught here", the catalog and the map pin show that
zone.

**Why this priority**: a place named after a continent, with cells the size of a zone, is wrong data that every
other player receives through the exchange and the seed.

**Independent Test**: the automated tests give a continent as the player's map; the cast is recorded on the zone
map the game reports under the point, never on the continent.

**Acceptance Scenarios**:

1. **Given** the game reports the continent as the player's map, **When** the player casts, **Then** the cast is
   recorded on the zone map under the player's point, with the position on that zone map.
2. **Given** the game gives no zone map under the point, **When** the player casts, **Then** the cast is not
   recorded (no continent place is ever written).
3. **Given** a cave cast was recorded on its zone, **When** the player opens "What can be caught here" in the cave,
   **Then** the tab shows the same zone and cell the cast went to.
4. **Given** the player is on a zone or city map, **When** the player casts, **Then** nothing changes from today.

---

### User Story 3 - Spots are named after their subzone (Priority: P2)

A player looks at the spots of a fish in the catalog. Each spot carries the subzone the game showed when it was
fished ("Stonebull Lake (46, 58)"), not just coordinates, wherever the game names a subzone.

**Why this priority**: names make spots easy to find, but coordinates already work, so this is less urgent than
wrong data.

**Independent Test**: the automated tests give a subzone text and a set of areas with names; the cast keeps the ID
of the area with that name, also when no explored region is at the position.

**Acceptance Scenarios**:

1. **Given** the game's subzone text is "Stonebull Lake" and an area of the game has that name, **When** the
   player casts, **Then** the cast keeps that area's ID, and the spot shows "Stonebull Lake (46, 58)" in the
   client's language.
2. **Given** several areas share the subzone's name, **When** the player casts, **Then** the same area is chosen
   every time (the same on every client of that language).
3. **Given** the game shows no subzone, or no area has its name, **When** the player casts, **Then** the spot keeps
   coordinates only, as today.
4. **Given** a client in another language, **When** the same spot is shown, **Then** the name comes from the area
   ID in that client's language.

---

### User Story 4 - Pool catches are not counted as open water (Priority: P2)

A player catches fish from a pool. The addon no longer claims to know whether a catch came from a pool or from open
water; the "Water" filter stays hidden and no catch is split by its source.

**Why this priority**: the split is wrong today but no screen shows it yet (the filter appears only once pool data
exists); this keeps it from ever showing wrong numbers.

**Independent Test**: the automated tests give a catch whose loot source is the bobber; the catch carries "source
unknown", no pool part is written, and the filter stays hidden.

**Acceptance Scenarios**:

1. **Given** a catch from the bobber, **When** it is recorded, **Then** it counts as a catch of the cell with no
   pool or open-water claim.
2. **Given** no data with a pool part, **When** the player opens "What can be caught here" or the catalog, **Then**
   no "Water" filter shows.
3. **Given** a received record with a pool part (an older build), **When** it is checked and shown, **Then** it is
   accepted as today.
4. **Given** the debug report, **When** a catch came in, **Then** it makes no claim about pools (the pool line went
   with the dead pool path in code review round 1).

---

### User Story 5 - No pole the player cannot use (Priority: P3)

A player with Fishing skill 40 carries a Darkwood Fishing Pole (needs 50) and a Strong Fishing Pole (needs 10).
Fishing mode equips the Strong Fishing Pole until the skill reaches 50.

**Why this priority**: not seen in game; a pole above the skill only fails to equip, it loses nothing.

**Independent Test**: the automated tests give two poles and a skill between their requirements; the best usable
one is chosen.

**Acceptance Scenarios**:

1. **Given** a pole above the Fishing skill and one at or below it, **When** fishing mode chooses a pole, **Then**
   it takes the usable one, even when the other has a larger bonus.
2. **Given** the skill rises past the better pole's requirement, **When** fishing mode chooses a pole next, **Then**
   it takes the better pole.
3. **Given** the skill is not known yet, or the pole is not in the addon's pole list, **When** fishing mode chooses,
   **Then** nothing is held back (as for lures).
4. **Given** the player chose a pole by hand in the settings, **When** fishing mode equips it, **Then** the choice
   is kept, as today.

### Edge Cases

- **A cave at a zone's border**: the zone under the point is the one the game reports there; a few casts may land
  on the neighbouring zone. Accepted.
- **A position the game does not give** (an instance): no cell, as today (cell "x").
- **A continent with no zone under the point** (sea between zones): the cast is not recorded.
- **A subzone named like its zone** ("Thunder Bluff" in Thunder Bluff): the area is kept; the spot shows the name.
- **A subzone name that matches no area** in a client language (a translation quirk): coordinates only.
- **Looking up the area name** must not freeze a frame: the cost of finding an area by name is paid once and
  spread out, not on every cast.
- **A secret value elsewhere** in the advice (rank name, area, book, quest): treated as missing, the fallback name
  is used.
- **A fight that ends while the player is dead or in a loading screen**: the owed notice comes with the next skill
  event.
- **Two poles of the same bonus**: the choice stays as today (item level, then the first found).
- **Data recorded before the fix**: kept as it is (decision above).

## Requirements *(mandatory)*

### Functional Requirements

**A fight (batch 6)**

- **FR-001**: The next-rank advice MUST treat a secret value from the game (any name it reads) as missing and use
  its fallback, with no error.
- **FR-002**: The skill checks MUST NOT build the advice or read a tooltip during a fight; a notice owed during the
  fight MUST be shown once after it.
- **FR-003**: A name that was a secret value MUST NOT be cached as the game's name; it is read again later.

**Caves (V2, V33)**

- **FR-004**: A cast whose reported map is a continent (or larger) MUST be recorded on the zone map the game gives
  under the player's point on that continent, with the cell and position of that zone map.
- **FR-005**: When no zone map is found under the point, the cast MUST NOT be recorded; no place key MUST ever name
  a continent.
- **FR-006**: "What can be caught here" MUST read the same place the cast would be recorded on.
- **FR-007**: If the in-game check shows the zone cannot be found from the continent, FR-004 falls away and FR-005
  alone applies.

**Subzones (V34)**

- **FR-008**: The area of a cast MUST be found by the subzone text the game shows, matched (case- and
  accent-folded, Principle II) against the names of the game's areas; only the area's ID is kept.
- **FR-009**: When several areas match, the choice MUST be deterministic.
- **FR-010**: When nothing matches, the cast MUST keep no area, and the spot shows coordinates.
- **FR-011**: Finding areas by name MUST NOT stall a frame: no single frame step spends more than 5 ms on it
  (SC-004); the plan's step of 2000 IDs takes about 0.5 ms.
- **FR-012**: If the in-game check shows the lookup does not find the subzone, the area search MUST stay as today
  and V34 closes with the facts. (Not needed: the check of 2026-11-08 found Ratchet 392 and Stonebull Lake 223.)

**Pools (V3)**

- **FR-013**: The addon MUST NOT claim a catch came from open water or from a pool; every catch's source is
  "unknown", and no pool part is written.
- **FR-014**: The record format, the record checks and the "Water" filter MUST stay as they are: a pool part from
  another client is still accepted, and the filter shows only when such data exists.

**Pole (batch 5)**

- **FR-015**: The automatic pole choice MUST pass over a pole whose Fishing requirement is above the character's
  Fishing skill; an unknown skill or a pole without a recorded requirement holds nothing back.
- **FR-016**: A pole the player chose by hand MUST still be used.

**Documents and checks**

- **FR-017**: Each fix MUST come with a test that fails without it (secret name, fight, continent, no zone, area by
  name, pool unknown, pole by skill).
- **FR-018**: The documents MUST follow in the same change: `CHANGELOG.md` (`[Unreleased]` "Fixed": the fight error
  as a fix of the released version, and the pole; the cave, subzone and pool changes belong to the unreleased
  shared database and need no line, CLAUDE.md "Definition of done"), the manual where a player sees it, the
  verification records of V2, V3, V33 and V34, `docs/forever-api.md`, the `CLAUDE.md` Forever API part where it
  changes, `docs/architecture/catch-db.md` and `fishing-mode.md`, `docs/tech-debt.md` (batches 2 and 6 and the
  pole item removed, the history line), `docs/release-plan.md`, and the checklists (`catch-catalog.md` steps 5 and
  6, `spike.md`).
- **FR-019**: The author's 1.2.0 test page MUST be updated after the implementation: the phase "After spec 011"
  lists this spec's in-game steps.
- **FR-020**: Code that rests on behaviour only the game can confirm MUST carry its `VERIFY` marker until the author
  confirms it in game.

### Key Entities

- **Place of a cast**: the map, the skill range and the cell of a cast; after this spec never a continent map.
- **Area of a cast**: the game's area ID of the subzone the game showed, or none; a cell counts its casts per area.
- **Loot source**: pool, open water or unknown; after this spec always unknown.
- **Owed notice**: a next-rank notice that came due during a fight and is shown after it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A fight of an hour in an instance with skill-ups raises no error from the addon.
- **SC-002**: After fishing in the cave before Wailing Caverns, no place named after a continent appears in the
  catalog or "What can be caught here"; the catches show under The Barrens (or are not recorded, per the fallback).
- **SC-003**: Spots fished at Stonebull Lake and Ratchet show the subzone the game showed there; a spot where the
  game shows no subzone (the Thunder Bluff pond) shows coordinates.
- **SC-004**: No frame of the game stalls by more than 5 ms because of the area lookup.
- **SC-005**: No "Water" filter shows after fishing in pools and in open water.
- **SC-006**: A character whose skill is below a carried pole's requirement is never offered that pole by the
  automatic choice.
- **SC-007**: `npm run check` and `npm test` pass; every new test fails when its fix is reverted.

## Assumptions

- The facts of `docs/forever-api.md` "Verified in game" hold: the continent map in the cave, the player's position
  there, the bobber as loot source of a pool, the explored regions that miss the subzone, the secret trainer name in
  an instance fight.
- `C_Map.GetMapInfoAtPosition` on a continent gives the zone under a point, and `C_Map.GetAreaInfo` gives the
  names of the game's areas by ID; both are checked by a `/run` in game before the code is built (the plan names
  the commands), each with its fallback above.
- The game's area IDs end at 17853 (seen); walking all of them once costs about 4 ms, so a name index can be built
  once per session, spread over frames.
- A pole's skill requirement is the one recorded in `GameData/FishingPoles.lua` (the original game); the base skill
  is compared, as for lures (V44).
- The second-player steps of 1.2.0 (phase `d` of the test page) do not depend on this spec.
