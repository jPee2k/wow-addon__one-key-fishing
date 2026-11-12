# Implementation Plan: Exchange Fixes for Forever

**Branch**: `002-shared-db` (no branch of its own; the setup script names `010-exchange-forever-fixes` from the
feature folder) | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/010-exchange-forever-fixes/spec.md`

## Summary

Tech-debt batch 1 and the "1 catches" item of batch 5, built on `002-shared-db` for release 1.2.0:

- **Names (R1)**: names are kept as the game gives them. `ns.WithRealm` goes, and friends are addressed
  `"w:" .. info.name`. `ns.SameCharacter` compares with or without a realm suffix. The own name comes from a new
  `ns.PlayerName()` (`GetUnitName("player", true)`).
- **The public channel (R2)**: `Channel.AVAILABLE = false`.
  - The spec 004 switch already hides every channel part.
  - At login the addon leaves, once, any of its channels an earlier build left joined.
  - `NOT_ALLOWED_IN_CHANNEL` on its channel counts as a channel refusal.
  - V20-V25 and V41 close as "not shipped". The channel tests switch it on with a stub flag.
- **Proof steps (R3)**: the merge queue and the login seed check walk chains in chunks of 4 links. A frame step
  stops at a 4 ms budget, and at least one chunk always runs.
- **Offline whisper (R4)**: the hidden "No player named" line ends the session to its address.
- **"1 catch" (R5)**: three singular keys with nine translations each, picked when the count is 1.
- **The spike (R6)**: what the open steps still need stays: network, proof-step timing, areas, folding, auction
  search. The rest goes, the deliberate error included. Its saved test entries are dropped from the error log.
- **Documents and the 1.2.0 test page** follow (FR-016, FR-017).

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+
for the tools

**Primary Dependencies**: the WoW Mainline API as shipped in Forever 1.60.1; no libraries

**Storage**:
- No saved field changes shape, so there is no `DB_SCHEMA` bump.
- The players' `settings.shareChannel` stays. It is ignored while `AVAILABLE` is false.
- `charDB.channelSession` is read once and dropped, as today.

**Testing**:
- `npm test` and `npm run check`.
- The channel tests set the new stub flag `channel_on = true` (`tests/wow.lua`: `load_addon` switches
  `ns.Channel.AVAILABLE` on before the login events).
- Time-budget tests use the existing `profile_ms` and `profile_step` stubs of `debugprofilestop`.

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: a record check spends at most about 5 ms per frame step (SC-003). A 4096-link chain finishes
in about 6 s at 60 fps.

**Constraints**:
- Blizzard's Add-On Policy: no new message type and no new automatic action. Sends shrink: no channel HELLOs.
- ASCII outside the locales, 120-character lines, Lua 5.1/5.3 neutral.
- Nine translations for each new key.

**Scale/Scope**:
- About 9 addon files:
  - `Core/Data.lua`, `Core/Core.lua`, `Core/Spike.lua`;
  - `Exchange/Channel.lua`, `Exchange/Comm.lua`, `Exchange/Share.lua`, `Exchange/ShareProtocol.lua`,
    `Exchange/ShareGame.lua`;
  - `Catalog/Catalog.lua`, `UI/StatsFrame.lua`, `UI/Minimap.lua`;
  - the 10 locale files.
- About 30 test files get the `channel_on` flag, plus 4-5 new or changed test files.
- About 14 documents and the author's 1.2.0 test page.

**Order of work** (the author): implement and fix first, then the in-game check. Steps already confirmed are cited
(spec Context).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How the plan meets it | Result |
|---|---|---|
| I. Blizzard Policy | Fewer sends (no channel), the same paced queue and budget, no new automatic action; the offline line only ends a session | Pass |
| II. Language-Independent Game Data | Names are compared as the game gives them, not parsed by language. The "No player named" line comes from the client's own `ERR_CHAT_PLAYER_NOT_FOUND_S` (as today). New texts through `ns.L`, nine translations | Pass |
| III. Safe, Restorable State | No fishing-mode state touched; the channel leave at login frees a chat slot the addon took | Pass |
| IV. Verified Forever API | Built on the verified facts. Markers: V11 stays on the friends list (its name shape is unseen), V12 on the offline line, V26 on the budget. V19-V25 and V41 are closed by decision, not assumed | Pass |
| V. Checked and Tested Changes | One test per fix that fails without it (quickstart.md); the channel tests keep running with the channel switched on | Pass |
| VI. Simple Module Boundaries | No new module or message. `ns.PlayerName` and `ns.ForgetErrors` sit in Core (layer 0), used by Exchange (layer 2) and the spike. The channel stays in its module, switched off | Pass |
| Development Workflow | `CHANGELOG.md` and the manual in the same change; `CLAUDE.md` (the Forever API names bullet, the `Core/Data.lua` helpers), `docs/architecture/exchange.md` and `core.md` updated | Pass |

Re-check after Phase 1: still passes. The channel code stays behind its spec 004 switch (no deviation), and the
spike remains temporary.

## Project Structure

### Documentation (this feature)

```text
specs/010-exchange-forever-fixes/
├── plan.md              # This file
├── research.md          # Phase 0: R1-R6
├── data-model.md        # Phase 1: names, refusals, the step budget, texts, stubs
├── quickstart.md        # Phase 1: what the tests prove, the in-game steps
├── contracts/
│   └── exchange.md      # names, channel off, refusal, budget, offline line, texts, spike
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

No `verification.md` of its own: the markers keep their IDs in `specs/003-guild-group-sync/verification.md` (V11,
V12) and `specs/004-public-channel-sync/verification.md` (V19-V26, V41).

### Source Code (repository root)

```text
OneKeyFishing/
├── Core/Data.lua          # ns.WithRealm removed; ns.SameCharacter by suffix; ns.PlayerName()
├── Core/Core.lua          # ns.ForgetErrors(match)
├── Core/Spike.lua         # trimmed (R6); no deliberate error; drops its saved test entries
├── Exchange/Channel.lua   # AVAILABLE = false; leave a leftover channel once at login; NOT_ALLOWED_IN_CHANNEL; IsMe
├── Exchange/Comm.lua      # friend address as given; notFound keeps the address; the hidden line ends the session
├── Exchange/Share.lua     # PROOF_CHUNK, PROOF_BUDGET_MS (replace PROOF_STEPS)
├── Exchange/ShareProtocol.lua  # MergeOne: chunks within the budget
├── Exchange/ShareGame.lua # the login seed check: chunks within the budget
├── Catalog/Catalog.lua    # CatchesText: "1 catch"
├── UI/StatsFrame.lua, UI/Minimap.lua  # "1 catch, %s", "Session: 1 catch, %s"
├── Locales/*.lua          # three keys, nine translations each
└── README.md              # the exchange without the public channel

tests/
├── wow.lua                         # channel_on flag
├── core/names_test.lua             # SameCharacter, PlayerName (new)
├── exchange/comm/friends_test.lua  # friend address as given; one peer (new)
├── exchange/comm/offline_test.lua  # the hidden line ends the session (new)
├── exchange/channel/off_test.lua   # no join, leftover left once, NOT_ALLOWED counts (new)
├── exchange/share/budget_test.lua  # chunks within the budget, at least one (new)
├── catalog/catches_text_test.lua   # "1 catch" (new, or extended in an existing catalog test)
├── ui/spike_test.lua               # trimmed; no error handed on
└── (channel tests)                 # channel_on = true at the top
```

**Structure Decision**: the fixes stay in the modules that own each part. Core gets two small helpers, since
names and the error log are Core's. New tests go into the folders of their areas (`docs/development.md`).

## Complexity Tracking

No violations.
