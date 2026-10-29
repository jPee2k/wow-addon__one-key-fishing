# Quickstart: validating the Catch Data Exchange

## Automated

```text
npm run check      # new globals in .luacheckrc; open VERIFY markers listed (V1-V9 of part 1 and V10-V17)
npm test           # share, comm, catchdb, catchhere and harvest tests plus the existing ones
npm test -- share
```

Expected: both pass. The tests cover:

- **Convergence**: three or more nodes over guild, group, whisper and Battle.net paths in different orders end
  with the same records and the same counts, and nothing is counted twice (SC-003, FR-003, FR-010). This includes
  a record that reaches a node twice by different paths.
- **Absorbed units**: a version a newer seed holds whole is not wanted and is deleted at login; a newer version of
  a unit the seed holds in part is kept and passed on but not counted (FR-014, SC-008).
- **Own record**: a copy of the own record coming back from the network is refused (FR-012).
- **Rejects**: broken, invalid, unwanted and flooding data is refused (FR-011).
- **Crossing sessions**: two clients that start an exchange with each other at once end with one session.
- **Game node**: the `HELLO` triggers (login, group join), the friend rotation and the pause messages work; after a
  session no peer name is in the saved data (FR-009); a group join leads to an exchange within 5 simulated minutes
  (SC-001).
- **Size limit**: the eviction order applies at the limit, and the own record is never deleted (FR-013).
- **Comm**: the framing and out-of-order joining, the pace, the hourly budget, the back-off on each result code,
  the paths the game keeps refusing, and the chat filter (FR-004, FR-005, SC-005).
- **Pauses and the setting**: combat, an instance, a loading screen and a restriction pause the exchange; with
  sharing off nothing is sent or accepted (FR-002, FR-020, SC-007).
- **The tab**: "All" with and without sharing; the player count; the status line; new data shows without
  reopening (FR-015 to FR-018).
- **Harvest**: an author file that holds other players' records puts each into the seed once (FR-025).

## In game: spike (after the game launch on 2026-11-04)

Needs a guild, or a second player or a second account for steps N1 and N3. With `/okf spike` after
`npm run install-addon` (or `npm run link`) and a game restart:

- **N1. Guild and group.** In the open world, run `/okf spike` in a guild and again in a group. Note the send
  results, whether each echo arrived, and the sender pattern. (V10, V11)
- **N2. Offline whisper.** Note the result for the made-up name, and whether a "No player named ..." line appears in
  chat. (V12)
- **N3. Battle.net.** With a Battle.net friend online in Forever, note the friend counts and the send result. (V13)
- **N4. Restrictions.** Note the restriction state lines in the open world. If possible, note them again in a
  dungeon and during a boss fight. (V14)
- **N5. Encoding.** Note the round-trip line and the encoded length. (V15)
- **N6. Client constants.** Note the `BNET_CLIENT_WOW` and `WOW_PROJECT_ID` values. (V13)
- **N7. Report back.** Paste the report back. The facts go into CLAUDE.md "Known API facts", the code is adjusted
  where needed and the `VERIFY` markers are removed.

## In game: the feature (two players, A and B, both with the addon)

1. **Popup.** A logs in after the update and sees the popup once. "Settings" opens "Shared database" with the
   setting on. After `/reload` the popup does not come back. (FR-021)
2. **Group.** A and B fish at different places, then form a group. Within 5 minutes each one's "What can be caught
   here" at the other's place shows the other's catches, "from 2 players". The chat shows nothing. (SC-001, FR-004)
3. **Guild, friends, Battle.net.** Repeat without a group:
   - A and B in one guild: within 30 minutes. (SC-002)
   - Only on each other's character friends list.
   - Only Battle.net friends.
4. **Status.** The status line in the tab and on the settings page shows the exchange. `/okf share` shows peers,
   the last exchange and the traffic. (FR-017, FR-022)
5. **Pauses.** Enter combat, then a dungeon: `/okf share` says paused and why. Outside, the exchange resumes.
   (FR-002)
6. **Setting off.** B turns the setting off: A's data disappears from B's tab, and `/okf share` says off. With
   `/okf share` on A, no new exchange with B appears. Turning it on brings the data back at once. (FR-020, SC-007)
7. **Relay.** A third player C exchanges only with A. After A meets B, B sees C's catches. (FR-003)
8. **Debug.** `/okf debug` has the "Shared database" section with no names and no IDs. (FR-023)
9. **Performance.** Watch the frame rate while a session runs and while the tab is open with many records. Login
   takes no noticeable extra time, and the longest step in `/okf debug` stays under 5 ms. (SC-006, V16)
10. **Harvest.** Before the release, `npm run harvest` on the author's PC lists other players' contributions, and a
    client that updates to that release shows the same counts as before. (US4, SC-008)
