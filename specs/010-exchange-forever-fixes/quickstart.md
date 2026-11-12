# Quickstart: Exchange Fixes for Forever

The rules being checked are in [contracts/exchange.md](contracts/exchange.md); the state is in
[data-model.md](data-model.md).

## Automated

```sh
npm run check
npm test
```

Each test fails without its fix (spec FR-015):

| Test | Proves | Fails without |
|---|---|---|
| `tests/core/names_test.lua` | N1, N2: the full own name; same character with or without the own realm suffix, another realm is another character; a space is no separator | `ns.PlayerName`; the new `SameCharacter` |
| `tests/exchange/comm/friends_test.lua` | N3, N4: friend "First Last" greeted at `w:First Last`; its own message makes no second peer | the address without `WithRealm` |
| `tests/exchange/channel/off_test.lua` | C1, C3: no join with the channel off; a leftover channel left once, silently; C4 with the channel on: `NOT_ALLOWED_IN_CHANNEL` counts and locks at the limit | `AVAILABLE = false`; the leftover leave; the notice branch |
| `tests/exchange/share/budget_test.lua` | P1-P3: with `profile_step` a long chain takes several frame steps, each within the budget; at least one chunk; one chunk without a clock | the chunk loop |
| `tests/exchange/comm/offline_test.lua` | O1, O2: the hidden line ends the session and drops the queue to that address; an unrelated line changes nothing | the address in `notFound` |
| catalog and UI text tests | T1, T2: "1 catch" for one, plural otherwise | the new keys |
| `tests/ui/spike_test.lua` | S1-S3: no error handed on; the kept sections; old test entries removed, others kept | the trim and the cleanup |

## In game (after the implementation)

Already confirmed, not repeated:
- names "First Last";
- the channel refusal (V19);
- 0.3 ms per proof step (V26);
- the 0 result of an offline whisper (V12);
- every solo spike step.

Alone:
1. `/reload` (or restart, if the TOC changed: it does not). Check that you are in no `OneKeyFishingShare*` channel
   (`/chatlist` or the chat channel list) and that the settings and `/okf share` show no public channel.
2. `/okf spike`: no error popup, and no new entry under "Errors" in `/okf debug`. Last time's 19 spike entries are
   gone too. The sections are Network, Proof steps, Areas, Folding and the auction search.
3. `/okf spike` "Proof steps": the 64-step timing, as before. During an exchange (later, with a second player)
   `/okf debug` `longest merge step` stays under 5 ms.
4. A place with one catch: "What can be caught here" says "1 catch" (in the addon's language).

With a second player (from the 1.2.0 test page, phase `d`):
- N1 (guild) and N3 (Battle.net) of the spike;
- a character friend greeted and counted once;
- a friend who logs out mid-exchange: the session ends, no "No player named" line.
