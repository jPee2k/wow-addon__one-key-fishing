# Research: The Public Channel Returns

The facts this feature stands on were seen in game on 2026-11-16 by `/run` tests (two players, then a level 4
character; `docs/forever-api.md` "Verified in game", `specs/004-public-channel-sync/verification.md` V19-V25). Each
item below compares one fact with `Exchange/Channel.lua` and `Exchange/Comm.lua` as they stand after spec 010.

## R1. A refusal by the server stops the channel for the session

- **Decision**: the server's `NOT_ALLOWED_IN_CHANNEL` notice (two on the current join, as today; a notice is never cleared by a successful send, since its send returned success too) marks the
  channel refused by the server for the session: the addon leaves and joins no fallback until the next login. A
  refused *send* result on the channel path (`InvalidChannel`, `GeneralError` when moderated or muted, any other)
  keeps locking only the current name and moving on, as today.
- **Rationale**: on 2026-11-06 the server refused every custom channel the same way (the test channel, a channel the
  player owned, `OneKeyFishingShare`): the refusal belongs to the server, not to one name. Today two notices call
  `Channel.OnRefused`, which locks the current name, joins the next, gets refused again and walks all six names, each
  one a join, a leave and a chat channel slot for nothing (SC-004). A real login tries again (FR-009): the session
  record that carries `refused` across a `/reload` is dropped at a real login already.
- **Alternatives considered**: a timed retry within the session (the server changed back once in ten days; an hourly
  retry adds a join every hour for every client while it is refused); a saved flag across logins (a player would stay
  without the channel after the server is fixed).

## R2. The password flow as seen

- **Decision**: no code change. Seen: `CHANNEL_PASSWORD_REQUEST` (the channel name) comes first, then the notice
  `WRONG_PASSWORD`; `GetChannelName` gives 0; Blizzard's popup stays until closed. The code hides the popup and locks
  the index on the request; `Lock` leaves and joins the next index, so `current` has moved when `WRONG_PASSWORD`
  arrives, and `OnNotice` returns early for an index that is not the current one (FR-005). A test drives the exact
  order (request, then the notice) and checks one lock, one move, no second leave.
- **Rationale**: the code was written for this order (research R4 of spec 004); a test makes the order explicit.
- **Risk**: closing the popup from addon code was not seen; the one "Interface action failed because of an AddOn"
  line in the owner test came from a `/run` session that never closed a popup, so it says nothing about the addon.
  Checklist step 4 watches for it (V21).

## R3. Ownership notices

- **Decision**: no code change; a test pins it. `OWNER_CHANGED` names the new owner in argument 2 ("First Last"),
  `PASSWORD_CHANGED` the actor in argument 2 with argument 5 empty, as the code reads them. `SET_MODERATOR` (first name
  only) reaches no branch of `OnNotice`, so ownership never follows it (FR-006). `IsMe` compares with
  `ns.SameCharacter` against `ns.PlayerName()` (FR-007).
- **Rationale**: the `/run` test printed exactly these arguments.

## R4. The switch and the tests

- **Decision**: `Channel.AVAILABLE = true`. The switch stays as the kill switch if the server refuses again for good.
  The test stub flips: the flag `channel_on` goes, and a new flag `channel_off` (before loading) sets
  `Channel.AVAILABLE = false` for the tests of a release without the channel (`off_test`, the two `*_nochannel` UI
  tests). Every other test runs the channel as shipped (FR-011).
- **Rationale**: tests that need a flag to switch the shipped behaviour on would pass while the release ships it off;
  the default must be what players get.

## R5. VERIFY markers back in the channel code

- **Decision**: the comments "(not shipped, V19)" in `Channel.lua` and `Comm.lua` become `-- VERIFY(Vn): ...`
  markers again, one per assumption only the game confirms, with the IDs of `specs/004-public-channel-sync/verification.md`
  (V21 hiding and the popup, V22 the join delay and numbers, V23 the limit line's event, V24 kicks and bans, V25 the
  throttle, V41 the leave echoes): those rows were reopened on 2026-11-16 and say what was seen since. One new
  assumption gets its own ID, **V53** in `specs/016-public-channel-return/verification.md`: `CommReceive.lua` keeps a
  channel message only when `CHAT_MSG_ADDON` names the addon's channel in argument 8 (or 5), and the `/run` tests of
  2026-11-16 printed neither (spec 004 never listed it, since V19 failed before it could be seen).
- **Rationale**: constitution Principle IV and the hard rule of `CLAUDE.md`: code built on an assumption only the
  game confirms carries a marker, and `npm run build` refuses to package while one is left, so release 1.3.0 cannot
  ship before the checklist ran or the author accepted each row.
- **Alternatives considered**: moving every row into a new `verification.md` for spec 016 (the assumptions are
  those of spec 004 and its rows already hold the history; only V53 is new).

## R6. What comes back with the switch

- **Decision**: nothing to build. The notice (`ShareGame.lua` `NoticeOwed`: owed again while `shareNoticeChannel` is
  false, which a 1.2.0 close never set), the settings checkbox (`UI/Settings.lua`), `/okf share` and `/okf debug`
  lines and the channel rounds of `Share` are behind `Channel.AVAILABLE` and return with it. The texts and their nine
  translations are still in `Locales/` (spec 010 kept them). The player manual's paragraph comes back from the text
  removed in commit `984eed2` (spec 010), updated with the facts of 2026-11-16.
- **Rationale**: spec 010 switched the channel off without removing it.

## R7. The state shown for a refusal

- **Decision**: no new player-visible state. A refusal by the server shows as today's "locked" state with its text
  "Public channel: locked or refused by the game" (already translated); `/okf debug` names the reason
  (`refused server` or `refused game` for a Trial account or an invalid name).
- **Rationale**: FR-013 prefers reused texts; the player needs to know the channel is not in use, the reason is for
  bug reports.
