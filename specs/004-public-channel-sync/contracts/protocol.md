# Contract: changes to the exchange protocol (`OKF1`)

Part 3 keeps the prefix `OKF1` and every message of `specs/003-guild-group-sync/contracts/sync-protocol.md`. All four
parts ship together in 1.2.0, so no released client speaks the part 2 form; the changes below are part of `OKF1`
from its first release. Values are starting values (constants in `Share.lua` and `Comm.lua`).

## Transport

| Path | Send | Receive | Used for |
| --- | --- | --- | --- |
| Channel (new) | `C_ChatInfo.SendAddonMessage("OKF1", text, "CHANNEL", Channel.GetNumber())` | `CHAT_MSG_ADDON`, chat type `CHANNEL`, from one of `Channel.NAMES` | `HELLO` only |

A peer heard in the channel has the address `w:<sender>`; its session goes by whisper, as for a guild peer. A
message from the channel that is not a whole `H` message is dropped, and so is a part of a long message from anyone
who is not in a session with this client (FR-010).

## Records

A record is `{ id, epoch, seq, proof, builds }`: `proof` (16 base32 characters) is new and required (data-model.md
"The version chain"). `seen` stays local and is stripped before encoding, as before.

## Accepting a record (changes to part 2 "A session")

- An item this client does not know is no longer a reason to refuse a record, and nothing about it is remembered
  (part 2 kept such versions out of the session; that rule is gone).
- A record of a blocked ID (the seed's `blocked`) is refused without ignoring its sender (the sender may run an
  older release) and is never wanted: its entries in a `DIFF` are skipped.
- A newer version of a unit held, or of a unit the seed absorbed in part, must pass `CatchDB.CheckVersion`
  (the chain to the held proof). Every record, newer or not, holds at most `STEP_SECONDS` = 180 s of casting per
  step of its seq (`CheckRecord`). A failing one is
  invalid data: the sender is ignored until logout. A long chain is walked over several frame steps; the session
  keeps running meanwhile (the merge is per record, as in part 2).

## Announcements in the channel

| What | Value |
| --- | --- |
| First channel `HELLO` | 30-90 s after joining (the join itself is 30-60 s after the login) |
| Channel rounds | every 30-50 min (random), each client on its own timer |
| After a move to a fallback channel | 5-30 s |
| A hearer starts a session | (measured in research R5: about 2 `SUM`s per channel `HELLO` in a network where every hash differs) with the chance `min(1, CHANNEL_TARGET / H)`, where `H` is the number of channel `HELLO`s it heard in the last 40 minutes (about the number of clients in the channel) and `CHANNEL_TARGET` is 2; then the part 2 rules (one session at a time, 2 min between starts, 30 min with the same peer) |
| Near peers first | a hearer does not start a session with a channel peer while a guild, group or friend peer heard in the last 15 min has a different hash and is about to get a session (its start is armed, its busy retry is due, or it waits for a session or a start to be over), also when the channel start's delay ends; a near peer that only waits for its cooldown, or that nothing will start a session with, does not block the channel |
| A near peer answers `BYE busy` | the initiator tries that peer again once, 120-180 s later (part 2 waited for the next `HELLO`) |
| A near peer's `HELLO` comes while this client is in a session | the peer is considered again when the session ends (2-20 s wait, the usual checks) |

Per sender, the part 2 limits apply unchanged (`HELLO` at most 1 per 60 s, message and record limits, ignored until
logout). At most 300 peers whose only path is the channel are kept in memory; the one heard longest ago goes first.

## What is never sent

Unchanged from part 2: no character names, no guild names, no anonymous ID together with a `HELLO`, no session
times, no gear. The chain's secret is never sent; only the link of the record's seq is.
