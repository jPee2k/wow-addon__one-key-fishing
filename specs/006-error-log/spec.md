# Feature Specification: Error Log

**Feature Branch**: `002-shared-db` (built on the current branch as one separate commit; no branch of its own,
because `develop` no longer matches this branch's architecture)

**Created**: 2026-11-01

**Status**: Draft

**Input**: User description: "Error capture for OneKeyFishing: a compact, developer-facing error log. Today the event
dispatcher, the message bus and the slash dispatcher call handlers in a bare loop, so one failing handler stops the
rest for that event or message (a Stats error on FISH_CAUGHT keeps CatchDB from recording the catch), and the error
leaves no trace a player can send. Blizzard already hides Lua error popups unless the scriptErrors CVar is on. Scope:
one Core helper runs a function protected, records the error and hands it on to the game's error handler, so BugSack
and scriptErrors still see it; only the three dispatch points use it; the log is a new account-wide saved field of at
most 30 entries with deduplication and a version drop; the /okf debug report gets an 'Errors' section. Out of scope:
a global error handler, wrapping other entry points, network reporting, fixing the bugs themselves."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One failing module no longer stops the others (Priority: P1)

Several modules listen to the same game event or addon message. When one of them fails, the others still get the
event or message, so a bug in one feature (statistics, a window) does not silently cost the player data of another
(a catch missing from the catch database).

**Why this priority**: this is the only part a player feels, and the loss it prevents is silent: nothing shows that a
catch was not recorded.

**Independent Test**: register three listeners on one message and on one event, make the second one fail, send the
message and the event; the first and third run, and the failure still reaches the game's error handler.

**Acceptance Scenarios**:

1. **Given** three listeners of one addon message, the second failing, **When** the message is sent, **Then** the
   first and third run with the same arguments, in their usual order.
2. **Given** three handlers of one game event, the second failing, **When** the event comes, **Then** the first and
   third run.
3. **Given** a slash command whose action fails, **When** the player types it, **Then** the failure is recorded and
   handed on like any other.
4. **Given** any of the above failures, **When** it happens, **Then** the game's own error handler receives it once,
   so a player with BugSack or with `scriptErrors` on sees it as before, and a player with neither sees nothing.

---

### User Story 2 - The developer reads recent errors in the debug report (Priority: P2)

A player who meets a bug opens `/okf debug`, copies the report and sends it. The report now holds an "Errors" section
with the addon's recent errors: where each happened, the message, a short stack, how often and when it last happened.
The developer can tell what broke without asking the player to install BugSack and reproduce it.

**Why this priority**: it turns a vague "it stopped working" into a fixable report, but it needs Story 1's capture.

**Independent Test**: cause a failure, open the report; the Errors section lists it; cause it again, the same entry
shows a count of 2; on a clean log the section says "none".

**Acceptance Scenarios**:

1. **Given** an error was recorded, **When** the debug report is built, **Then** its "Errors" section lists the entry
   with its context, message, count, first and last time and the short stack.
2. **Given** several entries, **When** the report is built, **Then** they are listed newest first.
3. **Given** no entries, **When** the report is built, **Then** the section reads "none".
4. **Given** errors recorded and then a `/reload` or relog, **When** the report is built, **Then** the entries are
   still there.

---

### User Story 3 - The log stays small and current (Priority: P3)

An error that repeats on every event does not flood the log or the saved file, and errors of an older addon version
disappear after an update, so the report shows only what is still broken.

**Why this priority**: it keeps Story 2 useful over time; without it the log is noise after the first busy session.

**Independent Test**: record 40 distinct errors, then one error 100 times; the log holds 30 entries and the repeated
one has a count of 100; load the log under another addon version; it is empty.

**Acceptance Scenarios**:

1. **Given** the log holds 30 entries, **When** a new distinct error is recorded, **Then** the least recently seen entry
   is dropped.
2. **Given** an entry for an error, **When** the same error (same context and same message) happens again, **Then**
   that entry's count rises and its last time updates, and no entry is added.
3. **Given** saved entries from another addon version, **When** the addon loads, **Then** they are dropped and entries
   of the running version are kept.

### Edge Cases

- An error before the saved variables are loaded (in an early `ADDON_LOADED` handler): it is kept in memory and
  joined to the saved log once it is loaded, so it is not lost.
- An error inside the recording itself: it must never fail the dispatch; the original error still goes to the game's
  error handler.
- A listener that sends another message whose listener fails: each level records its own failure once; the outer
  listeners keep running.
- A caller that already wraps code which sends a message in its own protected call (the catch exchange's merge step):
  a listener's failure no longer reaches that caller; it is recorded and handed on instead, and the caller goes on.
  Accepted: the listener's failure is not the caller's failure.
- An error value that is not text (a table or nil passed to `error`): it is recorded as its text form.
- A message that differs only by a changing number (an item ID) counts as a different error; deduplication is on the
  exact text, which keeps it simple and predictable.
- A very long message or stack: the message is kept whole, the stack is cut to its first 10 lines.
- A failing handler on an event that comes every frame: the count rises, the log does not grow, and the game's handler
  sees each occurrence as it does today.
- A hard crash of the client: errors of that session are lost, because saved variables are written only on
  `/reload` and logout. Accepted.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The addon MUST have exactly one protected-call helper in Core that runs a function with its arguments,
  records a failure with a context label and hands the failure on to the game's current error handler; it MUST work
  on the game's Lua 5.1, whose protected call with a handler passes the arguments on, as in the tests.
- **FR-002**: The game-event dispatcher MUST run each handler through the helper with the event name as its context,
  so one handler's failure does not skip the next ones.
- **FR-003**: The message bus MUST run each listener through the helper with the message name as its context, so one
  listener's failure does not skip the next ones; arguments and order stay the same.
- **FR-004**: The slash dispatcher MUST run the chosen command through the helper with the context
  "/okf <command>".
- **FR-005**: No failure MAY be swallowed: every failure caught by the helper MUST reach the game's error handler
  exactly once.
- **FR-006**: No other entry point (frame scripts, hooks, timers) is changed by this feature.
- **FR-007**: The log MUST be kept in the account-wide saved variables as a new field filled by the existing defaults
  step, with no schema bump.
- **FR-008**: An entry MUST hold the context, the error message, the stack cut to its first 10 lines, the addon
  version, the time of the first and of the last occurrence, and a count.
- **FR-009**: A failure with the same context and message as an existing entry MUST raise that entry's count and set
  its last time instead of adding an entry.
- **FR-010**: The log MUST hold at most 30 entries; a new entry beyond that drops the least recently seen one.
- **FR-011**: On load, entries recorded under another addon version MUST be dropped.
- **FR-012**: Failures recorded before the saved variables are loaded MUST be kept in memory and joined to the log once
  it is loaded.
- **FR-013**: The `/okf debug` report MUST have an "Errors" section, built like its other sections, listing entries
  newest first with context, message, count, first and last time, version and stack, or "none" when the log is empty. It
  is in English, like the rest of the report.
- **FR-014**: The feature MUST add no slash command, no setting, no frame and no translated text; it lives in the Core
  layer only, apart from the report section and a section of the temporary spike that checks
  the error path in game.
- **FR-015**: Automated tests MUST cover the helper (arguments in, results out, failure recorded and handed on once),
  the cap, the deduplication, the version drop, the early-failure buffer, and "one fails, the others still run" for
  both the message bus and the event dispatcher.

### Key Entities

- **Error entry**: one distinct failure. Context (event name, message name or "/okf <command>"), message text, short
  stack, addon version, first time, last time, count. Identity: context plus message.
- **Error log**: the ordered list of entries in the account-wide saved variables, ordered by last occurrence (the least
  recently seen first), at most 30, all of the running addon version.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: When any one listener of a message or handler of an event fails, 100% of the other listeners or
  handlers of it still run.
- **SC-002**: Every caught failure reaches the game's error handler exactly once; error tools the player uses show the
  same errors as before the change.
- **SC-003**: After any number of failures the saved log never exceeds 30 entries, and an error repeated 1000 times
  takes one entry.
- **SC-004**: A copied debug report alone lets the developer name the event or message and the code line of each
  recorded failure, without asking the player for anything else.
- **SC-005**: No visible change for a player without errors: no new text, window, command or setting, and no
  noticeable cost on events and messages.
- **SC-006**: Every existing automated check and test still passes.

## Assumptions

- The Forever client has the game's error handler accessors and the stack function of the Mainline client; Blizzard's
  own UI in the client export (build 1.60.1.70685) calls the error handler the same way. They go into `.luacheckrc`
  if missing.
- Players who send reports use the debug report's copy window; no other view of the log is needed.
- Ten stack lines are enough to find the failing line; the first lines are the addon's own frames.
- Times are kept to the second (`time()`); ordering ties are fine.
- The player manual describes the Errors section in one or two sentences, next to the debug report; the changelog gets
  one line under `[Unreleased]` for "one failing part no longer stops the others".
- `CLAUDE.md` and `docs/architecture/core.md` list the new saved field and the helper; no new message is added.
- Built on `002-shared-db`, the log ships with release 1.2.0, not with 1.1.0 (the first release after launch); the
  author chose this to avoid conflicts with `develop`.
- An unpackaged build has the version `dev`, so during development entries of changed code are not dropped on
  load; acceptable for a developer, who can clear the saved field by hand.
