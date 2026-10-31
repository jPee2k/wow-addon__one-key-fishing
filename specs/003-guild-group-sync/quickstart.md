# Quickstart: validating the Catch Data Exchange

## Automated

```text
npm run check      # new globals in .luacheckrc; open VERIFY markers listed (V1-V9 of part 1 and V10-V18)
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

## In game

The in-game steps live in `docs/checklists/`: [spike.md](../../docs/checklists/spike.md) prints the game facts
(V10-V15) with `/okf spike`, then [catch-exchange.md](../../docs/checklists/catch-exchange.md) checks the feature; the order of everything is
`docs/release-plan.md`.
