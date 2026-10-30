# Implementation Plan: Catch Data Exchange Through a Hidden Public Channel

**Branch**: `002-shared-db` (all four parts of the shared catch database) | **Date**: 2026-10-30 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-public-channel-sync/spec.md`

## Summary

Every client with the addon joins one hidden chat channel, `OneKeyFishingShare`, and announces itself there with the
part 2 `HELLO`. A client that hears a stranger's `HELLO` starts the part 2 whisper session with it only by chance,
about two hearers per announcement however many clients are in the channel. Guild, group and friends keep priority.
The channel is joined late after a login as a temporary channel, so General and Trade keep their numbers. It is
removed from every chat window, and chat filters drop its notices and anything typed into it. The game's channel
lists still show it under its own name, which they build without any filter (the author's choice). It always leaves
one chat channel slot free for the player, and gives its own slot up with one line when the player hits the limit.
A password or a ban moves every client to the same fallback channel, five fixed names walked in order. The game's
password prompt is closed at once, and an addon client that becomes the owner clears the password.

Strangers bring data nobody vouches for, so part 3 also protects the numbers. These protections ship even if the
channel cannot:
- **Owner-bound versions.** Every record carries a link of its owner's hash chain (SHA-256, 80 bits), so only the
  owner can make a newer version; no version holds more than 180 s of casting per version step.
- **Weights.** Other players' contributions are capped at a fifth of the weight at spots with five or more
  contributions; the own catch counts in full.
- **New items.** An item that neither the seed nor the own catch knows needs three contributions on the map before it
  is listed. An item the client does not know yet is kept and shown as an "Unknown item" row with its ID.
- **Eviction.** Above the limit, records that add the least new information go first.
- **Block list.** The harvest reports outliers. The author can block an ID; the seed carries the block list and the
  proofs of what it absorbed.

The game opens on 2026-11-04, so this is built on the assumptions V19-V29 in [verification.md](verification.md),
marked in the code, and `/okf spike` gets a chat-channel section. If the spike shows that addon messages in a custom
channel do not work, one constant (`Channel.AVAILABLE`) takes the channel out of the release: the setting and the
texts with it. Details and rejected alternatives: [research.md](research.md).

## Technical Context

**Language/Version**: Lua 5.1 (WoW Forever client, Interface 16001, build 1.60.1, Mainline API); Node.js 18+ for the
tools.

**Primary Dependencies**: WoW API only, all in the 1.60.1 export; behaviour per spike (research R2-R4, R8, R9):
- Joining and finding the channel: `JoinTemporaryChannel`, `LeaveChannelByName`, `GetChannelName`,
  `C_ChatInfo.GetChannelInfoFromIdentifier`, `C_ChatInfo.GetNumActiveChannels`.
- Owner functions: `SetChannelPassword`.
- Events: `CHAT_MSG_CHANNEL_NOTICE`, `CHAT_MSG_CHANNEL_NOTICE_USER`, `CHANNEL_PASSWORD_REQUEST`,
  `CHANNEL_UI_UPDATE`, `UPDATE_CHAT_WINDOWS`, `UI_ERROR_MESSAGE`, `CHAT_MSG_SYSTEM`.
- `C_ChatInfo.SendAddonMessage` with chat type `CHANNEL` and the channel number; `CHAT_MSG_ADDON`.
- Hiding: `ChatFrameMixin:RemoveChannel` / `ContainsChannel` on each chat window, `ChatFrameUtil.AddMessageEventFilter`,
  `StaticPopup_Hide("CHAT_CHANNEL_PASSWORD")`.
- `Constants.ChatFrameConstants.MaxChatChannels` (20) and `ERR_TOO_MANY_CHAT_CHANNELS`.
- The Lua `bit` library for SHA-256.
- Unknown items: `C_Item.GetItemInfoInstant`, `C_Item.DoesItemExistByID`, `C_Item.RequestLoadItemDataByID`,
  `ITEM_DATA_LOAD_RESULT`.

No Lua libraries. The harvest uses `node:crypto` for SHA-256.

**Storage**:
- New fields: `settings.shareChannel`, `shareNoticeChannel` and `shared.chain` (the owner's chain secret and marks,
  never sent).
- A `proof` on every record.
- Seed fields `proofs` and `blocked`; `blocked` in `seed/contributions.json`.
- `DB_SCHEMA` stays 1.
- See [data-model.md](data-model.md).

**Testing**: `npm test` (fengari, `tests/wow.lua` stubs, now also a LuaBitOp-faithful `bit` stub and the channel API).
- New: `proof_test.lua`, `catchdb_weights_test.lua`, `catchdb_items_test.lua`, `channel_test.lua`,
  `share_channel_test.lua`, `channel_sim_test.lua` (size from `OKF_SIM_NODES`).
- Extended: store, comm, CatchHere, settings, notice, spike and harvest tests.
- `npm run check` (seed shape).
- The in-game checklist with two or three accounts ([quickstart.md](quickstart.md)).

**Target Platform**: WoW Forever client in any client language (Windows).

**Project Type**: World of Warcraft addon (single package `OneKeyFishing/`) plus the Node harvest tool.

**Performance Goals**:
- The longest exchange step stays under 5 ms (SC-005). A chain is walked in chunks of `PROOF_STEPS` links per frame
  step (`PROOF_STEPS` from the spike's timing; 32 to start); the own proof costs at most 63 links per seq bump; the
  chain's marks are built 64 links per step.
- A busy channel costs one counter update per `HELLO`.
- At most 50 KB sent per hour (SC-003).
- At most about 5 session requests per announcement (SC-002).

**Constraints**:
- Blizzard UI Add-On Policy: data only, nothing in chat but the one line in answer to the player's own action, strict
  pace and budget.
- No names stored.
- Literal `L` keys with nine translations each; ASCII Lua, lines up to 120 characters; Lua 5.1/5.3-neutral code
  (`bit` through the game's library and a faithful stub); no `L` lookup at file load.

**Scale/Scope**:
- Possibly thousands of addon users in one channel; at most 300 channel peers in memory; other records still at most
  20,000 places.
- About 20 new English texts × 9 translations.
- 1 new runtime file (`Channel.lua`); SHA-256 in `Data.lua`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status |
| --- | --- | --- |
| I. Blizzard Policy | **No game action:** joining a chat channel and addon messages only; nothing is clicked or cast. **Pace:** channel announcements every 30-50 min, broadcast pace, the part 2 budget of 50 KB per hour for everything, sessions by chance (about 2 requests per announcement), back-off on every throttle result. **Nothing in chat:** the channel is removed from chat windows and its lines are filtered. The only line is the one in answer to the player's own refused join. **The player's chat:** the channel never takes one of the last two slots, never shifts General or Trade. **No personal data:** anonymous records, names in session memory only, the chain's secret never leaves the account. **Disclosure:** the notice and the settings page say that the catch goes to any addon user, and that the channel's member list shows who uses the addon. | Pass |
| II. Language-Independent Game Data | **IDs only:** items by ID, also those the client does not know yet. The channel is found by its own fixed name, never a localized one; General and Trade are compared by number. **Localized:** every new visible text goes through `ns.L` with nine translations. **English:** the debug lines. | Pass |
| III. Safe, Restorable State | **Saved data:** only new saved fields (`shareChannel`, `shareNoticeChannel`, `shared.chain`, `proof`), `DB_SCHEMA` stays 1. **The player's settings:** the channel is temporary, removed from chat windows only for its own names, so nothing of the player's chat setup changes. **Merges:** whole records only, as in part 2; a chain walk interrupted by a pause leaves nothing half-stored. | Pass |
| IV. Verified Forever API | **Checked against the export:** every new call (research R2). **Marked:** behaviour is marked `VERIFY(V19..V29)` with fallbacks; the release build refuses open markers. **Ship switch:** `Channel.AVAILABLE` takes the channel out if V19 fails. **Spike:** a chat-channel section. **Bookkeeping:** facts go into `docs/forever-api.md` and new globals into `.luacheckrc`. | Pass |
| V. Checked and Tested | **Without the game:** the chain, weights, items, eviction, block list, channel state machine, transport rules and a many-node simulation run in fengari; the harvest in Node. **Lua 5.1/5.3:** `bit` is the game's library. The stub gives signed or unsigned 32-bit results from functions compiled at runtime from strings, so `npm run check` still parses every test as Lua 5.1. Both modes are checked against SHA-256 test vectors and Node's digest. | Pass |
| VI. Simple Module Boundaries | **One job per module:** `Channel.lua` (join, hide, slots, locks) is new because joining and hiding a chat channel is a job of its own. `Comm` only gains a path, `Share` the channel rounds and checks, `CatchDB` the views and the chain, `Data` SHA-256. **Messages:** one new message, `CHANNEL_STATE`, listed in CLAUDE.md. **One setting:** for a stated player need (spec). **Commands:** no new command. | Pass |

Post-design re-check (after Phase 1): unchanged, all pass. No violations, so Complexity Tracking stays empty.

Re-checked against the code on 2026-10-30 (T052): unchanged, all pass. Two details the design did not name: the
`SHARED_DATA_CHANGED` message also carries the store Share changed (listed in CLAUDE.md), and moderation of the
channel has no undo call, so the owner only clears a password (contracts/channel.md).

## Project Structure

### Documentation (this feature)

```text
specs/004-public-channel-sync/
├── spec.md
├── plan.md              # this file
├── research.md          # R1-R14 decisions
├── verification.md      # V19-V29: assumptions built on before the game launch, how each is closed
├── data-model.md        # saved fields, the chain, seed fields, views, eviction, session memory, channel states
├── quickstart.md        # automated, spike (chat-channel section) and in-game validation
├── contracts/
│   ├── channel.md       # names, joining, hiding, locks, slots, what goes through it, texts
│   ├── protocol.md      # changes to OKF1: the channel path, the proof, accepting records, announcements
│   └── api.md           # Data, Channel, Comm, Share, CatchDB additions; harvest commands; /okf share and debug
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks (not created here)
```

### Source Code (repository root)

```text
OneKeyFishing/
├── OneKeyFishing.toc          # + Channel.lua between Comm.lua and Share.lua
├── Data.lua                   # + ns.SHA256, ns.ProofStep
├── Channel.lua                # NEW: names, delayed temporary join, chat-window removal, filters, slots and giving
│                              #   way, locks and fallbacks, kicks, owner self-heal, state, CHANNEL_STATE
├── Comm.lua                   # + the channel path (send, receive, refusals), the part filter, the cap of all buffers
├── Share.lua                  # + channel rounds, the chance to start, near peers first and the busy retry, channel
│                              #   peer bound; Store: blocked, CheckVersion, eviction classes, no unknown-item rule;
│                              #   resumable merges; status, /okf share, debug, the notice that names the channel
├── CatchDB.lua                # + the chain (secret, marks, proof per bump, roll at the top), CheckRecord (proof,
│                              #   unknown items), CheckVersion, SeedProof, IsBlocked; views: weights, items shown,
│                              #   missRate, known/reporters/inSeed
├── Core.lua                   # defaults shareChannel, shareNoticeChannel
├── Debug.lua                  # Channel.Describe lines in the "Shared database" section
├── Spike.lua                  # TEMPORARY: + "Chat channel (V19-V27)" section (research R13)
├── Locales/*.lua              # new texts in all ten languages
└── UI/
    ├── Settings.lua           # "Use the public channel" (greyed with the main setting off), the text, its state
    └── CatchHere.lua          # the "Unknown item" row and tooltip, the weighted miss rate

tools/harvest.mjs              # chain checks and the casting limit, blocked, --block/--unblock, weights, proofs,
                               #   outlier report, seedProblems for proofs and blocked
tests/
├── wow.lua                    # chat channel API and notices, a LuaBitOp-faithful bit, item loading
├── run.mjs lua.mjs            # OKF_SIM_NODES -> the simulation's size (setGlobalNumber in lua.mjs)
├── proof_test.lua catchdb_weights_test.lua catchdb_items_test.lua channel_test.lua share_channel_test.lua
│   channel_sim_test.lua       # NEW
└── share_store_test.lua comm_test.lua catchhere_test.lua settings_test.lua share_notice_test.lua spike_test.lua
    harvest_test.mjs           # extended

.luacheckrc                    # new WoW API globals
README.md CHANGELOG.md CLAUDE.md docs/architecture/exchange.md docs/architecture/catch-db.md docs/architecture/ui.md
docs/architecture/core.md docs/development.md docs/forever-api.md docs/shared-db-plan.md docs/tech-debt.md
docs/checklists/public-channel.md
```

**Structure Decision**: the existing single-addon layout with one new runtime module (`Channel.lua`, the chat
channel). The protections extend the modules that own the data they protect: CatchDB (records, views, the own
chain), Share (the store), the harvest (the seed).

## Phases (for /speckit-tasks)

Phases 1 to 9 run now, before the game launch; phase 10 runs after 2026-11-04 with the debt of the other parts.
The list below groups the work by module. [tasks.md](tasks.md) orders it by user story (the channel first, US1), and
either order ends in the same code (tasks.md "Implementation Strategy").
Release: 1.2.0 ships all four parts together from `002-shared-db` once no `VERIFY` marker is left; the channel goes
in only if V19 holds (FR-026).

1. **Verification and spike**: V19-V29 markers; the "Chat channel" section of `/okf spike`; `tests/wow.lua` fakes for
   the channel API and its notices, a LuaBitOp-faithful `bit`, item loading; `OKF_SIM_NODES` in `tests/run.mjs`.
2. **Hash and chain (US2)**: `ns.SHA256` and `ns.ProofStep` with test vectors; the own chain in CatchDB (secret, marks
   in the background, proof per bump, roll at the top, the login fix for old records); `proof` in `CheckRecord`,
   `CleanRecord` and the harvest; `CheckVersion` (resumable) and the seed's `proofs`; resumable merges in Share;
   `proof_test.lua`.
3. **Store rules (US2, US4)**: unknown items accepted (part 2's rule removed); blocked IDs (refused, cleaned,
   never wanted or offered, the own one not offered); eviction classes; `share_store_test.lua`.
4. **Views (US2)**: weights, items shown, `missRate`, `known`/`reporters`/`inSeed`; the "Unknown item" row and
   tooltip; tests.
5. **Harvest (US4)**: chain checks between versions and the casting limit, blocked list and `--block`/`--unblock`, weights per
   cell, `proofs` and `blocked` in the seed, the outlier report, `seedProblems`; `harvest_test.mjs`.
6. **Channel (US1)**: `Channel.lua` (join, hide, filters, slots and giving way, locks and fallbacks, kicks, left by
   hand, owner self-heal, state, `CHANNEL_STATE`); the Comm channel path, part filter and buffer cap;
   `channel_test.lua`, `comm_test.lua`.
7. **Channel protocol (US1)**: channel rounds, the chance to start, near peers first and the busy retry, the channel
   peer bound; `share_channel_test.lua`; `channel_sim_test.lua` (SC-001, SC-002, SC-011).
8. **Setting, notice, state (US3)**: `settings.shareChannel`, the checkbox and the page text, `shareNoticeChannel` and
   the notice text, `/okf share` and debug lines; texts and nine translations; tests.
9. **Docs and hand-off**:
   - README: the public channel, the setting, what others can see.
   - CHANGELOG `[Unreleased]`.
   - CLAUDE.md: the module, the message, the traps.
   - `docs/architecture/exchange.md`, `catch-db.md`.
   - `docs/shared-db-plan.md`: part 3 decisions, the plan's "10 channel slots" corrected to 20.
   - `docs/tech-debt.md`: the flood-of-parts item closed by FR-010.
   - `docs/checklists/public-channel.md`.
   - The spike and the checklists ready for launch day.
10. **After launch (debt)**: the author runs the spike (with a second player) and the checklist (three accounts).
    Then:
    - Answers go into `docs/forever-api.md`.
    - Code is fixed where an assumption was wrong.
    - If V19 fails, `Channel.AVAILABLE = false` and the channel's texts leave README and CHANGELOG.
    - Markers are removed and V19-V29 ticked.
    - Release 1.2.0 with the other parts.

## Complexity Tracking

No constitution violations to justify.
