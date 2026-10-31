# In-game checklist: the spike (game facts)

**Feature**: the game facts the shared catch database was built on before the game could be played
(`specs/002-local-catch-db` to `specs/005-catch-catalog`). `/okf spike` (`Spike.lua`, temporary) prints them in one
report with a section per part. This checklist is run **once, in one game session**, before the feature checklists;
afterwards the spike code is removed ([release-plan.md](../release-plan.md)).
**Closes**: V1-V7 (part 1), V10-V15 (part 2), V19-V27 (part 3), V30-V37 (part 4). Each `verification.md` says what
happens when an answer differs from the assumption.
**Needs**: one character with Fishing at open water, a fishing pool, a capital and, if reachable, a cave and an
instance with water; the auction house; a second player or account **B** with the addon (full account: Trial and
Veteran accounts cannot send addon data) in a guild and a group with you and on your Battle.net friends list; if
possible a character of the other faction or on another layer for step C6.

## Setup

1. Install the build on every client (`npm run install-addon`), or link the working folder once (`npm run link`).
2. Restart the game completely (new files in the TOC).
3. `/okf spike` opens the report in the copy window. Copy it with Ctrl+A, Ctrl+C and keep every report; the
   network and channel sections want a second run a few seconds later, so the echoes of the test messages show.

## Part 1: position, pools, auction (V1-V7)

- [ ] **Open water** (V1, V2, V7): start fishing in fishing mode and run `/okf spike` while the bobber is out.
  Expected: a map ID, map type 3 (zone), a position with two numbers between 0 and 1, the game version `1.60.x`.
  Report: ____
- [ ] **Fishing pool** (V3): fish a pool until you catch something, then `/okf spike`. Expected: the loot source is
  a `GameObject` whose object ID is not 35591. Then catch once in open water and run it again: object ID 35591 or
  no source. Reports: ____
- [ ] **City with water** (V1, V2): fish in a capital and run `/okf spike`. Note the map ID and type (a city may
  have its own map) and whether there is a position. Report: ____
- [ ] **Cave with water**, if you know one (V2): the same. Report: ____
- [ ] **Instance with water**, if one is reachable (V1): the same; the position is expected to be `nil`.
  Report: ____
- [ ] **Auction house** (V4, V5): open the auction house, scan prices (`/okf scan` or the button), then
  `/okf spike`. Expected for a fish: results with prices in ascending order, a total quantity at least the loaded
  quantity. For an item that does not stack (if one was scanned): `buyoutAmount` and `quantity`. Report: ____

## Part 2: network (V10-V15), section "Network"

- [ ] **N1. Guild and group** (V10, V11): in the open world, run `/okf spike` in a guild, then again in a group with
  B. Expected: `RegisterAddonMessagePrefix` and the `GUILD`, group and `WHISPER to self` results are `0`, an echo
  arrives for each, and the sender is shaped `Name-Realm`. Report: ____
- [ ] **N2. Offline whisper** (V12): the result of the whisper to the made-up name (expected `12`, `TargetOffline`,
  or `0`) and whether a "No player named ..." line appeared in chat. Report: ____
- [ ] **N3. Battle.net** (V13): with B online in Forever as a Battle.net friend, the counts show at least one game
  account "on this project", and `SendGameData to the first` is `0`. Report: ____
- [ ] **N4. Restrictions** (V14): in the open world out of combat every restriction is `false`, and so is
  `InChatMessagingLockdown` (`AreOutgoingAddonChatMessagesRestricted` is expected `true` on a normal realm: it is
  about chat messages addons send and does not pause the exchange; note its value). If possible, run it again in a
  dungeon and during a boss fight and note what turns `true`. If anything is `true` in the open world, stop here
  and report it: the exchange cannot run there. Report: ____
- [ ] **N5. Encoding** (V15): the round trip line says `equal`, with an encoded length and `Base64 characters only:
  true`. Report: ____
- [ ] **N6. Client constants** (V13): `BNET_CLIENT_WOW` and `WOW_PROJECT_ID` (expected `WoW` and `18`).
  Report: ____

## Part 3: chat channel (V19-V27), section "Chat channel"

The section joins a test channel with a random name (`OKFSpikeNNNN`), never the real one. Run it in the open
world, out of combat.

- [ ] **C1. Slots** (V23): `MaxChatChannels` (expected `20`), `GetNumActiveChannels()`, and the "too many channels"
  text as the addon looks for it. Report: ____
- [ ] **C2. Joining and hiding** (V19, V21): what `JoinTemporaryChannel` returned, the notice tokens and their
  events, the channel number; a chat window listed the channel before the removal and none after it. Report: ____
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

**If C2, C3 and C6 show that addon messages in a custom channel do not work (V19 fails)**: set
`Channel.AVAILABLE = false` in `OneKeyFishing/Channel.lua`; the release ships without the channel, V20-V25 are
closed as "not shipped" in `specs/004-public-channel-sync/verification.md`, and the feature checklist of the public
channel keeps only its protection steps.

## Part 4: map pins and areas (V30-V37), section "Map pins and areas"

Run the section at three waters: an open zone, a named subzone (a lake with its own name) and a city; once more
inside a cave (a map of type 5, Micro) and, if reachable, in an instance. Run it twice at the first place: the
items part shows the names before and after the game was asked for them.

- [ ] **P1. Pins** (V30, V31, V33): `CanSetUserWaypointOnMap` for the map and its parent, the map type, the game
  rule `WorldMapTrackingPinDisabled`, the CVar `showInGameNavigation` and the current waypoint, at each place.
  Expected: true on zone maps, false in the instance; the cave converts to a point on its zone map. Report: ____
- [ ] **P2. Areas** (V34): at each water the area IDs at the position with their names, `GetSubZoneText()` and the
  area the addon keeps. Expected: one area's name equals the subzone text. Report: ____
- [ ] **P3. Item names** (V35): the load state of three catalog items before and after the game was asked for them.
  Expected: known after the request, or "unknown" for an item Forever hides. Report: ____
- [ ] **P4. Folding and order** (V36): `CaseAccentInsensitiveParse` of the sample and the `strcmputf8i` order on
  this client's language. Report: ____
- [ ] **P5. Templates** (V37): the scroll and search templates and the pin atlas exist: `true` for each.
  Report: ____

## Report back

- Paste every report into the conversation (the section headers name the parts).
- The answers go into `docs/forever-api.md` "Verified in game"; a wrong assumption is fixed in the code with a
  test; the `VERIFY` markers of the closed ids are removed and the ids ticked in the four `verification.md` files.
- Then the feature checklists: [catch-database.md](catch-database.md), [catch-exchange.md](catch-exchange.md),
  [public-channel.md](public-channel.md), [catch-catalog.md](catch-catalog.md).
- Once every section has run, the spike code goes: `OneKeyFishing/Spike.lua`, its TOC line, the `spike` entry in
  `OneKeyFishing/Commands.lua`, `tests/ui/spike_test.lua`, the "Spike.lua" section of `docs/architecture/ui.md` and
  its row in `CLAUDE.md` ([release-plan.md](../release-plan.md)).

## Results

- Date, build, client language, second player:
- Problems found:
