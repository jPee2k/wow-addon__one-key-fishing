# Implementation Plan: Tech Debt Fixes for 1.3.0

**Branch**: `015-tech-debt-fixes` | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/015-tech-debt-fixes/spec.md`

> **Revision, review 4 (2026-11-16): User Story 1 withdrawn.** The game writes saved variables only at a logout,
> a `/reload` or the exit, never at a crash, and `PLAYER_LOGOUT` restores the CVars (emptying the record) before that
> write, so a crash leaves no record on disk on any character; a disconnect logs out and restores as before. The
> account-wide record (US1, FR-001 to FR-004, SC-001, the schema 2 migration, V52) was built and reverted at the
> author's choice; the CVar record stays per character as in 1.2.0. US2 and US3 stand. `docs/tech-debt.md` "History"
> records the dropped item.

## Summary

The three open items of `docs/tech-debt.md`, fixed in one commit: the CVar record of fishing mode becomes
account-wide (schema 2, the old per-character record migrated), so a crash is restored at any character's login; the
rows the player changed by hand while fishing survive a `/reload` in the character record next to `resumeMode`; and
the exchange's activity counts group peers by one client key (`Node:ClientKey`, which `Node:SameClient` uses too),
so a partner who relogs counts once. No message, text
or exchange format changes.

## Technical Context

**Language/Version**: Lua 5.1 (WoW Forever client, Interface `16001`); tests in fengari (Lua 5.3), Node.js 18+ tools

**Primary Dependencies**: WoW Mainline API (`C_CVar`, saved variables); no library

**Storage**: SavedVariables `OneKeyFishingDB` (account-wide) and `OneKeyFishingCharDB` (per character); schema 1 -> 2

**Testing**: `npm test` (fengari harness, stubs in `tests/wow.lua`), `npm run check` (luacheck and the repository
rules)

**Target Platform**: WoW Forever 1.60.1 (`WOW_PROJECT_ID = 18`)

**Project Type**: game addon

**Performance Goals**: `Node:Activity` stays linear in the peer count (it groups in one pass); called for the status
line and the reports only

**Constraints**: Blizzard UI Add-On Policy; CVars recorded before they change; no 5.1/5.3 differences

**Scale/Scope**: four files of addon code (`Core/Core.lua`, `Fishing/Mode.lua`, `Exchange/ShareNode.lua`,
`Exchange/ShareProtocol.lua`) and one line of `Core/Debug.lua`; two test helpers in `tests/wow.lua`, four test files
extended and four new; docs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Policy | no game action added or automated; the exchange's traffic is unchanged | Pass |
| II. Language-independent data | CVars by name (not localized); no new text | Pass |
| III. Safe, restorable state | the record is still written before each change; it is now restored at any character's login (stronger); a moved field bumps `DB_SCHEMA` with a migration; only a CVar still holding the addon's value is restored | Pass |
| IV. Verified Forever API | no new API; the scope of each CVar is read from the client's CVar table (none per character) and marked `VERIFY(V52)` with its checklist step, as a fact only the game confirms; the `/reload` events are those of today | Pass |
| V. Checked and tested | each fix gets a test that fails without it; Mode, Core and Share logic run in the harness | Pass |
| VI. Module boundaries | changes inside Fishing (layer 1), Core (layer 0) and Exchange (layer 2); no new message, module or command; `Debug.lua` reads the record as before; `ClientKey` lives in `ShareNode.lua` with `SameClient`, the one place that defines "the same client" (no second copy in `ShareProtocol.lua`); the test helpers live once in `tests/wow.lua` | Pass |

Post-design re-check (after research, data model, contract): still Pass. The new saved field (`resumeOwned`) and the
moved one (`savedCVars`) are documented in `docs/architecture/core.md` and `fishing-mode.md`; the CLAUDE.md
cross-module rule "stored in the character DB" is corrected for the CVars.

## Project Structure

### Documentation (this feature)

```text
specs/015-tech-debt-fixes/
├── plan.md              # This file
├── research.md          # R1-R6
├── data-model.md        # savedCVars moved, resumeOwned, the activity counts
├── quickstart.md        # the tests that prove each fix
├── contracts/
│   └── module-api.md    # D0-D4, M1-M6, K1-K2, A1-A4, G1
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── Core/Core.lua                 # DB_SCHEMA 2, Migrate passes the account table, MIGRATIONS.charDB[2]
├── Core/Debug.lua                # "saved by the addon: CVars" reads ns.db.savedCVars
├── Fishing/Mode.lua              # the record in ns.db; resumeOwned at logout, taken at PLAYER_ENTERING_WORLD
├── Exchange/ShareNode.lua        # Node:ClientKey; Node:SameClient through it
└── Exchange/ShareProtocol.lua    # Node:Activity counts a client key once

tests/
├── wow.lua                                 # fishing_ready(), login_with(): one copy each
├── core/migrations_test.lua
├── fishing/cvar_restore_test.lua
├── fishing/cvar_sync_test.lua
├── fishing/cvar_other_character_test.lua   # new
├── fishing/cvar_reload_test.lua            # new
├── fishing/cvar_reload_fight_test.lua      # new
├── fishing/cvar_login_owned_test.lua       # new (a real login is its own load sequence)
└── exchange/share/protocol_test.lua

docs/
├── architecture/core.md          # the saved-field tables
├── architecture/fishing-mode.md  # the record's scope, resumeOwned, the two-accounts limit
├── architecture/exchange.md      # the activity counts per client
└── tech-debt.md                  # the three items out, a History line

CLAUDE.md                         # cross-module rule: the CVars in the account DB
CHANGELOG.md                      # [Unreleased] Fixed: two lines (crash restore on any character, the count)
```

**Structure Decision**: no new addon file or folder; the fixes stay in the modules that own the state (Mode, Core,
ShareProtocol). The player manual (`OneKeyFishing/README.md`) already says the settings come back "after a `/reload`,
a disconnect or a crash" and that a hand-changed setting keeps its value; it gains nothing.

## Implementation notes

1. **Core.lua**: `DB_SCHEMA = 2`; `Migrate(data, migrations, account)` calls `migrations[version](data, account)`;
   `ADDON_LOADED` passes `OneKeyFishingDB` when it migrates the character table (after the account table).
   `MIGRATIONS.charDB[2](data, account)` copies `data.savedCVars` into `account.savedCVars` (created on demand; the
   character's entry overwrites) and sets `data.savedCVars = nil`. A brand-new character table gets schema 2 with
   nothing to move.
2. **Mode.lua**: replace `ns.charDB.savedCVars` with `ns.db.savedCVars` in `RestoreSaved`, `DropEmptyRecord`,
   `SyncCVars`, `RestoreCVars` and the `PLAYER_REGEN_DISABLED` handler; update the file's header comment.
   `PLAYER_LOGOUT`: after `RestoreCVars()`, `ns.charDB.resumeOwned = next(playerOwned) and CopyOf(playerOwned)` (nil
   when empty). `PLAYER_ENTERING_WORLD`: take `resumeOwned` with `resumeMode` and clear both; on resume call
   the file-local `Enter(owned)`. The body of `Mode.Enter` moves into that local (`playerOwned = owned or {}`, set
   before `SyncCVars()`); the public `Mode.Enter()` calls `Enter(nil)`, so no caller (the minimap menu passes its own
   arguments to `Mode.Toggle`) can hand it a table.
3. **ShareNode.lua**: `Node:ClientKey(address)` next to `Node:SameClient`, which becomes
   `self:ClientKey(a) == self:ClientKey(b)`. **ShareProtocol.lua**: `Node:Activity` keeps, per
   `self:ClientKey(address)` of each non-channel peer, the peer with the latest `heard` in the hour and a synced flag,
   then adds each key once; channel peers as today.
4. **Debug.lua**: one line.
5. **Tests** as in [quickstart.md](quickstart.md); first the two helpers in `tests/wow.lua` (research R6); existing tests that set `ns.charDB.savedCVars` move to
   `ns.db.savedCVars`; the migration tests' expected schema becomes 2.
6. **Docs** as listed above; `docs/tech-debt.md` keeps its "Fix batches" heading with no batch and a History line for
   2026-11-16 (spec 015). `docs/release-plan.md`: only the batch 11 line leaves the 1.2.1 section (the author
   rewrites that section for 1.3.0 when the release is prepared).

## Complexity Tracking

No violation; nothing to justify.
