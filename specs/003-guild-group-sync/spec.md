# Feature Specification: Catch Data Exchange in the Guild, the Group and with Friends

**Feature Branch**: `002-shared-db` (all parts of the shared catch database are built on this branch)

**Created**: 2026-10-29

**Status**: Draft

**Release**: 1.2.0, together with parts 1, 3 and 4 of the shared catch database (decided on
2026-10-29; 1.1.0 is the interface-language release). The release numbers in the input below are from the
earlier plan of one release per part.

**Input**: User description: "Catch database, part 2 of 4 (release 1.2.0): exchange catch data with guild and group
members in game. The bundled data only refreshes with releases; players fishing together or in one guild should see
each other's catches right away. The addon finds other addon users and exchanges catch data with them in the
background, invisibly; the 'What can be caught here' tab also counts data from other players and shows 'N catches
from K players'; a 'Shared database' settings page, /okf share and a /okf debug section; a one-time notice on first
login after the update; the author's client collects others' data so the release command bundles it. Rules: within
Blizzard's UI Add-On Policy, pauses in combat, instances, restricted states and loading screens, no effect on frame
rate, anonymous contributions, nothing counted twice, bad data rejected, saved data size-limited. Depends on part 1;
needs an in-game spike first. Design: docs/history/shared-db-plan.md (phases 1 and 4)."

## Clarifications

### Session 2026-10-29

- Q: Is sharing on or off after the update? → A: On by default, with a one-time notice at the first login.
- Q: When does the exchange run? → A: Whenever the player is online, not only in fishing mode (outside combat,
  instances, restricted states and loading screens).
- Q: Who takes part? → A: The guild, the party, the raid, and online friends from the friends list who run the addon.
- Q: What does the one-time notice look like? → A: A popup with two buttons: "Got it" and "Settings".
- Q: Separate "share my catch" and "receive others' data" settings? → A: No: one setting, "Use the shared catch
  database". Off means nothing is sent and nothing is received.
- Q: A "new anonymous ID" button? → A: No; the ID is random and tied to no name, and turning the setting off is enough.
- Q: Source filter options? → A: Unchanged, "All" and "Only mine"; "All" also takes in the data from other players.
- Q: Is the exchange visible outside the settings and `/okf share`? → A: Only as a quiet status line in the "What can
  be caught here" tab; no popups or chat lines.
- Q: What happens to other players' data already received when the setting is turned off? → A: It is kept but not
  shown; turning the setting back on shows it again at once.
- Q: Where does the setting live? → A: On a separate "Shared database" settings page, with a short text on what is
  shared and a status line.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the catches of the people I fish with (Priority: P1)

Two friends fish in the same zone in a group, or two guild members fish in different zones. Without doing anything,
each of them sees the other's catches in "What can be caught here": the counts grow by the other's catches, and the
tab says how many catches from how many players the numbers come from. Nothing appears in chat, and the game feels
the same as before.

**Why this priority**: this is the value of the release: data stops waiting for the next release and flows between
players who already play together.

**Independent Test**: two accounts (or the author and a friend) with the addon, both fish at different places, then
join a group; within minutes each one's tab shows the other's places and counts; the chat shows nothing; repeat with
two guild members who are not in a group, and with two players who are only on each other's friends list.

**Acceptance Scenarios**:

1. **Given** player A caught 40 fish at a spot where player B has 20, **When** A and B are in one group and an
   exchange took place, **Then** B's tab at that spot shows 60 catches "from 2 players", and so does A's.
2. **Given** A and B are in the same guild but not in a group, **When** both are online, **Then** they exchange
   their data in the background as well.
3. **Given** A has B on the friends list and both are online, outside a guild or group together, **Then** they
   exchange their data as well.
4. **Given** A also received B's data through C, **When** the tab is shown, **Then** B's catches are counted once.
5. **Given** A carries data of player D, whom B has never met, **When** A and B exchange, **Then** B also gets D's
   data: data spreads further than the people one meets directly.
6. **Given** an exchange is running, **When** the player looks at the chat, **Then** no line about the exchange, a
   hidden channel or a player who could not be found appears.
7. **Given** the source filter "Only mine", **When** the tab is open, **Then** data from other players is not
   counted.

---

### User Story 2 - Know what is shared and switch it off (Priority: P2)

On the first login after the update, the player gets a popup: their catch is shared anonymously with guild, group
and friends, no names are sent, and it can be turned off on the "Shared database" settings page. "Got it" closes
it; "Settings" opens that page. On the page, one setting, "Use the shared catch database", turns the exchange on or
off, and a status line tells what is happening. With the setting off, nothing is sent and nothing is received, and
the tab shows only the bundled data and the player's own catches.

**Why this priority**: sharing is on by default, so the player must be told honestly and must be able to stop it in
one place; without this the release would not be fair to players, but it adds no data on its own.

**Independent Test**: update an existing install, log in and check the popup and both buttons; log in again and
check that it does not reappear; turn the setting off and check that no exchange takes place and the tab no longer
counts other players; turn it on and check that their data is back at once.

**Acceptance Scenarios**:

1. **Given** the first login after updating to 1.2.0, **When** the player enters the world, **Then** the popup
   explains what is shared and where to turn it off; no exchange starts before the player has closed it.
2. **Given** the popup was closed once, **When** the player logs in again (any character of the account), **Then**
   it is not shown again.
3. **Given** the player presses "Settings" in the popup, **Then** the "Shared database" page opens and the setting
   is still on.
4. **Given** the setting is turned off, **When** guild or group members with the addon are online, **Then** the
   player's client sends nothing and accepts nothing.
5. **Given** the setting is turned off after data from other players was received, **When** the tab is open,
   **Then** it counts only the bundled data and own catches; **When** the setting is turned on again, **Then** the
   received data is counted again at once.
6. **Given** a fresh install of 1.2.0 (no earlier version), **When** the player logs in the first time, **Then**
   the same popup is shown once.

---

### User Story 3 - Check the state of the exchange (Priority: P3)

A player wonders whether the exchange works. The "What can be caught here" tab has a quiet status line ("Exchange:
3 players, 5 min ago", or why it is paused). The "Shared database" page shows the same status. `/okf share` prints
the full state: the bundled data and its version, the number of contributions held, the players seen in the last
hour, the last exchange, the traffic of the last hour, and whether the exchange is paused and why. `/okf debug`
contains the same section for bug reports.

**Why this priority**: it does not add data, but it lets players and the author see that the invisible exchange
works and lets bug reports explain why it does not.

**Independent Test**: check the status line, the page, `/okf share` and `/okf debug` while alone, in a group with an
addon user, in combat, in a dungeon and with the setting off.

**Acceptance Scenarios**:

1. **Given** an exchange with 3 players took place 5 minutes ago, **When** the tab is open, **Then** the status line
   says so.
2. **Given** the player is in a dungeon, **When** they type `/okf share`, **Then** it says that the exchange is
   paused because of the instance.
3. **Given** the setting is off, **When** the tab, the page or `/okf share` is shown, **Then** each says the shared
   database is off.
4. **Given** a bug report, **When** the player runs `/okf debug`, **Then** the report contains the exchange state
   and no anonymous ID or character names of other players.

---

### User Story 4 - Network data reaches the next release (Priority: P4)

Before a release, the author's client has collected other players' contributions like any client. The release
command bundles them together with the author's own data, so every player gets them with the next release, and
nothing is counted twice: neither on clients that already had those contributions from the network, nor on clients
that receive them again later.

**Why this priority**: it closes the loop between the network and the releases, but only the author runs it, once
per release.

**Independent Test**: on prepared saved data that holds the author's and other players' contributions, run the
release command, then load the new bundled data on a client that already holds the same contributions and check
that the counts do not grow.

**Acceptance Scenarios**:

1. **Given** the author's saved data holds contributions of 5 other players, **When** the release command runs,
   **Then** all 6 contributions go into the bundled data and the report counts them.
2. **Given** a client holds the same 5 contributions from the network, **When** it updates to the release that
   bundles them, **Then** its counts are the same as before the update, apart from data gathered after the
   author's harvest.
3. **Given** after that update another player still sends one of those contributions, **When** it arrives, **Then**
   it is not counted again.

---

### Edge Cases

- A player is in the guild, the group and on the friends list at once: data is exchanged and counted once.
- A group with strangers (a pick-up group in the open world): their data is accepted, with the same checks as any
  other.
- A dungeon, raid instance, battleground or arena group: the exchange pauses while the player is in the instance
  and resumes outside.
- Combat, a loading screen or a restricted game state starts during an exchange: it stops at once and continues
  later; nothing is lost or counted twice.
- The setting is turned off during an exchange: it stops at once.
- The first login lands in combat or a loading screen: the popup waits until the player can see it.
- A guild with many addon users online: the exchange stays within its traffic budget; data arrives over a longer
  time instead of all at once.
- A player with an older addon version (1.1.0 or earlier) or an unknown newer exchange version: no exchange with them, no error.
- A peer goes offline during an exchange: it is cancelled silently, with no line in chat.
- A peer sends broken, implausible or too much data: it is rejected, and that peer is ignored until the end of the
  session.
- A copy of the player's own contribution comes back from the network: the local one is kept.
- A friend on the friends list plays another game or another WoW version: nothing happens.
- The game version changes (a patch): data before and after it is still kept apart, as in part 1.
- Two clients hear each other and start an exchange with each other at the same moment: one of them gives way, and
  the exchange happens once.
- The saved data reaches its size limit: the contributions no peer has confirmed for the longest time are dropped
  first; the player's own is never dropped.
- The game keeps refusing addon data on one path (guild, group, whisper or Battle.net), for example because the
  in-game check shows it does not work in WoW Forever: that path is left out until logout and the other paths keep
  working. When the game refuses every path (Trial and Veteran accounts cannot send addon data), the status says
  the exchange is unavailable.

## Requirements *(mandatory)*

### Functional Requirements

**Exchange**

- **FR-001**: The addon MUST find other users of the addon among the player's guild, party, raid and online friends
  on the friends list, and exchange catch data with them in the background.
- **FR-002**: The exchange MUST run whenever the player is online, also outside fishing mode, and MUST pause in
  combat, in instances, in restricted game states and on loading screens, resuming afterwards.
- **FR-003**: The exchange MUST carry the contributions of other players too, not only the peers' own, so data
  spreads beyond the people a player meets directly.
- **FR-004**: The exchange MUST NOT show anything in chat: no messages, no channel notices, no "player not found"
  lines.
- **FR-005**: The exchange MUST stay within a fixed traffic budget per client and MUST back off when the game reports
  a limit; the budget MUST respect Blizzard's UI Add-On Policy (no chat spam, no harm to the server).
- **FR-006**: The exchange MUST NOT cause noticeable frame rate drops or stutter; heavy work MUST be spread over
  time.
- **FR-007**: Clients with an incompatible exchange version MUST be ignored silently.

**Data**

- **FR-008**: A contribution MUST stay one account's catch data under its random anonymous identifier, as in part 1;
  no character names, guild names, session times or gear MUST be sent or stored with it. Positions are sent only as
  each cell's sums of the cast positions (`px`, `py`, part 1), whose average is the spot fished from in that cell
  (for a cell of one cast, that cast's spot); the "Shared database" page MUST say so.
- **FR-009**: Names of the players exchanged with MUST be kept only in memory for the current session, never in
  saved data.
- **FR-010**: Data received twice, from several players or by several paths MUST be counted once; a newer version
  of a contribution MUST replace the older one.
- **FR-011**: Received data MUST be checked before it is kept: format, limits and plausibility (no more catches than
  the time fished allows, no item counts beyond what a catch can hold, items that exist). Data that fails MUST be
  rejected entirely, and a sender who floods or sends bad data MUST be ignored for the rest of the session.
- **FR-012**: The player's own contribution MUST only be changed by the player's own fishing; a copy from the
  network MUST NOT replace it.
- **FR-013**: The saved shared data MUST stay within a size limit; above it, the contributions no peer has confirmed
  for the longest time MUST be dropped first, and the player's own contribution MUST never be dropped.
- **FR-014**: When a new release bundles contributions, clients MUST stop counting their network copies, so nothing
  is counted twice after the update.

**What can be caught here**

- **FR-015**: Under the source filter "All", the tab MUST count the bundled data, the player's own catches and the
  contributions received from other players; "Only mine" MUST stay the player's own catches only.
- **FR-016**: The tab MUST show how many players the shown numbers come from ("N catches from K players"), counting
  each contribution at most once, including those in the bundled data; where the bundled data does not tell whether
  the players of several places overlap (the whole-map numbers), K MUST be a lower bound, never an overcount.
- **FR-017**: The tab MUST show a quiet status line about the exchange (one line of small text; no sound, popup or
  chat line): how many players it exchanged with in the last hour and when the last exchange was, or that the
  exchange is paused and why, or that it is unavailable, or that the shared database is off.
- **FR-018**: The tab MUST update when new data arrives, without being reopened.

**Setting, notice and state**

- **FR-019**: A new "Shared database" settings page MUST hold the setting "Use the shared catch database" (on by
  default; one setting for sending and receiving), a short text about what is shared, and the status line of
  FR-017. Part 3 adds its public-channel setting to the same page.
- **FR-020**: With the setting off, the addon MUST send nothing and accept nothing; data received earlier MUST be
  kept but not counted, and MUST be counted again as soon as the setting is turned on.
- **FR-021**: On the first login with 1.2.0 (after an update or a fresh install), the addon MUST show once per
  account a popup that says the catch is shared anonymously with guild, group and friends, that no names are sent,
  and where to turn it off, with the buttons "Got it" and "Settings" ("Settings" opens the "Shared database" page).
  No exchange MUST start before the popup has been closed. The text MUST name every way the catch is shared in the
  release that shows it (part 3 adds the public channel).
- **FR-022**: `/okf share` MUST show the state: the bundled data and its version, the number of contributions held,
  the players seen in the last hour, the last exchange, the traffic of the last hour, and the pause and its reason
  (or that the exchange is unavailable).
- **FR-023**: `/okf debug` MUST contain the same state; neither MUST show the anonymous identifier or other players'
  names.
- **FR-024**: Every new visible text (the tab, the settings page, the popup, the output of `/okf share`) MUST be
  translated into all supported interface languages; the `/okf debug` section stays English, like the rest of the
  debug report.

**Author's release command**

- **FR-025**: The release command MUST include other players' contributions found in the author's saved data, with
  the same checks as for the author's own, and count each contribution once.

**Before the release**

- **FR-026**: Before the release, an in-game check MUST confirm how addon data travels in WoW Forever for the guild,
  the group and friends: the limits and the results the game reports, whether direct messages between two players
  are limited, whether messages to an offline player show anything in chat, and which restricted states block the
  exchange. The game opens on 2026-11-04, so the feature is built before that on marked assumptions; the release
  MUST NOT happen while any assumption is unchecked. The answers MUST be recorded with the other verified game
  facts.

### Key Entities

- **Contribution**: one account's catch data under a random anonymous identifier, with a version that grows with
  changes; the player's own and those received from others, kept apart from the bundled data.
- **Peer**: another addon user met in the guild, the group or the friends list during the session; known only by the
  name used to reach them, kept in memory only.
- **Exchange**: a short background conversation with one peer in which both learn which contributions the other is
  missing and send them, within the traffic budget.
- **Exchange state**: whether the shared database is on, whether the exchange is paused and why or unavailable, the
  paths the game refuses, the peers seen in the last hour, the last exchange, the traffic of the last hour, the number of contributions held.
- **Shared database setting**: one account-wide on/off choice, on by default, plus a flag that the one-time notice
  was shown.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Two addon users who join a group see each other's catches in the tab within 5 minutes.
- **SC-002**: Two addon users who are online in the same guild, or on each other's friends list, see each other's
  catches within 30 minutes.
- **SC-003**: In tests with three or more clients exchanging in any order and over several paths, every client ends
  with the same counts, and no catch is counted twice, in 100% of the tested cases.
- **SC-004**: During a week of normal play with the exchange on, no line about the exchange appears in chat and the
  game reports no throttling errors.
- **SC-005**: A client sends no more than 50 KB of exchange data per hour, also in a large guild.
- **SC-006**: Players notice no stutter or frame rate drop from the exchange, also while it receives data; the
  longest single exchange step that `/okf debug` reports stays under 5 ms.
- **SC-007**: With the setting off, a client sends no exchange data at all.
- **SC-008**: After an update to a release that bundles network contributions, a client's counts for places it
  already knew do not grow from those contributions.

## Assumptions

- Part 1 (`specs/002-local-catch-db`) is in place: the place key, the anonymous contribution record
  with its versions, the bundled data, the "What can be caught here" tab and the release command.
- The game cannot be played before 2026-11-04; how addon data travels in WoW Forever is assumed from public API
  documentation and the Retail client and checked in game before the release (FR-026).
- Friends means both character friends and Battle.net friends who are playing WoW Forever; the friends list itself
  is not changed or stored.
- Strangers in an open-world group are accepted as peers: the data is anonymous and checked, so the risk is a wrong
  percentage at worst.
- Contribution weights, outlier detection and blocking bad contributors in the bundled data come with the public
  channel (part 3); in part 2 the checks on receipt are the protection.
- Dropping data by how much new information it adds (the places it covers that the bundled data already knows well)
  also waits for part 3, when strangers bring far more data; within a guild, a group and friends the size limit is
  rarely reached, and the data of players who stopped playing is the natural first to go.
- Friends are greeted a limited number at a time (friends already known to run the addon first, the rest in turn),
  so SC-002 holds for up to about 40 friends online at once; with more, finding a new addon user among them can
  take longer.
- The exchange shows no toasts or popups apart from the one-time notice.
- All four parts of the shared catch database ship together in release 1.2.0. Part 2 writes the popup, the settings
  page and the README for the guild, the group and friends; part 3 (the public channel) completes them before the
  release, because the popup is shown only once and must already name every way the catch is shared.
- Data gathered by the network after the author's harvest and before a release reaches players through the network,
  not through that release.
- Out of scope: the hidden public channel (part 3), the catch catalog, map pins, tooltips and shared auction prices
  (part 4).
