# Research: Tech Debt Fixes for 1.3.0

No open questions needed the game: every decision below is read from the code (`Fishing/Mode.lua`,
`Core/Core.lua`, `Exchange/ShareProtocol.lua`) and the in-game facts already recorded in `docs/forever-api.md`.

> **Revision, review 4 (2026-11-16): R1 to R3 withdrawn (User Story 1).** The game writes saved variables only at a logout,
> a `/reload` or the exit, never at a crash, and `PLAYER_LOGOUT` restores the CVars (emptying the record) before that
> write, so a crash leaves no record on disk on any character; a disconnect logs out and restores as before. The
> account-wide record (US1, FR-001 to FR-004, SC-001, the schema 2 migration, V52) was built and reverted at the
> author's choice; the CVar record stays per character as in 1.2.0. US2 and US3 stand. `docs/tech-debt.md` "History"
> records the dropped item.

## R1: Where the CVar record lives

- **Decision**: move `charDB.savedCVars` to the account-wide `OneKeyFishingDB.savedCVars` (same shape:
  `name -> the player's value before fishing mode`). `Mode.lua` reads and writes only `ns.db.savedCVars`.
- **Rationale**: no row is a per-character CVar. The CVar table of Ketho's Forever resources (`CVars.lua`,
  `var = default, category, account, character, secure, help`) marks `autoLootDefault` and the three `SoftTarget*`
  rows `account` (one value per game account, the scope of the addon's account-wide saved variables) and the
  `Sound_*` rows neither account nor character (one value per installation, `Config.wtf`; the account-wide saved
  variables are the closest scope the addon has). Not seen in game: V52 (`verification.md`). Any character's
  `PLAYER_LOGIN` then sees a crash's record. Only one client of a game account runs at a time (a second login ends
  the first), so no two writers race.
- **Alternatives considered**: keep it per character and also read every character's record (impossible: a client
  loads only its own character's `SavedVariablesPerCharacter`); a copy in both places (two truths to keep in step).

## R2: Moving the old per-character record (schema 2)

- **Decision**: raise `DB_SCHEMA` to 2. `Migrate` gets the account table as a third argument and hands it to each
  step (`migrations[version](data, account)`), so a step of the character table names the account data it moves into
  instead of reading the global `OneKeyFishingDB`. `MIGRATIONS.charDB[2]` moves a character's `savedCVars` into
  `account.savedCVars` and removes it from the character; on a name found in both, the character's entry wins.
  No `MIGRATIONS.db[2]` entry is needed (the account record is a new optional field, nil when empty).
- **Rationale**: Principle III requires a schema bump for a moved field. A character's record left by 1.2.0 can only
  come from a crash before the update, so it is older than any account entry; the older snapshot holds the player's
  real value (a later entry recorded the crash's leftover as "old"). `ADDON_LOADED` migrates the account data before
  the character's and passes it in, so the order the step depends on is visible at the call. `PLAYER_LOGIN` then restores the
  merged record by the usual rule (only CVars still holding the applied value).
- **Alternatives considered**: read `charDB.savedCVars` as a legacy source at login without a schema bump (breaks the
  rule; the field would linger forever); account entry wins (restores a crash leftover instead of the player's value).
- **Downgrade**: a 1.2.0 client then sees schema 2 and prints its "newer version" line, as for every schema bump.
- **A name in both records** (reviews 1-3): a character's 1.2.0 record holds only the rows 1.2.0 had (auto loot, the
  soft target; no sound row), so a conflict needs a crash on 1.2.0, a hand change of that same row after the update
  and a second crash on another character before the first logs in. Accepted as not worth a rule that needs the rows
  (`Fishing/Mode.lua`, layer 1) in the migration (`Core/Core.lua`, layer 0).

## R3: Two game accounts on one computer

- **Decision**: accepted limit. A crash on account A is restored at A's next login; account B still plays with the
  silenced settings until then. Recorded in the spec's edge cases and in `fishing-mode.md`.
- **Rationale**: no saved variable is shared across game accounts; reading `Config.wtf` is not possible from an addon.
  Only the sound rows are affected: the other rows are per game account in the game too.

## R4: The hand-changed rows across a /reload

- **Decision**: at `PLAYER_LOGOUT` with the mode on, after `RestoreCVars()` (which marks every row that no longer holds
  the applied value), store the live rows of the set `playerOwned` (review 2: only the "Sound effects" rows, which
  their switch can take back; a soft target changed by hand or by another addon would otherwise keep the hook key
  from the bobber past every `/reload`, where before it was set again) as `charDB.resumeOwned` (`name -> true`, nil when empty) next to
  `resumeMode`. `PLAYER_ENTERING_WORLD` takes and clears both at once; the resume calls a file-local `Enter(owned)` with the taken
  set as the starting `playerOwned`; the public `Mode.Enter()` takes no argument and calls `Enter(nil)` (the minimap
  menu passes its own arguments to `Mode.Toggle`, so a public parameter could receive a stray table). A real login, or a resume that does not happen (a fight), drops it.
- **Rationale**: the logout's restore already finds the hand-changed rows (they differ from the applied value), so
  the set is complete at that point; per character is right, because a `/reload` keeps the character. Today's
  `Mode.Enter` wipes `playerOwned`; seeding it keeps FR-015 of spec 013 across the reload with no new logic in
  `SyncCVars`. A failed resume is the mode's end (FR-006), so nothing is kept for a later fresh entry.
- **Alternatives considered**: keep the list in the account-wide record (it is per session of one character, and the
  account record is for crashes); skip the restore at logout for owned rows (it would change the crash safety of
  Principle III).

## R5: Counting clients, not addresses (batch 11)

- **Decision**: one definition of "the same client": a new `Node:ClientKey(address)` in `Exchange/ShareNode.lua`
  returns the peer's `node` tag, or the address when the peer has none. `Node:SameClient(a, b)` becomes
  `self:ClientKey(a) == self:ClientKey(b)` (the same answers as today: an address always starts with `w:` or `b:` and
  never equals a 4-character tag; an unknown peer or one without a tag is only the same client as its own address).
  `Node:Activity` groups the non-channel peers by `ClientKey`. For each key: "heard" counts once under the `via` of the peer with the latest
  `heard` in the hour; "exchanged" counts once if any peer of the key has `synced` in the hour. Channel peers count per
  address in `heard.channel`, as today; `recent` and `lastExchange` do not change.
- **Rationale**: after a relog the group address takes the new tag first (`Handlers.H`, the HELLO round broadcasts
  before greeting friends); the Battle.net address keeps its old `heard` and `synced` and, once its HELLO with the new
  tag arrives, gets `peer.node = newTag` without a refresh (the "same client by another path" branch). Grouping by
  tag then counts the two addresses once, under the group (heard last), and the Battle.net `synced` still counts the
  partner as exchanged with, once. This is the direction in `docs/tech-debt.md`; the protocol and the messages stay.
- **The client's other addresses take the new tag at once** (review 3): when an address announces a new tag,
  `DropOldTag` (`Handlers.H`) moves every other non-channel address that still carries the old one (the client's
  other path, already the same client) to the new tag, and the old tag leaves `byTag`. So the client counts once from
  its first `HELLO` with the new tag, whichever path greets first, without waiting for a friend rotation that can take
  several rounds. Channel peers are left out (a stranger's 4-character tag may match by chance). The old test that
  kept the first address on the old tag (batch D, the `byTag` bound) now checks the move: the old tag names nobody,
  so the bound holds.
- **Alternatives considered**: a second key rule written inside `Activity` (`peer.node or address`), next to the
  one inside `SameClient` (two copies of one rule drift apart); refresh `heard` of the other address in the "same client" branch (it would change the
  HELLO cooldowns and sessions, which FR-008 keeps as they are); forget the old address (loses its `synced` time and
  the session cooldown on it).

## R6: Tests

- **Decision**: extend `tests/fishing/cvar_restore_test.lua` (account record, restore at another character's login,
  old character record migrated and merged), `tests/fishing/cvar_sync_test.lua` (a hand change kept across the
  `/reload` resume and the exit; a resume blocked by a fight drops it), `tests/core/migrations_test.lua` (schema 2; a
  1.2.0 character record moved; the existing "schema stays 1" assertions become 2), and
  `tests/exchange/share/protocol_test.lua` (a client heard by Battle.net, then by the group with a new tag, counts once
  in `heard` and `exchanged`; two clients still count twice). Each new test fails on today's code.
- **Test helpers, no copies** (`docs/development.md`: helpers several files need go into one file): `tests/wow.lua`
  gets `fishing_ready()` (the fishing spell known, the key bound, gear and camera off, out of combat), which
  `enter_fishing_mode()` now calls before `Mode.Enter()`, and `login_with(db, charDB, isInitialLogin, isReloadingUi)`
  (sets the saved tables, loads the TOC files, fires `ADDON_LOADED`, `PLAYER_LOGIN`, enters the world, runs the
  resume delay), next to `load_addon`. The new login and reload files use both. A real login and a `/reload` are
  two load sequences, so each needs its own file (a test file is one fresh Lua state).
- **Rationale**: the tests the tech-debt items name; the areas' existing files (one per architecture document).
