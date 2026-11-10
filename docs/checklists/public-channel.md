# In-game checklist: the hidden public channel

**Status**: the public channel is off in 1.2.0 (spec 010); this checklist applies only if it is switched on again.
The protections (steps 9 and 11) are checked with the exchange of [catch-exchange.md](catch-exchange.md) meanwhile.

**Feature**: the exchange through the hidden public channel and the protections against data from strangers
(`specs/004-public-channel-sync`, part 3 of the shared catch database).
**Closes**: V28, V29 of `specs/004-public-channel-sync/verification.md`, and the feature side of V19-V27 and V41
(their API side is closed by [spike.md](spike.md), which runs first).
**Needs**: accounts **A** and **B** for the exchange and **C** for the lock test (two accounts show everything but
the lock). A, B and C share no guild, group or friends list. Full accounts: Trial and Veteran accounts cannot send
addon data.

**If the spike failed V19** (addon messages in a custom channel do not work): `Channel.AVAILABLE` is `false`, the
release ships without the channel; skip steps 1-8 and 10 and run only steps 9 and 11 (the protections).

**Status 2026-11-07**: the spike showed V19 failing (the server answers `NOT_ALLOWED_IN_CHANNEL` to every addon
message in a custom channel). Spec 010 set `Channel.AVAILABLE = false` and closed C6 as not shipped: only steps 9
and 11 stay.

## Setup

1. Install the build on every client (`npm run install-addon`), or link the working folder once (`npm run link`);
   restart the game completely (new files in the TOC).
2. Everyone logs in; A and B on characters that have learned Fishing.

## Steps

1. [ ] **Hidden** (V21, V22): A logs in; after about a minute `/okf share` says "Public channel: in use". The
   channel is in no chat window or tab; the Chat Channels window and Chat Settings list it as `OneKeyFishingShare`.
   General and Trade keep their numbers (check over three logins). C joins `/join OneKeyFishingShare` and types a
   line: nothing shows on A.
2. [ ] **Strangers** (V19, V20): A and B fish at different places and stay online; within a few hours each one's
   "What can be caught here" at the other's place counts the other's catches, and "from K players" includes the
   other.
3. [ ] **Not fishing** (V19): A stays in the channel outside fishing mode (`/okf share`).
4. [ ] **Lock** (V24): C takes the channel over (joins it first, or becomes its owner) and sets a password. A and B
   move to `OneKeyFishingShare2` (`/okf share`: "in use (fallback channel 2)") and keep exchanging; nothing shows in
   chat and no password prompt stays on screen. When C leaves and A becomes the owner of a locked channel, A clears
   the password.
5. [ ] **Slots** (V23): A joins channels by hand until 19 are taken: the addon leaves with one line ("OneKeyFishing
   left its hidden channel to free a chat channel slot. Try joining again."); the next join by hand works; leaving
   two channels brings the addon back within a few minutes.
6. [ ] **Setting**: "Use the public channel" off leaves the channel at once, the guild exchange goes on, data from B
   stays counted; on joins at once. With "Use the shared catch database" off the channel setting is greyed out.
7. [ ] **Left by hand** (V41): `/leave` the channel: the addon stays out until the next login (`/okf share`: "you
   left it, back at the next login"). The same when the `/leave` comes within a few seconds of the addon's join (right
   after the login delay, or 60 s after a kick), of the move to a fallback channel (step 4), or of turning "Use the
   public channel" off and on again; turning it off and on twice in a row leaves the addon in the channel.
   `/join OneKeyFishingShare` by hand after that, then `/reload`: the channel stays in the chat window and the addon
   does not leave it (also with "Use the public channel" turned off). The setting's checkbox ticked while the notice
   popup is open closes the popup.
8. [ ] **Slow join and kicks** (V24): `/okf debug` after a login on a busy realm: the channel is the main one
   (index 1), not a fallback, also when the join took a few seconds. C kicks A while A fights: A is back in the
   channel within about a minute of the combat's end, and B (who has not heard A this hour) counts A among the
   players heard in the channel (`/okf share`) within about 2 minutes of A's return.
9. [ ] **Notice and unknown items** (V27): on a fresh install the popup names the public channel; nothing joins
   before it is closed. A player who closed the earlier notice sees it once more after the update. If an item of
   the bundled data is unknown to the client, the tab shows an "Unknown item" row with a question mark; its tooltip
   has the item ID, and the name appears once the game knows the item.
10. [ ] **A week** (V25, V28): normal play with the channel on: no chat line, no throttle error, General and Trade
    numbers right on every login, the longest step in `/okf debug` under 5 ms. Value: ____
11. [ ] **Harvest** (SC-010): before the release, `npm run harvest` lists contributions from players outside the
    author's guild, group and friends; the outlier report is read, and any block is made with
    `npm run harvest -- --block <id> "why"`.

## Results

- Date, build, accounts used:
- Problems found:

What happens next is in [release-plan.md](../release-plan.md).
