# OneKeyFishing: a database shared between players

Oct 23, 2026 · Serhii Pylypenko

## Goal and rules

Goal: a "what can be caught where" database for all of WoW Forever that fills itself from the fishing of players
who run the addon. The data travels between players through addon messages in game and arrives with every release
as a bundled file. The only manual work is one command the author runs before a release (`npm run harvest`, see
"Seeding the database from releases").

This extends item 1 of `docs/ROADMAP.md`: there the data travels only through a manual export. Here the export
becomes optional.

| Blizzard rule | What it means for the feature |
| --- | --- |
| The addon is free and its code is open | Libraries ship in the package as they are. Data compression is allowed: it is the data that is compressed, not the code. |
| Do no harm to the server or to players ("excessive use of the chat system", "slow frame rates") | A hard traffic budget, jitter, a queue with a limit. Data is processed in chunks through `C_Timer`, so the frame rate does not drop. |
| No advertising or donation requests in game | The feature's interface shows nothing but data. Donations only on CurseForge. |
| An addon shows information, it does not act for the player | The database only shows statistics. The addon's rule does not change: every action is a real key press. |
| Forever has Midnight-level restrictions | There are `AddOnRestrictionType` states: Combat, Encounter, ChallengeMode, PvPMatch, Map, Chat. There is the `AddOnMessageLockdown` result. Syncing pauses in these states. |
| An addon cannot send data out of the game | Between players only `C_ChatInfo.SendAddonMessage`. The SavedVariables file is read only by the author, on their own PC and outside the game. |

No external programs for players: everything works inside the addon.

## What data we share

The core of the database is catch counters per place: how many times each item dropped and over how many casts.
They already exist in `Stats.lua` and `Catch.lua`; only a new place key is needed.

| Data | Source in the addon | Why | Shared |
| --- | --- | --- | --- |
| Item (item ID) and count | `FISH_CAUGHT` | What is caught and in what proportion | Yes, phase 2 |
| Catches and misses | `FISH_CAUGHT` / `FISH_MISSED` | Chances (ROADMAP item 2) | Yes, phase 2 |
| Minutes of fishing at the place | `modeTime` in Stats | Plausibility check (no more catches than the time allows) | Yes, rounded to minutes |
| Skill range | `Skill.lua` (base rank) | The catch may depend on the skill | Yes, as a range number |
| Pool or open water | `GetLootSourceInfo` (check in game) | Pools have a different catch | If the spike confirms it |
| Auction prices | `Auction.lua` | Catch value without your own scan | Later, phase 6 |

Not shared: character names, guild, exact coordinates, session times, gear.

### A place key without names

Today a zone in Stats is `mapID .. ":" .. GetSubZoneText()`. The subzone name is localized, so a ruRU player and an
enUS player get different keys for the same lake. The shared database needs a key made of numbers only:

```
<uiMapID>:<skill range>:<grid cell>
1415:3:47   -- map 1415, skill 225-299, cell x=4, y=7 of a 10x10 grid
```

- The cell comes from `C_Map.GetPlayerMapPosition(mapID, "player")`, rounded to a 10x10 grid (a square of 10% of
  the map). This also protects privacy: the exact position is not stored.
- The skill range is `floor(base rank / 75)`: 0, 1, 2, 3, 4+. Pole and lure bonuses are left out, so a cell does
  not split in two whenever a lure runs out (decided for part 1).
- The display name is built on the client: `C_Map.GetMapInfo(mapID).name` plus the cell coordinates. The local
  subzone name is remembered only for cells the player has been to.
- If the position is not available (dungeons, the Map state of `AddOnRestrictionType`), the cell is `x` (the
  whole zone).
- The existing statistics do not change: the new key is written alongside, into its own contribution record (next
  section).

## Transport

The public channel carries only short announcements ("I am here, I have this data"); the data itself goes by
whisper between two players. Whispers outside instances are not subject to the per-prefix limit, and the channel
is not flooded.

| Type | Who hears it | Limits | Role |
| --- | --- | --- | --- |
| `CHANNEL` (a hidden channel, for example `OKFishData`) | Every player with the addon in the mode (to check: all layers or only your own, both factions or one) | 10 messages of headroom, +1 per second; allowed on Retail, disabled on Classic | Only `HELLO`: who is online and with what data |
| `WHISPER` | One player | No per-prefix limit outside instances (the server may change this) | Main data transfer; `HELLO` to character friends |
| `GUILD` | The guild | Per-prefix limit | `HELLO`; the fallback path if `CHANNEL` does not work |
| `PARTY` / `RAID` | The group | Per-prefix limit | The same, for friends who fish together |
| Battle.net game data (`C_BattleNet.SendGameData`) | One Battle.net friend playing Forever | To check in the spike | `HELLO` and sessions with Battle.net friends (part 2) |

API limits: a prefix up to 16 characters, a message up to 255 characters. The `Enum.SendAddonMessageResult` result
is always read: `AddonMessageThrottle`, `ChannelThrottle`, `AddOnMessageLockdown` mean back off and pause.

### What the player sees

Nothing: addon messages do not reach the chat window, only addons with the same prefix receive them (the
`CHAT_MSG_ADDON` event). Only the wrapping around them can become visible:

| What can slip through | How we hide it |
| --- | --- |
| The `OKFishData` channel in the channel list and the line about joining it | `ChatFrame_RemoveChannel` from every chat window; a `CHAT_MSG_CHANNEL_NOTICE` filter through `ChatFrame_AddMessageEventFilter`. |
| General / Trade numbers shifting | Join the channel 30-60 s after login, when the common channels are already in place. |
| Text someone types into the channel by hand (`/join OKFishData`) | A `CHAT_MSG_CHANNEL` filter for this channel. |
| "Player X not found" after a whisper to a player who logged off | 12.0 has the `TargetOffline` code, probably silent. If not, a `CHAT_MSG_SYSTEM` filter for the names we have just whispered. |
| All 10 channel slots are taken | The addon does not join the channel and works through the guild and the group; `/okf share` shows this. |

GUILD, PARTY, RAID and WHISPER are completely invisible for addon messages.

### How the addon finds others

Every client sends a `HELLO` to the channel, the guild or the group from time to time. `CHAT_MSG_ADDON` brings the
sender's name, and that name becomes the whisper address. The peer list lives only in session memory: name, time of
the last `HELLO`, database hash. A peer with no `HELLO` for 30 min is removed.

### Libraries

None (decided for part 2, `specs/003-guild-group-sync/research.md` R4):

- **Encoding.** The game's own `C_EncodingUtil` (CBOR, Deflate, Base64, all in the Forever client) replaces
  LibSerialize and LibDeflate.
- **Sending.** A small queue with pace, budget and result handling (`Comm.lua`) replaces ChatThrottleLib.
- **Splitting.** An own part format replaces AceComm-3.0, which has no Battle.net path.

The first idea (those four libraries in `OneKeyFishing/Libs/`) would also have needed exceptions in
`npm run check`.

### Traffic budget (starting values, to refine after the spike)

| What | Limit |
| --- | --- |
| `HELLO` | Once per 10-15 min (random jitter), the first 60-120 s after login; 5-30 s after joining a group (at most once per 2 min); up to 20 friends per round, known peers first |
| Pace | Broadcasts at most 1 message per 2 s; whispers and Battle.net at most 2 per s |
| Sync sessions | 1 at a time, no more than 1 per 2 min; with one peer at most once per 10 min in a group, once per 30 min otherwise |
| Session size | Up to 8 KB and 25 encoded records per direction, but always at least one record; a record a peer would refuse (over 1,000 places or 32 KB, no cells of a game version, a seq above its casts) is not sent; the own record rolls to a new epoch at 500 places, so it always fits |
| Total sent | Up to 50 KB per hour per client |

The values for part 2 are in `specs/003-guild-group-sync/research.md` R7.

Syncing pauses on:
- `InCombatLockdown()`;
- the add-on restrictions `Chat`, `Encounter`, `ChallengeMode` and `PvPMatch`;
- `C_ChatInfo.InChatMessagingLockdown()` (not `AreOutgoingAddonChatMessagesRestricted()`: it is about chat
  messages sent by addons, allowed on tournament realms only, so it is true on a normal realm);
- an instance (`IsInInstance()`);
- a loading screen.

It is re-checked on the matching events (`ADDON_RESTRICTION_STATE_CHANGED` among them) and every 5 s while paused.
A path the game keeps refusing is left out until logout.

## Data model and merging

Every player publishes one "contribution record" under an anonymous ID. Clients keep the latest version of each
record, and the database is the sum of the records. Merging is idempotent: a record received twice or from
different people is not counted twice.

Why not just add up counters: in a network without a server the same data arrives by several paths. Summing over
paths inflates the numbers. A record with an owner and a version number (a simplified CRDT) solves this.

```lua
-- OneKeyFishingDB.shared (account-wide)
shared = {
  myID = "k7f2q6xa",    -- random, created once per account; never a character name
  seedEpoch = 3,         -- epoch of the bundled SeedData.lua
  records = {
    ["k7f2q6xa"] = {    -- contributor ID
      epoch = 3,         -- seed epoch the owner counted against
      seq = 41,          -- grows on every change of the owner's data
      seen = 1761234567, -- local: when we last received it (for eviction)
      cells = {
        ["1415:3:47"] = {
          c = 120, m = 9, t = 38,                   -- catches, misses, minutes fishing
          sx = 5420, sy = 8190,                     -- sums of catch positions (0-100), for the average point
          i = { [6291] = 64, [6303] = 41, [6358] = 7 }, -- item ID -> count
        },
      },
    },
  },
}
```

Merge rules:

1. Only the owner changes their own record, on every `FISH_CAUGHT` / `FISH_MISSED` and every minute of fishing.
   `seq` grows at most once a minute, so no needless versions are produced.
2. Someone else's record replaces the local one only when it has a higher `seq` (same ID and `epoch`). Duplicates
   and old versions are ignored.
3. The database shown = `SeedData` + the sum of the records not yet absorbed into the seed. The sums are cached per
   cell and recomputed only for the cells that changed.

### Epochs: how the seed and the records are not counted twice

A release with a seed of epoch E carries the sums and `absorbed`: every unit `<id>@<epoch>` the sums hold, with the
seq they hold it up to.

- A client deletes a stored version the seed holds whole (its seq up to the named one), keeps and passes on a newer
  one without counting it (the seed has its first part), and counts every unit the seed does not name.
- An owner whose record the seed names rolls it: a new record starts at the next epoch from zero, and the old one,
  when it is newer than what the seed holds, is kept and offered until a seed holds it whole
  (`specs/002-local-catch-db/data-model.md`, "Rolling the own record").
- Nothing is lost: the catches gathered after the author's harvest, or after the version of a record the author's
  client happened to hold (it may be weeks old for a record that came over the network), reach the next seed
  through the network. Until then they are not counted, so nothing counts twice.

### Size and eviction

- A record: up to 1,000 places and 32 KB encoded; anything larger is not accepted (part 2). The own record rolls to a
  new epoch at 500 places, so it always fits and keeps reaching the network.
- Part 2, among guild, group and friends: other records hold at most 20,000 places (~2 MB). Above the limit, the
  record with the oldest `seen` is evicted first, and no record of your own ID ever is.
- Part 3, with strangers: the order below replaces it. Above the limit, the records that add the least new information
  are evicted: first those whose cells already have thousands of catches in the seed, then those not seen for over
  60 days. Contributions for rare places (low-level zones, little data) are evicted last. `seen` is updated not
  only when a new version arrives, but also when a peer in a session confirms the same version (the bucket matched
  in `SUM` or `DIFF`). This way the records of players who stopped playing live on as long as they are in the
  network. Your own record is never evicted.
- A renamed, moved or reshaped field = `DB_SCHEMA` +1 and a migration in `Core.lua`, as CLAUDE.md requires; a new
  field is filled by `ApplyDefaults` without a bump.

### Performance

Goal: the feature adds no noticeable lag, neither in game nor on the loading screen.

| Where it can slow down | Protection |
| --- | --- |
| Loading SavedVariables at login | Other players' records are stored as compressed strings (as they arrived from the network), not as thousands of nested tables. The game reads a string many times faster. |
| Decompressing and computing the sums | Lazily and in chunks: up to 2 ms per frame, the rest in the next frames. Sums are computed only for the cells the UI looks at, and cached. |
| Receiving data from the network | One session at a time, up to 8 KB. Validation and merging go through the same queue with a per-frame limit. |
| Combat, instances, restrictions | All network work stops. Deferred work is processed later, not all at once. |
| Fishing | Your own record is updated by plain counter additions, as Stats does now; compression only before sending. |

Check: a test with 5,000 synthetic records in `tests/` measures loading and summing time. In game `/okf share`
shows the database size, memory (`GetAddOnMemoryUsage`) and the longest step in milliseconds (`debugprofilestop`).

## Sync protocol

Two clients first compare short hashes of their databases, and only then transfer the records the other one is
missing. If the databases are the same, the session ends after two messages. This is anti-entropy, as in
distributed databases: every session brings two copies closer, and a record spreads to everyone within a few
"handshakes".

Prefix `OKF1`: the digit is the protocol version. A client registers only its own prefix, so other versions never
reach it. The exact message forms, the part format and the limits on what is received are in
`specs/003-guild-group-sync/contracts/sync-protocol.md`.

| Message | Where | Content | Size |
| --- | --- | --- | --- |
| `HELLO` | CHANNEL / GUILD / PARTY / RAID, whisper or Battle.net to friends | node tag of this login, `seedEpoch`, number of records, hash of the whole database (never the anonymous ID) | 1 message |
| `SUM` | WHISPER | 32 bucket hashes (bucket = the first character of the ID in base32) | 1 |
| `DIFF` | WHISPER | `id.epoch.seq` for the buckets that differ | 1-10 |
| `WANT` | WHISPER | the `id@epoch` units needed | 1-3 |
| `REC` | WHISPER | a record, `C_EncodingUtil` CBOR + Deflate + Base64, in parts | up to 8 KB per session |
| `BYE` | WHISPER | end of session or refusal (sent, done, busy, paused, off, limit) | 1 |

Session flow:

1. Client B hears a `HELLO` from A with a different hash. There is no epoch gate: a unit B's seed already absorbed
   is simply not wanted.
2. B waits a random 2-20 s. A takes one session at a time and answers others `BYE busy`. This way a hundred
   clients do not rush at one. If A and B send each other `SUM` at the same moment, the smaller node tag leads.
3. B → A: `SUM`. A → B: `DIFF` for the buckets with different hashes.
4. Each side sees whose versions it is missing and sends `WANT`; `REC` comes in reply. The exchange goes both ways.
5. At the 8 KB limit the sender ends with `BYE`; the rest goes in the next session. The own record goes first, then
   the most recently seen.
6. No reply for 15 s or `TargetOffline`: the session is cancelled and the peer is paused for 30 min.

Hash: a 32-bit polynomial hash in plain arithmetic (no `bit`, so it is the same in the client and in fengari) over
the sorted `id.epoch.seq` strings of a bucket. Bucket hashes are cached and recomputed only on change. Every rule
is tested in `tests/` without the game: several protocol nodes in one fengari state with a fake network between
them.

## Protection against spam and fakes

Without a server it is impossible to prove the data is honest, so the protection has layers: checks on receipt,
contribution weights when showing, and cleanup in `harvest` before seeding. The stakes are low (someone sees a
wrong percentage), so this is enough.

| Threat | Protection |
| --- | --- |
| Flood from one sender | A limit per sender name (part 2, `Share.lua`): `HELLO` no more than 1 per 60 s (more are ignored), up to 1,160 units per hour (one per 240 bytes of a message, at least one per message: twice what an honest client can send to one peer in an hour), no more records in a session than it asked for and 175 records per hour, one record up to 32 KB encoded and 1,000 places. An offender is ignored until the end of the session. A peer answered with a `DIFF` gets `BYE busy` to another `SUM` within 8 minutes. |
| Impossible numbers | Catches in a cell no more than `t × 60 / 5` (a cast takes several seconds). The item sum ≤ catches × the maximum count per cast. An invalid record is rejected entirely. |
| Made-up items | The item ID must exist (`C_Item.GetItemInfoInstant`). An item that is in neither the seed nor your own catch is shown only when at least 3 different IDs report it in the same zone. |
| Many fake IDs (Sybil) | One contribution gives no more than 20% of the weight in a cell with 5+ contributions. The tooltip always says "based on N catches from K players". `harvest` looks for outliers and adds blocked IDs to the seed (`banned`). |
| Broken or old data | Version in the prefix, decoding in `pcall`, schema check (types, cell and size limits). |
| Frame rate drops | Decoding and recomputing sums take no more than 2 ms per frame, the rest in the next frame (`C_Timer.After(0, ...)`). |
| Forged versions of a record | Records are anonymous and unsigned, and a higher `seq` replaces a lower one. A record whose `seq` is above its casts is refused by the client and the harvest (the owner bumps it only after a settled cast), so a made-up `seq` needs as many made-up casts. Not covered yet: a forger who sends another player's ID and epoch with a higher `seq` and enough made-up casts makes the owner's real updates look older everywhere until a release names the unit, and the harvest keeps the forged version. Part 3 brings strangers in and has to close it before it ships: for example, limit how far a version may grow over the one held (casts and seq against the time since it was seen), or tie versions to the owner. |
| Privacy | Records have no names. The ID is random, but a peer that gets a record from its owner sees the sender's name next to the ID; a cell carries the sums of its cast positions, the average spot fished from. The notice and the settings page say so. The whisper sender's name is kept only in session memory, not in SavedVariables. |

## Seeding the database from releases

The author's client is an ordinary node of the network, so it collects other players' records by itself. Before a
release `npm run harvest` reads the author's SavedVariables and writes `OneKeyFishing/SeedData.lua`. All of this is
one command, with no manual collection. The seed gives new players the full database at once, and the network
brings the fresh data between releases.

```
Players with the addon  <->  In-game network (HELLO + whispers)  <->  Author's client
       ^                                                                   |
       | keep playing                                                      | before a release
       |                                                                   v
Updated addon  <--  Release on CurseForge (SeedData.lua)  <--  npm run harvest (the only manual step)
```

The network carries records between players, and `harvest` freezes them into the seed once per release. This way
the database grows without manual filling.

1. The author logs in a day before the release and stays online for several hours. They can use a heightened
   collection mode (`/okf share collect`): sessions more often, but within the same budget. They will not send
   more.
2. `npm run harvest`:
   - finds `WTF/Account/*/SavedVariables/OneKeyFishing.lua` from `WOW_ADDONS_DIR` in `.env` (what already exists
     for `link`);
   - reads the Lua table through fengari, which is already in the repository;
   - applies the same checks as the addon, plus outlier detection (a contribution that differs sharply from the
     rest in the same cell);
   - adds the new contributions to the old seed and writes `SeedData.lua`: `epoch + 1`, sums per cell, `absorbed`,
     `banned`;
   - prints a report: new cells, new items, rejected contributions, file size.
3. A commit to `develop` and the usual release (CHANGELOG, merge into `main`, tag). `npm run check` checks the
   seed's format and size (up to ~1 MB; the whole world is about 1,500 cells with water, ~3,000 combinations with
   skill and ~450 KB of text).

The `SeedData.lua` format is ASCII, uncompressed, so it can be read in review:

```lua
local _, ns = ...
ns.SeedData = {
  epoch = 4, built = "2026-12-01",
  cells = { ["1415:3:47"] = { c = 1840, m = 122, t = 610, k = 14, i = { [6291] = 912, [6303] = 655 } } },
  absorbed = "k7f2q6xa,m3p7x2zd,...", -- comma list, parsed on demand
  banned = "",
}
```

Start before the network exists: the first seed is built from the author's own catch by the same `harvest`.
Friends can voluntarily send their SavedVariables file; this is an option, not a duty. `harvest` accepts several
files.

### Modes and layers instead of realms

Forever has no realms. There are four "megarealm" modes (Normal, PvP, Roleplay, Hardcore), split by faction. The
world is divided into layers, and Familiar Faces picks the player's layer: by acquaintances, language and PvP
balance. A guild always sees each other. How custom channels and whispers pass through this is not publicly
documented, so it is on the spike checklist. In any case the network works without the author, and the seed
stitches together the parts that never meet directly. Catch tables are the same everywhere.

| If the channel reaches | What it means |
| --- | --- |
| The whole mode, all layers | One network per mode (or per faction within a mode). The seed carries data between modes and factions. |
| Only your own layer | The network still spreads: players move between layers and carry records with them, and the guild always links them. Slower, but with no change to the protocol. |

- `harvest` sees only what reached the author's client. To cover other modes and the other faction: characters
  there (log in before the release), or friends voluntarily send their SavedVariables; `harvest` accepts several
  files.
- Records from different modes merge without conflicts: the contribution ID does not depend on the mode or faction.
- Mode and faction are not stored in the records. Auction prices (phase 6), if they are ever shared, are tied to
  their own auction house and do not go into the seed.

### The data does not age

The seed only accumulates: every `harvest` adds new contributions to the old sums, and nothing is removed over
time. Low-level zones where almost nobody fishes after launch keep everything gathered before. The data of level 60
players in the same zones goes into a different skill range and does not mix with the data of newcomers.

The exception is a patch that changes the catch tables:

- `HELLO`, the records and the seed carry the game version (`GetBuildInfo`, for example `1.60.1`). After a new
  version the owner starts a new record, so data from before and after the patch does not mix.
- `harvest` compares item shares before and after the patch in every zone and prints the zones with a notable
  difference or new items.
- `npm run harvest -- --reset <uiMapID>` resets the zone's old sums, and from then on it counts only data from the
  new version. This is a rare manual step, only when Blizzard really changed something.

## UI and settings

The feature's main place is a "What can be caught here" tab in the statistics window. All texts go through `ns.L`;
data for other places goes into tooltips.

| Where | What it shows |
| --- | --- |
| StatsFrame, "What can be caught here" tab | Items of the current cell (or zone, when there is little data) for your skill range: icon, chance %, price, "1,840 catches · 14 players". A source mark: your catch / network / seed. |
| Item tooltip (ItemHooks) | "Caught in: Zone A 12%, Zone B 8%", top 3 zones. |
| Minimap button tooltip | Top 3 items of the current place. |
| StatsFrame, "Catch catalog" tab | Every item in the database (seed, your own catch, network) with a search by name in the client's language. Choosing an item lists the places it was caught: zone, cell, chance, catches, skill range. Choosing a place sets a map pin there. |
| Settings, a new "Shared database" page | "Use the shared catch database" (part 2), "Use the public channel" (part 3; off = guild, group and friends only), a status line. |
| `/okf share` | State: the seed and its epoch, records, peers in the last hour, last session, traffic in the last hour, pause and its reason. |
| `/okf debug` | A new section with the same state for bug reports. |
| First login after the update | A one-time popup: what is shared (no names) and where to turn it off. |

The chance in the tab = item / all catches in the cell, taking the contribution weights into account. Under 50
catches "little data" is shown instead of a percentage. This covers ROADMAP item 2, "Catch chances".

## Implementation phases

All phases ship together in release 1.2.0, built one spec at a time (parts 1 to 4, "Releases and specs"). Release
1.1.0 is the interface-language feature (`specs/001-interface-language`), released on its own. The network goes
first to the guild and the group, where it is easy to test with friends, and only then to the public channel.

1. **In-game spike** (no release). A separate branch with `/okf spike`, a checklist for the author: `CHANNEL` addon
   messages and `JoinTemporaryChannel` from an addon; the actual limits and result codes; whether whispers are
   unlimited; `C_Map.GetPlayerMapPosition` while fishing; `GetLootSourceInfo` in a pool and in open water; whether
   joining the channel and a whisper to an offline player show in chat; whether channel messages reach players on
   another layer and of the other faction (two accounts or a friend); when the Chat state of `AddOnRestrictionType`
   is active; whether `C_Map.SetUserWaypoint` and `C_SuperTrack.SetSuperTrackedUserWaypoint` work (map pins).
   - Done when: the answers to every question are written into CLAUDE.md "Known API facts".
2. **Local data v2.** The new place key, your own contribution record, `myID`, a `DB_SCHEMA` migration. The "What
   can be caught here" tab on your own data.
   - Done when: tests for the key and the record; two clients in different languages produce the same keys in game.
3. **Seed and `harvest`.** `tools/harvest.mjs`, `SeedData.lua`, merging the seed with your own data, checks in
   `npm run check`. Part 1 (spec 002).
   - Done when: a fresh install sees data from the first login.
4. **Network in the guild and the group.** `Comm.lua` (the transport) and `Share.lua` (the protocol), `HELLO` to
   GUILD / PARTY / RAID and to friends, whisper and Battle.net sessions, checks on receipt, pauses, `/okf share`.
   Part 2 (spec 003).
   - Done when: tests with two or three addon states converge to the same database; the author and a friend in a
     group exchanged data in game.
5. **Public channel.** The hidden channel, peer selection, jitter, contribution weights, `banned`. Part 3 (spec 004;
   left out of 1.2.0 if the spike shows that `CHANNEL` does not work).
   - Done when: a week in game without throttle errors or frame rate complaints; `harvest` sees records from
     players the author does not know.
6. **Catalog, chances and tooltips.** The "Catch catalog" tab: every item in the database with a search, the
   places for a chosen item, a map pin for a chosen place (`C_Map.SetUserWaypoint` + super tracking; no button on
   maps where `C_Map.CanSetUserWaypointOnMap` is false, such as instances). Item and minimap tooltips, a pool mark.
   Optionally, auction prices within a realm: the freshest scan wins, a price older than 3 days is not shared.
   - Done when: every item in the seed is found by a search in any interface language; a chosen place puts a pin
     on the map and the navigation arrow points to it. Part 4 (spec 005).

This plan lives in `docs/` while the feature is being built; when release 1.2.0 is out it moves to
`docs/history/`. Item 1 of the ROADMAP links to it.

## Releases and specs

The phases are built as four parts, each with its own spec (`speckit-specify`), all on the branch `002-shared-db`,
and ship together as release 1.2.0 (decided on 2026-10-29; 1.1.0 is the interface-language release). Each brief
below is the input for its spec: it says what and why, and repeats the shared rules, so every spec reads on its
own. The technical design stays in this plan and goes into `speckit-plan`.

| Part | Spec | Phases | Depends on |
| --- | --- | --- | --- |
| 1 | `002-local-catch-db` | 2, 3 (+ the spike questions it needs) | - |
| 2 | `003-guild-group-sync` | 1 (network questions), 4 | part 1 |
| 3 | `004-public-channel-sync` | 5 | part 2, a spike that confirms `CHANNEL` |
| 4 | `005-catch-catalog` | 6 | parts 1 and 2 (part 3 optional) |

- The spike (phase 1) is one temporary command, `/okf spike`; each part adds the questions it needs: part 1
  `C_Map.GetPlayerMapPosition` while fishing, `GetLootSourceInfo` in a pool, whether the catch depends on the skill
  at all; part 2 the guild, group, whisper and Battle.net questions; part 3 the channel; part 4 the map pins.
- Each spec is written once the previous one is implemented. The later ones depend on spike answers that come only
  after the game launch, so they are built on `VERIFY` assumptions like the earlier ones.

### Release 1.2.0

The game opens on 2026-11-04. Until then every part is built and tested without the game; after it, the debt of
all parts is closed and the release goes out once:

1. The author runs `/okf spike` (all sections, with a second player for the network) and the in-game checklists of
   every part (`docs/checklists/`). The answers go into CLAUDE.md "Known API facts"; code is fixed where an
   assumption was wrong; `VERIFY` markers are removed and the `verification.md` items of every spec are ticked.
2. Part 3 ships only if the spike confirmed `CHANNEL`; otherwise its code is left out of 1.2.0 (its spec says how).
3. `Spike.lua`, its TOC line, the `spike` command entry and `tests/spike_test.lua` are removed.
4. The author fishes and runs `npm run harvest` for the first real seed (own data, friends' files and the records
   the exchange collected); `SeedData.lua` and `seed/contributions.json` are committed.
5. `develop` (which by then holds 1.1.0) is merged into `002-shared-db`. In `CHANGELOG.md`, the interface-language
   entries stay under `[1.1.0]` and leave `[Unreleased]`.
6. `package.json` and `CHANGELOG.md` get version 1.2.0; `npm run build` must pass with no `VERIFY` marker left.
7. `002-shared-db` is merged into `develop`, `develop` into `main`, and the tag `1.2.0` is pushed
   (`docs/publishing.md`).

### Part 1 (spec 002): local catch data and bundled data

Decisions (agreed on 2026-10-29, before the spec):

| Topic | Decision |
| --- | --- |
| Place key | `<mapID>:<skill range>:<cell>`; the mapID as `C_Map.GetBestMapForUnit` returns it (no climb to the zone map) |
| Grid | 10x10, plus an average catch point per cell (sums of x and y), for the part 4 map pin |
| Skill range | `floor(base rank / 75)`, no pole or lure bonus |
| Contribution record | One per account (`OneKeyFishingDB.shared`, random `myID`); all characters add up; `epoch` and `seq` from the start |
| What counts | Only fishing in fishing mode, as now |
| Per item | Catches that contained the item and the number of pieces |
| Chance | Catches with the item / all catches (misses left out); the average pieces per catch next to it; the miss rate on its own line |
| Game version | `GetBuildInfo` in the record and the seed; `harvest --reset <mapID>` in part 1 |
| Pool or open water | Separate counters if the spike shows `GetLootSourceInfo` tells them apart; not shown in the tab yet |
| Old statistics | Not converted; they keep working as they are |
| Window | Tabs in the statistics window: "Statistics" and "What can be caught here" |
| Little data | Under 50 catches in the cell: all cells of the same mapID; under 50 there too: "little data" instead of a percentage |
| Skill filter | Own range by default; each range and "All" in a dropdown; no automatic switch, only a hint |
| Source filter | "All / Only mine", "All" by default (in part 2 "All" also takes in the network) |
| Remembered | Only the last open tab; the filters reset to their defaults |
| Auction price | Average unit price of the cheapest 20% of all listed pieces (instead of the lowest lot); under 5 pieces or 3 auctions listed: shown with a "few lots" mark and left out of catch value sums (vendor price there); the higher of vendor and auction as now; this also changes the value in the "Statistics" tab |
| Harvest input | Every `WTF/Account/*/SavedVariables/OneKeyFishing.lua` under `WOW_ADDONS_DIR`, plus friends' files as arguments |
| Release | Ships with whatever seed there is, no coverage threshold |
| Spike | Built now, run after the game launch on 2026-11-04 (the work goes ahead on assumptions marked `VERIFY(Vn)`, listed in `specs/002-local-catch-db/verification.md`; a release build refuses open markers): a temporary `/okf spike` and a checklist: `C_Map.GetPlayerMapPosition` while fishing, `GetLootSourceInfo` in a pool, what mapID caves and cities return, whether the auction house returns enough results for the cheapest 20%; the answers go into CLAUDE.md "Known API facts", the command is removed before the release |

```
Catch database, part 1 of 4 (release 1.2.0): local catch data and bundled data, no network.

Who and why: players want to know what a fishing spot gives, and in what proportions, before spending time
there. Today each player only sees their own statistics, keyed by localized subzone names.

What the player gets:
- The statistics window gets tabs: "Statistics" (today's content) and "What can be caught here". The window
  remembers the last open tab.
- "What can be caught here" lists the items of the spot the player stands at: icon, chance %, average pieces
  per catch, price, and how many catches the numbers are based on; the miss rate on its own line.
- Chance = catches that contained the item / all catches at the spot.
- Under 50 catches at the spot, the tab uses the whole map; under 50 there too, it says "little data" instead
  of a percentage. With no data at all it explains that.
- A skill filter (the player's own skill range by default, any range or "All") and a source filter ("All" or
  "Only mine"); both reset to their defaults on the next login.
- Data from the first login: every release bundles a catch database gathered so far, merged with the player's
  own catches without counting anything twice.
- Places are identified by numbers only (map, a 10x10 grid cell, a skill range of 75 points of base rank), so
  players in different client languages get the same places; the shown name is built in the player's language.
- Auction prices become robust: the average of the cheapest 20% of listed pieces instead of the lowest lot;
  with under 5 pieces listed the price is marked "few lots" and catch value sums use the vendor price. This
  also applies to the existing statistics.

Author's side: one command before a release finds every account's saved data on the author's PC (plus friends'
files given to it), checks it, and writes the bundled data file, with a report (new places, new items, rejected
data, file size). It can reset a zone after a game patch that changed its catch.

Rules: only fishing in fishing mode counts. One anonymous contribution per account; no names, exact
coordinates or gear in it (only a per-cell average catch point). The game version is recorded with the data.
Existing statistics keep working unchanged and are not converted (the new data is recorded alongside, with a
saved-data migration). Bundled data is readable text and size-limited. No noticeable effect on frame rate or
login time. Data does not expire, except that a game patch that changes catch tables can reset a zone. Pool
and open-water catches are counted apart if the game can tell them apart (not shown yet).

Before the release: an in-game spike checks position while fishing, pool detection, map IDs of caves and cities,
and how many auction results the game returns (built now, run after the game launch on 2026-11-04).

Covers ROADMAP item 2 (catch chances) for own and bundled data. Design: docs/shared-db-plan.md
(phases 2 and 3, section "Releases and specs").
```

### Part 2 (spec 003): exchange in the guild and the group

Decisions (agreed on 2026-10-29, while writing `specs/003-guild-group-sync/spec.md`; they replace the matching parts
of the brief below and of "UI and settings"):

| Topic | Decision |
| --- | --- |
| Who | Guild, party, raid, and online friends (character and Battle.net friends playing Forever) |
| When | Whenever online, also outside fishing mode; pauses as above |
| Setting | One: "Use the shared catch database", on by default. Off = nothing sent, nothing received; received data is kept but not counted, and counts again when turned back on |
| Anonymous ID | No "new ID" button |
| First login | A popup, once per account: what is shared (no names), where to turn it off; "Got it" / "Settings"; no exchange before it is closed |
| Settings page | A separate "Shared database" page: the setting, a short text, the status line (room for the part 3 channel setting) |
| Tab | Source filter stays "All / Only mine" ("All" takes in the network); "N catches from K players"; a quiet status line ("Exchange: 3 players, 5 min ago" or the pause reason); no toasts |
| `/okf share` | Translated, as other addon output; the `/okf debug` section stays English |
| Libraries | None: the game's own `C_EncodingUtil` (CBOR, Deflate, Base64; in the Forever client) replaces LibSerialize and LibDeflate, an own small queue and framing replace ChatThrottleLib and AceComm (`specs/003-guild-group-sync/research.md` R4; the "Libraries" section above is updated) |
| Battle.net | `C_BattleNet.SendGameData` (the global `BNSendGameData` is only a deprecated fallback in Forever) |
| Protocol | The version lives only in the prefix (`OKF1`), not in `HELLO`; no epoch gate (a unit the seed absorbed is simply not wanted); crossing `SUM`s: the smaller node tag leads; a path the game refuses 5 times in a row is left out until logout, and with every path left out the exchange is "unavailable"; the state also says "unavailable" while nothing went out since the login and every path tried is left out |
| Size limit | 20,000 places of other records; the oldest `seen` goes first, no record of the own ID; the order by new information moves to part 3 ("Size and eviction" above) |
| Player count | "N catches from K players": each contribution at most once; for bundled whole-map numbers K is a lower bound; a newer epoch of an ID the seed absorbed counts only above the seed's k. Shown from 2 players on; one player is just "N catches" |
| Storage of others' records | Plain tables in `shared.records` (the part 1 shape plus `seen`), copied field by field from the checked record, not compressed strings: the harvest reads them unchanged, and the view indexes each stored record per map once (built at runtime, never saved) |
| Own record's seq | Before a `HELLO` or a session the waiting seq bump of the own record is done at once (`CatchDB.FlushSeq`), so a peer never gets cells under an old seq |
| Absorbed | `absorbed` names every unit with the seq the seed holds, not only an ID's newest epoch: a newer version of a unit (an older copy reached the author's harvest) is kept and passed on instead of being deleted; the own record rolls when the seed names it or at 500 places (`docs/tech-debt.md`, the review of 2026-10-29) |
| Release | All four parts ship together as 1.2.0 from `002-shared-db` ("Release 1.2.0" above); 1.1.0 is the interface-language release |

```
Catch database, part 2 of 4 (release 1.2.0): exchange catch data with guild and group members in game.

Who and why: the bundled data only refreshes with releases; players fishing together or in one guild should
see each other's catches right away.

What the player gets:
- The addon finds other addon users in the guild and the group and exchanges catch data with them in the
  background, invisibly: nothing appears in chat.
- The "What can be caught here" tab also counts data from other players and shows "N catches from K players";
  the source mark gains "network".
- A new "Shared database" settings page: share my catch, receive others' data, reset my anonymous ID, a status
  line. /okf share shows the state (records, peers, last exchange, traffic, pause and its reason); /okf debug
  gets the same section.
- A one-time notice on first login after the update: what is shared (no names) and where to turn it off.
- The author's client collects others' data like any player, so the release command bundles it into the next
  release.

Rules: within Blizzard's UI Add-On Policy (data only, strict traffic budget, no chat spam); exchange pauses in
combat, instances, restricted states and loading screens; no effect on frame rate. Contributions are under a
random anonymous ID; no character names are stored. Data received twice or by several paths is never counted
twice. Implausible, broken or flooding data is rejected. Saved data stays size-limited.

Depends on part 1. Needs an in-game spike first (limits and result codes, whisper behavior). Design:
docs/shared-db-plan.md (phases 1 and 4).
```

### Part 3 (spec 004): the hidden public channel

```
Catch database, part 3 of 4 (release 1.2.0): exchange catch data with every addon user through a hidden
public channel.

Who and why: guild and group exchange only reaches people the player already knows; a public channel lets data
spread across the whole game mode between releases.

What the player gets:
- The addon announces itself in a hidden channel and exchanges data with strangers who run the addon, invisibly:
  the channel does not show in chat or the channel list, does not shift General/Trade numbers, and text typed
  into it by hand is hidden. If all channel slots are taken, the addon keeps working through guild and group.
- A setting "Use the public channel" (off = guild and group only).
- No single contributor can dominate a spot's numbers; tooltips and the tab keep saying how many players the
  data comes from. The author can block bad contributors in the bundled data.

Rules: same policy, privacy and performance rules as part 2; announcements are rare and jittered so many
clients do not hit one player at once.

Ships only if the in-game spike confirms that addon messages in custom channels work in WoW Forever (and shows
whether they reach other layers and the other faction). Depends on part 2. Design:
docs/shared-db-plan.md (phase 5).
```

### Part 4 (spec 005): catch catalog, tooltips, pools, prices

```
Catch database, part 4 of 4 (release 1.2.0): a catalog of everything caught in the game, and catch chances
outside the current spot.

Who and why: players want to find where a particular item is caught without going there first, and they look at
items and the minimap, not only at the statistics window.

What the player gets:
- A "Catch catalog" tab in the statistics window: every item anyone with the addon has caught (bundled data, own
  catch, other players), with a search by name in the player's language.
- Choosing an item lists the places it was caught: zone, spot, chance, number of catches, skill range.
- Choosing a place sets a map pin there, and the game's navigation arrow points to it. Places where the game does
  not allow pins (instances) are listed without the pin button.
- Item tooltips: "Caught in: Zone A 12%, Zone B 8%", the top 3 zones.
- The minimap button tooltip: the top 3 items of the current spot.
- If the game can tell them apart: pool catches separated from open water.
- Optional: shared auction prices, so the catch value shows without a scan of one's own (the freshest scan
  wins; prices older than 3 days are not shared), only if the auction house scope in Forever allows it.

Rules: the pin is the game's own user waypoint, the same one a player sets by hand; nothing acts for the player.
Searching and listing stay smooth with the whole database loaded.

Needs a spike check that map pins work in WoW Forever. Depends on parts 1 and 2 (part 3 optional). Design:
docs/shared-db-plan.md (phase 6).
```

## Risks and open questions

The biggest risk is that in Forever `CHANNEL` is disabled for addon messages, as in Classic. Then the data spreads
only through guilds and groups, more slowly, and the seed becomes the main path. The plan works in both cases:
phases 2-4 do not depend on the channel.

| Risk | What we do |
| --- | --- |
| `CHANNEL` is not available in Forever | GUILD / PARTY / WHISPER + seed; phase 5 is postponed. |
| Blizzard changes the limits or adds Chat restrictions | Result codes are always read, the backoff is exponential. The budget is constants in one place. |
| Few users at launch | The seed and your own data bring the value; the network only speeds things up. |
| Data poisoning | The "Protection" section + cleanup in `harvest` + `banned` in the seed. |
| A bloated SavedVariables, a long login | The ~2 MB limit and eviction; the seed absorbs old records with every release. |
| Other mapIDs in Classic / Anniversary / SoD (a ROADMAP plan) | `HELLO` and the seed carry `WOW_PROJECT_ID`; a separate seed for each game version. In Classic `CHANNEL` is definitely disabled. |

Open questions:

- [ ] Do `CHANNEL` addon messages and `JoinTemporaryChannel` from an addon work in Forever? (spike)
- [x] A 10x10 or a 20x20 grid? Decided for part 1: 10x10 plus an average catch point per cell.
- [ ] Does the catch in Forever depend on the skill at all (check on the gathered data; if not, drop the ranges)?
  Decided for part 1: ranges of 75 by base rank, no lure or pole bonus.
- [x] Sharing on or off by default? Decided for part 2: on, with a one-time popup at first login that says so
  honestly.
- [x] Pin precision: a cell is 10% of the map, so its centre may fall on land. Decided for part 1: an average catch
  point per cell (still not an exact position).
- [ ] Is the auction house in Forever per realm or per region? This decides whether to share prices.
- [ ] Does `GetLootSourceInfo` show a pool, so that pool catches can be separated?

### Sources

- [UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534)
- [C\_ChatInfo.SendAddonMessage — Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage)
- [C\_RestrictedActions.IsAddOnRestrictionActive — Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_C_RestrictedActions.IsAddOnRestrictionActive)
- [Addons in WoW Forever — Icy Veins](https://www.icy-veins.com/wow-forever/news/addons-in-wow-forever-blizzard-devs-just-addressed-the-big-question/)
- [WoW Forever addons: as restricted as Midnight — Kami Labs](https://kami-labs.fr/en/wow-classic/wow-forever-addons-restreints-comme-sur-midnight/)
- [OneKeyFishing repository](https://github.com/jPee2k/wow-addon__one-key-fishing) (`docs/ROADMAP.md`, `CLAUDE.md`,
  `Stats.lua`)
