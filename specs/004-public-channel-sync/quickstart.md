# Quickstart: validating the public channel

How to show that part 3 works: first without the game (every change), then in game after the launch on 2026-11-04. Details live in [contracts/](contracts/), [data-model.md](data-model.md) and
[verification.md](verification.md); this page only says what to run and what to expect.

## Without the game (every change)

```text
npm run check        # Lua 5.1 syntax, globals, line length, packager keywords, the seed's proofs and blocked
npm test             # every test, the channel simulation at its default size included
```

Expected: both pass. The part 3 tests (research R14):

| Test | Shows |
| --- | --- |
| `proof_test.lua` | SHA-256 test vectors; a chain made by the owner verifies; a made-up newer version is refused; a record with more than 180 s of casting per step of its seq is refused; the owner's next real version is accepted after a made-up one; a seed proof anchors an absorbed unit; a long chain is walked in steps of at most `PROOF_STEPS` links (SC-007) |
| `catchdb_weights_test.lua` | one made-up contribution with 10,000 catches moves no chance by more than 20 points at a spot with 5+ contributions; the own catch is not scaled; under 5 contributions nothing is scaled; `catches` stays the raw sum (SC-006) |
| `catchdb_items_test.lua` | an item reported by 1 or 2 other IDs on a map is left out, by 3 it is shown; seed and own items are always shown; an unknown item is kept, counted and comes with `known = false`, `reporters`, `inSeed` |
| `channel_test.lua` | the join waits for the login delay and two free slots; the channel is removed from chat windows; the filters drop its notices and typed text; a lock moves to the next name, a kick rejoins, three kicks count as a ban; leaving by hand stays out; the player's limit makes the addon give way with one line; the setting and `Channel.AVAILABLE = false` |
| `share_channel_test.lua` | only whole `H` messages are taken from the channel; the chance to start a session; near peers first and the busy retry; at most 300 channel peers kept; `heard.channel` |
| `share_store_test.lua` (extended) | the eviction classes; blocked IDs refused, cleaned up and not offered; records without a proof cleaned up |
| `comm_test.lua` (extended) | the channel path and its refusals (a fresh count per channel); parts only from the session peer; the 128 KB cap of all part buffers; a sender flooding parts reported and dropped |
| `channel_sim_test.lua` | many protocol nodes in one fake channel: spread, requests per announcement, budget, a lock and the move to a fallback (SC-001, SC-002, SC-011, scaled) |
| `catchhere_test.lua`, `settings_test.lua`, `share_notice_test.lua` (extended) | the "Unknown item" row and tooltip; the channel setting greyed out with the main one off; the notice that names the channel, and shown again when the channel comes later |
| `harvest_test.mjs` (extended) | chain checks between versions and the casting limit; blocked IDs left out of the sums and `absorbed`; `--block` / `--unblock`; the weight limit in the seed's cells; `proofs` and `blocked` written and checked; the outlier report |

The full-size simulation (500 clients for the spread, 1,000 for the requests per announcement) is slower; run it
before the release:

```text
OKF_SIM_NODES=1000 npm test -- channel_sim
```

Expected: in the cold hour (nobody holds anybody's record) at most 5 requests per announcement on average and no
client over 50 KB in an hour (SC-002, SC-003); in the warm network (everybody holds everybody's record) at least 90%
of the clients hold a changed contribution within 3 simulated hours (SC-001); and 90% meeting again in one fallback
channel within 15 minutes after a lock (SC-011). Measured numbers and run times: research.md R5.

Measured on 2026-10-30 (constants of research R5 unchanged):

| Clients | Requests per announcement (cold) | Busiest hour, `BYE` aside (cold) | Changed contribution at hour 3 (warm) | Met again after a lock | Run time |
| --- | --- | --- | --- | --- | --- |
| 60 | 2.05 | 50,895 bytes | 100% | 100% | 14 s |
| 120 | 2.09 | 51,144 bytes | 99% | 100% | 43 s |
| 500 | 2.07 | 51,152 bytes | 100% | 100% | 25 min |
| 1,000 | 2.07 | 51,149 bytes | stopped at 30 min | not reached | 27 min for the cold hour |

## In game

The in-game steps live in `docs/checklists/`: [spike.md](../../docs/checklists/spike.md) prints the game facts
(V19-V27) with `/okf spike`, then [public-channel.md](../../docs/checklists/public-channel.md) checks the feature; the order of everything is
`docs/release-plan.md`.
