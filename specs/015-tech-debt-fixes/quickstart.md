# Quickstart: Tech Debt Fixes for 1.3.0

The rules being checked are in [contracts/module-api.md](contracts/module-api.md); the state is in
[data-model.md](data-model.md).

> **Revision, review 4 (2026-11-16): User Story 1 withdrawn: the parts below about the account-wide record, schema 2 and character B (D0-D4, M1, M2, M6, G1, `cvar_other_character_test.lua`) no longer apply.** The game writes saved variables only at a logout,
> a `/reload` or the exit, never at a crash, and `PLAYER_LOGOUT` restores the CVars (emptying the record) before that
> write, so a crash leaves no record on disk on any character; a disconnect logs out and restores as before. The
> account-wide record (US1, FR-001 to FR-004, SC-001, the schema 2 migration, V52) was built and reverted at the
> author's choice; the CVar record stays per character as in 1.2.0. US2 and US3 stand. `docs/tech-debt.md` "History"
> records the dropped item.

## Automated

```sh
npm run check
npm test
```

Each new test fails on the code before this spec (spec FR-009):

| Test | Proves | Fails without |
|---|---|---|
| `tests/core/migrations_test.lua` (extended) | D1-D4: schema 2; a 1.2.0 character record moved into the account record, the character's entry winning; nothing else changed | `MIGRATIONS.charDB[2]` |
| `tests/fishing/cvar_restore_test.lua`, `cvar_sync_test.lua` (extended) | M1: the record is written to the account table only | the account-wide record |
| `tests/fishing/cvar_other_character_test.lua` (new) | M2, M6: a crash's record left by character A is restored when character B logs in (a fresh character table), the line shows once, a later login restores nothing, gear untouched | the account-wide record |
| `tests/fishing/cvar_sync_test.lua` (extended) | M3: the logout stores the hand-changed rows in `resumeOwned` | `resumeOwned` at logout |
| `tests/fishing/cvar_reload_test.lua` (new) | M4, M5, SC-002: a hand-raised music volume stays through the resume, a second `/reload` and the exit; an untouched row is applied again; a fresh entry owns nothing | `resumeOwned` at the resume |
| `tests/fishing/cvar_reload_fight_test.lua`, `cvar_login_owned_test.lua` (new) | M4: a resume blocked by a fight, and a real login, drop the list | the drop in `PLAYER_ENTERING_WORLD` |
| `tests/exchange/share/protocol_test.lua` (extended) | A1-A3: a client heard by Battle.net, then by the group with a new tag (and its Battle.net HELLO with the new tag), counts as group 1, bnet 0, exchanged 1; two different clients and a peer without a tag each count once; K1, K2: `SameClient` answers as before | `ClientKey` and the grouping in `Activity` |

The new files start through `login_with` and `fishing_ready` of `tests/wow.lua` (research R6), not copies of the
loading steps.

## In game (optional, after the implementation)

Not required for the release (research: each fix is proven by a test). If the author wants it, one step goes into
`docs/checklists/fishing-mode.md`:

1. Character A, splash focus on, enter fishing mode; end the game process (Task Manager). Log in on character B: the
   chat says "Restored game settings from an unfinished fishing session.", music and ambience play.
