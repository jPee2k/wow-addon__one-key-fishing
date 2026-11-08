# Contract: Exchange Fixes for Forever

## Names (Core/Data.lua, Comm, Channel)

| # | Rule |
|---|---|
| N1 | `ns.PlayerName()` returns `GetUnitName("player", true)`, a string. |
| N2 | `ns.SameCharacter(a, b)` is true for `a == b`. It is also true when the two are equal after the suffix `"-" .. GetNormalizedRealmName()` (the own realm) is taken off either side. It is false otherwise: a suffix of another realm, or names that differ. A space is part of the name. |
| N3 | `Comm.ForEachFriend` calls `fn("w:" .. info.name)` for every connected character friend, with the name unchanged. Battle.net game accounts stay `"b:" .. gameAccountID`. |
| N4 | A friend whose message arrives from `"w:First Last"` and who is greeted at `"w:First Last"` is one peer (one entry in the node's peers). |
| N5 | `Channel`'s `IsMe(name)` is `ns.SameCharacter(name, ns.PlayerName())`. |

## The public channel off (Channel)

| # | Rule |
|---|---|
| C1 | `Channel.AVAILABLE` is `false`. `Channel.GetState()` returns `"unavailable"`, and no join is ever started. |
| C2 | The settings page, `/okf share`, the one-time notice and the debug report show no channel option, status line or text (the spec 004 switch, unchanged). |
| C3 | At `PLAYER_ENTERING_WORLD` with the channel unavailable, every name of `Channel.NAMES` the client is in (`GetChannelName` gives a number) is left once with `LeaveChannelByName`. It is removed from the chat windows, and no chat line is printed. A second login finds none and leaves nothing. |
| C4 | With the channel switched on, `CHAT_MSG_CHANNEL_NOTICE` `NOT_ALLOWED_IN_CHANNEL` for one of the addon's channel names counts as one channel refusal. `CHANNEL_REFUSALS` in a row call `Channel.OnRefused()`. A notice for another channel is ignored. |

## Proof steps (ShareProtocol, ShareGame)

| # | Rule |
|---|---|
| P1 | `Node:MergeOne` checks a version chain by calling `CatchDB.CheckVersion(held, record, PROOF_CHUNK, state)` repeatedly. It stops when the result is not `"more"` or when `clock() - started >= PROOF_BUDGET_MS`. |
| P2 | At least one call runs per frame step. Without a clock (`env.clock` nil), exactly one call runs. |
| P3 | The login check of the seed chains follows P1 and P2. |

## Offline whisper (Comm)

| # | Rule |
|---|---|
| O1 | `Deliver` records, for a whisper, the expected "No player named" line texts (with and without a realm suffix) with the message's address. |
| O2 | When `HideNotFound` hides a line recorded within `FILTER_WINDOW`, it runs `Unreachable` for that address once (drops the queued messages to it, runs the offline handlers). A line for a name with no record is left to the game. |

## Texts

| # | Rule |
|---|---|
| T1 | `Catalog.CatchesText(1, players)` returns `L["1 catch"]`. Other counts behave as today. |
| T2 | The zone list and the minimap tooltip use `L["1 catch, %s"]` and `L["Session: 1 catch, %s"]` for one catch. |

## Spike

| # | Rule |
|---|---|
| S1 | `/okf spike` hands on no error, and no `ns.Safe` call of the spike fails on purpose. |
| S2 | Its sections are Network, Proof steps (V26), Areas (V34), Folding (V36) and Last auction search (V5), plus the version header. |
| S3 | At load, the spike removes its saved test-error entries (`ns.ForgetErrors`). Other entries stay. |
