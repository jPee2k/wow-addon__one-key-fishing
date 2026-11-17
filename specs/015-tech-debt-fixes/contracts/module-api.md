# Contract: Module Behaviour Changed by Spec 015

No message is added or changed; no visible text is added; the exchange format does not change.

> **Revision, review 4 (2026-11-16): User Story 1 withdrawn: the parts below about the account-wide record, schema 2 and character B (D0-D4, M1, M2, M6, G1, `cvar_other_character_test.lua`) no longer apply.** The game writes saved variables only at a logout,
> a `/reload` or the exit, never at a crash, and `PLAYER_LOGOUT` restores the CVars (emptying the record) before that
> write, so a crash leaves no record on disk on any character; a disconnect logs out and restores as before. The
> account-wide record (US1, FR-001 to FR-004, SC-001, the schema 2 migration, V52) was built and reverted at the
> author's choice; the CVar record stays per character as in 1.2.0. US2 and US3 stand. `docs/tech-debt.md` "History"
> records the dropped item.

## `Core/Core.lua` (saved data)

- D0: `Migrate(data, migrations, account)` passes the account table to each step: `migrations[n](data, account)`;
  `ADDON_LOADED` migrates the account table first and passes it when it migrates the character table.
- D1: `DB_SCHEMA` is 2. A new player gets schema 2 in both tables and no `savedCVars` anywhere.
- D2: a character table of schema 1 with `savedCVars` loads with the entries in `OneKeyFishingDB.savedCVars` (the
  character's entry wins on a name in both) and no `savedCVars` in the character table.
- D3: a character table of schema 1 without `savedCVars` loads unchanged but for the schema; the account record is
  not created.
- D4: every other field keeps its value, as the existing migration tests check.

## `Fishing/Mode.lua`

- M1: every read and write of the CVar record goes to `ns.db.savedCVars`; `ns.charDB.savedCVars` is never written.
- M2: `PLAYER_LOGIN` restores `ns.db.savedCVars` by the rule of today (only a CVar still holding the applied value is
  set back; every entry is dropped) on whatever character logs in; the chat line shows only when a value changed.
- M3: `PLAYER_LOGOUT` with the mode on restores the CVars, sets `charDB.resumeMode`, and sets `charDB.resumeOwned` to
  the live rows the player owns (the "Sound effects" rows; nil when none). A hand-changed row that is not live (auto
  loot, the soft target) is not kept: the resume sets it again (review 2).
- M4: `PLAYER_ENTERING_WORLD` takes and clears `resumeMode` and `resumeOwned`. When it resumes, the owned rows start
  as the player's: the resumed mode neither sets nor restores them. When it does not resume (a real login, a fight),
  they are dropped.
- M5: `Mode.Enter()` (public, no parameter) called by the key, the toggle, the minimap menu or a command starts with
  no owned rows, as today, whatever arguments its caller had.
- M6: gear and camera records stay in the character table, unchanged.

## `Exchange/ShareNode.lua`

### `Node:ClientKey(address)` -> string (new)

- K1: the peer's `node` tag when the peer is known and has one; otherwise the address itself.
- K2: `Node:SameClient(a, b)` is `ClientKey(a) == ClientKey(b)`, with the same answers as today.

## `Exchange/ShareProtocol.lua`

### `Node:Activity()` -> `{ heard, exchanged, recent, lastExchange }`

- A1: non-channel peers with one `ClientKey` count as one client: once in `heard`, under the path of the peer with
  the latest `heard` in the last hour, and once in `exchanged` when any of them synced in the last hour.
- A2: a non-channel peer without a tag counts on its own, as today.
- A3: channel peers count per address in `heard.channel`, as today.
- A4: `recent` and `lastExchange` as today. The messages do not change.
- A5 (reviews 3, 5): a `HELLO` with a new tag moves the client's address of the other kind (`w:` / `b:`) that carries
  the old tag to the new one, and the old tag leaves `byTag`; a name of the same kind and channel peers are never
  moved.

## `Core/Debug.lua`

- G1: the report's "saved by the addon: CVars ..." reads the account record.
