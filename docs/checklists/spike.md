# In-game checklist: the spike (game facts)

**Feature**: the game facts the shared catch database was built on before the game could be played
(`specs/002-local-catch-db` to `specs/005-catch-catalog`), and the error log (`specs/006-error-log`). `/okf spike`
(`Core/Spike.lua`, temporary) prints them in one report with a section per part. This checklist is run **once, in one
game session**, before the feature checklists; afterwards the spike code is removed
([release-plan.md](../release-plan.md)).
**Closes**: V1-V7 (part 1), V10-V15 (part 2), V19-V27 (part 3), V30-V37 (part 4), V42 (error log). Each
`verification.md` says what happens when an answer differs from the assumption.
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

- [x] **Open water** (V1, V2, V7): start fishing in fishing mode and run `/okf spike` while the bobber is out.
  Expected: a map ID, map type 3 (zone), a position with two numbers between 0 and 1, the game version `1.60.x`.
  Report: 2026-11-06, Stonebull Lake: map 1412, type 3, a position while channeling (7731), 1.60.1.
- [x] **Fishing pool** (V3): fish a pool until you catch something, then `/okf spike`. Expected: the loot source is
  a `GameObject` whose object ID is not 35591. Then catch once in open water and run it again: object ID 35591 or
  no source. Reports: 2026-11-06, Ratchet, Oily Blackmouth School: the source is object 35591 (the bobber) for the pool catch too; V3 fails.
- [x] **City with water** (V1, V2): fish in a capital and run `/okf spike`. Note the map ID and type (a city may
  have its own map) and whether there is a position. Report: 2026-11-06, Thunder Bluff: its own map 1456, type 3, a position (run beside the pond, not channeling).
- [x] **Cave with water**, if you know one (V2): the same. Report: 2026-11-06, the cave before Wailing Caverns: the continent map Kalimdor 1414 (type 2) with a position, also while channeling; no cave map.
- [x] **Instance with water**, if one is reachable (V1): the same; the position is expected to be `nil`.
  Report: 2026-11-06, Wailing Caverns (near the entrance, not at water): best map nil, position nil, the `Map` restriction active.
- [x] **Auction house** (V4, V5): open the auction house, scan prices (`/okf scan` or the button), then
  `/okf spike`. Expected for a fish: results with prices in ascending order, a total quantity at least the loaded
  quantity. For an item that does not stack (if one was scanned): `buyoutAmount` and `quantity`. Report: 2026-11-06, Orgrimmar: fish 6291, 31 results ascending, total 1592, full; club 4564, `buyoutAmount` with quantity 1; no stacked item or bid-only auction seen.

## Part 2: network (V10-V15), section "Network"

- [ ] **N1. Guild and group** (V10, V11): in the open world, run `/okf spike` in a guild, then again in a group with
  B. Expected: `RegisterAddonMessagePrefix` and the `GUILD`, group and `WHISPER to self` results are `0`, an echo
  arrives for each, and the sender is shaped `Name-Realm`. Report: 2026-11-06/07: no guild; in a group `PARTY` 0 with an echo, the sender shaped `Name` ("First Last", no realm: V11 failed, `docs/tech-debt.md`). Open: the guild, with B.
- [x] **N2. Offline whisper** (V12): the result of the whisper to the made-up name (expected `12`, `TargetOffline`,
  or `0`) and whether a "No player named ..." line appeared in chat. Report: 2026-11-06: `0` (not `TargetOffline`), and "No player named 'Okfspikenobody' is currently playing." in chat.
- [ ] **N3. Battle.net** (V13): with B online in Forever as a Battle.net friend, the counts show at least one game
  account "on this project", and `SendGameData to the first` is `0`. Report: ____
- [x] **N4. Restrictions** (V14): in the open world out of combat every restriction is `false`, and so is
  `InChatMessagingLockdown` (`AreOutgoingAddonChatMessagesRestricted` is expected `true` on a normal realm: it is
  about chat messages addons send and does not pause the exchange; note its value). If possible, run it again in a
  dungeon and during a boss fight and note what turns `true`. If anything is `true` in the open world, stop here
  and report it: the exchange cannot run there. Report: 2026-11-06: all `false` out of combat in the open world and capitals, `InChatMessagingLockdown` false, `AreOutgoingAddonChatMessagesRestricted` true; in the Wailing Caverns instance `Map` true. A boss fight not checked.
- [x] **N5. Encoding** (V15): the round trip line says `equal`, with an encoded length and `Base64 characters only:
  true`. Report: 2026-11-06, Thunder Bluff: equal, length 116, Base64 only true.
- [x] **N6. Client constants** (V13): `BNET_CLIENT_WOW` and `WOW_PROJECT_ID` (expected `WoW` and `18`).
  Report: 2026-11-06: `WoW`, `18`.

## Part 3: chat channel (V19-V27), section "Chat channel"

The section joins a test channel with a random name (`OKFSpikeNNNN`), never the real one. Run it in the open
world, out of combat.

- [x] **C1. Slots** (V23): `MaxChatChannels` (expected `20`), `GetNumActiveChannels()`, and the "too many channels"
  text as the addon looks for it. Report: 2026-11-06: 20, 5 active, "You can only be in 20 channels at a time."
- [ ] **C2. Joining and hiding** (V19, V21, V41): what `JoinTemporaryChannel` returned, the notice tokens and their
  events, the channel number; a chat window listed the channel before the removal and none after it. Then a macro
  with `/leave OKFSpikeNNNN` and `/join OKFSpikeNNNN` (the name the report prints), and one with `/join`, `/leave`
  and `/join` of it: the notices in their order (one `YOU_LEFT` per leave, before the next `YOU_JOINED`?). Report: 2026-11-06: `JoinTemporaryChannel` returns `0, empty`; the join notice is `YOU_CHANGED` only; no chat window listed the test channel; the macros: only the first `/join` or `/leave` of a channel in a macro takes effect (one notice), the rest is lost. Still open: B's view.
- [x] **C3. Sending** (V19, V25): the result of the `OKFSPIKE` message to the channel (expected `0`) and, for its
  echo, the chat type (expected `CHANNEL`) and the shapes of `target` and `name`. Report: 2026-11-06: `0`, but no echo; the server answers `NOT_ALLOWED_IN_CHANNEL` (also by `/run` to `OneKeyFishingShare`): V19 failed, `docs/tech-debt.md`.
- [x] **C4. Ownership** (V24): whether the player owns the new channel; the notices after setting and clearing a
  password on it. Report: 2026-11-06: the joining player owns it (`IsDisplayChannelOwner` true, `CHANNEL_OWNER` with the player's name); setting and clearing a password each bring `PASSWORD_CHANGED` with the player's name, actor empty.
- [x] **C5. Numbers** (V22): the channel numbers before the join and after the leave are the same: yes / no.
  Report: 2026-11-06: yes (`channel numbers back as before the last join: true`).
- [ ] **C6. Reach** (V20): B (and, if possible, a character of the other faction, and one on another layer) joins
  the test channel name the report prints and runs `/okf spike` too; note which echoes arrive. Report: ____
- [ ] **C7. Lock** (V24, V21): B sets a password on the test channel (`/password OKFSpikeNNNN x`); note the notices
  A gets. A leaves and joins it again: the password prompt came and was closed (note any flash). Report: ____
- [x] **C8. The hash** (V26): `bit` exists, the raw results of `bnot(0)` and `band(-1, 4294967295)`,
  `ns.SHA256("abc")` equals the known digest, and the time of 64 proof steps (expected under 5 ms). Report: 2026-11-06: `bit` true, both 4294967295, the digest known; 64 steps 17-20 ms over seven runs (over 5 ms: `docs/tech-debt.md`).
- [x] **C9. Unknown items** (V27): how many item IDs of the bundled data the game does not know or says do not
  exist, and the result of asking the game to load one of them. Report: 2026-11-06 (synthetic seed, items 6000-6899): 36 unknown to `GetItemInfoInstant`, 0 not existing by `DoesItemExistByID`; the load request gives `ITEM_DATA_LOAD_RESULT` false.

**If C2, C3 and C6 show that addon messages in a custom channel do not work (V19 fails)**: set
`Channel.AVAILABLE = false` in `OneKeyFishing/Exchange/Channel.lua`; the release ships without the channel, V20-V25 are
closed as "not shipped" in `specs/004-public-channel-sync/verification.md`, and the feature checklist of the public
channel keeps only its protection steps.

## Part 4: map pins and areas (V30-V37), section "Map pins and areas"

Run the section at three waters: an open zone, a named subzone (a lake with its own name) and a city; once more
inside a cave (a map of type 5, Micro) and, if reachable, in an instance. Run it twice at the first place: the
items part shows the names before and after the game was asked for them.

- [x] **P1. Pins** (V30, V31, V33): `CanSetUserWaypointOnMap` for the map and its parent, the map type, the game
  rule `WorldMapTrackingPinDisabled`, the CVar `showInGameNavigation` and the current waypoint, at each place.
  Expected: true on zone maps, false in the instance; the cave converts to a point on its zone map. Report: 2026-11-06: true on Mulgore 1412, The Barrens 1413, Thunder Bluff 1456 and their parent Kalimdor 1414; the cave reports Kalimdor itself (no Micro map, V33 not met); the instance has no map; the rule not active; `showInGameNavigation` 0; no waypoint.
- [x] **P2. Areas** (V34): at each water the area IDs at the position with their names, `GetSubZoneText()` and the
  area the addon keeps. Expected: one area's name equals the subzone text. Report: 2026-11-06: Ratchet: area 392 = "Ratchet", kept; Stonebull Lake: none, or 222 "Bloodhoof Village"; Thunder Bluff and the cave: none (V34 partly failed, `docs/tech-debt.md`).
- [x] **P3. Item names** (V35): the load state of three catalog items before and after the game was asked for them.
  Expected: known after the request, or "unknown" for an item Forever hides. Report: 2026-11-06 (synthetic seed): items 6000, 6004, 6008 stay without a name after the request (the client cannot load them).
- [x] **P4. Folding and order** (V36): `CaseAccentInsensitiveParse` of the sample and the `strcmputf8i` order on
  this client's language. Report: 2026-11-06, enUS: case folded (Latin and Cyrillic), accents kept; `strcmputf8i(b, A)` 1. Open: a deDE / frFR client.
- [x] **P5. Templates** (V37): the scroll and search templates and the pin atlas exist: `true` for each.
  Report: 2026-11-06: every template created, the atlas true.

## Part 5: error log (V42), section "Error log (V42)"

Each run of the report causes one deliberate error, recorded like any other.

- [x] **E1. Error path** (V42): `/console scriptErrors 1`, then `/okf spike`. Expected: one popup (or one BugSack entry)
  with "OneKeyFishing spike test error" and a stack whose first Lua line is in `Spike.lua`; the section shows
  `ns.Safe returned false; entry spike, count <runs>` and that `Spike.lua` line; `/okf debug` lists the error under
  "Errors" with the same count. Then `/console scriptErrors 0`. Report: 2026-11-06: one popup per run, first Lua line `Spike.lua:576`; `count 2` after two runs, `/okf debug` lists `2x spike`.

## Report back

- Paste every report into the conversation (the section headers name the parts).
- The answers go into `docs/forever-api.md` "Verified in game"; a wrong assumption is fixed in the code with a
  test; the `VERIFY` markers of the closed ids are removed and the ids ticked in the five `verification.md` files
  (002 to 006).
- Then the feature checklists: [catch-database.md](catch-database.md), [catch-exchange.md](catch-exchange.md),
  [public-channel.md](public-channel.md), [catch-catalog.md](catch-catalog.md).
- Once every section has run, the spike code goes: `OneKeyFishing/Core/Spike.lua`, its TOC line, the `spike` entry in
  `OneKeyFishing/Core/Commands.lua`, `tests/ui/spike_test.lua`, the "Spike.lua" section of `docs/architecture/ui.md` and
  its row in `CLAUDE.md` ([release-plan.md](../release-plan.md)).

## Results

- Date, build, client language, second player: 2026-11-06 and 2026-11-07, game 1.60.1 (70790), EU realm, enUS
  client, branch `002-shared-db` linked (version `dev`), level 10-11 with Fishing 150; no second player yet.
- Problems found: V19 (no addon messages in a custom channel), V11 (names "First Last", `UnitName` two values),
  V3 (pool loot from the bobber), V26 (a proof step 0.3 ms), V34 (the subzone often not found), V2 (a cave is the
  continent map), V12 (offline whisper returns 0), V31 (no arrow on screen): `docs/tech-debt.md` "Fix batches".
