# In-game checklist: the public channel (part 3)

What to check in the game for the exchange through the hidden public channel and the protections of part 3
(`specs/004-public-channel-sync`), on and after the game launch on 2026-11-04. The feature was built before the game
could be played, on the assumptions V19-V29 of `specs/004-public-channel-sync/verification.md`; each step below says
which ones it closes. Tick each box, note anything that looks wrong, and paste the `/okf spike` reports back: the
answers go into `docs/forever-api.md`, and the `VERIFY` markers in the code are removed only after that.

**Accounts**: A and B for the exchange, C for the lock test (two accounts show everything but the lock). A, B and C
share no guild, group or friends list. Trial and Veteran accounts cannot send addon data, so use full accounts.

**If the spike fails V19** (addon messages in a custom channel do not work): set `Channel.AVAILABLE = false` in
`OneKeyFishing/Channel.lua`, skip Part 2 steps 1-8 and 10, and close V20-V25 as "not shipped"
(verification.md). The protections (steps 9 and 11) are checked as usual.

## Setup

1. Install the build into the game on every client (or link the working folder once with `npm run link`):

   ```bash
   npm run install-addon
   ```

2. Restart the game completely. A new file was added to the TOC (`Channel.lua`), so `/reload` is not enough.
3. Run the spike part in the same game session as the spike steps of parts 1 and 2
   (`docs/checklists/catch-database.md`, `docs/checklists/catch-exchange.md`): `Spike.lua` is removed once all are
   done.

## Part 1: Spike (game facts)

`/okf spike` opens a window with a report; its "Chat channel (V19-V27)" section joins a test channel with a random
name (`OKFSpikeNNNN`), never the real one. Run it in the open world, out of combat. Copy each report (Ctrl+A,
Ctrl+C). Run it twice a few seconds apart: echoes show in the second report.

- [ ] **C1. Slots** (V23): `MaxChatChannels` (expected `20`), `GetNumActiveChannels()`, and the "too many
  channels" text as the addon looks for it. Report: ____
- [ ] **C2. Joining and hiding** (V19, V21): what `JoinTemporaryChannel` returned, the notice tokens and their
  events, the channel number; a chat window listed the channel before the removal and none after it.
  Report: ____
- [ ] **C3. Sending** (V19, V25): the result of the `OKFSPIKE` message to the channel (expected `0`) and, for its
  echo, the chat type (expected `CHANNEL`) and the shapes of `target` and `name`. Report: ____
- [ ] **C4. Ownership** (V24): whether the player owns the new channel; the notices after setting and clearing a
  password on it. Report: ____
- [ ] **C5. Numbers** (V22): the channel numbers before the join and after the leave are the same: yes / no.
  Report: ____
- [ ] **C6. Reach** (V20): B (and, if possible, a character of the other faction, and one on another layer) joins
  the test channel name the report prints and runs `/okf spike` too; note which echoes arrive. Report: ____
- [ ] **C7. Lock** (V24, V21): B sets a password on the test channel (`/password OKFSpikeNNNN x`); note the notices
  A gets. A leaves and joins it again: the password prompt came and was closed (note any flash). Report: ____
- [ ] **C8. The hash** (V26): `bit` exists, the raw results of `bnot(0)` and `band(-1, 4294967295)`,
  `ns.SHA256("abc")` equals the known digest, and the time of 64 proof steps (expected under 5 ms). Report: ____
- [ ] **C9. Unknown items** (V27): how many item IDs of the bundled data the game does not know or says do not
  exist, and the result of asking the game to load one of them. Report: ____
- [ ] **C10. Report back**: paste all reports into the conversation.

## Part 2: The feature

- [ ] **1. Hidden** (V21, V22): A logs in; after about a minute `/okf share` says "Public channel: in use". The
  channel is in no chat window or tab; the Chat Channels window and Chat Settings list it as `OneKeyFishingShare`.
  General and Trade keep their numbers (check over three logins). C joins `/join OneKeyFishingShare` and types a
  line: nothing shows on A.
- [ ] **2. Strangers** (V19, V20): A and B fish at different places and stay online; within a few hours each one's
  "What can be caught here" at the other's place counts the other's catches, and "from K players" includes the
  other.
- [ ] **3. Not fishing** (V19): A stays in the channel outside fishing mode (`/okf share`).
- [ ] **4. Lock** (V24): C takes the channel over (joins it first, or becomes its owner) and sets a password. A and
  B move to `OneKeyFishingShare2` (`/okf share`: "in use (fallback channel 2)") and keep exchanging; nothing shows in
  chat and no password prompt stays on screen. When C leaves and A becomes the owner of a locked channel, A clears
  the password.
- [ ] **5. Slots** (V23): A joins channels by hand until 19 are taken: the addon leaves with one line ("OneKeyFishing
  left its hidden channel to free a chat channel slot. Try joining again."); the next join by hand works; leaving two
  channels brings the addon back within a few minutes.
- [ ] **6. Setting**: "Use the public channel" off leaves the channel at once, the guild exchange goes on, data from
  B stays counted; on joins at once. With "Use the shared catch database" off the channel setting is greyed out.
- [ ] **7. Left by hand**: `/leave` the channel: the addon stays out until the next login (`/okf share`: "you left
  it, back at the next login"). The same when the `/leave` comes within a few seconds of the addon's join (right
  after the login delay, or 60 s after a kick). `/join OneKeyFishingShare` by hand after that, then `/reload`: the
  channel stays in the chat window and the addon does not leave it (also with "Use the public channel" turned off).
  The setting's checkbox ticked while the notice popup is open closes the popup.
- [ ] **7a. Slow join** (V24): `/okf debug` after a login on a busy realm: the channel is the main one (index 1), not
  a fallback, also when the join took a few seconds. A kick in combat (C kicks A while A fights): A is back in the
  channel within about a minute of the combat's end, and B (who has not heard A this hour) counts A among the
  players heard in the channel (`/okf share`) within about 2 minutes of A's return.
- [ ] **8. Notice**: on a fresh install the popup names the public channel; nothing joins before it is closed. A
  player who closed the part 2 notice sees it once more after the update.
- [ ] **9. Unknown items** (V27): if an item of the bundled data is unknown to the client, the tab shows an
  "Unknown item" row with a question mark; its tooltip has the item ID, and the name appears once the game knows the
  item.
- [ ] **10. A week** (V25, V28): normal play with the channel on: no chat line, no throttle error, General and Trade
  numbers right on every login, the longest step in `/okf debug` under 5 ms.
- [ ] **11. Harvest** (SC-010): before the release, `npm run harvest` lists contributions from players outside the
  author's guild, group and friends; the outlier report is read, and any block is made with
  `npm run harvest -- --block <id> "why"`.

## After the checklist

1. Record the answers in `docs/forever-api.md`; fix the code where an assumption was wrong (with tests).
2. Remove the `VERIFY(V19)` and `VERIFY(V21)` to `VERIFY(V27)` markers that are closed and tick V19-V29 in
   `specs/004-public-channel-sync/verification.md`.
3. The spike removal and the release are the steps of `docs/checklists/catch-database.md` "After the checklist";
   all four parts of the shared catch database ship together as 1.2.0.
