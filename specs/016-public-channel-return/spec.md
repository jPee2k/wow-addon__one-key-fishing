# Feature Specification: The Public Channel Returns

**Feature Branch**: `016-public-channel-return`

**Created**: 2026-11-16

**Status**: Draft

**Input**: User description: "Bring the hidden public channel of the catch exchange back. Addon messages in a custom
chat channel pass again since 2026-11-16 (V19 closed: two players, levels 4 to 31, also in OneKeyFishingShare;
docs/forever-api.md "Verified in game"), so set Channel.AVAILABLE = true and make Exchange/Channel.lua (written for
spec 004, off since spec 010, never run in game against a working server) fit the facts seen in game: the join notice
is YOU_CHANGED only; the password flow (CHANNEL_PASSWORD_REQUEST, WRONG_PASSWORD, Blizzard's popup "Please enter a
password" stays until closed); ownership (OWNER_CHANGED with "First Last", SET_MODERATOR with the first name only);
names are "First Last". Keep the 1.2.0 behaviour that leaves a channel of its own names it did not join only where it
still fits. The share notice, settings ("Use the public channel"), /okf share and the debug report come back with the
channel. Open in game: the other faction (V20, not checkable on a PvE realm with one faction per account), layers.
In-game checks: docs/checklists/public-channel.md."

## Context

Spec 004 built a hidden public chat channel (`OneKeyFishingShare` and five fallbacks) so that addon users who share no
guild, group or friends list still exchange catch data. On 2026-11-06 the server refused every addon message in a
custom channel (`NOT_ALLOWED_IN_CHANNEL`), so spec 010 switched the channel off (`Channel.AVAILABLE = false`) and
1.2.0 shipped without it; the exchange runs over guild, group, friends and Battle.net only. The code, its tests and its
settings stayed behind the switch.

On 2026-11-16 `/run` tests between two players showed the server carries addon messages in a custom channel again:
both ways, under the addon's own channel name, from a level 4 character, ten messages in one frame, 255-byte
messages whole (`docs/forever-api.md` "Verified in game"). The same tests confirmed the password and owner notices
the code was written for (password set, wrong password with Blizzard's popup, join with the password, the owner
passing to the one who stays, the new owner clearing the password).

This feature turns the channel on again and makes sure the code that has never met a working server behaves as the
game now shows. It is mostly a release of existing behaviour, not new behaviour: the player-facing parts (the setting,
the notice that names the channel, the status lines) are those of spec 004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Strangers share catches through the hidden channel (Priority: P1)

Two players with the addon fish in different places. They are in no common guild or group and on no friends list of
each other. Within a few hours each one's "What can be caught here" at the other's place counts the other's catches,
and "from K players" includes the other. Neither sees the channel anywhere in their chat.

**Why this priority**: it is the reason the channel exists: the shared catch database grows from every addon user,
not only from the player's own circle.

**Independent Test**: the automated tests run two clients over a simulated working channel and check that records
travel; in game, `docs/checklists/public-channel.md` step 2 with two accounts that share nothing.

**Acceptance Scenarios**:

1. **Given** a fresh install after the update, **When** the player logs in, **Then** the notice about the exchange
   names the public channel, and the addon joins no channel before it is closed.
2. **Given** a player who closed the 1.2.0 notice, which did not name the channel, **When** they log in
   with this version, **Then** the notice shows once more, now naming the channel.
3. **Given** the notice closed and "Use the public channel" on, **When** 30 to 60 seconds have passed after the login,
   **Then** the addon is in `OneKeyFishingShare`, and `/okf share` says "Public channel: in use".
4. **Given** two such players in the channel, **When** each has a record to offer, **Then** each receives the other's
   record and counts the other among the players heard in the channel.
5. **Given** the channel is in use, **When** the player looks at every chat window, tab and the combat log, **Then**
   the channel appears in none of them, and nothing typed into the channel by anyone shows.

---

### User Story 2 - The channel leaves the player's chat alone (Priority: P1)

A player who already uses many chat channels logs in. General, Trade and their own channels keep their numbers.
When they join channels by hand up to the game's limit, the addon gives its slot back with one line; when slots are
free again, the addon returns. A player who leaves the channel by hand stays out of it until the next login.

**Why this priority**: an addon that moves General to another number or takes the player's last channel slot is
uninstalled; this is the price of the channel and it must be near zero.

**Independent Test**: the automated tests cover the slot count, the give-way line, the leave by hand and the join
delay (existing channel tests); in game, checklist steps 1, 5, 6 and 7.

**Acceptance Scenarios**:

1. **Given** a player in General, Trade and own channels, **When** the addon joins after the login delay, **Then**
   their numbers are the same as before, over three logins.
2. **Given** a player in 18 channels besides the addon's, **When** they join one more by hand and the game refuses it
   for the limit, **Then** the addon leaves its channel with one line, and the next join by hand works.
3. **Given** the addon gave its slot back, **When** two slots are free again, **Then** the addon joins again within a
   few minutes.
4. **Given** the player types `/leave` for the addon's channel, **When** the session goes on (also over a `/reload`),
   **Then** the addon does not join again until the next login.
5. **Given** the player turns "Use the public channel" off, **When** the setting changes, **Then** the addon leaves
   at once and the other paths of the exchange go on; turned on again, it joins at once.

---

### User Story 3 - A locked or hostile channel does not disturb the player (Priority: P2)

Someone takes over `OneKeyFishingShare` and sets a password, kicks the addon's users or bans them. The addon users
move to the next fallback channel without the player seeing a password popup that stays, a chat line or a stuck
state. An addon user who becomes the owner of a locked channel clears its password.

**Why this priority**: a public channel name can be taken over by anyone; the exchange must survive it, but it is
rare, and the fallbacks were built and tested in spec 004.

**Independent Test**: the automated tests drive the notices seen in game on 2026-11-16 (their exact order and
arguments) through the channel module; in game, checklist steps 4 and 8 (a third account for the lock).

**Acceptance Scenarios**:

1. **Given** the addon joins a channel that has a password, **When** the game asks for it, **Then** the game's
   password popup is closed before the player can see it, and the addon moves to the next fallback.
2. **Given** the addon is in the channel, **When** a player who is not an addon user sets a password, **Then** after
   a short wait (in which an addon owner may clear it) the addon users move to the next fallback.
3. **Given** the channel's owner leaves and the ownership passes to an addon user while a stranger's password is
   set, **When** the new owner is told it owns the channel, **Then** it clears the password.
4. **Given** the addon user is kicked, **When** the combat or the wait after the kick ends, **Then** it joins again
   within about a minute; a third kick in a session counts as a ban.

---

### User Story 4 - A refusal by the server switches the channel off quietly (Priority: P2)

Blizzard may refuse addon messages in custom channels again, as it did on 2026-11-06. If the server answers the
addon's messages with a refusal, the addon stops using the channel for the session at once, without walking the
fallback channels (which the server would refuse too) and without any chat line. The exchange goes on over the other
paths.

**Why this priority**: the refusal already happened once; without this, every client would join and leave all six
channel names in turn, filling the channel list for nothing.

**Independent Test**: the automated tests send two refusals on the channel path and check the addon leaves, joins no
fallback, and reports the channel as refused in `/okf share` and `/okf debug`.

**Acceptance Scenarios**:

1. **Given** the addon is in the channel, **When** the server answers two of its messages with "not permitted in this
   channel", **Then** the addon leaves the channel, joins none of the fallbacks this session, and `/okf share` says
   why.
2. **Given** that refusal, **When** the player logs in again, **Then** the addon tries the main channel once more
   (the server may have changed back).
3. **Given** a send that the game refuses for a reason tied to one channel (a password, a ban, a mute), **When** it
   happens, **Then** the addon moves to the next fallback as before.

### Edge Cases

- **Older clients in the channel's name**: a 1.2.0 client never joins the channel; if it finds itself in one
  of the addon's names (a `/join` by hand) it leaves it at its next login. Nothing to do for them; they exchange over
  the other paths only.
- **A channel of the addon's names joined by hand** while the addon is elsewhere (a fallback, or not joined yet): the
  addon leaves it (1.2.0 behaviour, spec 004), unless the player joined it by hand after leaving the addon's own
  channel (the player's choice wins, checklist step 7).
- **The other faction** (V20): whether the channel reaches players of the other faction is not known (not checkable on
  a PvE realm, one faction per account). If the game keeps channels per faction, each faction has its own exchange
  through the channel (whether Battle.net game data crosses factions is not known either). Nothing in the code depends
  on it; the answer goes into `docs/forever-api.md` and the manual.
- **Layers**: whether the channel reaches players on another layer of a zone is not known; nothing depends on it.
- **Owner notices name the player in two shapes**: `OWNER_CHANGED` and `CHANNEL_OWNER` give "First Last",
  `SET_MODERATOR` only the first name. The addon decides ownership from the owner notices only.
- **"Interface action failed because of an AddOn"**: seen once on the second player's side during the `/run` owner
  test (its source unknown). The addon's own reactions to channel notices (closing the password popup, clearing a
  password) must not cause it; the in-game checks watch for it.
- **A server refusal right after a fallback move**: the channel stops for the session (User Story 4), whichever
  channel the refusal came on.
- **Trial or Veteran account**: cannot send addon data at all (the exchange's "unavailable" pause); the channel is not
  joined, as in spec 004.

## Requirements *(mandatory)*

### Functional Requirements

**Switching on**

- **FR-001**: The public channel MUST be part of the release again: the addon joins it, sends and receives through it,
  and every player-facing part of spec 004 comes back with it: the "Use the public channel" setting (account-wide, on
  by default, greyed out while the shared database is off), the notice that names the channel, the channel lines of
  `/okf share` and `/okf debug`.
- **FR-002**: A player who closed the notice of a version without the channel MUST see the notice once more, naming
  the channel, before the addon joins any channel (spec 004 behaviour, unchanged).
- **FR-003**: The behaviour that leaves a channel of the addon's names left joined by an earlier build MUST stay only
  where it still fits: at login a channel of its names that is not the one it will use is left; one the player joined
  by hand after leaving the addon's own channel is kept (spec 004 User Story 3 scenario 6, checklist step 7).

**Fitting the game's facts (2026-11-16)**

- **FR-004**: A join MUST count as done on `YOU_CHANGED` alone (no `YOU_JOINED` comes in Forever), and on the
  channel's number when no notice comes.
- **FR-005**: A password request for one of the addon's names MUST close the game's password popup in the same frame
  and mark that name locked for the session; the `WRONG_PASSWORD` notice that follows MUST NOT count as a second
  lock or start a second move.
- **FR-006**: Ownership MUST be read from `OWNER_CHANGED` and `CHANNEL_OWNER` (which name the player "First Last");
  `SET_MODERATOR` (first name only) MUST NOT change what the addon believes about ownership.
- **FR-007**: Player names in channel notices MUST be compared as the game gives them ("First Last"), through the same
  helper the rest of the exchange uses.

**A refusal by the server**

- **FR-008**: When the server refuses the addon's messages in the channel (`NOT_ALLOWED_IN_CHANNEL`, two on the current join as
  today), the addon MUST leave the channel and stop using every channel name for the rest of the session, without
  joining a fallback; the state MUST be visible in `/okf share` and `/okf debug`, and no chat line may appear.
- **FR-009**: At the next login the addon MUST try the main channel again.
- **FR-010**: Locks tied to one channel (password, ban, mute, kicks) MUST keep moving to the next fallback (spec 004).

**Quality**

- **FR-011**: Each change of behaviour MUST come with an automated test that fails without it; the tests that run the
  channel with the switch on MUST run with the shipped setting, not a test-only override.
- **FR-012**: `Exchange/Channel.lua` MUST be reviewed against the facts of `docs/forever-api.md` before the release;
  its comments that say "not shipped" or "V19" MUST be brought up to date.
- **FR-013**: Every new visible text MUST come with its nine translations; texts spec 004 already translated are
  reused.
- **FR-014**: The player manual (`OneKeyFishing/README.md`, which today says the addon joins no chat channel), the
  `CHANGELOG.md`, `CLAUDE.md`, `docs/architecture/exchange.md`, `docs/checklists/public-channel.md` and the
  verification rows of spec 004 that were closed as "not shipped" (V20-V25, V41) MUST be updated in the same change.

### Key Entities

- **Public channel**: one chat channel shared by addon users, under a fixed name and five fallbacks walked in the same
  order by every client; hidden from every chat window; one per client at a time.
- **Channel state**: in use (and which fallback), waiting (login delay), no free slot, left by hand, locked (every
  name locked this session, or refused: by the game for a Trial account, or, new, by the server, which turns the
  whole channel off until the next login; both show as "locked or refused by the game"), paused, off.
- **Channel session record**: what lasts until the next login and survives a `/reload` (left by hand, locked names,
  kicks, slot given up, a lock still waited on), and now the server refusal.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Two addon users who share no guild, group or friends list each count the other's catches within a few
  hours of play in the same session window.
- **SC-002**: Over a week of play with the channel on: 0 chat lines from the channel, 0 throttle errors, General and
  Trade on the same numbers at every login.
- **SC-003**: The longest exchange step stays under 5 ms with the channel in use (spec 004 SC-004).
- **SC-004**: When the server refuses the channel, the client joins at most one channel name that session (0 fallback
  walks).
- **SC-005**: The password popup of a locked addon channel is never left on the player's screen.
- **SC-006**: `npm run check` and `npm test` pass; the checklist `docs/checklists/public-channel.md` passes in game
  except the steps that need what the author cannot reach (the other faction), which are recorded as open.

## Assumptions

- The channel ships in release 1.3.0, together with the fishing sounds (spec 013), the catch kinds (spec 014)
  and the tech-debt fixes (spec 015), decided by the author on 2026-11-16; 1.3.0 then waits for this feature's
  in-game checks as well as V51, or the author releases it with the markers still open (`npm run build -- --force`,
  a release tag whose message says `--force`).
- The server's behaviour of 2026-11-16 holds; if it changes back, User Story 4 keeps the addon quiet.
- The code of spec 004 and its tests are the base; this feature changes what the facts require and the refusal
  handling, not the design (names, fallbacks, delays, budgets stay).
- The in-game checks need two accounts that share nothing for step 2 (a Battle.net friend exchanges over Battle.net
  too, which hides whether the channel carried the data) and a third account for the lock test; a PvP realm or a
  second faction is not available to the author, so V20 stays open.
- Only the addon's reactions are checked in game; the facts of the notices themselves were checked on 2026-11-16 by
  `/run` and are not checked again (the author's rule: no duplicate checks).
