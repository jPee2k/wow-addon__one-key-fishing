# In-game checklist: Catch Data Exchange (part 2)

What to check in the game for the exchange of catch data with the guild, the group and friends
(`specs/003-guild-group-sync`), on and after the game launch on 2026-11-04. The feature was built before the game
could be played, on the assumptions V10-V18 of `specs/003-guild-group-sync/verification.md`; each step below says
which ones it closes. Tick each box, note anything that looks wrong, and paste the `/okf spike` reports back: the
answers go into `CLAUDE.md` "Known API facts", and the `VERIFY` markers in the code are removed only after that.

**A second player is needed**: a friend with the addon, or a second account (a second game client on the same PC
works). Steps marked "B" are done on the second client. Trial and Veteran accounts cannot send addon data, so use
full accounts for both.

## Setup

1. Install the build into the game on both clients (or link the working folder once with `npm run link`):

   ```bash
   npm run install-addon
   ```

2. Restart the game completely. New files were added to the TOC (`Comm.lua`, `Share.lua`), so `/reload` is not
   enough.
3. Run the spike part in the same game session as the spike steps of part 1 (`docs/checklists/catch-database.md`):
   `Spike.lua` is removed once both are done.

## Part 1: Spike (game facts)

`/okf spike` opens a window with a report; its "Network (V10-V15)" section is at the end. Copy it (Ctrl+A,
Ctrl+C) and keep each one. Run it twice a few seconds apart: echoes of the test messages show in the second
report.

- [ ] **N1. Guild and group** (V10, V11): in the open world, run `/okf spike` in a guild, then again in a group with
  B. Expected: `RegisterAddonMessagePrefix` and the `GUILD`, group and `WHISPER to self` results are `0`, an echo
  arrives for each, and the sender is shaped `Name-Realm`. Report: ____
- [ ] **N2. Offline whisper** (V12): note the result of the whisper to the made-up name (expected `12`,
  `TargetOffline`, or `0`) and whether a "No player named ..." line appeared in chat. Report: ____
- [ ] **N3. Battle.net** (V13): with B online in Forever as a Battle.net friend, the counts show at least one
  game account "on this project", and `SendGameData to the first` is `0`. Report: ____
- [ ] **N4. Restrictions** (V14): in the open world out of combat every restriction is `false`, and so is
  `InChatMessagingLockdown` (`AreOutgoingAddonChatMessagesRestricted` is expected `true` on a normal realm: it is
  about chat messages addons send and does not pause the exchange; note its value). If possible, run it again in a dungeon
  and during a boss fight and note what turns `true`. If anything is `true` in the open world, stop here and
  report it: the exchange cannot run there. Report: ____
- [ ] **N5. Encoding** (V15): the round trip line says `equal`, with an encoded length and `Base64 characters
  only: true`. Report: ____
- [ ] **N6. Client constants** (V13): note `BNET_CLIENT_WOW` and `WOW_PROJECT_ID` (expected `WoW` and `18`).
- [ ] **N7. Report back**: paste all reports into the conversation.

## Part 2: The feature (A and B, both with the addon)

- [ ] **1. Popup** (V17): A logs in after the update and sees the popup once. "Settings" opens "Shared database"
  with the setting on. After `/reload` the popup does not come back; on another character of the account neither.
- [ ] **2. Group** (V10, V11, V17): A and B fish at different places (a few casts each), then form a group. Within
  5 minutes each one's "What can be caught here" at the other's place shows the other's catches, "from 2
  players". The chat shows nothing at any point.
- [ ] **3. Guild, friends, Battle.net** (V10, V11, V13, V17): repeat without a group, after both relogged:
  - [ ] A and B in one guild: within 30 minutes.
  - [ ] Only on each other's character friends list: within 30 minutes.
  - [ ] Only Battle.net friends: within 30 minutes.
- [ ] **4. Status** (V17): the status line in the tab and on the settings page shows the exchange ("Exchange: 1
  players, ... ago"). `/okf share` shows the peers heard, the last exchange and the traffic.
- [ ] **5. Pauses** (V14, V17): enter combat, then a dungeon: `/okf share` says paused and why. Outside, the
  exchange resumes (the status line goes back to the exchange).
- [ ] **6. Setting off** (V17): B turns the setting off: A's data disappears from B's tab, and `/okf share` says
  off. `/okf share` on A shows no new exchange with B. Turning it on brings the data back at once.
- [ ] **7. Relay** (V17): a third player or account C exchanges only with A (a group of A and C). After A meets B,
  B sees C's catches.
- [ ] **8. Offline peer** (V12): B logs out in the middle of an exchange (right after a group join): no line about
  it appears in A's chat.
- [ ] **9. Debug** (V17, V18): `/okf debug` has the "Shared database" section, with no names and no anonymous ID.
  Note the line "own record offered: yes, N bytes encoded for P places" after fishing at several places: N / P
  times 500 stays under 24 KB (otherwise lower `ROLL_PLACES` in `CatchDB.lua`).
- [ ] **10. Performance** (V16): watch the frame rate while a session runs and while the tab is open. For a load
  test, copy many records into the saved data (or use `tests/share_load_test.lua` as a model); login takes no
  noticeable extra time, and the longest merge step in `/okf debug` stays under 5 ms.
- [ ] **11. Harvest** (US4): before the release, `npm run harvest` on the author's PC lists other players'
  contributions ("Contributions: N"), and a client that updates to that release shows the same counts as before.
  B, who fished on after A's client last got B's record, keeps those catches: after the update B's `/okf debug`
  still offers its record, and B's newer catches reach the next harvest.
- [ ] **12. Refused account** (V10): with a Trial or Veteran account in a guild, after an hour of HELLO rounds the
  status line says "Exchange unavailable: the game refuses addon messages" (not "Nobody to exchange with").

## After the checklist

1. Record the answers in `CLAUDE.md` "Known API facts"; fix the code where an assumption was wrong (with tests).
2. Remove the `VERIFY(V10)` to `VERIFY(V16)` and `VERIFY(V18)` markers that are closed and tick V10-V18 in
   `specs/003-guild-group-sync/verification.md`.
3. The spike removal and the release are the steps of `docs/checklists/catch-database.md` "After the checklist";
   all four parts of the shared catch database ship together as 1.2.0.
