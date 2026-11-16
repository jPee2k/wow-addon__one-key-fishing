# Data Model: Tech Debt Fixes for 1.3.0

> **Revision, review 4 (2026-11-16): User Story 1 withdrawn: the parts below about the account-wide record, schema 2 and character B (D0-D4, M1, M2, M6, G1, `cvar_other_character_test.lua`) no longer apply.** The game writes saved variables only at a logout,
> a `/reload` or the exit, never at a crash, and `PLAYER_LOGOUT` restores the CVars (emptying the record) before that
> write, so a crash leaves no record on disk on any character; a disconnect logs out and restores as before. The
> account-wide record (US1, FR-001 to FR-004, SC-001, the schema 2 migration, V52) was built and reverted at the
> author's choice; the CVar record stays per character as in 1.2.0. US2 and US3 stand. `docs/tech-debt.md` "History"
> records the dropped item.

## Saved data (schema 1 -> 2)

### `OneKeyFishingDB.savedCVars` (account-wide; moved from the character DB)

| Field | Type | Meaning |
|---|---|---|
| `[cvarName]` | string | the player's value before fishing mode changed the CVar |

- nil when empty (no fishing mode change outstanding); written by `Fishing/Mode.lua` only.
- **Written** before a CVar is set (constitution Principle III), also when the CVar already holds the applied value.
- **Entry dropped** when restored, or when the CVar no longer holds the applied value (the player's value stays).
- **Restored** at exit, at `PLAYER_LOGOUT` (also a `/reload`), and at any character's `PLAYER_LOGIN` (a crash).
- A name without a row in `CVARS` (an older build's) is set back as it was, as today.

### `OneKeyFishingCharDB.savedCVars` (removed)

- Migration `charDB[2]`: if present, each entry is copied into `OneKeyFishingDB.savedCVars`, overwriting an entry of
  the same name (the character's is older, research R2); then the field is removed.

### `OneKeyFishingCharDB.resumeOwned` (new, per character)

| Field | Type | Meaning |
|---|---|---|
| `[cvarName]` | `true` | a live row (the "Sound effects" page) the player changed by hand while fishing, kept across a `/reload`; rows that are not live are set again by the resume |

- Written at `PLAYER_LOGOUT` with the mode on, after the CVars are restored, only when not empty.
- Taken and cleared at `PLAYER_ENTERING_WORLD` together with `resumeMode`; handed to `Mode.Enter` only when the mode
  resumes (a `/reload` with the mode on, outside a fight).
- A new optional field: `ApplyDefaults` has nothing to fill, no migration entry.

## State transitions (one CVar row, splash focus on)

```text
not recorded --enter / setting on--> recorded + applied
recorded + applied --exit / logout / fight lift / setting off--> restored, entry dropped
recorded + applied --player changes it--> (on the next restore) entry dropped, row player-owned
player-owned --/reload with the mode on--> player-owned (resumeOwned) --resume--> player-owned
player-owned --exit / real login / failed resume / its setting switched on--> forgotten
recorded + applied --crash--> recorded (account-wide) --any character's login--> restored, entry dropped
```

## In memory: the exchange activity (no saved change)

`Node:Activity()` returns the same shape as today:
`{ heard = { guild, group, friend, bnet, channel }, exchanged, recent, lastExchange }`.

- **Count key** of a non-channel peer: `Node:ClientKey(address)` (`Exchange/ShareNode.lua`): its `node` tag, or its
  address when it has none; the same key `Node:SameClient` compares.
- `heard[path]`: per key, +1 under the `via` (whisper -> friend) of the key's peer with the latest `heard` in the hour.
- `exchanged`: per key, +1 if any of its peers has `synced` in the hour.
- `heard.channel`: per channel address, as today. `recent`, `lastExchange`: unchanged.
