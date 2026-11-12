# Contract: the exchange protocol (`OKF1`)

What two clients send each other. The prefix `OKF1` carries the protocol version: a client ignores every other
`OKF` prefix (FR-007), and a change that breaks this contract needs a new digit. Values are starting values; they
live as constants in `Comm.lua` and `Share.lua` (research R7).

## Transport

| Path | Send | Receive | Used for |
| --- | --- | --- | --- |
| Guild | `C_ChatInfo.SendAddonMessage("OKF1", text, "GUILD")` | `CHAT_MSG_ADDON`, channel `GUILD` | `HELLO` |
| Group | `... "RAID"` when `IsInRaid()`, else `"PARTY"` (home group only) | channel `RAID` / `PARTY` | `HELLO` |
| Whisper | `... "WHISPER", name` | channel `WHISPER`, sender `Name-Realm` | `HELLO` to friends, every session message |
| Battle.net | `C_BattleNet.SendGameData(gameAccountID, "OKF1", text)` | `BN_CHAT_MSG_ADDON` (prefix, text, channel, senderID) | `HELLO` to Battle.net friends, sessions with them |

A peer's address is `w:<sender>` or `b:<gameAccountID>`; a session always goes back over the path its `HELLO`
came by (a guild or group `HELLO` -> whisper to the sender).

## Messages

Every message is at most 255 bytes, ASCII only, and starts with the single letter of its type: `H` (`HELLO`), `S`
(`SUM`), `D` (`DIFF`), `W` (`WANT`), `R` (`REC`), `B` (`BYE`); a message of any other type is ignored. `<sid>` is a
2-character session ID (base32) chosen by the initiator; all session messages carry it right after the letter.

| Message | Form | Sent by | Meaning |
| --- | --- | --- | --- |
| `HELLO` | `H <node> <epoch> <count> <hash>` | everyone | "I am here": node tag of this login (4 base32), seed epoch, units held (the numbers in decimal), whole-database hash (7 base32) |
| `SUM` | `S<sid> <h1><h2>...<h32>` | initiator | the 32 bucket hashes, 7 base32 characters each, buckets in base32 order |
| `DIFF` | `D<sid> <buckets> <entry> <entry> ...` | both | the buckets that differ (their base32 characters, one word) and every `id.epoch.seq` the sender holds in them (none when it holds nothing there) |
| `WANT` | `W<sid> <id@epoch> ...` | both | the units the sender wants from the other side (may be empty: then just `W<sid>`) |
| `REC` | `R<sid> <data>` | both | one record, `EncodeBase64(CompressString(SerializeCBOR(record)))` |
| `BYE` | `B<sid> <reason>` | both | `sent` (I sent all you wanted, or all the limit allowed), `done` (the session is over), `busy`, `limit`; the receiver ends the session on any other reason |

A message longer than 255 bytes is sent in parts: `<type><sid>#<msg>.<part>.<total> <chunk>`, where `<msg>` is a
per-sender counter (base32, always 2 characters) and parts are numbered from 1. The receiver joins the chunks by part
number (Battle.net delivery is unordered), keeps at most 64 KB of parts per peer and drops a message whose parts
did not get a new part for 15 s (a 32 KB record takes over a minute at the whisper pace). `HELLO` and `BYE` always fit one message.

## A session

`A` broadcasts `HELLO`; `B` hears it.

```text
B: the hash differs, B is not paused, not in a session, within budget, and the cooldowns allow it
   (a new session at least 2 min after the last one started; with A at most once per 10 min in a group,
   30 min otherwise) -> waits a random 2-20 s, re-checks
B -> A  SUM
A -> B  BYE busy | limit                         (A in another session or answered B's last SUM with a DIFF
                                                  less than 8 min ago; over budget). A paused node or one with
                                                  sharing off drops the SUM unanswered: B times out
A -> B  BYE done                                 (all bucket hashes equal: both refresh `seen` of every unit)
A -> B  DIFF <differing buckets> <A's entries>   (equal buckets: A refreshes `seen` of their units)
B -> A  DIFF <same buckets> <B's entries>        (B refreshes `seen` of units equal on both sides)
B -> A  WANT <units B wants>                     (A holds a newer seq, or B lacks it, and B's seed does not hold
                                                  that version whole)
A -> B  WANT <units A wants>
A -> B  REC ... REC, then BYE sent               (B's wants, own first, newest first, within 8 KB and 25 records, at least one)
B -> A  REC ... REC, then BYE done               (after A's BYE sent and B's own sends)
```

- Each received `REC` is decoded and checked (research R6) one per frame step, then stored per `id@epoch`
  (data-model.md). A `REC` that was not wanted, does not decode or fails the check makes the sender ignored until
  logout; the session ends.
- A relayed record is checked again before it is sent (it passed the check when it was stored, but the saved file
  may have been damaged since): a damaged one is dropped, not sent, so an honest client is never ignored for it.
- No message from the peer for 15 s, or 5 min since the session started however busy it is (parts alone must not
  hold the one session slot): the session is dropped without a message and the peer is paused for 30 min, or until
  its next `HELLO` (a peer that paused for combat greets again when the pause ends). `TargetOffline` on a send has
  the same effect.
- A pause (research R8) or turning sharing off drops the running session without a message.
- Only the hearer of a `HELLO` starts a session, and `A` takes one at a time; another hearer gets `BYE busy` and
  tries again after `A`'s next `HELLO`.
- The cooldowns are kept by the initiator; the responder keeps its side too: a `SUM` from a peer it answered with
  a `DIFF` less than 8 min ago (the 10 min group cooldown less 2 min for the initiator's queue) gets `BYE busy`, so a
  peer that ignores the cooldowns cannot spend the hourly budget on `DIFF`s. A `SUM` that could not be sent (the
  budget, a path left out) starts no session, sends no `BYE` and spends no cooldown.
- Crossing `SUM`s: when `A` and `B` heard each other and each sent `SUM` to the other, the one with the smaller node
  tag (from the other's `HELLO`, compared as strings) stays the initiator and drops the other's `SUM` without an
  answer; the other drops its own session and answers the `SUM` as the responder. Equal tags: both drop their
  sessions and wait for the next `HELLO`. The rule also holds when the two know each other by different addresses
  (one heard the other's guild `HELLO` first, the other its Battle.net one): a `HELLO` by a second path notes the
  tag on that address too, and a `SUM` is matched to the session by the tag, not the address. The tag is noted only
  on an address of the other kind (a client has one whisper and at most one Battle.net address), so a tag heard in
  the guild cannot be used from another name to take over a session; both addresses then carry the cooldown.
- Units wanted but not sent because of the 8 KB limit, or because the hourly budget would not let the next record
  out whole, come in a later session: the records just end, with `BYE sent` / `BYE done` as usual (`BYE limit` is
  for a `SUM`, `DIFF` or `WANT` the budget cannot carry).
- A session in which neither side wanted anything (the two hold sets that never agree: another bundled seed, a
  record evicted for the size limit) is not started again with that peer until one of the two hashes changes.
- A record refused only because the receiving client does not know one of its items (a new item, a client not
  yet patched) is dropped without ignoring its sender.

## Limits on what is received (per sender, per session of play)

| What | Limit | Above it |
| --- | --- | --- |
| `HELLO` | 1 per 60 s | ignored |
| Messages | 1,160 units per hour (a whole message counts one unit per 240 bytes, at least one): twice what one honest client can send to one peer in an hour, its whole 50 KB budget plus one unit for each message it can send (HELLOs up to 3 copies, session messages, `BYE busy`, records); a flood of one message per second is still caught within 20 min | the sender is ignored until logout |
| Records | more in a session than its `WANT` asked for, or over 175 per hour (25 per session in each of the 7 sessions the group cooldown allows within an hour, its edges included) | the sender is ignored until logout |
| One record | 32 KB encoded, 1,000 places, `seq` not above its casts | rejected, the sender is ignored |
| Broken, unwanted or invalid data | none allowed | the sender is ignored until logout |

## Paths the game refuses

A path (`guild`, `group`, `whisper`, `bnet`) that the game refuses 5 times in a row (any result but `Success`, the
throttle codes, `AddOnMessageLockdown`, `TargetOffline`, `NotInGuild` and `NotInGroup`) is left out until logout; a
success resets the count. A refusal of a whisper or Battle.net message counts once for that player: the rest queued
to them is dropped and they are treated as offline (`TargetOffline`: the session with them ends, no session with
them for 30 min), so one unreachable player, whatever code the game reports, never costs more than one refusal. A
refused `HELLO` to a friend (a greeting) costs none, so a few odd names on the friends list cannot leave the
whisper or Battle.net path out.
Peers reached only by a left-out path are not contacted. With every path left out the
exchange is unavailable until logout. The state also says unavailable while nothing went out since the login and
every path tried with more than a greeting is left out (a Trial account in a guild never tries the other paths);
this is a state only, so a later success on a path not tried yet clears it.

## What is never sent

Character names (the game itself shows the sender to the receiver), guild names, the anonymous ID together with a
`HELLO`, session times, gear (FR-008). A peer that gets a record from its owner sees the sender's name next to the
record's ID, and a cell's `px`/`py` are the sums of the cast positions (the average spot fished from in that cell):
the texts of the notice and the "Shared database" page say so. A record carries only its part 1 fields: `id`, `epoch`,
`seq`, `builds`; `seen` is local and stripped before encoding. A cell may carry the subzone counts `a` of part 4
(area IDs, never names; `specs/005-catch-catalog`), which a receiver checks and copies like the other counts.
