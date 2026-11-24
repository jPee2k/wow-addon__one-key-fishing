# In-game checklist: the hidden public channel

**Status**: the public channel was off in 1.2.0 (spec 010) and comes back in 1.3.0 (spec 016,
`specs/016-public-channel-return`): V19 passed again on 2026-11-16, so every step below applies. Run it on a build of
spec 016.
The protections (steps 9 and 11) are checked with the exchange of [catch-exchange.md](catch-exchange.md) meanwhile.

**Feature**: the exchange through the hidden public channel and the protections against data from strangers
(`specs/004-public-channel-sync`, part 3 of the shared catch database).
**Closes**: V28, V29 of `specs/004-public-channel-sync/verification.md`, and the feature side of V19-V27 and V41
(their API side is closed by [spike.md](spike.md), which runs first); step 12 is the feature side of V70-V74 of
`specs/022-channel-order/verification.md` (the channel's number; their `/run` checks run first).
**Needs**: accounts **A** and **B** for the exchange and **C** for the lock test (two accounts show everything but
the lock). A, B and C share no guild, group or friends list. Full accounts: Trial and Veteran accounts cannot send
addon data.

**If the spike failed V19** (addon messages in a custom channel do not work): `Channel.AVAILABLE` is `false`, the
release ships without the channel; skip steps 1-8 and 10 and run only steps 9 and 11 (the protections).

**Status 2026-11-07**: the spike showed V19 failing (the server answers `NOT_ALLOWED_IN_CHANNEL` to every addon
message in a custom channel). Spec 010 set `Channel.AVAILABLE = false` and closed C6 as not shipped: only steps 9
and 11 stay.

**Status 2026-11-16**: `/run` tests showed V19 passing again (two players, levels 4 to 31, also in
`OneKeyFishingShare`; the password and owner notices as the code expects: `docs/forever-api.md` "Verified in game").
Spec 016 switches the channel on: all steps apply again. Step 2 needs two accounts that are not Battle.net friends
(Battle.net carries the exchange too and would hide whether the channel did); the other faction (V20) cannot be
checked on a PvE realm and stays open.

**Status 2026-11-24**: V20 is answered on a PvP mode with a Horde and an Alliance account: the channel is one per
faction (Results below).

## Setup

1. Install the build on every client (`npm run install-addon`), or link the working folder once (`npm run link`);
   restart the game completely (new files in the TOC).
2. Everyone logs in; A and B on characters that have learned Fishing.

## Steps

1. [x] **Hidden** (V21, V22): A logs in; after about a minute `/okf share` says "Public channel: in use". The
   channel is in no chat window or tab; the Chat Channels window and Chat Settings list it as `OneKeyFishingShare`.
   General and Trade keep their numbers (check over three logins). C joins `/join OneKeyFishingShare` and types a
   line: nothing shows on A. **Passed in part 2026-11-17** (one login): A's channels by `GetChannelList()` are General 1,
   Trade 2, LocalDefense 3, Services 4, TradeLocal 5, the player's OOC 6 and `OneKeyFishingShare` 7, after all of
   them; B typed `/7 test from tester` into the addon's channel and no line showed on A or on B (`/chatlist` prints
   nothing in Forever). Three more logins kept General 1, Trade 2, LocalDefense 3, Services 4, TradeLocal 5 (V22).
2. [x] **Strangers** (V19, V20): A and B fish at different places and stay online; within a few hours each one's
   "What can be caught here" at the other's place counts the other's catches, and "from K players" includes the
   other. **Passed 2026-11-17** (build `30cedf5`; A Green Neerg, B Corvus Druidus, not friends in game or on
   Battle.net, no guild or group): both `/okf share` "channel 1, exchanged with 1"; A's stored places went from 57
   to 58 and A's catalog shows B's catch at The Hinterlands, Revantusk Village (78, 76), 3 catches, two minutes after
   B fished there and reloaded; no Lua error on either side.
3. [x] **Not fishing** (V19): A stays in the channel outside fishing mode (`/okf share`). `/okf debug` shows
   `refused false` (**passed 2026-11-17**: A out of fishing mode, "channel: in (index 1) ... refused false"; the
   refusal by the server is covered by the tests, not seen in game); after a refusal by the server it shows `refused server`, the state is locked and no fallback is
   joined until the next login (spec 016 US4).
4. [x] **Lock** (V24): C takes the channel over (joins it first, or becomes its owner) and sets a password. A and B
   move to `OneKeyFishingShare2` (`/okf share`: "in use (fallback channel 2)") and keep exchanging; nothing shows in
   chat and no password prompt stays on screen. When C leaves and A becomes the owner of a locked channel, A clears
   the password. **Passed in part
   2026-11-17** (the lock before the join): B, without the addon, alone in `OneKeyFishingShare` (its owner) set
   `/password OneKeyFishingShare x`; A logged in: no password popup showed at any moment, no chat line, and
   `/okf share` said "waiting", then "in use (fallback channel 2)". The lock while A is in the channel passed too: B
   (owner, no addon) set the password at 02:20; A's `/okf share` said "in use" at 02:20:03 and "in use (fallback
   channel 2)" at 02:20:21, with no popup and no chat line. The addon owner's self-heal passed: B set the password and
   left at once; 30 s later A was still in the main channel, `/okf debug` "in (index 1) ... locked none ... owner true,
   self-heals 1". Left: two addon clients moving together (a third account).
5. [x] **Slots** (V23): A joins channels by hand until 19 are taken: the addon leaves with one line ("OneKeyFishing
   left its hidden channel to free a chat channel slot. Try joining again."); the next join by hand works; leaving
   two channels brings the addon back within a few minutes. **Passed in part 2026-11-17**: with 5 own channels, the
   addon's and 14 joined by `/run`, the 21st join gave "You can only be in 20 channels at a time.", the addon's one
   line, and the next join worked; `/okf debug` "noslot, free slots 0, refused false". `GetNumActiveChannels` counts
   temporary channels too (6 = 6, 19 = 19). Found: a join of the addon at the limit (the player joining channels
   fast) returned nothing and the addon took it as the game's refusal for the whole session; fixed in spec 016 (it
   waits for free slots). Left: leaving two channels brings the addon back.
6. [ ] **Setting**: "Use the public channel" off leaves the channel at once, the guild exchange goes on, data from B
   stays counted; on joins at once. With "Use the shared catch database" off the channel setting is greyed out.
7. [x] **Left by hand** (V41): `/leave` the channel: the addon stays out until the next login (`/okf share`: "you
   left it, back at the next login"). The same when the `/leave` comes within a few seconds of the addon's join (right
   after the login delay, or 60 s after a kick), of the move to a fallback channel (step 4), or of turning "Use the
   public channel" off and on again; turning it off and on twice in a row leaves the addon in the channel.
   `/join OneKeyFishingShare` by hand after that, then `/reload`: the channel stays in the chat window and the addon
   does not leave it (also with "Use the public channel" turned off). The setting's checkbox ticked while the notice
   popup is open closes the popup. **Passed in part
   2026-11-17**: `/leave OneKeyFishingShare` gave "you left it, back at the next login" (V41). Left: the leaves within
   a few seconds of a join, and a `/join` by hand kept over a `/reload`.
8. [ ] **Slow join and kicks** (V24): `/okf debug` after a login on a busy realm: the channel is the main one
   ("name 1" beside its chat number, as in "channel: in (name 1, chat number 7)"), not a fallback, also when the join took a few seconds. C kicks A while A fights: A is back in the
   channel within about a minute of the combat's end, and B (who has not heard A this hour) counts A among the
   players heard in the channel (`/okf share`) within about 2 minutes of A's return. **Kick not checkable 2026-11-17**: as the channel's owner (no addon), B's
   `/run ChannelKick("OneKeyFishingShare", "Green Neerg")`, `/ckick OneKeyFishingShare Green Neerg` and
   `/owner OneKeyFishingShare` (and `/run DisplayChannelOwner(...)`) printed nothing and A stayed in the channel
   (`GetChannelName` 6, `kicks 0`): Forever seems to give players no way to kick from a custom channel. The kick
   handling (V24) stays covered by the tests only.
9. [ ] **Notice and unknown items** (V27): on a fresh install the popup names the public channel; nothing joins
   before it is closed. A player who closed the earlier notice sees it once more after the update. If an item of
   the bundled data is unknown to the client, the tab shows an "Unknown item" row with a question mark; its tooltip
   has the item ID, and the name appears once the game knows the item. **Notice passed 2026-11-17**: B, who had
   closed the 1.2.0 notice, saw the popup again at the first login with the spec 016 build (`notice closed true`
   after it). Left: a fresh install, the unknown item.
10. [ ] **A week** (V25, V28): normal play with the channel on: no chat line, no throttle error, General and Trade
    numbers right on every login, the longest step in `/okf debug` under 5 ms. Value: ____
11. [ ] **Harvest** (SC-010): before the release, `npm run harvest` lists contributions from players outside the
    author's guild, group and friends; the outlier report is read, and any block is made with
    `npm run harvest -- --block <id> "why"`.
12. [x] **Numbers** (spec 022; V70 to V74). The list of channels is
    `/run for i=1,20 do local n,s=GetChannelName(i) if n>0 then print(n,s) end end`.
    1. A normal login: after about a minute the channel is behind every channel of the game, and `/okf debug` says
       "channel: in (name 1, chat number N)" and "channel number: General 1, swaps 0, failed 0, repair on".
    2. Turn "Use the public channel" off, `/leave 1`, turn it on: the channel is **not** joined (`/okf share`: the
       channel waits; `/okf debug`: "General not joined"). `/join General`: about 10 seconds later the channel is joined,
       General is on 1.
    3. The same, but wait two minutes without General: the channel joins on 1. `/join General`: within seconds
       General is on 1 and the channel where the game had put General; `/okf debug` says "swaps 1". General's lines
       show in the chat window in General's colour (also after a `/reload`) and `/1 test` goes to General.
    4. Enter a city after a login made outside one: the city's channels (OOC) are before the addon's channel.
    5. Drag a channel of the game below the addon's channel in Chat Settings > Channels: it stays there.
    6. A fight, a `/reload` and a second login during these steps: no "Interface action failed because of an AddOn",
       no Lua error, `/okf share` as before.
    7. With the hidden channel below a channel of the game (leave LocalDefense in a city, turn the setting off and
       on): `/reload` three times; the list stays the same and `/okf debug` says "swaps 0" each time (V73).

## Results

- 2026-11-17, dev build `30cedf5` (spec 016), A Green Neerg (level 1), B Plague Corvus / Corvus Druidus (levels 8
  and 47), not friends in game or on Battle.net, no guild or group, EU realm, enUS clients: steps 1 (one login), 2,
  3, 4 (a lock before the join, a lock while in, the addon owner's self-heal), 5 (the give-way; not yet the way
  back), 9 (the notice again) passed; step 8's kick cannot be done in Forever. Found and fixed: a join of the addon
  at the 20-channel limit returned nothing and stopped the channel for the session (now it waits for free slots).
  Later the same night: step 1 over three logins (V22) and step 7's leave by hand (V41) passed; V24 (kicks) and V25
  (the throttle) were accepted without a check, to check later (`docs/release-plan.md`). Open: 5 the way back, 6, the
  rest of 7, 8 (slow join), 10, 11; a third account for two addon clients moving together; the other faction (V20).

- 2026-11-22, step 12 (Drog Earthshaker, client 1.60.1.71037, a build of `develop` after `ff99079`): 12.1 a login
  put the channel on 6 after every channel of the game, "chat number 6 ... swaps 0"; 12.2 with General left the
  channel joined nothing ("1.Empty" in Chat Settings), and after `/join General` it joined on 6 behind General 1;
  12.3 after two minutes it joined on 1, and `/join General` (General on 6) was answered by one swap, General 1,
  "swaps 1, failed 0"; 12.4 not run in a capital (V74 accepted), but LocalDefense joined again behind the channel
  got its number 3 back by one swap; 12.5 LocalDefense dragged behind the channel stayed there, also after a
  `/reload`; 12.6 a fight: no "Interface action failed", "Errors: none"; 12.7 three `/reload` with the channel on 3
  below Services and TradeLocal moved nothing (V73). With 1.5.0 before it: V70, V71, V72 by `/run`
  (`specs/022-channel-order/verification.md`). Found: the chat edit box left on General's old number opens the
  hidden channel after a swap (left as it is, `docs/tech-debt.md`).

- 2026-11-24, 1.6.0 (client 1.60.1.71037), PvP mode, two accounts: Drog Earthshaker (Horde, level 40) and Rare John
  (Alliance, level 1, no Fishing), enUS clients. The other faction (V20, step 2): the channel is one per faction, so
  the two never heard each other in it (`/okf share` "channel 6" on one and "channel 1" on the other at the same
  minute, each exchanging with its own faction); an addon whisper across the factions gives "No player named ...",
  as for an offline player. As Battle.net friends with the channel off on both: "Battle.net 1, channel 0, exchanged
  with 1" on both, records 63 to 75 and 135 to 146. No chat line from the addon, no refusal, no Lua error. V20 is
  closed (`docs/forever-api.md` "The other faction"); another layer is not checked.

- Date, build, accounts used:
- Problems found:

What happens next is in [release-plan.md](../release-plan.md).
