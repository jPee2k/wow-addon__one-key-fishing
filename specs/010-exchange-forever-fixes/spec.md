# Feature Specification: Exchange Fixes for Forever

**Feature Branch**: `002-shared-db` (spec 010 is built on the 1.2.0 branch itself, no branch of its own)

**Created**: 2026-11-07

**Status**: Draft

**Input**: User description (translated from Ukrainian): "Spec 010 on branch 002-shared-db (no new branch), part
of release 1.2.0. Fix batch 1 of docs/tech-debt.md: Forever names 'First Last' (V11: ns.WithRealm,
ns.SameCharacter, Channel IsMe, the own name from GetUnitName(unit, true)); turn the public channel off (V19:
Channel.AVAILABLE = false, close V20-V25 as not shipped, count NOT_ALLOWED_IN_CHANNEL as a refusal); the proof step
budget (V26: 0.3 ms per step); an offline whisper returns 0 (V12). Plus batch 5 '1 catches'. Facts:
docs/forever-api.md, specs/003 and 004 verification.md. After the spec, update the 1.2.0 checklist artifact (the
phase 'after batches 1-2'). Check the spike: much is already confirmed in the artifacts, in the code and in the
checklists; remove what is no longer needed, and remove the test error."

## Context

The solo spike and the `/run` tests of 2026-11-06/07 showed four ways the catch exchange of 1.2.0 does not fit
WoW Forever (`docs/tech-debt.md`, batch 1; `docs/forever-api.md` "Verified in game"):

- **Names.** Forever character names are "First Last" with a space, and the realm name the game reports is an
  internal one. The addon adds that realm to friends' names ("First Last-Realm"), an address that does not exist:
  whispers to character friends never arrive, may print "No player named ...", and one friend can count as two
  peers. The addon also takes its own name from a call that returns only the first name, so it fails to recognise
  itself (V11, `specs/003-guild-group-sync/verification.md`).
- **The public channel.** The server refuses every addon message in a custom chat channel
  (`NOT_ALLOWED_IN_CHANNEL`), although the send reports success. The hidden channel takes a chat slot and reaches
  nobody (V19; V20-V25 depend on it, `specs/004-public-channel-sync/verification.md`).
- **Proof steps.** One proof step costs about 0.3 ms in the game, six times the assumed cost, so checking a
  received record takes about 10 ms per frame step (V26).
- **Offline whispers.** A whisper to a player who is not online reports success, not "target offline"; only a
  system line ("No player named ...") tells it, and the addon hides that line (V12).

Batch 5's "1 catches" (a count of one shown with a plural word) goes in with them, because it touches the same
exchange texts ("60 catches from 3 players").

The temporary spike (`/okf spike`) has done most of its work: every solo step of `docs/checklists/spike.md` is
answered. Its deliberate test error was confirmed (V42) and now fills every debug report's error list. What is still
open with a second player (guild, Battle.net) stays; the rest goes.

The exchange through guild, group and friends stays; with the channel off it is the only way between players. This
spec is built on `002-shared-db` and ships in 1.2.0; tech-debt batch 2 (where a catch is recorded) is the next spec
(011).

**Order of work** (the author): implement and fix first, then the in-game check. A step already confirmed in game is
cited, not repeated.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Friends are reached under their real names (Priority: P1)

A player has character friends who use the addon. The addon greets them under the names the game uses ("First
Last"), the greeting arrives, and each friend counts as one player, whether the message came from the friend or
went to the friend.

**Why this priority**: today every greeting to a character friend goes to an address that does not exist; the
friends path of the exchange does not work at all, and a failed whisper can print "No player named ..." in chat.

**Independent Test**: with a character friend who uses the addon (a second player), log in both; `/okf share` shows
the friend once, with no "No player named" line; the automated tests show the address of a friend equals the
address its own messages come from.

**Acceptance Scenarios**:

1. **Given** a character friend "First Last" on the same realm, **When** the addon greets friends, **Then** the
   greeting goes to "First Last", with no realm added.
2. **Given** that friend's own message arrives from "First Last", **When** the addon counts players, **Then** the
   friend is one player, not two.
3. **Given** the player's own name is "First Last", **When** a channel or exchange notice names the player,
   **Then** the addon recognises it as the player's own.
4. **Given** a sender from another realm whose name the game gives with a realm, **When** the addon stores and
   compares it, **Then** it keeps that form as the game gave it and still matches the same sender later.

---

### User Story 2 - No public channel that reaches nobody (Priority: P1)

A player installs 1.2.0. The addon does not join the hidden public channel, takes no chat slot for it, and its
status and settings do not offer it. The exchange with guild, group and friends works as before.

**Why this priority**: the server refuses addon messages in the channel, so it takes a chat slot (of 20) and gives
nothing; its status would even claim it is in use.

**Independent Test**: a fresh login with sharing on: no channel join, `/okf share` and the settings page show no
public-channel line or option, the one-time notice does not mention the channel; the debug report shows no join.

**Acceptance Scenarios**:

1. **Given** sharing on, **When** the player logs in, **Then** the addon joins no chat channel and the chat channel
   list is as without the addon.
2. **Given** a player who had the channel setting on in an earlier build, **When** they log in with 1.2.0, **Then**
   the addon does not join it, and if the addon's channel is still joined from that build, it leaves it once.
3. **Given** the settings page and `/okf share`, **When** the player opens them, **Then** no public-channel option or
   status line shows, and the texts about sharing name only guild, group and friends.
4. **Given** the channel switched on and an addon message to it that the server refuses with "not permitted in
   this channel", **When** that notice comes back, **Then** the send counts as refused, not as sent, and the
   channel is left out like any other refused path.

---

### User Story 3 - Checking a received record does not stutter (Priority: P2)

Two players exchange catch records. While the addon checks a received record's chain, the game keeps a smooth
frame rate.

**Why this priority**: at about 0.3 ms a step, today's 32 steps per frame step cost about 10 ms, a visible hitch on
each frame step of a long chain; nothing breaks, so it follows the P1 fixes.

**Independent Test**: the automated test shows the steps per frame step are bounded by a time budget; in game, the
debug report's longest merge step stays under 5 ms during an exchange.

**Acceptance Scenarios**:

1. **Given** a received record with a long chain, **When** the addon checks it, **Then** no frame step of the check
   spends more than about 5 ms.
2. **Given** a chain of the longest allowed length (4096 links), **When** the addon checks it, **Then** the check
   still finishes within the exchange's session time.

---

### User Story 4 - A friend who logged out ends the session at once (Priority: P3)

A player is exchanging with a friend who logs out. The addon notices it from the game's "No player named ..." line
(which it hides) and ends that session, instead of waiting for the session to time out.

**Why this priority**: the session times out anyway; this only saves the wait and the queued traffic.

**Independent Test**: the automated test: the hidden "No player named" line for an address ends the session to that
address; in game it needs a second player (`d-offline` of the 1.2.0 test page).

**Acceptance Scenarios**:

1. **Given** an open session to a friend, **When** a whisper to that friend brings the game's "No player named ..."
   line, **Then** the line stays hidden and the session to that address ends.
2. **Given** that line for an address with no session, **When** it comes, **Then** it stays hidden and nothing else
   changes.

---

### User Story 5 - One catch reads "1 catch" (Priority: P3)

A map with a single catch shows "1 catch", not "1 catches".

**Why this priority**: wording only.

**Independent Test**: "What can be caught here" on a place with one catch; the statistics window's session line with
one catch.

**Acceptance Scenarios**:

1. **Given** one catch, **When** a count of catches shows (the catch tab, the catalog, the session line), **Then**
   it reads "1 catch"; with more, the plural as today.
2. **Given** one player behind the numbers, **When** a count of catches shows, **Then** no "from N players" part
   appears: it shows only from two players, so "1 players" never reads.
3. **Given** a language whose translation already uses a neutral form ("catches: 1"), **When** the count is one,
   **Then** the text stays correct in that language.

---

### User Story 6 - The spike keeps only what is still open (Priority: P3)

The author runs `/okf debug` after this change. Its error list no longer fills with the spike's deliberate test
error, and `/okf spike` reports only the checks that still need the game (the second-player network steps and the
facts the next spec needs).

**Why this priority**: housekeeping before the release removes the spike entirely; it makes bug reports readable
now.

**Independent Test**: `/okf spike` shows no error section and raises no error; the sections whose steps are all
answered are gone; `/okf debug` shows no new spike error.

**Acceptance Scenarios**:

1. **Given** `/okf spike`, **When** it runs, **Then** it raises no deliberate error and no "Errors" entry appears.
2. **Given** the steps of `docs/checklists/spike.md`, **When** a section's steps are all answered or no longer
   shipped (the public channel), **Then** that section is gone from the spike; a section still needed for an open
   step stays.

### Edge Cases

- **A friend's name with a realm**: when the game gives a friend's name with a realm (another realm), it is kept as
  given and compared the same way on both ends.
- **The own name** of a character on another realm than the friend: compared without a realm on the player's own
  side.
- **The channel joined by an older build**: left once on login, without a chat line, and never joined again.
- **A refused channel message** while the channel is off: none is sent. The server's "not permitted" notice exists
  only for chat channels, so the rule covers the channel path alone.
- **A very slow client**: the time budget gives at least one proof step per frame step, so a check always moves on.
- **"No player named" for a name that is not a peer**: hidden as today when the addon sent to it, otherwise left to
  the game.
- **Translations** with a plural rule beyond "one" and "many" (Ukrainian): the neutral form they use today stays.

## Requirements *(mandatory)*

### Functional Requirements

**Names (V11)**

- **FR-001**: The addon MUST address a character friend by the name the game gives for that friend, with no realm
  added; a realm appears in an address only when the game gave one.
- **FR-002**: The addon MUST take the player's own name in its full form ("First Last") and compare names of the
  same character as equal whether or not one side carries the player's own realm.
- **FR-003**: A friend MUST count as one peer whether the addon's message went to the friend or the friend's message
  came to the addon.

**The public channel (V19-V25, V41)**

- **FR-004**: The release MUST ship with the public channel off: no join, no chat slot, no channel option, status
  line or channel text in the settings, `/okf share` or the one-time notice.
- **FR-005**: A channel of the addon left joined by an earlier build MUST be left once at login, silently.
- **FR-006**: A channel send that the server answers with "not permitted in this channel" MUST count as refused,
  not sent, and the channel MUST then be left out like any refused path.
- **FR-007**: V20-V25 and V41 MUST be closed as "not shipped" in their verification record, with the reason (V19);
  the channel code MAY stay in the source, switched off, if removing it is larger than switching it off.

**Proof steps (V26)**

- **FR-008**: The work per frame step of a record check MUST be bounded by time, so no frame step spends more than
  about 5 ms on proof steps on a client where one step costs about 0.3 ms, and at least one step runs per frame
  step.
- **FR-009**: A chain of 4096 links MUST still be checked within the exchange's session time.

**Offline whispers (V12)**

- **FR-010**: The game's hidden "No player named ..." line for an address the addon whispered MUST end an open
  session to that address; the branch that waited for a "target offline" send result MAY go.

**"1 catches" (batch 5)**

- **FR-011**: Every count of catches and of players the addon shows MUST use the singular for one, in English and in
  every translation that has a singular form; translations with a neutral form keep it. New texts come with their
  nine translations in the same change.

**The spike**

- **FR-012**: The spike MUST NOT raise its deliberate test error any more.
- **FR-013**: The spike MUST keep only the sections that an open step of `docs/checklists/spike.md` or of the next
  spec still needs; sections whose steps are all answered, or that cover the channel, go, with their tests.
- **FR-014**: The spike checklist MUST say which steps are closed as not shipped (the channel) and which stay open.

**Documents and checks**

- **FR-015**: Each fix MUST come with a test that fails without it (names, channel off, the refusal, the step
  budget, the offline line, the singular texts, the spike without the error).
- **FR-016**: The documents MUST follow in the same change: `CHANGELOG.md` (`[Unreleased]`: the public channel is
  not part of 1.2.0; the friends path and the wording), the manual (the exchange without the channel), the
  verification records of V11, V12, V19-V25, V26, V41 and V42, `docs/forever-api.md`, the `CLAUDE.md` Forever API
  part where it changes, `docs/architecture/exchange.md`, `docs/tech-debt.md` (batch 1 and the "1 catches" item
  removed, the history line), `docs/release-plan.md`, and the checklists (`spike.md`, `catch-exchange.md`,
  `public-channel.md`).
- **FR-017**: The author's 1.2.0 test page MUST be updated after the implementation: the phase for batches 1-2 lists
  this spec's in-game steps; the batch 2 steps move to their own phase for the next spec; steps that no longer
  apply (the channel's) are removed or marked not shipped.
- **FR-018**: Code that rests on behaviour only the game can confirm MUST carry its `VERIFY` marker until the author
  confirms it in game.

### Key Entities

- **Peer address**: how the addon names another player on a path (guild, group, whisper, Battle.net); after this
  spec the name as the game gives it, with a realm only when the game gave one.
- **Own name**: the player's full character name, used to recognise the player's own messages and notices.
- **Refused path**: a path (chat type, or whisper target) on which the server refused a send; it is left out for a
  while, as today for the other refusal results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With a character friend who uses the addon, the friend shows once in `/okf share`, and no "No player
  named" line appears in a session of an hour.
- **SC-002**: After login with sharing on, the number of chat channels the player is in is the same as without the
  addon.
- **SC-003**: During an exchange, the debug report's longest merge step stays under 5 ms.
- **SC-004**: No count of one reads "1 catches" or "1 players" in English or any translation that has a singular.
- **SC-005**: `/okf debug` after a `/okf spike` run shows no new error entry.
- **SC-006**: `npm run check` and `npm test` pass; every new test fails when its fix is reverted.

## Assumptions

- The facts of `docs/forever-api.md` "Verified in game" hold: names "First Last", the internal realm name, the
  channel refusal, 0.3 ms per proof step, the 0 result of an offline whisper with the system line after it.
- How a character friend's name looks in the friends list is not seen yet (the list was empty in the test); the fix
  uses the name as the game gives it and carries a marker until a second player shows it.
- A sender from another realm (V11's last open part) is seen only with a second player; the rule "keep the realm
  only when the game gave one" covers both answers.
- Turning the channel off keeps its code in the source, switched off, so a later release can bring it back if the
  server allows it; the plan decides whether any of it can go.
- The second-player steps (guild, Battle.net, group exchange, offline friend) are run later, from the 1.2.0 test
  page; this spec does not wait for them.
- The whole spike is removed before the release (`docs/release-plan.md`); this spec only trims it.
