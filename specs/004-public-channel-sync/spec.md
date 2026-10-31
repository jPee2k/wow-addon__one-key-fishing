# Feature Specification: Catch Data Exchange Through a Hidden Public Channel

**Feature Branch**: `002-shared-db` (all parts of the shared catch database are built on this branch)

**Created**: 2026-10-30

**Status**: Draft

**Release**: 1.2.0, together with parts 1, 2 and 4 of the shared catch database. The public channel ships only if
the in-game check confirms that addon messages in a custom channel work in WoW Forever; otherwise the release goes
out without the channel but with the protections of the numbers, as FR-026 describes.

**Input**: User description: "Catch database, part 3 of 4 (release 1.2.0): exchange catch data with every addon user
through a hidden public channel. Who and why: guild and group exchange only reaches people the player already knows;
a public channel lets data spread across the whole game mode between releases. What the player gets: the addon
announces itself in a hidden channel and exchanges data with strangers who run the addon, invisibly: the channel does
not show in chat or the channel list, does not shift General/Trade numbers, and text typed into it by hand is hidden.
If all channel slots are taken, the addon keeps working through guild and group. A setting 'Use the public channel'
(off = guild and group only). No single contributor can dominate a spot's numbers; tooltips and the tab keep saying
how many players the data comes from. The author can block bad contributors in the bundled data. Rules: same policy,
privacy and performance rules as part 2; announcements are rare and jittered so many clients do not hit one player at
once. Ships only if the in-game spike confirms that addon messages in custom channels work in WoW Forever (and shows
whether they reach other layers and the other faction). Depends on part 2. Design: docs/shared-db-plan.md (phase 5)."

## Clarifications

### Session 2026-10-30

- Q: If the in-game check shows that addon messages in a custom channel do not work, do the protections of the
  numbers still ship in 1.2.0? → A: Yes. Only the channel itself (joining, hiding, the setting, the texts about it)
  is left out; the weight limit, the three-contributions rule, the protection against forged versions, the eviction
  by new information and the block list ship anyway, since strangers also arrive through open-world groups and
  relayed contributions.
- Q: How strong must the protection against forged versions of someone else's contribution be? → A: Owner-bound
  versions plus limits: only the owner's client can make a newer version that others accept, and a version may not
  add more fishing than the time since the held one allows.
- Q: A custom channel has an owner (usually the first player in it) who can set a password, kick and ban, and the
  channel's name is in the open code; what if one person takes it over and locks it? → A: Fallback channels: a
  client that finds the channel locked, or is banned from it, moves to a fallback channel every client finds the
  same way, so the person has to take over each one in turn (FR-005a); the owner's powers join the in-game check.
- Note from the author: WoW Forever has items that nobody's client knows until someone finds them in game; this is a
  feature of the game. A contribution with an item the client does not know yet must therefore not be refused
  (FR-017a), which replaces part 2's rule of dropping it.

### Quiz on the gameplay, 2026-10-30

- Q: "Use the public channel" after the update? → A: On by default.
- Q: When is the addon in the channel? → A: Whenever the player is online, also outside fishing mode, like the part 2
  exchange.
- Q: The addon's channel takes a slot the player needs (WoW Forever allows 20 chat channels)? → A: Both: the addon
  joins only while at least two slots are free, so one is always left for the player; and when the player still
  hits the limit while the addon is in its channel, the addon gives its slot up and says so in one chat line ("try
  again"); it comes back only when two slots are free again (FR-005).
- Q: The player leaves the hidden channel by hand? → A: The addon stays out until the next login; the setting does not
  change (another addon that cleans up channels must not turn it off behind the player's back).
- Q: Is the player's own catch under the weight limit? → A: No: one fifth from five contributions applies to other
  players' contributions only.
- Q: An item the client does not know yet? → A: Shown as its own "Unknown item" row (question mark icon, chance and
  pieces per catch, no price) once three contributions report it on the map; its tooltip says the game has not shown
  the item yet, how many contributions reported it, and the item ID. The row turns into a normal one as soon as the
  game knows the item (FR-017a).
- Q: Is a player whose ID the author blocked told? → A: No; only `/okf debug` says so, for bug reports.
- Q: Data from strangers arrives within hours (90% of clients within 3 hours)? → A: Fine; the guild and the group stay
  the fast path.
- Q: Raise the limit of 20,000 places of others' data now that strangers take part? → A: No, it stays.
- Q: The author's collection mode (`/okf share collect`)? → A: Stays an idea, not part 3.
- Q: Tell players that the channel's member list shows who runs the addon? → A: One sentence on the settings page,
  not in the one-time notice.
- Q: Keep game modes or factions apart? → A: No; the addon exchanges with everybody the game connects it to.
- Q: Mention the channel in the tab's quiet status line? → A: No, the line stays as in part 2.

### While implementing, 2026-10-30

- The limit of FR-015 compares each version with its own version steps, not with the version a client holds. A client
  may hold a made-up copy at a version number the owner already published, and the owner's next real version does not
  contain the made-up data; a comparison with the held version would refuse the owner forever, against the first half
  of FR-015 (research R9).
- SC-001 is measured in a network that already holds the earlier contributions (a warm start: after a release the
  bundled data has absorbed what came before), with one contribution changing. A cold network of 500 clients, in
  which every record must still reach every client, needs far more than 3 hours under the 50 KB budget of SC-003
  whatever the protocol does; its one-hour run measures SC-002 and SC-003 instead (research R5).

### While planning, 2026-10-30

- Q: The client's own export shows that the Chat Channels window and Chat Settings > Channels are built without any
  filter; hiding the channel there would take a hook into Blizzard's list code. Hide it with a hook, or leave it
  listed? → A: Leave it listed under its own name; it is in no chat window or tab, next to the player's chats and the
  combat log nothing shows (FR-003).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Catches of players I have never met (Priority: P1)

A player fishes alone: nobody in their guild runs the addon, and they rarely join a group. With the public channel,
their addon finds other addon users wherever the game connects them and exchanges catch data with them in the
background, the same way it does with the guild and the group. Within hours the "What can be caught here" tab counts
catches from players they have never met, and the number of players behind the numbers grows. None of this shows in
the chat: the channel is in no chat window, no line about it appears, and General and Trade keep their usual
numbers. Only the game's channel lists show it, under a name that says it belongs to OneKeyFishing.

**Why this priority**: the guild, group and friends exchange only reaches people a player already knows; the channel
is what lets data spread across the whole game between releases, and it is the reason for this part.

**Independent Test**: two accounts with the addon that share no guild, group or friends list fish at different
places and stay online; within a few hours each one's tab shows the other's places; the chat shows nothing, no chat
window lists the channel, and General and Trade have the same numbers as without the addon. Then lock the channel with
a password from a third account and check that both move to the same fallback channel and keep exchanging; finally
join channels by hand on one account until fewer than two slots are free and check that the addon gives its slot up
with one chat line, that the next join by hand succeeds, and that the guild and group exchange still works.

**Acceptance Scenarios**:

1. **Given** A and B share no guild, group or friends list and both are online with the public channel on, **When**
   enough time has passed for an exchange, **Then** each one's tab counts the other's catches, and "from K players"
   includes the other.
2. **Given** A carries data of player C, whom B has never met, **When** A and B exchange through the channel,
   **Then** B gets C's data too.
3. **Given** the player logs in, **When** the addon has joined the channel, **Then** General, Trade and the player's
   own channels have the same numbers they have without the addon.
4. **Given** someone joins the channel by hand and types text into it, **When** the player looks at the chat,
   **Then** none of that text appears.
5. **Given** the addon is in the channel and exchanges through it, **When** the player looks at the chat, **Then**
   no line about the channel appears (joining, leaving, other members, owner changes) and no chat window or tab
   lists it; **When** the player opens the game's channel lists, **Then** the channel shows there under its own name.
6. **Given** fewer than two channel slots are free, **When** the player logs in, **Then** the addon does not join
   the channel, the guild, group and friends exchange works as before, and `/okf share` says there is no free
   channel slot.
7. **Given** a thousand addon users are in the channel, **When** one of them announces itself, **Then** only a few
   of the others ask it for an exchange, and the game stays smooth for everybody.
8. **Given** someone took over the channel and locked it with a password, **When** a client logs in, or is already
   inside when the lock comes, **Then** it moves to a fallback channel that the other clients find as well, and the
   exchange with strangers goes on there; nothing about it appears in chat.
9. **Given** the addon is in its channel and the player's channels fill every slot, **When** the player tries to join
   one more channel and the game refuses, **Then** the addon leaves its channel, one chat line says it freed a slot
   and the player can try again, the next try succeeds, and the addon stays out until two slots are free again.
10. **Given** the player is not in fishing mode, **When** they are online with both settings on, **Then** the addon
    is in the channel and exchanges as usual.

---

### User Story 2 - Numbers no single player can skew (Priority: P2)

With strangers in the network, someone may send made-up data. A player looks at a spot where many people fished:
one contribution that claims thousands of catches of a rare item barely moves the percentages; an item nobody else
reports on that map does not appear because of one report; a stranger cannot replace another player's data with a
made-up newer version. The tab keeps saying how many players the numbers come from.

**Why this priority**: the channel brings in data from people nobody knows, and without these protections one person
could make a spot's numbers wrong for everybody. They rank below the channel itself only because the stakes are a
wrong percentage, never the player's game. They ship even if the channel does not (FR-026): strangers also arrive
through open-world groups and relayed contributions.

**Independent Test**: without the game, on prepared data: a spot with five or more contributions plus one made-up
contribution that claims 10,000 catches of one item; an item reported by only one or two contributions; a forged
newer version of another player's contribution; a full store that receives one more contribution. Check the shown
numbers and what is kept.

**Acceptance Scenarios**:

1. **Given** a spot with 6 contributions where an item has a 5% chance, **When** a 7th contribution claims 10,000
   catches that all contained that item, **Then** the shown chance of that item rises by no more than 20 percentage
   points, and the catch count still shows the real number of catches.
2. **Given** an item that is neither in the bundled data nor in the player's own catch, **When** only one or two
   contributions report it on a map, **Then** the tab does not show it there; **When** a third contribution reports
   it on that map, **Then** it is shown.
3. **Given** a client holds a version of player D's contribution, **When** a stranger sends a made-up version of it
   that claims to be newer than anything D's client has sent, **Then** it is refused; **When** any version holds
   more fishing than its owner could have done in its version steps, **Then** it is refused too; **When** D's next
   real version arrives, **Then** it is accepted, whatever was made up before.
4. **Given** the saved shared data is at its size limit, **When** another contribution arrives and is kept, **Then**
   the contributions whose places the bundled data already knows from 1,000 or more catches are dropped first,
   contributions for places where the bundled data has under 50 catches are dropped last, and the player's own
   contribution is never dropped.
5. **Given** the player fished a spot 1,000 times and five other players 10 times each, **When** the tab is open
   with the source "All", **Then** the player's own catch is counted in full.
6. **Given** a contribution holds an item this client does not know yet, **When** it arrives, **Then** it is kept,
   counted and passed on; **When** three contributions report that item on the map (or the bundled data has it),
   **Then** the tab lists it as an "Unknown item" row with a question mark icon, its chance and pieces per catch and
   no price, and the row's tooltip says the game has not shown the item yet, how many contributions reported it,
   and the item ID; **When** the game learns the item, **Then** the row shows its name and icon like any other.

---

### User Story 3 - Turn the public channel off and see its state (Priority: P3)

The "Shared database" settings page gets a second setting, "Use the public channel". Off, the addon leaves the
channel at once and exchanges only with the guild, the group and friends. The one-time notice and the page say that
with the channel on, any addon user can receive the catch. `/okf share` shows whether the addon is in the channel,
why not if it is not, and how many players it heard there.

**Why this priority**: players must be able to keep the exchange to people they know, and to see why the channel is
not in use; this adds no data, so it ranks below the exchange and its protections.

**Independent Test**: turn the setting off and on and check the channel membership, the exchange and `/okf share`;
repeat with the main setting off, with fewer than two channel slots free, and after leaving the channel by hand.

**Acceptance Scenarios**:

1. **Given** the addon is in the channel, **When** the player turns "Use the public channel" off, **Then** the addon
   leaves the channel at once, the guild, group and friends exchange goes on, and the data already received from
   strangers stays counted.
2. **Given** "Use the shared catch database" is off, **When** the settings page is open, **Then** "Use the public
   channel" is greyed out and the addon is not in the channel.
3. **Given** the channel setting is off, **When** the player turns it on, **Then** the addon joins the channel
   without waiting for a new login.
4. **Given** any state of the channel, **When** the player types `/okf share`, **Then** it says whether the addon is
   in the channel (and whether it is a fallback channel), or why not (setting off, no free channel slot, every
   channel locked or refused, left by hand), and how many players it heard in the channel in the last hour.
5. **Given** the first login with 1.2.0, **When** the one-time notice appears, **Then** it names the public channel
   next to the guild, the group and friends.
6. **Given** the player leaves the hidden channel by hand, **When** the session goes on, **Then** the addon stays out
   of the channel until the next login, and `/okf share` says the channel was left by hand.

---

### User Story 4 - The author blocks a bad contributor (Priority: P4)

Before a release, the release command lists the contributions that look abnormal next to the others at the same
places. The author blocks those that are clearly made up. The next release leaves them out of the bundled numbers and
carries the list of blocked contributions, so every client drops them and stops passing them on.

**Why this priority**: it is the last line of defence against a persistent spammer, and only the author uses it, once
per release.

**Independent Test**: on prepared saved data with one made-up contribution, run the release command and check that
the report lists it; block it and check that the bundled data leaves it out; load that bundled data on a client that
holds the contribution and check that it is dropped, refused from the network and not passed on.

**Acceptance Scenarios**:

1. **Given** the author's saved data holds a contribution whose numbers are far from all others at the same places,
   **When** the release command runs, **Then** the report lists it.
2. **Given** the author blocked that contribution's anonymous ID, **When** the release command runs, **Then** its
   numbers are not in the bundled data, and the bundled data names the blocked ID.
3. **Given** a client holds that contribution, **When** it updates to the release, **Then** it drops the
   contribution, refuses it from the network and does not pass it on.
4. **Given** a later release no longer blocks the ID, **When** a client updates to it, **Then** it accepts that
   contribution again.
5. **Given** the player's own ID is blocked, **When** the player opens the tab, **Then** their own catch still counts
   for them, and their client no longer offers it to others.

---

### Edge Cases

- The game builds its channel lists (the Chat Channels window, Chat Settings > Channels) without any filter: the
  channel shows there under a name that says it belongs to OneKeyFishing, and the README says so (FR-003).
- Someone takes over the channel (it has an owner, usually the first player in it, and its name is in the open
  code) and locks it with a password: new clients cannot join, and clients inside learn of the lock; all of them move
  to the same fallback channel, so the network does not split (FR-005a). The person has to take over each fallback
  channel in turn. The game answers a join into a locked channel with a password prompt; the addon closes it at once,
  so the player sees nothing.
- The owner kicks or bans one client: a kicked client joins again later; a banned one moves to the fallback channel
  and may find few players there until others follow, while it keeps exchanging through the guild, the group and
  friends.
- Every fallback channel is locked or refused (someone took them all over in advance): the exchange goes on through
  the guild, the group and friends, `/okf share` says every channel is locked, and the addon tries again at the next
  login.
- The player joins a new channel by hand during the session after the addon joined the hidden one: that channel
  takes the next free number; at the next login the player's channels get their usual numbers again (FR-002).
- Two channel slots become free during the session after the addon found fewer, or after it gave its slot up for
  the player: the addon joins then, or at the latest at the next login.
- The player hits the channel limit a second time in the same session after the addon already gave its slot up: the
  game's own refusal stands; the addon is not in the way, so it says nothing.
- The player or another addon uses a channel of the same name for something else: its text stays hidden, as any
  text typed into the channel by hand. A copy of one of the addon's names joined outside the addon's own join (by
  hand, or kept by the game from an older session) is left at once: the names belong to the addon, and one copy is
  enough. After the player left the channel by hand, a channel they join again by hand is theirs until the next
  login.
- `/reload`: the addon is still in the channel and it stays hidden; nothing about it appears in chat.
- Combat, an instance, a loading screen or a restricted game state: nothing is sent to the channel and what arrives
  is ignored, as for the rest of the exchange; the addon may stay in the channel.
- Hundreds of announcements per hour arrive in a busy channel: they cost no noticeable frame time, and the memory for
  players heard stays bounded (the strangers heard longest ago are forgotten first, never guild, group or friends).
  Strangers who only whispered (a session they started) are not counted in that bound: each one is a real character
  that heard this client, so their number grows with the session's length, not with the channel's size.
- A stranger floods the channel or a whisper with messages or message parts: they are dropped cheaply and the sender
  is ignored until logout.
- A stranger runs an incompatible exchange version: no exchange with them, no error, as in part 2.
- The channel reaches only the player's own layer, or only their own faction or game mode: the network still
  spreads through players who move between layers and through guilds, and the bundled data carries the catches
  between factions and modes.
- Many made-up identities from one person each pass the checks: the weight limit applies per contribution, so they
  can still outweigh the real data at a spot with little data; the "from K players" count, the three-contributions
  rule for new items, the release command's report and the block list are the answer.
- A blocked ID's contribution arrives through a client that has not updated yet: it is refused and not passed on;
  the sender is not blamed, since it may simply have an older release.
- A contribution holds an item the player's client does not know yet (WoW Forever reveals some items only when
  someone finds them): the contribution is kept and passed on, its catches count in the spot's totals, and the item
  shows as an "Unknown item" row once three contributions report it on the map (FR-017a).
- A made-up item ID that no client will ever know: reported by fewer than three contributions it is never listed;
  three made-up identities can make it an "Unknown item" row, with a chance held down by the weight limit; it costs
  only the room the contributions' size limit allows, and the block list is the answer to its sender.
- An "Unknown item" row has no price: it is left out of the catch value sums, as an item without a vendor or auction
  price is today.
- A stranger re-sends a real version of someone else's contribution with changed numbers: it cannot claim to be
  newer than the owner's newest version, it holds no more fishing than its version steps allow, and the owner's next
  real version replaces it.
- A Trial or Veteran account that the game does not let send addon data or join custom channels: the state says the
  channel is refused, as part 2 says the exchange is unavailable.
- The public channel arrives in a later release than 1.2.0 (the in-game check did not confirm it in time): players
  who already closed the one-time notice see it once more, naming the channel (FR-022).

## Requirements *(mandatory)*

### Functional Requirements

**Public channel**

- **FR-001**: While "Use the shared catch database" and "Use the public channel" are both on and the one-time notice
  has been closed, whenever the player is online (also outside fishing mode), the addon MUST join one hidden
  channel shared by every addon user the game lets meet there (or a fallback channel, FR-005a), announce itself in
  it, and exchange catch data with the addon users it hears there,
  the same way as with the guild, the group and friends in part 2 (one player at a time, with part 2's checks and
  limits).
- **FR-002**: The addon MUST join the channel only after the game's standard channels are in place after the login,
  so General, Trade and the player's own channels keep the numbers they have without the addon.
- **FR-003**: The channel MUST stay invisible in the chat: it MUST NOT appear in any chat window or tab, no notice
  about it (joining, leaving, other members joining or leaving, owner or setting changes) MUST appear in chat, and
  the game's password prompt for it MUST NOT stay on screen. The game's channel lists (the Chat Channels window,
  Chat Settings > Channels), which the game builds without any filter, MAY show it under a name that says it belongs
  to OneKeyFishing, and the README MUST say so.
- **FR-004**: Text typed into the channel by hand, by anyone, MUST NOT appear on the player's screen.
- **FR-005**: The addon MUST NOT cost the player a channel slot: it MUST join only while at least two channel slots
  are free, so one is always left for the player. When the player still hits the channel limit while the addon is
  in its channel, the addon MUST give its slot up at once and say so in one chat line (it freed a slot, try again),
  the only line the channel feature ever puts in chat, and only in answer to the player's own action; it MUST come
  back only when two slots are free again or at the next login. When the addon cannot join any channel (fewer than
  two slots free, a refusal by the game), the exchange MUST keep working through the guild, the group and friends.
  When the player leaves the channel by hand, the addon MUST stay out of it until the next login, without changing
  the setting.
- **FR-005a**: One person MUST NOT be able to stop the channel exchange for everybody by taking the channel over.
  When the channel is locked with a password, or the client is banned from it, the addon MUST move to a fallback
  channel that every client finds the same way, without any coordination; clients already inside a channel that
  gets locked MUST move as well, so the network does not stay split. When every fallback channel is locked or
  refused, the exchange MUST keep working through the guild, the group and friends, and the addon MUST try again at
  the next login. Moving between channels MUST stay as invisible as the channel itself (FR-002 to FR-004).
- **FR-006**: Announcements in the channel MUST be rarer than in the guild and the group and spread by random waits.
  A client that hears an announcement in the channel MUST start an exchange with that player only now and then (at
  random, and not when it exchanged recently), so one announcement draws only a few requests however many addon users
  hear it.
- **FR-007**: The exchange with the guild, the group and friends MUST keep priority over strangers from the channel;
  the channel MUST NOT delay the part 2 exchange beyond part 2's timing goals.
- **FR-008**: All channel traffic MUST fit the same hourly traffic budget per client as part 2, refusals included;
  it MUST respect the game's limits for channel messages and back off when the game reports one.
- **FR-009**: Names of players heard in the channel MUST be kept only in memory for the current session, never in
  saved data, as in part 2; that memory MUST stay bounded however many addon users are in the channel, forgetting
  the strangers heard longest ago first and never a guild, group or friends peer.
- **FR-010**: A burst of messages or message parts from one sender MUST be dropped without noticeable frame time, and
  the sender ignored until logout, for strangers as for anybody else.
- **FR-011**: While the exchange is paused (combat, instances, restricted game states, loading screens), the addon
  MUST send nothing to the channel and ignore what arrives there; it MAY stay in the channel.
- **FR-012**: Turning "Use the public channel" off MUST leave the channel at once; turning it on MUST join the channel
  without waiting for a new login. Contributions already received from strangers MUST stay counted when the channel
  is turned off (whether other players' data counts is decided by "Use the shared catch database", as in part 2).

**Protection of the numbers**

- **FR-013**: At a spot with data from five or more contributions, every single contribution of another player MUST
  carry no more than one fifth of the weight in the shown numbers (chances, pieces per catch, miss rate); the
  player's own catch is counted in full. The catch count ("N catches from K players") MUST stay the real number of
  catches. The release command MUST apply the same rule when it builds the bundled data.
- **FR-014**: An item that is neither in the bundled data nor in the player's own catch MUST be shown for a map only
  when at least three different contributions report it on that map.
- **FR-015**: Only the owner's client MUST be able to make a version of a contribution newer than the newest one it
  has sent: a version made up by anybody else that claims to be newer MUST be refused, whatever its numbers, and a
  made-up version MUST NOT keep the owner's later real versions from being accepted. In addition, every version MUST
  be refused when it holds more fishing than its owner could have done in its version steps. Records carry no
  timestamps (privacy), so fishing time is measured in version steps, each of which stands for at most about a
  minute of the owner's fishing; a version relayed slowly is no reason to refuse it. The limit applies to each
  version alone: compared with the version a client holds, which may itself be made up, it could block the owner's
  next real version. The release command MUST apply the same checks, so the bundled data never keeps a made-up
  version over a real one.
- **FR-016**: Above the size limit of the saved shared data (20,000 places of other players' contributions, as in
  part 2), the contributions that add the least new
  information MUST be dropped first: those whose places the bundled data already knows from 1,000 or more catches,
  then those no peer has confirmed for over 60 days; contributions for places where the bundled data has under 50
  catches (part 1's "little data") MUST be dropped last, and the player's own contribution MUST never be dropped.
- **FR-017**: Contributions from strangers MUST pass the same checks as in part 2 (format, limits, plausibility)
  before they are kept, and the "N catches from K players" line MUST count them like any other contribution, each at
  most once.
- **FR-017a**: A contribution that holds an item this client does not know yet MUST NOT be refused for it: WoW Forever
  has items that a client learns about only when they are found in game. It MUST be kept, counted and passed on like
  any other. Once FR-014 lets such an item show, the tab MUST list it as its own "Unknown item" row (one row per
  item): a question mark instead of the icon, its chance and pieces per catch, no price, and left out of catch value
  sums; the row's tooltip MUST say that the game has not shown the item yet, how many contributions reported it, and
  the item ID. As soon as the game knows the item, the row MUST show its name and icon like any other. This replaces
  part 2's rule of dropping a contribution with an unknown item.

**Blocking bad contributors**

- **FR-018**: The release command MUST report the contributions whose numbers look abnormal next to the others at the
  same places, so the author can review them.
- **FR-019**: The author MUST be able to block contributions by their anonymous ID. The release command MUST leave a
  blocked ID out of the bundled numbers, and the bundled data MUST carry the list of blocked IDs (anonymous IDs only,
  no names).
- **FR-020**: Every client with that release MUST drop the held contributions of a blocked ID, refuse them from the
  network and not pass them on, without blaming the sender; an ID that a later release no longer blocks MUST be
  accepted again. A player whose own ID is blocked MUST keep their own catch in their own view, and their client MUST
  stop offering it; nothing tells the player apart from one line in `/okf debug` (for bug reports).

**Setting, notice and state**

- **FR-021**: The "Shared database" settings page MUST hold a second setting, "Use the public channel": account-wide,
  on by default; off means the guild, the group and friends only. It MUST be greyed out and without effect while
  "Use the shared catch database" is off.
- **FR-022**: The page's short text and the one-time notice MUST name the public channel as a way the catch is
  shared: any addon user may receive it, and the players who exchange with the player can tell which anonymous ID is
  theirs. The page MUST also say, in one sentence, that anyone who joins the channel by its name can see which
  characters in it run the addon; the notice stays short without it. If the public channel ships in a later release
  than the one that showed the notice, players who already closed it MUST see it once more with the new text.
- **FR-023**: `/okf share` MUST show the state of the public channel (in use, in use as a fallback channel, setting
  off, no free channel slot (fewer than two free, or given up for the player), every channel locked or refused, left
  by hand) and count the players heard in the
  channel in the last hour next to the guild, the group, friends and Battle.net. `/okf debug` MUST contain the same
  state in English; neither MUST show the anonymous ID or other players' names.
- **FR-024**: Every new visible text (the setting, the page's text, the notice, the `/okf share` lines, the chat line
  about the freed channel slot, the "Unknown item" row and its tooltip) MUST be translated into all supported
  interface languages; the `/okf debug` section stays English, like the rest of the
  debug report.
- **FR-025**: The "What can be caught here" tab, and every later place that shows catch chances (the part 4
  tooltips), MUST keep saying how many players the numbers come from, with the weights of FR-013 applied to the
  chances.

**Before the release**

- **FR-026**: Before the release, an in-game check MUST confirm that the addon can join a custom channel and hide it
  (chat windows, notices, the password prompt, General and Trade numbers), and that addon messages sent to it reach
  other
  addon users in WoW Forever; it MUST also record whether they reach players on other layers and of the other
  faction, the game's limits and results for channel addon messages, who becomes the channel's owner and what the
  owner can do to addon users (password, kick, ban), what the game tells a client that cannot join a locked channel
  or is banned from it, what the game reports when the player hits the channel limit, and how the game reveals an
  item a client did not know (when its name and icon become available). The game opens on 2026-11-04, so the
  feature is built before that on marked assumptions; the release MUST NOT happen while any assumption is
  unchecked, and the answers MUST be recorded with the other verified game facts. If addon messages in a custom
  channel do not work, the release MUST go out without the public channel: no channel is joined, the setting is not
  shown, and the notice, the settings
  page and the README do not mention it. The protections of FR-013 to FR-020 MUST ship in any case, since strangers
  also arrive through open-world groups and relayed contributions.

### Key Entities

- **Public channel**: one hidden channel shared by every addon user the game lets meet there, with a fixed set of
  fallback channels every client finds the same way for when one is locked; joined once per login after the
  standard channels; its state is in use (in the first or a fallback channel), setting off, no free slot, every
  channel locked or refused, or left by hand.
- **Channel peer**: an addon user heard in the channel, usually a stranger; known only by the name used to reach
  them, kept in bounded session memory, with lower priority than guild, group and friends peers.
- **Contribution weight**: the share of a spot's shown numbers that one contribution carries; capped for other
  players' contributions at spots with five or more contributions.
- **Block list**: the anonymous IDs the author blocked, carried in the bundled data; clients drop, refuse and do not
  pass on their contributions.
- **Outlier report**: the release command's list of contributions whose numbers look abnormal next to the others at
  the same places.
- **Version proof**: what each version of a contribution carries so that other clients and the release command can
  tell it was made by the owner's client; nobody else can make a newer one.
- **Public channel setting**: one account-wide on/off choice, on by default, under "Use the shared catch database".
- **Unknown item row**: a line in "What can be caught here" for an item the client does not know yet, reported by
  three contributions on the map; question mark, chance, pieces per catch, a tooltip with the item ID; it becomes a
  normal row once the game knows the item.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a simulation of 500 clients connected only through the channel, a new contribution reaches at least
  90% of them within 3 hours of play.
- **SC-002**: In a simulation of 1,000 clients in the channel, a client that announces itself is asked for an
  exchange by at most 5 others per announcement on average, and no client goes over the hourly traffic budget.
- **SC-003**: A client sends no more than 50 KB of exchange data per hour with the channel on, whatever the number of
  addon users in the channel.
- **SC-004**: During a week of normal play with the channel on, no line about the hidden channel or the exchange
  appears in chat, General, Trade and the player's own channels keep their numbers on every login, and the game
  reports no throttling errors.
- **SC-005**: Players notice no stutter or frame rate drop with the channel on, also while the channel is busy or a
  sender floods it; the longest single exchange step that `/okf debug` reports stays under 5 ms.
- **SC-006**: A made-up contribution that claims any number of catches at a spot with five or more other
  contributions changes no shown chance there by more than 20 percentage points.
- **SC-007**: In tests, 100% of made-up versions that claim to be newer than the owner's newest are refused, 100% of
  versions that hold more fishing than their version steps allow are refused, and the owner's next real version is
  accepted after any made-up one.
- **SC-008**: After a release that blocks an ID, no client with that release counts, keeps or passes on that ID's
  contribution, in 100% of the tested cases.
- **SC-009**: With the public channel off, or with fewer than two free channel slots, the client is not in the
  channel and sends nothing to it, and the guild, group and friends exchange still meets part 2's timing goals.
- **SC-010**: Before the release, the release command's report shows contributions from players who are not in the
  author's guild, group or friends list.
- **SC-011**: In a simulation where one person locks the channel, at least 90% of the clients exchange with each
  other again in one fallback channel within 15 minutes, as long as a fallback channel is free.
- **SC-012**: The addon never takes one of the last two free channel slots, and when the player hits the channel
  limit while the addon is in its channel, the player's next try succeeds, in 100% of the tested cases.

## Assumptions

- Part 2 (`specs/003-guild-group-sync`) is in place: the exchange with the guild, the group and friends, its checks,
  limits, pauses, traffic budget, the "Shared database" page, the one-time notice and `/okf share`.
- The game cannot be played before 2026-11-04; how custom channels behave in WoW Forever (addon messages, joining
  from an addon, hiding, layers, factions, limits) is assumed from public API documentation and the Retail client and
  checked in game before the release (FR-026).
- "Use the public channel" is on by default: the brief describes what turning it off does, part 2 made the exchange
  itself on by default with an honest one-time notice, and a channel few players join would not spread data.
- Whatever the channel reaches (one layer or all, one faction or both, one game mode) is the network; the protocol
  does not change with it, and the bundled data stitches together the parts that never meet directly.
- The channel's member list, for anyone who joins it by name, shows which characters run the addon and are online;
  it shows no catch data. The notice and the settings page say that the public channel connects to any addon user;
  the member list is mentioned on the settings page only (FR-022).
- WoW Forever allows 20 chat channels (`MaxChatChannels` in the client's own API export), so keeping two free costs
  almost nobody the public channel; players who use many channels (roleplay) are the ones FR-005 protects.
- Data from strangers within hours is enough: the channel is for spreading data between releases, the guild and the
  group stay the fast path.
- The limit of 20,000 places of other players' contributions stays: the bundled data absorbs records every release,
  and the eviction by new information keeps the most useful ones.
- The weight limit leaves the player's own catch in full: the player trusts their own fishing, and "Only mine" shows
  it alone anyway. The bundled data counts as already limited, since the release command applies the same rule when
  it builds it.
- The tab's quiet status line stays as in part 2; the channel's state is on the settings page, in `/okf share` and in
  `/okf debug`.
- The version proof (FR-015) needs a small computation per version on the owner's and the receiver's side, without
  any help from the game; it must fit the frame-time goal of SC-005. The plan decides how it is made.
- An item the client does not know yet is shown as an "Unknown item" row with its ID in the tooltip (the author's
  choice): it tells players there is something to find at the spot, and a curious player may look the ID up; the
  three-contributions rule and the weight limit keep made-up IDs rare and small.
- Part 2's rule of dropping a contribution with an unknown item (and not wanting that version again in the session)
  is replaced by FR-017a in part 3 for every peer, not only for strangers.
- The fallback channels limit what one person can do but cannot rule it out: whoever takes over every fallback
  channel ahead of time stops the channel exchange until those channels are free again. The plan should make that
  costly (for example, fallback names that change over time, or an addon client that becomes a channel's owner
  undoing the lock, where the game allows it); the guild, group and friends exchange and the bundled data are never
  affected.
- One case of FR-005a is accepted as a known limit. A clean lock by an addon client that becomes the owner (the
  self-heal) must not move anybody, so a lock set by someone who also runs the addon looks like that and moves
  nobody inside. New clients go to the next fallback channel; the two groups meet again as the clients inside log
  in again, and through guilds, groups and friends meanwhile (research R4).
- The stakes of bad data are a wrong percentage, never the player's game, so layered protection (checks on receipt,
  weights, the three-contributions rule, the release command's report and the block list) is enough without a
  server.
- Out of scope: the catch catalog, map pins, tooltips and shared auction prices (part 4); a heightened collection mode
  for the author (`/okf share collect`), which stays an idea.
