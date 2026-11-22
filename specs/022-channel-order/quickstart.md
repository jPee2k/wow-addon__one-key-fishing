# Quickstart: The Hidden Channel Keeps Off the Game's Channel Numbers

**Spec**: [spec.md](spec.md) | **Measurements**: [research.md](research.md) | **Assumptions**:
[verification.md](verification.md)

## Run

```text
npm install      # once
npm run check    # luacheck, layers, locales, Markdown; lists the open VERIFY markers (V70 to V74)
npm test         # fengari, Lua 5.3
npm test -- exchange/channel
```

## What the tests prove

The stub of the game (`tests/wow.lua`) has the game's channels now: an entry of `channels_joined` may carry `zone`
(a channel of the game), `general` and `disabled` (only its number is kept); `game_channel_join` joins one on the
lowest free number; `general_local_id` is General's number while no such entry exists (1 by default, so every
earlier test has General); `channel_swaps` records the swaps and `channel_swap_dead` makes the game ignore them.

Each new test file fails on the code before this spec (the tests that pin what must not change pass on it).

| Test file | Proves | Spec |
|---|---|---|
| `tests/exchange/channel/general_wait_test.lua` (new) | a login without General joins nothing and says `waiting`; General joining lets the channel in 10 s later, after the channels that came back with it (the player's own keeps its number), and the seconds waited are counted; the setting turned on without General waits 120 s, then joins on 1; General coming back with no event is seen within 5 s and gets 1 again by one swap; after that the next join waits anew and General's join notice starts its last 10 s; with General there all along the setting joins at the click; a wait given up or run out with the setting off does not shorten the next one; a game without `GetGeneralChannelLocalID` joins at the click | FR-001, FR-002, FR-003, FR-007, FR-009 |
| `tests/exchange/channel/order_general_test.lua` (new) | the order seen on 2026-11-22 (the channel 1, General 7) after a `/reload` with no record of the comparison: one swap (1, 7), nothing else moved, no join; counted once in `/okf debug` with the chat number; General dragged behind the channel by the player afterwards stays | FR-003, FR-005, FR-007 |
| `tests/exchange/channel/order_reload_kept_test.lua` (new) | a `/reload` whose record says the comparison was made leaves General where the player dragged it, and the next logout says so again | FR-003, FR-005 |
| `tests/exchange/channel/order_reload_list_test.lua` (new) | a `/reload` whose channel list fills after it: the channels the logout's record knows are not moved when they are listed late (Services, TradeLocal, General dragged behind the channel); a channel new after the `/reload` still gets the channel's number; the logout's record holds the known names and numbers, not the hidden channel | FR-004, FR-005 |
| `tests/exchange/channel/order_reload_settle_test.lua` (new) | the first `/reload` after a version before this spec (a record without the channels): channels listed in the seconds after it are not new, one that turns up later is | FR-004, FR-005 |
| `tests/exchange/channel/order_reload_join_test.lua` (new) | a `/reload` while the channel is not joined: it joins at once, and channels listed a second later (Services, TradeLocal above its number) are not moved; one that turns up after the 10 s is new | FR-004, FR-005 |
| `tests/exchange/channel/order_kept_number_test.lua` (new) | a channel of the game listed behind the channel on a kept number, with free numbers below it, stays; one that takes the lowest free number still gets the channel's number | FR-004, FR-005 |
| `tests/exchange/channel/order_reload_owed_test.lua` (new) | a `/reload` in the channel on number 1 without General swaps nothing, goes on looking every 5 s, and General joining with no event gets number 1 | FR-003, FR-009 |
| `tests/exchange/channel/order_general_retry_test.lua` (new) | a swap with General the game ignored is not repeated within 10 s and stays owed in the logout's record; after 10 s it is tried again and works, counted as one failure and one swap, no longer owed | FR-003, FR-006 |
| `tests/exchange/channel/order_newcomer_test.lua` (new) | the channel on the free number 3 moves neither Services nor TradeLocal above it, also when they come alive; the player's own channel behind it stays; a channel of the game listed behind it with only its number kept is not taken for a custom one, and gets the channel's number once it is alive; two at once: one swap, then the second after 2 s, the lowest first; a dragged channel and its new name on a known number are left alone; the seventh swap of a session is not made | FR-004, FR-005, FR-006 |
| `tests/exchange/channel/order_limits_test.lua` (new) | no swap in a fight, the swap after it; no swap while a name of the list is a secret value, the swap once it shows; a swap the game ignores is tried again after 10 s, not before, and after the second failure the repair stops, the channel still in | FR-006 |
| every earlier test under `tests/exchange/channel/` (unchanged) | the channel behaves as before where General is there | FR-008 |

## In game

The `/run` checks of V70, V71 and V72 in [verification.md](verification.md) first (they decide whether the repair can work as
built), then step 12 of [docs/checklists/public-channel.md](../../docs/checklists/public-channel.md) on a build of
this branch (`npm run install-addon`; no new addon file, so a `/reload` is enough).
