# Feature Specification: Architecture Alignment

**Feature Branch**: `002-shared-db` (spec 008 is built on the 1.2.0 branch itself, no branch of its own)

**Created**: 2026-11-06

**Status**: Draft

**Input**: User description (translated from Ukrainian): "We released 1.1.0; next is the work on `002-shared-db`,
release 1.2.0. The rebase is done, but the `002-shared-db` code went through many architectural changes, so: align
the whole addon with the new architecture, align the documentation, make sure no leftovers or dead code remain.
Work in the current branch. We also have information from the game as GameData, tables that describe game
entities; put these tables where the architecture says, as a data model, not scattered through the code. If there
are questions, ask them as a quiz."

## Context

`002-shared-db` was rebased onto `develop` after release 1.1.0 (2026-11-05). The branch had moved the addon to a
layered architecture (a core plus feature modules over a message bus, one folder per area, layers 0 to 3,
`docs/architecture/core.md` "Layers"), while 1.1.0 added `GameData/FishingRanks.lua` and `Core/MapPin.lua`. An
audit of the rebased code (2026-11-06) found:

- **Game data outside `GameData/`**: the lures and fished containers (`Fishing/Bags.lua`), the pole bonuses, slot
  tables and the pole's item class (`Fishing/Gear.lua`), the Fishing spell IDs and the bobber ID (`Core/Data.lua`),
  the fallback rank names keyed by spell ID (`Fishing/Skill.lua`), the skill range step (`CatchDB/CatchDB.lua`), an
  icon file ID (`UI/CatchHere.lua`). `GameData/` itself is missing from the layer tables in `CLAUDE.md` and
  `core.md`, has no architecture document and no test folder.
- **Duplicated logic**: the catalog's map pin (`Catalog.PinTarget`, `CatalogTab.Pin`) repeats `Core/MapPin.lua`
  and toasts directly instead of through `MAP_PIN_SET`; the range label, the "little data" threshold (50), the own
  record lookup, the scan button update, the catalog's default filter and the reported CVar names exist twice.
- **Dead code**: `ns.FISHING_SKILL_LINE` (read by nothing), the `ns.Minimap` export (read by nothing); functions
  that only the tests call (`CatchDB.OwnProofReady`, `Comm.GetPaths`, the `CatchDB.STEP_SECONDS` export).
- **Documentation drift**: about twenty statements in `CLAUDE.md`, the root `README.md`, `docs/` and the
  constitution that no longer match the code (layer tables, saved fields, who writes which setting, file paths,
  the MapPin claims, the test naming rule that ten tests break, tests outside their area's folder).
- **VERIFY bookkeeping**: the markers `R11`, `R12`, `R14` of spec 001 are explained only in its `research.md`;
  `CLAUDE.md` says only features 002 to 006 have a `verification.md`.

The work also settles the 1.2.0 technical debt listed in `docs/release-plan.md` (move the older game data into
`GameData/`; switch the catalog's pin to `ns.MapPin`) and the tech-debt item "A lure above the Fishing skill is
offered until it fails" (`docs/tech-debt.md`).

### Decisions (quiz with the author, 2026-11-06)

- Q: Name and branch? → A: `specs/008-architecture-alignment`, built in the current branch `002-shared-db`.
- Q: Shape of the game data model? → A: one namespace `ns.GameData.<Entity>`, one file per entity, records keyed by
  ID with named fields (not bare lists), data only; `FishingRanks` and `NpcNames` move into it too.
- Q: What is game data? → A: game facts by ID (spells, items, objects, NPCs, areas, maps, skill line, icon IDs) and
  the mappings of client enums (equip location to slots, the pole's item class and subclass, weapon slots).
  Addon tuning (timeouts, grid, limits) stays in its modules.
- Q: The lure's required skill? → A: in scope, in full: the required skill per lure in the data (marked VERIFY), a
  lure above the character's skill is never offered, with tests; its own user story and a changelog line.
- Q: Visible changes? → A: small visible changes that the alignment brings naturally are allowed; each one that
  touches released behaviour gets a changelog line.
- Q: Older specs 002 to 006? → A: their spec, plan, research and tasks are history and stay; only the living files
  (`verification.md`, `quickstart.md`) are updated. The living docs are aligned in full.
- Q: How deep? → A: conformance to the rules plus splitting and renaming. A file over 600 lines is split along its
  logical seams only when it mixes roles; a file that is one coherent whole stays. Shared helpers go into their own
  file where needed.
- Q: Test names? → A: rename the ten tests that break the naming rule of `docs/development.md`; move the tests
  that sit outside their area's folder.
- Q: Functions only the tests call? → A: move them into the module's private table (as `CatchDB.private`), apart
  from the public interface.
- Q: The catalog's pin? → A: the parent-map fallback for micro maps moves into `MapPin.Target` (one rule for every
  pin); the catalog's own pin code and its duplicate test go.
- Q: Small duplicates? → A: merge all of them.
- Q: `GameData/` as an area? → A: a full area: layer 0 in every layer table, its own architecture document, its own
  test folder, and `npm run check` rejects logic and `ns.L` in it.
- Q: VERIFY ids of spec 001? → A: a `verification.md` for spec 001 (R11, R12, R14); the new markers of this spec go
  into its own `verification.md`. Everything already confirmed in game is recorded where agents look first, so
  nobody asks again.
- Q: In-game check? → A: no new checklist; the steps go into the existing checklists (`fishing-mode.md`,
  `catch-catalog.md`), and the already ticked steps that these changes affect are unticked to be run again. No
  duplicate steps.
- Q: `Core/Spike.lua`? → A: out of scope; the next spec confirms and checks the spike.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Game data lives in one model (Priority: P1)

A developer (the author or an agent) needs a game fact: which items are lures and how strong they are, which clams
are fished containers, which pole gives which bonus, the Fishing spell of each rank, the bobber's object ID, the
NPC that sells the Expert book. They open `GameData/` and find each entity in its own file under one name, with
named fields and its source, and nowhere else in the code.

**Why this priority**: game facts scattered through logic files get copied, drift apart and are hard to check
against the game. One model is the base the other stories build on (the lure's required skill, the rank names).

**Independent Test**: search the addon for by-ID game tables outside `GameData/`; run `npm run check` and the tests
of `tests/gamedata/`.

**Acceptance Scenarios**:

1. **Given** the aligned addon, **When** a developer looks for the lure list, the fished containers, the pole
   bonuses, the Fishing spell IDs, the bobber ID, the rank steps, the NPC names, the slot and item class mappings or
   the skill range step, **Then** each is found in exactly one file under `GameData/`, reached as
   `ns.GameData.<Entity>`, and no logic file holds its own copy.
2. **Given** a file in `GameData/`, **When** `npm run check` runs, **Then** it fails if the file holds a function, a
   lookup of `ns.L` or anything other than data.
3. **Given** the game data model, **When** its tests run, **Then** every record has the fields its entity's
   document lists, with values of the right kind (IDs are positive whole numbers, bonuses and skills are numbers).
4. **Given** the modules that read game data, **When** the addon runs with the model in place, **Then** they behave
   as before the move (the tests of fishing mode, bags, gear, skill, catch and catalog pass unchanged in meaning).

---

### User Story 2 - A lure above the Fishing skill is never offered (Priority: P1)

A player with Fishing 50 has Bright Baubles (needs 100) and Shiny Bauble (needs 0) in the bags. In fishing mode
the indicator and the action key offer only Shiny Bauble; Bright Baubles is offered as soon as the skill reaches
its requirement. A lure the table does not know is not offered, as today; a known lure whose recorded requirement
turns out too low is still tried and skipped after it fails.

**Why this priority**: today a lure above the skill is offered, the game refuses it, and the player loses up to 5
seconds per attempt. It was seen in game on 2026-11-06 and is the author's wish for 1.2.0.

**Independent Test**: in the tests, a character with a given skill and a set of lures in the bags; check which lure
is offered. In game: the step "Lure too high" of `docs/checklists/fishing-mode.md`.

**Acceptance Scenarios**:

1. **Given** Fishing skill 50 and a known lure that needs 100 in the bags, **When** the addon picks the next lure,
   **Then** that lure is not offered, and a usable lower lure is offered if there is one.
2. **Given** Fishing skill exactly equal to a lure's requirement, **When** the addon picks the next lure, **Then**
   that lure is offered.
3. **Given** the skill rises past a lure's requirement during the session, **When** the addon picks the next lure
   again, **Then** that lure is offered without leaving fishing mode.
4. **Given** a known lure whose recorded requirement is lower than the game's, **When** it is offered and the game
   refuses it, **Then** it is skipped after the failure, as today (the failure path stays). A lure the table does
   not list is not offered at all, as today.
5. **Given** the Fishing skill cannot be read, **When** the addon picks the next lure, **Then** the requirement is
   not applied (no lure is held back on an unknown skill).

---

### User Story 3 - One map pin for every place (Priority: P2)

A player pins a fishing spot from the catalog tab and, on another day, the next rank's trainer from the rank
notice. Both pins behave the same: the same question before replacing a pin the player set themselves (no question
when the pin is already at that place), the same toast, the same map opening, the same fallback to the parent map
for a place on a small map the pin cannot use.

**Why this priority**: two implementations of one action already differ (the catalog asks even when the pin is
already there; it skips the checks the shared code has) and each fix would have to be made twice. The catalog is
not released yet, so the change costs players nothing.

**Independent Test**: the map pin tests with targets from the catalog and from the rank advice; in game, the pin
steps of `docs/checklists/catch-catalog.md`.

**Acceptance Scenarios**:

1. **Given** a catalog spot on a micro map, **When** the player pins it, **Then** the pin is set on the parent map
   at the same rule the rank advice uses.
2. **Given** the addon's own pin already at the chosen spot, **When** the player pins it again, **Then** no
   replace question appears.
3. **Given** a pin the player set, **When** the player pins a catalog spot, **Then** the replace question appears
   in the addon's language, as for the rank advice.
4. **Given** a pin is set or refused, **When** it happens from the catalog, **Then** the toast is the one shown for
   every pin, through the shared message.

---

### User Story 4 - No dead code, no duplicates, files with one role (Priority: P2)

A developer reads any module and finds only code the addon uses, each piece of logic once, each file with one role.
What exists only for the tests sits in the module's private table, apart from the public interface.

**Why this priority**: the rebase left two copies of several functions and code nothing calls; every copy is a
place where a fix can be missed, and every unused function costs review time before 1.2.0.

**Independent Test**: the dead code audit (definitions with no caller in the addon) finds nothing outside the
private tables and the temporary spike; the duplicate list of the audit is empty; `npm run check` and `npm test`
pass.

**Acceptance Scenarios**:

1. **Given** the aligned addon, **When** every public definition of a module is checked for callers in the addon,
   **Then** each has at least one, except the temporary spike's own code.
2. **Given** a function or value only the tests use, **When** a developer looks for it, **Then** it is in the
   module's private table, and the tests reach it there.
3. **Given** the seven duplicates of FR-016, **When** the code is searched, **Then** each exists once and the other
   places use it.
4. **Given** a file over 600 lines that mixes roles, **When** the alignment is done, **Then** it is split along its
   seams into files of the same module (as `CatchDB/` is), the TOC lists them in a working order, and a file that is
   one coherent whole stays as it is.
5. **Given** helpers that more than one file of an area needs after a split, **When** they are placed, **Then** they
   go into one shared file of that area, not into copies.

---

### User Story 5 - The documents tell the truth (Priority: P2)

A developer or agent starting a session reads `CLAUDE.md`, the root `README.md`, `docs/` and the constitution, and
every file, module, function, message, saved field, layer, folder and rule they name matches the code. A fact
already confirmed in game is recorded where an agent looks first, so nobody guesses it or asks the author again.

**Why this priority**: agents work from these documents; a wrong statement becomes wrong code. The audit found
about twenty.

**Independent Test**: each drift item of the audit is checked against the documents; `npm run check` passes; a
search for the old paths (`UI/MapPin.lua`, `OneKeyFishing/SeedData.lua`) in the living documents finds nothing.

**Acceptance Scenarios**:

1. **Given** the layer tables of `CLAUDE.md` and `core.md`, **When** a developer reads them, **Then** `GameData/` is
   in layer 0, `Core/MapPin.lua` is listed, and they match `tools/addon.mjs`.
2. **Given** the saved field tables of `core.md`, **When** compared with the defaults and the writers in the code,
   **Then** every field is listed with every module that writes it.
3. **Given** every `VERIFY` marker in the addon, **When** a developer looks up its id, **Then** it is explained in a
   `verification.md` (spec 001 gets one for R11, R12, R14; this spec has its own), and `CLAUDE.md` says which
   features have one.
4. **Given** a fact the in-game runs of 1.1.0 already confirmed, **When** the alignment is done, **Then** it is
   recorded in `docs/forever-api.md` "Verified in game" or ticked in its `verification.md`, and its marker is gone.
5. **Given** the older specs 002 to 006, **When** the alignment is done, **Then** only their `verification.md` and
   `quickstart.md` are changed (paths, test names), and their spec, plan, research and tasks stay as written.
6. **Given** the test folder rules of `docs/development.md`, **When** compared with `tests/`, **Then** every test
   sits in the folder of the area it tests and follows the naming rule.

---

### User Story 6 - The in-game checklists cover the changes (Priority: P3)

Before 1.2.0 the author runs the existing checklists. The steps that this alignment can affect are unticked and
run again; the new behaviour (a lure above the skill) has a step; nothing is duplicated.

**Why this priority**: Claude cannot run the game; moved data and merged code are checked by the tests, but only
the game confirms the lure requirements and the pin from the catalog.

**Independent Test**: read `docs/checklists/fishing-mode.md` and `catch-catalog.md`: each affected step is
unticked, the lure step expects the new behaviour, and no step appears twice.

**Acceptance Scenarios**:

1. **Given** `fishing-mode.md`, **When** the alignment is done, **Then** its steps on lures, fished containers, the
   pole swap and its bonus, the rank names and the next-rank notice and pin are unticked, and "Lure too high"
   expects that the lure is never offered.
2. **Given** `interface-language.md` (released 1.1.0 behaviour), **When** the alignment is done, **Then** only its
   steps whose code changed (the rank data and names, the next-rank notices, the pin) are unticked; the language
   steps stay ticked.
3. **Given** `catch-catalog.md`, **When** the alignment is done, **Then** its pin steps expect the shared pin's
   behaviour (no question when the pin is already there, the parent map for a micro map).
4. **Given** the three checklists, **When** compared, **Then** no step is repeated in another checklist.

### Edge Cases

- A known lure whose recorded requirement is wrong: too low, it is tried and skipped on failure as today; too high,
  it is held back until the skill reaches the recorded value. Either way the value is corrected when the game shows
  it (V43). A lure not in the table is not offered, as today.
- The Fishing skill is not read yet at login (the professions come late): no lure is held back until it is.
- A lure ID that Forever does not have: it stays in the table; it is never in the bags, so it costs nothing.
- An item the client does not know until it is found (`specs/004` FR-017a): it is hidden, never refused, as before.
- A module read at file load time from `GameData/`: `GameData/` files load before every module that reads them (in the TOC
  right after the locales, before `Core/Core.lua`; plan research R3), so the tables exist when the modules load.
- A split file: no function may move to a later file than its first caller at load time; the TOC order keeps the
  rule "a module may only call another at runtime unless it comes earlier".
- A test renamed or moved: `npm test` finds it in its new place; no test is lost (the count of test files before
  and after matches, minus the merged duplicate pin test).
- Saved data: no saved field changes its name or shape; if one would, `DB_SCHEMA` is bumped with a migration.

## Requirements *(mandatory)*

### Functional Requirements

**Game data model**

- **FR-001**: Every game fact by ID and every mapping of a client enum that the addon uses MUST live in
  `GameData/`, one file per entity, reached as `ns.GameData.<Entity>`. At least: lures, fished containers, fishing
  poles (bonus), Fishing spell ranks, the bobber object, the rank steps (`FishingRanks`), the NPC names, the equip
  location to slot mapping, weapon slots, the pole's item class and subclass, the unknown item icon. The catch
  database's skill range step (75) and number of ranges (4) stay literals in the catch database, because they are
  part of the saved format; a test holds them equal to the Fishing spell ranks (changed by the spec 008 review).
- **FR-002**: Records MUST be keyed by ID with named fields where an entity has more than one fact (for example a
  lure: bonus, order, required skill); the source of the values is named in the file.
- **FR-003**: `GameData/` files MUST hold data only: no function, no `ns.L`, no reading of other modules;
  `npm run check` MUST reject a break. Non-ASCII stays allowed only inside string literals, as today.
- **FR-004**: Addon tuning values (timeouts, limits, grid sizes, delays) MUST stay in their modules.
- **FR-005**: `GameData/` MUST be layer 0 in `CLAUDE.md`, `docs/architecture/core.md` and `tools/addon.mjs`, MUST
  have its own document `docs/architecture/game-data.md` (each entity, its fields, its source, its readers) and its
  own test folder `tests/gamedata/` with shape tests of every entity.
- **FR-006**: The behaviour of every module that reads moved data MUST stay the same, except where FR-007 to FR-010
  change it.

**The lure's required skill**

- **FR-007**: Each known lure MUST carry the Fishing skill it needs, taken from the original game and marked
  `VERIFY` until each value is seen in game; the ids are explained in this spec's `verification.md`.
- **FR-008**: The addon MUST NOT offer a known lure (indicator, action key, debug report's next lure) while the
  character's Fishing skill is below its requirement, and MUST offer it once the skill reaches it, within the same
  session.
- **FR-009**: While the skill is unknown, every known lure MUST be handled as today (no requirement applied). The
  failure path (skip after the game refuses) MUST stay for a known lure whose recorded requirement is lower than the
  game's. A lure not in the table stays unoffered, as today.
- **FR-010**: The change MUST have a line in `CHANGELOG.md` `[Unreleased]` and, if the manual describes lure
  choice, a matching sentence in `OneKeyFishing/README.md`; the tech-debt item MUST be removed once tested.

**One map pin**

- **FR-011**: The catalog MUST set its pins through `ns.MapPin`; the catalog's own pin code, its own position
  check, its own popup key and its duplicate test MUST be removed; the result toast MUST come through `MAP_PIN_SET`.
- **FR-012**: The parent-map fallback for maps the pin cannot use MUST be part of `MapPin.Target`, applying to every
  pin.
- **FR-013**: The VERIFY marker of the removed catalog pin path (V32) MUST be closed in its `verification.md` as
  replaced by the shared pin's marker (R14), so one id covers the one remaining assumption.

**Dead code, duplicates, file roles**

- **FR-014**: Code no part of the addon uses MUST be removed (at least `ns.FISHING_SKILL_LINE` and the `ns.Minimap`
  export), with its mentions in the documents; the temporary spike and what only it uses are out of scope (the next
  spec handles the spike).
- **FR-015**: Functions and values used only by the tests MUST move into their module's private table, and the tests
  MUST reach them there. The one exception is diagnostic state that belongs in the debug report: `ns.earlyLookups`,
  the keys looked up before the language was set, gets the report as its reader instead (plan research R7).
- **FR-016**: Each duplicate of the audit MUST exist once: the range label, the little data threshold, the own
  record lookup, the scan button update, the catalog's default filter, the reported CVar names, the rank spell IDs
  of the fallback rank names.
- **FR-017**: A file over 600 lines (counted with comments; plan research R9 found two: `Exchange/Comm.lua` and
  `CatchDB/Views.lua`) that mixes roles MUST be split along its logical seams into files of the same
  module; a coherent file MUST stay whole; shared helpers of an area MUST go into one file of that area. The rule
  MUST be written in `docs/development.md`.
- **FR-018**: No split, move or merge may break the layer rule or the load order rule; `npm run check` MUST pass.
- **FR-019**: No saved field may change name or shape without a `DB_SCHEMA` bump and a migration.

**Tests**

- **FR-020**: The test files that break the naming rule of `docs/development.md` MUST be renamed to follow it: the
  ten the audit found and the three the analysis added (plan research R10);
  tests outside their area's folder (the catalog pin test, the share notice tests, the statistics window test in
  `catch/`) MUST move to the folder of the area they test, or merge where they duplicate another test. The spike's
  test stays where it is: it goes with the spike in spec 009 (plan research R10).
- **FR-021**: Every change of logic that can run without the game MUST have a test that fails without the change
  (the lure requirement, the pin fallback, each merged duplicate where its callers differed).

**Documents**

- **FR-022**: Every drift item of the audit MUST be fixed in the living documents (`CLAUDE.md`, the root
  `README.md`, `docs/`, `.specify/memory/constitution.md`), and `CLAUDE.md` MUST stay consistent with the
  constitution.
- **FR-023**: In specs 002 to 006 only `verification.md` and `quickstart.md` MAY change; spec, plan, research and
  tasks MUST stay as written.
- **FR-024**: Spec 001 MUST get a `verification.md` explaining R11, R12 and R14 with their state; `CLAUDE.md` MUST
  name every feature that has one. The header sentence of `GameData/FishingRanks.lua` MUST no longer count as a
  marker.
- **FR-025**: Every fact the in-game runs of 1.1.0 already confirmed (the Results of
  `docs/checklists/interface-language.md` and `fishing-mode.md`) MUST be recorded in `docs/forever-api.md`
  "Verified in game" or ticked in its `verification.md`, and its `VERIFY` marker removed.
- **FR-026**: `docs/release-plan.md` MUST drop the settled 1.2.0 debt items, and `docs/tech-debt.md` the items this
  spec fixes with a test.

**In-game checklists**

- **FR-027**: No new checklist. The steps for this spec MUST go into `docs/checklists/fishing-mode.md` and
  `docs/checklists/catch-catalog.md`. The already ticked steps the changes affect MUST be unticked there and in
  `docs/checklists/interface-language.md`. No step may be duplicated across checklists.

### Key Entities

- **Lure**: an item that raises the Fishing skill for a while: item ID, bonus, order (best first), required Fishing
  skill.
- **Fished container**: an item caught while fishing that is opened for its loot: item ID.
- **Fishing pole**: an item that can be equipped to fish: item ID, Fishing bonus (the fallback when the tooltip
  cannot be read); the pole's item class and subclass identify any pole.
- **Fishing rank**: a spell per rank (Apprentice, Journeyman, Expert, Artisan) with its cap; the next rank's step:
  the skill and level it can be learned at, where (trainer, book, quest) with item, quest, NPC, area and map IDs and
  the point.
- **NPC name**: the name of an NPC per client language, a fallback when the client does not give it.
- **Bobber**: the game object ID of the fishing bobber.
- **Equipment slots**: the mapping of equip locations to inventory slots, the weapon slots.
- **Skill range**: the step of skill points the catch database groups catches by, and the highest range.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A search of the addon for by-ID game tables outside `GameData/` finds none: 0 of the places in the
  "Replaces" column of the plan's data model remain.
- **SC-002**: A player with a known lure above their skill is offered it 0 times; they lose no seconds on refused
  attempts for known lures.
- **SC-003**: The map pin is implemented once: 1 implementation instead of 2, 1 VERIFY id for its one open
  assumption instead of 2.
- **SC-004**: The dead code audit finds 0 public definitions without a caller in the addon (outside the private
  tables and the spike), and the duplicate list is empty (0 of 7, plus the pin).
- **SC-005**: Every drift item of the audit (about 20) is fixed; a search of the living documents for paths that do
  not exist finds 0.
- **SC-006**: Every `VERIFY` id in the addon is explained in a `verification.md` (100%), and no marker remains for a
  fact the 1.1.0 runs confirmed.
- **SC-007**: `npm run check` and `npm test` pass; the number of test cases does not drop except by the merged
  duplicate pin test.
- **SC-008**: No file of the addon over 600 lines mixes roles after the work.
- **SC-009**: A player who updates sees no change except the lure choice and the small changes listed in the
  changelog; saved settings, statistics and the catch database carry over untouched.

## Assumptions

- The audit of 2026-11-06 is the starting inventory; the plan rechecks it, and anything new it finds is handled by
  the same rules.
- The required skill of each lure is taken from the original game (Wowhead Classic); Forever is assumed to keep it
  until the game shows otherwise.
- The catalog and the catch database are not released (1.2.0), so changes to their behaviour need no changelog line;
  changes to released behaviour (fishing mode, lures, the rank advice) do.
- `Core/Spike.lua` stays as it is; the next spec confirms the spike in game and removes it (release-plan step 4),
  including what only it uses (`ns.ReportSection`).
- The work is committed in the current branch `002-shared-db` only when the author asks.
- The game cannot be run by Claude; every in-game check is handed to the author through the existing checklists.
