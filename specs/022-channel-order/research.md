# Research: The Hidden Channel Keeps Off the Game's Channel Numbers

Measured in game on 2026-11-22 by the author (Drog Earthshaker, level 38, client 1.60.1.71037, enUS client, addon
1.5.0, Stranglethorn Vale); the facts are also in [docs/forever-api.md](../../docs/forever-api.md), "Chat channel
numbers". The list of channels was printed with
`/run for i=1,20 do local n,name=GetChannelName(i) print(i,n,name) end`.

## R1. What was seen

The hidden channel stood on number 1 and General on 7. "Chat Defaults" in the chat settings put every channel back:
General 1, Trade 2, LocalDefense 3, Services 4, TradeLocal 5, OOC 6, `OneKeyFishingShare` 7. `/okf debug` of that
session: "channel: in (index 1), free slots 13, locked none, kicks 0, ... refused false", no error. The "index 1" of
that line is the index of the channel's name, not its chat number, which misled the reading (FR-007).

## R2. The mechanism, reproduced

1. "Use the public channel" off, `/leave 1` (General), the setting on again: the addon joins at once and its channel
   gets number **1**.
2. `/join General`: General gets number **7**, behind Trade 2, LocalDefense 3, Services 4, TradeLocal 5, OOC 6.
3. "Chat Defaults": General 1 ... OOC 6, the channel 7.

So a join gets the lowest free number; General's number is free while the player is not in General; the numbers of
the other channels of the game stay kept while they are not active (outside a city `GetChannelName(2)` gives 0, and
Chat Settings > Channels lists "2.Trade" greyed).

**Decision**: do not join without General (FR-001), with a limit, since a player may have left General (FR-002).

## R3. A channel of the game learned of later

After a logout and login outside a city the list was General 1, LocalDefense 3 and, a minute later,
`OneKeyFishingShare` **6**; Chat Settings listed Trade 2, Services 4, TradeLocal 5 greyed and no OOC. "Chat Defaults"
then listed OOC on 6 and the channel on 7. The client did not know the city's OOC at the join, so the channel took
the number OOC has otherwise.

**Decision**: rule N (FR-004). A channel that joins takes the lowest free number F. If F is above the addon's number,
every number below F is taken, so without the addon the lowest free number would have been the addon's own: trading
the two numbers gives exactly the order the game would have had. This holds wherever the addon's channel is, and it
needs no knowledge of the game's default numbers. One exception: a channel the player joined after the addon's sits
between the two numbers and keeps its own, so the game's channel ends up before it, where without the addon it would
have come after it; no channel of the player moves.

## R4. The repair call

`/run C_ChatInfo.SwapChatChannelsByChannelIndex(1,7)` in the order of R2 step 2 put General on 1 and the channel on
7, with no error, no "Interface action failed because of an AddOn" and no chat line. It is the call of
`ChatConfigChannelSettings_SwapChannelsByIndex` (Blizzard's `ChatConfigFrame.lua`), which also trades the two
`ChatTypeInfo` entries so that a colour follows its channel.

**Decision**: the addon calls the swap alone and leaves `ChatTypeInfo`: when General comes back to 1 it meets the
colour of number 1, which is the one it had before the order broke; writing the global table from addon code would
also taint it. The typed `/run` had a key press behind it; the addon's call has none (V70).

**Rejected**: `C_ChatInfo.ResetDefaultZoneChannels()` (the "Chat Defaults" button) restores every default number in
one call, but it would undo an order the player chose in Chat Settings; leaving and joining again does not help
either, since number 1 stays free and the join takes it again.

## R5. What was ruled out

- The LayerSwap addon: its code joins and leaves only its own channels (`layer`, `LayerSwap`); a layer change by its
  group invite left General 1, LocalDefense 3, the channel 7.
- A `/reload`: the numbers stayed (General 1, LocalDefense 3, the channel 7).
- The game bringing the channel back at a login before General: right after a login the channel was not in the list
  (`JoinTemporaryChannel` is not kept by the game).
- The hiding: the row's checkbox in Chat Settings > Channels ticked by hand, then
  `/dump ChatFrame1:ContainsChannel("OneKeyFishingShare")` gave false.

## R6. Open (the checks of verification.md)

The moment the author's order broke is not known. Whether the broken order outlives a logout (so that players of
1.3.0 to 1.5.0 may still have it) is not checked; rule G repairs it either way, at the join after the login.
