# In-game checklist: the catch exchange with guild, group and friends

**Feature**: the exchange of catch data with the guild, the group and friends (`specs/003-guild-group-sync`,
part 2 of the shared catch database).
**Closes**: V16, V17, V18 of `specs/003-guild-group-sync/verification.md`, and the feature side of V10-V14 (their
API side is closed by [spike.md](spike.md), which runs first).
**Needs**: a second player **B** with the addon (a friend, or a second account; a second game client on the same PC
works). Full accounts for both: Trial and Veteran accounts cannot send addon data. A third player or account **C**
for step 7. Steps marked "B" are done on the second client.

## Setup

1. Install the build on both clients (`npm run install-addon`), or link the working folder once (`npm run link`);
   restart the game completely (new files in the TOC).
2. Both log in on characters that have learned Fishing.

## Steps

1. [ ] **Popup** (V17): A logs in after the update and sees the popup once. "Settings" opens "Shared database" with
   the setting on. After `/reload` the popup does not come back; on another character of the account neither.
2. [ ] **Group** (V10, V11, V17): A and B fish at different places (a few casts each), then form a group. Within
   5 minutes each one's "What can be caught here" at the other's place shows the other's catches, "from 2 players".
   The chat shows nothing at any point, and the addon joins no chat channel (the public channel is off, spec 010).
3. [ ] **Guild, friends, Battle.net** (V10, V11, V13, V17): repeat without a group, after both relogged:
   - [ ] A and B in one guild: within 30 minutes.
   - [ ] Only on each other's character friends list: within 30 minutes; `/okf share` counts B once among the
     friends heard, and when B logs out during an exchange no "No player named" line shows (V11, V12, spec 010).
   - [ ] Only Battle.net friends: within 30 minutes.
4. [ ] **Status** (V17): the status line in the tab and on the settings page shows the exchange ("Exchange:
   1 players, ... ago"). `/okf share` shows the peers heard, the last exchange and the traffic.
5. [ ] **Pauses** (V14, V17): enter combat, then a dungeon: `/okf share` says paused and why. Outside, the exchange
   resumes (the status line goes back to the exchange).
6. [ ] **Setting off** (V17): B turns the setting off: A's data disappears from B's tab, and `/okf share` says off.
   `/okf share` on A shows no new exchange with B. Turning it on brings the data back at once.
7. [ ] **Relay** (V17): C exchanges only with A (a group of A and C). After A meets B, B sees C's catches.
8. [ ] **Offline peer** (V12): B logs out in the middle of an exchange (right after a group join): no line about it
   appears in A's chat.
9. [ ] **Debug** (V17, V18): `/okf debug` has the "Shared database" section, with no names and no anonymous ID. Note
   the line "own record offered: yes, N bytes encoded for P places" after fishing at several places: N / P times
   500 stays under 24 KB (otherwise lower `ROLL_PLACES` in `CatchDB.lua`). Value: 2026-11-06, one place: the section
   has no names and no ID; "156 bytes encoded for 1 places" (one place is mostly the record's fixed part, so no
   estimate yet: read it again after fishing at many places).
10. [ ] **Performance** (V16): watch the frame rate while a session runs and while the tab is open. For a load
    test, copy many records into the saved data (or use `tests/exchange/share/load_test.lua` as a model); login takes no
    noticeable extra time, and the longest merge step in `/okf debug` stays under 5 ms. Value: ____
11. [ ] **Harvest** (US4): before the release, `npm run harvest` on the author's PC lists other players'
    contributions ("Contributions: N"), and a client that updates to that release shows the same counts as before.
    B, who fished on after A's client last got B's record, keeps those catches: after the update B's `/okf debug`
    still offers its record, and B's newer catches reach the next harvest.
12. [ ] **Refused account** (V10): with a Trial or Veteran account in a guild, after an hour of HELLO rounds the
    status line says "Exchange unavailable: the game refuses addon messages" (not "Nobody to exchange with").

## Results

- Date, build, client languages, second player:
- Problems found:

What happens next is in [release-plan.md](../release-plan.md).
