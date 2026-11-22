# Fix Specification: The Hidden Channel Keeps Off the Game's Channel Numbers

**Feature Branch**: `022-channel-order` (off `develop`)

**Created**: 2026-11-22

**Status**: Built with tests and checked in game on 2026-11-22: V70 to V73 confirmed, V74 accepted, step 12 of
`docs/checklists/public-channel.md` passed (12.4 not in a capital)

**Input**: A bug found by the author in play on 2026-11-22: the addon's hidden chat channel `OneKeyFishingShare`
stood on chat channel number 1 and General on 7, until "Chat Defaults" was pressed. Planned for the patch 1.5.1.

A short spec: one module changes (`Exchange/Channel.lua`), no message, no visible text; the session record
`channelSession` gains two values (`generalOwed`, `known`; no schema change: the record is read once and dropped). The
measurements are in [research.md](research.md), the assumptions in [verification.md](verification.md), what the tests
prove in [quickstart.md](quickstart.md); the module's description is in
[docs/architecture/exchange.md](../../docs/architecture/exchange.md).

## The bug

The game gives a joined channel the lowest free chat channel number. It keeps the numbers of its own channels the
client knows (Trade, Services, TradeLocal, a city's OOC) while they are not active, but not General's once the player
is not in General. The addon looked only at the count of free channel slots before a join. Joined while General was
not there, its channel took number 1; General then came back behind every channel and stayed there, so `/1` no longer
wrote to General. A weaker form of the same: a channel of the game the client learns of after the addon's join (a
city's OOC after a login outside a city) lands behind the addon's channel instead of on its usual number.

The moment it happened to the author is not known (a `/reload`, a late General, a chat hiccup); the mechanism was
reproduced in game with `/leave 1`.

## Requirements

- **FR-001**: The addon does not join its channel while the player is not in General, on every path that joins (the
  login, a `/reload`, the setting, the end of a pause, slots given back, the rejoin after a kick, a fallback name).
- **FR-002**: The wait of FR-001 is 120 seconds at most (a timer ends it on time), counted from the first look that found no General when a
  join wanted it: a player who left General for good still gets the channel. A pause, a fight or the setting turned
  off does not restart it, and it ends for good only when General is seen (looked for every 5 seconds from then on),
  after which the next wait is a whole one. A game without the call for General's number changes nothing (the join
  as before this spec). A `/reload` starts the wait anew (it is not kept across it). Once General is there after a
  look had missed it, the join waits 10 seconds more: the channels that come back with General (the game's others,
  the player's own) take their numbers first, as they do in the 30 to 60 seconds after a login.
- **FR-003** (rule G): when General's number is above the channel's, the two trade places. The comparison is owed
  once after each join; a `/reload` keeps whether it is still owed, and counts it as owed after a version before
  this spec, so General left behind by an earlier version is put back once.
- **FR-004** (rule N): when a channel of the game that is new (neither its name nor its number was listed at any of
  the addon's looks since the join, the first one being the join itself) turns up above the channel, the two trade places: that channel
  took the lowest free number, which without the addon was the channel's, so the result is the order the game would
  have had. A new channel with a free number below it did not take the lowest free number (the game kept that number
  for it, as for a row dragged in an earlier session) and is not moved. One exception to "the order the game would
  have had": a channel of the player joined between the two keeps its number (FR-005), so the game's channel then
  stands before it. Several are handled one swap at a time, the lowest number first.
- **FR-005**: Nothing else moves: not a channel that was listed at the last look (a player who left LocalDefense has
  the channel on 3 below Services and TradeLocal, and they stay; a channel once listed stays known until the hidden channel's next
  join, so one that a look misses, after a loading screen, is not new when it is listed again), not the player's own channels or another addon's, not a channel the player
  dragged in Chat Settings > Channels afterwards, also over a `/reload`: the channels known before it stay known,
  and whatever is listed in the 10 seconds after a `/reload` counts as there before it, also beside a join made at
  the `/reload`. Channel colours
  (`ChatTypeInfo`) are not written: a colour stays with its number, as before the order broke. A limit: General kept
  behind a free lower number on purpose cannot be told from a broken order at a new join of the channel (a login,
  the setting), which puts General back.
- **FR-006**: No swap in a fight (it follows the fight), none while the channel list holds secret values, at most
  one in 2 seconds. A swap that changed nothing after 10 seconds is a failure and is tried again (not earlier: a
  swap that shows late must not be undone by a second one); two failures in a row, or six swaps in a session, stop
  the repair until the next login or `/reload`. The channel itself goes on working. A new channel the game tells
  nothing about yet is looked at again, not taken for a custom one; so is a list or a number the game hides (secret
  values), every 5 seconds. A hidden number never counts as "not in the channel".
- **FR-009**: The repair looks after a join, on `CHANNEL_UI_UPDATE`, on the join notice of another channel, every 5
  seconds while General is away, on each channel round and after a fight: it does not depend on one event alone.
- **FR-007**: `/okf debug` shows the channel's chat number beside the index of its name, General's number, the swaps
  made and failed, whether the repair is on, and the seconds joins waited for General.
- **FR-008**: Every earlier behaviour of the channel is unchanged where General is there and no channel of the game
  turns up behind the addon's: the existing tests under `tests/exchange/channel/` pass unchanged.

## Out of scope

- The player's own channels joined after the addon's (they get the next number, as after any channel).
- Putting the game's channels on their default numbers in general (`C_ChatInfo.ResetDefaultZoneChannels`, the "Chat
  Defaults" button): it would also undo an order the player chose.

## If V70 fails

If the game ignores a swap made without a key press, FR-003 and FR-004 cannot repair anything (the repair stops
itself after two tries, FR-006). The wait of FR-001 still prevents the common case, and the fallback is one chat line
per session that names the "Chat Defaults" button (a new text with its nine translations), decided then.
