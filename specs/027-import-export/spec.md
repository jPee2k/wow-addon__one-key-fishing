# Feature Specification: Import and Export of Catch Records

**Feature Branch**: `027-import-export`

**Created**: 2026-11-25

**Status**: Draft

**Input**: User description (translated): "The roadmap has an item about faster data exchange between the author and
the players; time to talk about it." The research and the decisions of the author's interview of 2026-11-25 are in
[docs/import-export-research.md](../../docs/import-export-research.md) (section 4, decisions I1-I10).

## Clarifications

### Decisions of the author, 2026-11-25

- **Import and export** of catch records, between any players and both ways, by copy and paste outside the game (a
  message, a forum, a chat app). The records then travel without both players being online at once, across the
  factions and the game modes.
- **Protection**:
  - every imported record passes the checks a record received through the exchange passes;
  - a checksum of the whole string catches damage;
  - there is no secret key: it would have to ship in the addon's open code.
- **Content**: the player's own record first, then the freshest records of others, up to about 256 KB of text. With
  sharing off, only what counts for the player: their own record and the imported ones.
- **The page**:
  - a settings page of its own, "Import and export", with a selector (Import, Export; Import by default);
  - Export fills the text area at once, selected and focused, with a hint below;
  - Import shows an empty, focused area, a hint below and an **Import** button;
  - the addon cannot use the clipboard: the player presses the copy and paste keys;
  - `/okf share import` and `/okf share export` open the page on that choice.
- **The result**: after an import the hint shows how many records were new, already held, the player's own and
  refused. The own record and versions already held are not imported again.
- **Imported records**:
  - they are ordinary received records: the same checks, passed on through the exchange, shown in the catch lists;
  - import works whatever the sharing switch says, and imported records count at once, also with sharing off;
  - a player's record once imported keeps that standing, so its newer versions from the exchange count with sharing
    off too.
- **Not built**: a harvest that reads pasted strings outside the game. A Battle.net bridge feature is not built
  either; the player manual gets only a paragraph on Battle.net friends of the other faction.

### Session 2026-11-25

- Q: What of this work goes into the public repository? → A: Only the import and export, and neutral extension points
  for code loaded after the addon (local development builds). Nothing else of that work is part of this repository.
- Q: How does code outside the repository get into a build? → A: Through its own tools, around the public
  development build. The public repository adds no flag, variable or script for it. A release takes only files tracked
  in git and listed in the public TOC, as today.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A player exports their catch data and another imports it (Priority: P1)

A player opens **Options → AddOns → OneKeyFishing → Import and export** (or types `/okf share export`), chooses
Export and copies the selected text with the copy key. They paste it into a message to a friend or a forum post. The
friend opens the same page on Import (the default), pastes the text with the paste key and presses **Import**. The
hint below says, for example: "12 new records, 3 already known, 1 refused". The new records show in the catch lists
at once.

**Why this priority**: the data then travels without both players being online at once, across the factions and the
game modes. A player of the other faction, or one who rarely meets other addon users, gets the network's data in a
minute.

**Independent Test**: in the tests, an export of one store, imported into an empty store, gives the same records with
the same checks passed. A damaged, cut or altered string is refused as a whole, or record by record as the checks say.

**Acceptance Scenarios**:

1. **Given** the page is opened, **When** nothing is chosen, **Then** Import is selected, the text area is empty and
   focused, the hint explains pasting and the **Import** button is shown.
2. **Given** the player chooses Export, **When** the page shows it, **Then** the text area holds the export string,
   selected and focused, and the hint explains copying and says how many records the string holds.
3. **Given** a valid string from another player, **When** it is pasted and **Import** is pressed, **Then** the
   records new to the player are stored, the hint shows the counts (new, already known, own, refused) and the catch
   lists show the new data.
4. **Given** the player imports their own export, or a string already imported, **When** **Import** is pressed,
   **Then** nothing is stored and the hint says that the records are already known or their own.
5. **Given** sharing is off, **When** the player imports a valid string, **Then** the records are stored and counted in
   the catch lists at once, while records received earlier through the exchange still do not count.
6. **Given** a damaged or cut string, **When** **Import** is pressed, **Then** nothing is stored and the hint says the
   text is damaged or incomplete.
7. **Given** sharing is off, **When** the player exports, **Then** the string holds only their own record and the
   records they imported.
8. **Given** the store holds more than fits, **When** the player exports, **Then** the string holds the own record and
   the freshest others' records up to the size limit.
9. **Given** `/okf share import` or `/okf share export`, **When** it is typed, **Then** the page opens on that choice.

---

### User Story 2 - Code loaded after the addon can extend it without touching its internals (Priority: P3)

A developer's local build adds files that load after the addon's own. Those files adjust the exchange's session
rules within the limits the exchange keeps, add entries to the minimap button's menu, and add a line to `/okf share`
and to the debug report. They do so through documented module functions, never by reading a module's internals.
With no such file loaded, the addon behaves exactly as it does today.

**Why this priority**: it costs players nothing and keeps a development build from patching the addon's internals,
which would break with every refactor.

**Independent Test**: in the tests, the session rules set through the module function change the simulated node's
behaviour, and the defaults give exactly today's numbers. An entry or a line added at runtime shows in the menu, the
status line and the report, and nothing shows without one.

**Acceptance Scenarios**:

1. **Given** no extension is loaded, **When** the addon runs, **Then** the session rules, the minimap menu, `/okf
   share` and the debug report are exactly as before this feature.
2. **Given** code sets the session rules (time between session starts, the chance of starting a session with a
   stranger, whether others' records are offered), **When** the exchange runs, **Then** it follows them. It never goes
   past the limits it keeps toward its peers (send budget, session size, pause per peer).
3. **Given** code adds a minimap menu entry, a status line or a report line, **When** the menu, `/okf share` or the
   report is shown, **Then** the addition shows after the addon's own items.

### Edge Cases

- **A string larger than the edit box takes**: export stays below the limit. A paste the box cut short is refused as
  incomplete by the checksum (VERIFY: the box's real limit in WoW Forever).
- **A string of a newer format**: refused with a hint to update the addon. A string of an older known format is read.
- **A string with a blocked contribution ID, impossible numbers or a broken chain**: those records are refused and
  counted as refused, the rest is imported.
- **A record whose versions the bundled database already holds whole**: counted as already known, not stored.
- **A large import**: records are checked and stored a few at a time across frames, as the exchange does, so the game
  does not freeze. While one import runs, the **Import** button is disabled.
- **Importing in a fight**: allowed. It only stores data and uses no protected action.
- **Pasted text with spaces, line breaks or text around the string**: whitespace is ignored, and so is text outside
  the string's start and end markers.
- **The store is full** (20,000 places): an import makes room by the store's usual eviction. The hint counts records
  the eviction removed again as refused.
- **An export the player did not mean to give**: the Export hint says what the string holds (an anonymous ID and catch
  counts per place, no names). Nothing leaves the game unless the player copies it.
- **An extension sets a rule beyond a limit** (for example, sessions faster than the exchange can carry): the value is
  clamped to the limit, and the debug report shows the rules in force.

## Requirements *(mandatory)*

### Functional Requirements

**Import and export**

- **FR-001**: The addon's settings MUST have an "Import and export" page with a selector (Import, Export; Import by
  default), one text area, a hint below it and, on Import, an **Import** button.
- **FR-002**: Choosing Export MUST fill the area at once with the export string, selected and focused. Choosing Import
  MUST empty the area and focus it.
- **FR-003**: `/okf share export` and `/okf share import` MUST open the page on that choice.
- **FR-004**: The export string MUST hold the own record first, then the others' records by freshness, up to the size
  limit (about 256 KB). It MUST carry a format version and a checksum of its content between clear start and end
  markers.
- **FR-005**: With sharing off, the export MUST hold only the own record and the imported records. With sharing on, it
  holds every record the player holds.
- **FR-006**: Import MUST refuse a string whose checksum fails, whose format version is unknown or newer, or that is
  cut short, and MUST store nothing from it.
- **FR-007**: Import MUST check every record of a valid string exactly as a record received through the exchange is
  checked, store those that pass, and count each as new, already known, own or refused.
- **FR-008**: The hint MUST show the result of the last import (the four counts), or why the string was refused.
- **FR-009**: Imported records MUST be stored and handled as received records: kept, passed on through the exchange,
  shown in the catch lists.
- **FR-010**: Import MUST work whatever the sharing switch says. Imported records, and later versions of the same
  player's record, MUST count in the catch lists also with sharing off.
- **FR-011**: The work of an import MUST be spread over frames so the game stays responsive, and a second import MUST
  wait until the first has ended.
- **FR-012**: Every visible text of the page, its hints and the commands' replies MUST be translated in all of the
  addon's languages.
- **FR-013**: The player manual MUST describe the page, the two commands and what an export holds, with a short
  paragraph on Battle.net friends of the other faction carrying records across the factions.

**Extension points**

- **FR-014**: The exchange MUST offer a documented module function that sets its session rules (time between session
  starts, the chance of starting a session with a stranger, whether others' records are offered) and one that puts
  back the defaults. The defaults MUST be today's values, and no rule MAY go past the limits the exchange keeps toward
  its peers.
- **FR-015**: The minimap button's menu, the `/okf share` status and the debug report MUST each accept additions
  registered at runtime, shown after the addon's own items. With none registered, they are unchanged.
- **FR-016**: A release and the release build MUST hold only files tracked in the public repository and listed in its
  TOC (as today; a tool test keeps it so).

### Key Entities

- **Export string**: a block of text with a start marker, a format version, the encoded records, a checksum and an
  end marker. It holds anonymous catch records only: contribution IDs and counts per place, no character names.
- **Imported standing**: a mark on a player's record (by contribution ID and epoch) that it came in by import. It lets
  the record and its later versions count with sharing off, and it is kept with the saved data.
- **Session rules**: the exchange's time between session starts, chance for a stranger and whether others' records
  are offered, with today's values as defaults.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A player can export and another can import in under one minute, counting from opening the page to
  seeing the new data in the catch lists.
- **SC-002**: Every damaged, cut, altered or unknown-format string is refused with nothing stored, and every forged
  record in a valid string is refused as the exchange's checks refuse it (tests).
- **SC-003**: An import of a string at the size limit ends without a visible freeze of the game: no frame spends more
  on it than the exchange's own per-frame budget.
- **SC-004**: With no extension loaded, the exchange simulation gives the same numbers as before this feature.
- **SC-005**: No release package holds a file outside the public TOC (tool test).

## Assumptions

- The game's multi-line edit box takes a pasted string of about 256 KB. If it takes less, the export limit follows
  the measured value (VERIFY).
- Import and export reuse the record encoding and checks the exchange already has. The record format does not change,
  so older clients exchange imported records as usual.
- "Freshest" means the most recent `seen` of a held record. The own record always comes first.
- The imported standing is a new saved field. Adding it reshapes nothing, so `DB_SCHEMA` only changes if the plan
  finds a reshape.
