# Implementation Plan: Catch Data Exchange in the Guild, the Group and with Friends

**Branch**: `002-shared-db` (all four parts of the shared catch database) | **Date**: 2026-10-29 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-guild-group-sync/spec.md`

## Summary

Clients that run the addon find each other in the guild, the home group and the friends list (character and
Battle.net friends playing Forever) and exchange the part 1 contribution records in the background. Discovery is a
`HELLO` broadcast to the guild and the group, and a `HELLO` by whisper or Battle.net game data to online friends.
A session goes by whisper (or game data) between two clients: bucket hashes, then the differing entries, then only
the missing records, each one serialized, compressed and Base64-encoded with the game's own `C_EncodingUtil`. No
third-party library is needed. Received records are checked by the same rules as the harvest and stored per
`id@epoch`. They count in "What can be caught here" under "All" next to the seed and the own record, and they drop
out once a release's seed absorbs them, so nothing counts twice.

One setting turns everything on or off. A one-time popup explains it. A status line, `/okf share` and a
`/okf debug` section show the state. The transport keeps a pace far below the game's throttle and a 50 KB per hour
budget, reads every send result, and pauses in combat, in instances, on loading screens and under Midnight-level
restrictions. The game opens on 2026-11-04, so this is built now on the assumptions V10-V18 in
[verification.md](verification.md), marked in the code; `/okf spike` gets a network section for launch day.
Details and rejected alternatives: [research.md](research.md).

## Technical Context

**Language/Version**: Lua 5.1 (WoW Forever client, Interface 16001, build 1.60.1, Mainline API); Node.js 18+ for
the existing tools.

**Primary Dependencies**: WoW API only. All of it is in the 1.60.1 dump; behaviour is per spike.
- `C_ChatInfo`: `RegisterAddonMessagePrefix`, `SendAddonMessage`, `InChatMessagingLockdown`,
  `AreOutgoingAddonChatMessagesRestricted`; `CHAT_MSG_ADDON`.
- `C_BattleNet`: `SendGameData`, `GetFriendNumGameAccounts`, `GetFriendGameAccountInfo`; `BNGetNumFriends`;
  `BN_CHAT_MSG_ADDON`.
- `C_FriendList`: `GetNumFriends`, `GetFriendInfoByIndex`.
- `C_RestrictedActions.IsAddOnRestrictionActive` and `ADDON_RESTRICTION_STATE_CHANGED`.
- `C_EncodingUtil`: `SerializeCBOR`, `DeserializeCBOR`, `CompressString`, `DecompressString`, `EncodeBase64`,
  `DecodeBase64`.
- `ChatFrameUtil.AddMessageEventFilter`.
- Already in use or plain: `IsInGuild`, `IsInGroup`, `IsInRaid`, `IsInInstance`, `InCombatLockdown`,
  `C_Item.GetItemInfoInstant`.

No Lua libraries (research R4).

**Storage**: `OneKeyFishingDB.settings.shareDB`, `OneKeyFishingDB.shareNotice`, and other players' records in
`OneKeyFishingDB.shared.records` keyed `<id>@<epoch>` with `seen`. Peers, sessions and traffic live in memory only.
`DB_SCHEMA` stays 1. See [data-model.md](data-model.md).

**Testing**: `npm test` (fengari, `tests/wow.lua` stubs).
- New: the `share_*_test.lua` files (the store and hashes; several protocol nodes over a fake network:
  convergence, duplicates, limits, pauses; the game node and the setting; absorbed units; the load test; a refused
  account; the popup), `comm_test.lua` and `comm_enum_test.lua` (framing, pace, budget, result codes, filter) and
  `settings_test.lua` (research R13).
- Extended: `catchdb_test.lua`, `catchhere_test.lua`, `harvest_test.mjs`.
- `npm run check`.
- In-game checklist with a second player in [quickstart.md](quickstart.md).

**Target Platform**: WoW Forever client in any client language (Windows).

**Project Type**: World of Warcraft addon (single package `OneKeyFishing/`).

**Performance Goals**:
- No frame does more than one record decode, check and merge (spread with `C_Timer.After(0, ...)`); the longest
  step, shown in `/okf debug`, stays under 5 ms (SC-006).
- The view cache is invalidated only when records change.
- Login is not noticeably slower with 20,000 stored places (V16).
- At most 50 KB sent per hour (SC-005).

**Constraints**:
- Blizzard UI Add-On Policy: data only, no game action, strict pace and budget, nothing in chat.
- No names stored; no ID next to a name in `HELLO`.
- Literal `L` keys with nine translations each; ASCII Lua, lines up to 120 characters; Lua 5.1/5.3-neutral code
  (hash by arithmetic, no `bit`); no `L` lookup at file load.

**Scale/Scope**:
- Guild, group and friends: tens of peers, up to a few hundred records; other records together at most 20,000
  places.
- About 25 new English texts × 9 translations.
- 2 new runtime files (`Comm.lua`, `Share.lua`); 1 new settings page.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status |
| --- | --- | --- |
| I. Blizzard Policy | **No game action:** only addon messages carrying data. **No outside traffic:** only `SendAddonMessage` and Battle.net game data. **Pace:** one session at a time, a pace far below the throttle, a 50 KB per hour budget, back-off on throttle and lockdown results, pauses under restrictions. **Nothing in chat**; no ads. **No personal data:** anonymous records, names only in session memory, never an ID next to a name in `HELLO`. **Disclosure:** sharing is disclosed by a one-time popup and can be turned off in one place. | Pass |
| II. Language-Independent Game Data | **IDs only:** items by ID; places by number keys (part 1). **Localized:** every new visible text goes through `ns.L` with nine translations, `/okf share` output included. **English:** the `/okf debug` section and the `share` command description. | Pass |
| III. Safe, Restorable State | **Saved data:** only new saved fields (`shareDB`, `shareNotice`, other records), filled by `ApplyDefaults`; `DB_SCHEMA` stays 1. **Merges:** a received record is merged only whole, so a pause or logout mid-session leaves nothing half-written. **Untouched:** the own record and the statistics. | Pass |
| IV. Verified Forever API | **Checked against the dump:** every new call was checked there (research). **Marked:** behaviour is marked `VERIFY(V10..V18)` with fallbacks; the release build refuses open markers. **Spike:** it gets a network section for launch day. **Bookkeeping:** facts go into CLAUDE.md and new globals into `.luacheckrc`. | Pass |
| V. Checked and Tested | **Without the game:** the protocol and the transport logic are tested in fengari (the `share_*_test` files, `comm_test`), and convergence runs over several nodes. **Extended tests:** CatchDB, the tab and the harvest tests are extended. **Lua 5.1/5.3:** the hash avoids `bit`, so the code stays 5.1/5.3-neutral. | Pass |
| VI. Simple Module Boundaries | **One job per module:** `Comm` (transport) and `Share` (protocol, others' records, state); `CatchDB` (check, views). **Commands:** `share` is declared in `Commands.lua`. **Messages:** two new messages, `SHARED_DATA_CHANGED` and `SHARE_PAUSE`, listed in CLAUDE.md. **One setting:** it answers a stated player need (spec). **No libraries.** | Pass |

Post-design re-check (after Phase 1): unchanged, all pass. No violations, so Complexity Tracking stays empty.

## Project Structure

### Documentation (this feature)

```text
specs/003-guild-group-sync/
├── spec.md
├── plan.md              # this file
├── research.md          # R1-R13 decisions
├── verification.md      # V10-V18: assumptions built on before the game launch, how each is closed
├── data-model.md        # saved fields, other records, views, session memory, states, hashes
├── quickstart.md        # automated, spike (network section) and two-player in-game validation
├── contracts/
│   ├── sync-protocol.md     # OKF1 messages, framing, session, limits
│   └── share-api.md         # ns.Comm, ns.Share, CatchDB additions, /okf share, /okf debug
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks (not created here)
```

### Source Code (repository root)

```text
OneKeyFishing/
├── OneKeyFishing.toc          # + Comm.lua and Share.lua after CatchDB.lua
├── Comm.lua                   # NEW: prefix, framing, send queue (pace, budget, results, back-off), receive,
│                              #   friends enumeration, pause rule, "player not found" filter
├── Share.lua                  # NEW: protocol node (peers, HELLO rounds, sessions, buckets, hashes, encoding),
│                              #   others' records (accept, replace, absorbed cleanup, eviction), status,
│                              #   /okf share text, debug lines, the one-time popup
├── CatchDB.lua                # CheckRecord; "All" takes in others' records when sharing is on; players in views;
│                              #   version bump on SHARED_DATA_CHANGED (Comm fires SHARE_PAUSE)
├── Core.lua                   # defaults shareDB, shareNotice; ns.ShowPopup onCancel / onHide
├── Commands.lua               # + share
├── Debug.lua                  # "Shared database" section
├── Spike.lua                  # TEMPORARY: + network section (research R12)
├── Locales/*.lua              # new texts in all ten languages
└── UI/
    ├── Settings.lua           # "Shared database" subcategory page: the setting, a text, the status line
    └── CatchHere.lua          # "N catches from K players", the status line

tests/
├── wow.lua                    # addon messages, Battle.net, friends, restrictions, C_EncodingUtil fakes
├── share_*_test.lua comm_test.lua comm_enum_test.lua settings_test.lua   # NEW (research R13)
├── catchdb_test.lua catchhere_test.lua   # extended
└── harvest_test.mjs           # extended: other players' records in the author's file

.luacheckrc                    # new WoW API globals
README.md CHANGELOG.md CLAUDE.md docs/shared-db-plan.md docs/ROADMAP.md docs/checklists/
```

**Structure Decision**: the existing single-addon layout with two new runtime modules (transport and protocol), a
new settings page in the existing settings file, and no new tool. `tools/harvest.mjs` already reads every record
in the saved data; only its test grows.

## Phases (for /speckit-tasks)

Phases 1 to 8 run now, before the game launch; phase 9 runs after 2026-11-04, together with the debt of the other
parts. Release: 1.2.0 ships all four parts of the shared catch database together from `002-shared-db`, once no
`VERIFY` marker is left (`docs/shared-db-plan.md` "Release 1.2.0"); 1.1.0 is the interface-language release.

1. **Verification and spike**: the V10-V18 markers convention (as part 1); the network section of `/okf spike`
   (research R12); `tests/wow.lua` fakes for every new API, `C_EncodingUtil` included.
2. **Foundation**: the defaults (`shareDB`, `shareNotice`); `CatchDB.CheckRecord` with tests; storing others'
   records (accept, replace, absorbed cleanup at login, eviction) with tests.
3. **Transport (`Comm.lua`)**: prefix, framing and joining, the queue with pace and budget, result codes and
   back-off, the pause rule, friends enumeration, the chat filter; `comm_test.lua`.
4. **Protocol (`Share.lua`, US1)**: the node, `HELLO` rounds and triggers, sessions, buckets and hashes, encoding,
   limits per sender; `share_protocol_test.lua` with convergence of three or more nodes; the game node bound to
   `Comm` (`share_game_test.lua`).
5. **Views (US1)**: "All" with others' records, `players`, `SHARED_DATA_CHANGED`; the tab's player count; tests.
6. **Setting, popup, status (US2, US3)**: the "Shared database" page, `Share.SetEnabled`, the one-time popup
   (`ns.ShowPopup` extended), the status line in the tab and on the page, `/okf share`, the debug section; texts
   and translations; tests.
7. **Harvest and release notes (US4)**: `harvest_test.mjs` with other players' records. Docs:
   - README: what is shared and how to turn it off.
   - CHANGELOG `[Unreleased]`.
   - CLAUDE.md: modules, the message, the protocol, new API facts once known.
   - `docs/shared-db-plan.md`: libraries replaced by `C_EncodingUtil`, decisions.
   - ROADMAP.
   - `docs/checklists/` with the two-player checklist.
8. **Hand-off**: the spike and feature checklists and [verification.md](verification.md) ready for launch day; the
   feature stays unreleased.
9. **After launch (debt)**: the author runs the spike (with a second player) and the feature checklist. Then:
   - Each answer goes into CLAUDE.md.
   - The code is adjusted where an assumption was wrong.
   - The markers are removed and V10-V18 ticked.
   - Release 1.2.0 with the other parts. The spike sections of all parts run in one session before `Spike.lua` is
     removed.

## Complexity Tracking

No constitution violations to justify.
