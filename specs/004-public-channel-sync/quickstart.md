# Quickstart: validating the public channel

How to show that part 3 works: first without the game (every change), then the spike and the in-game checklist after
the launch on 2026-11-04. Details live in [contracts/](contracts/), [data-model.md](data-model.md) and
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

## The spike (launch day, research R13)

`/okf spike` gets a "Chat channel (V19-V27)" section. It joins a test channel with a random name, so the real one is
never created by a test. Run it in the open world, out of combat; for steps 6 and 7 a second player (a friend, or a
second account of the other faction) joins the test channel name the report prints.

1. Slots: `MaxChatChannels`, `C_ChatInfo.GetNumActiveChannels()`, and the "too many channels" text as the addon
   will look for it.
2. Joining: what `JoinTemporaryChannel` returned, the notice tokens and their events, the channel number; whether a
   chat window listed the channel before and after the removal.
3. Sending: the result of an `OKFSPIKE` addon message to the channel and, for its echo, the chat type and the shapes
   of the `target` and `name` arguments (not the sender's name).
4. Ownership: whether the player owns the new channel; the notices after setting and clearing a password on it.
5. Numbers: the channel numbers before the join and after the leave are the same (yes or no; no channel names).
6. Reach: echoes from the second player (same layer, another layer, the other faction, as the author notes them).
7. Lock: after the second player sets a password, the notices the first one gets; on a fresh join, whether the
   password prompt came and was closed (the author notes any flash).
8. The hash: whether `bit` exists, its raw results for `bnot(0)` and `band(-1, 4294967295)`, `ns.SHA256("abc")`
   against the known digest, and the time of 64 proof steps.
9. Unknown items: how many item IDs of the bundled data the game does not know or says do not exist; the result of
   asking the game to load one of them.

The author pastes the report into the conversation; the answers go into `docs/forever-api.md` and close V19-V27
(verification.md).

## In game: the feature (after the spike, V29)

Three accounts make it complete (A and B for the exchange, C for the lock test); two show everything but the lock.
`docs/checklists/public-channel.md` holds the checklist with report blanks; in short:

1. **Hidden** (US1): A logs in; after a minute the channel exists (`/okf share`: "in use"). It is in no chat window
   or tab; the Chat Channels window and Chat Settings list it as `OneKeyFishingShare`. General and Trade keep their
   numbers. Typing into it from C (`/join OneKeyFishingShare`, then text) shows nothing on A.
2. **Strangers** (US1): A and B share no guild, group or friends list, fish at different places and stay online;
   within a few hours each one's tab counts the other's catches and "from K players" includes the other.
3. **Not fishing** (US1): A stays in the channel outside fishing mode.
4. **Lock** (US1, FR-005a): C joins the channel first or takes it over and sets a password; A and B move to
   `OneKeyFishingShare2` (`/okf share`: "in use (fallback channel 2)") and keep exchanging; nothing shows in chat and
   no password prompt stays on screen. When C leaves and A becomes the owner of a locked channel, A clears the
   password.
5. **Slots** (FR-005): A joins channels by hand until 19 are taken: the addon leaves with one line; the next join by
   hand works; leaving two channels brings the addon back.
6. **Setting** (US3): the channel setting off leaves the channel at once, the guild exchange goes on, data from B
   stays counted; on joins at once; with the main setting off the channel setting is greyed out.
7. **Left by hand** (US3): `/leave` the channel: the addon stays out until the next login.
8. **Notice** (US3): a fresh install shows the notice naming the public channel; nothing joins before it is closed.
9. **Unknown items** (US2): if an item of the bundled data is unknown to the client, the tab shows an "Unknown item"
   row with its ID in the tooltip.
10. **A week** (SC-004, SC-005, V28): normal play with the channel on: no chat line, no throttle error, General and
    Trade numbers right on every login, the longest step in `/okf debug` under 5 ms.
11. **Harvest** (US4, SC-010): before the release, `npm run harvest` lists contributions from players outside the
    author's guild, group and friends; the outlier report is read, and any block is made with `--block`.
