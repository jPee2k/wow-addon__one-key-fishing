# Data Model: The Public Channel Returns

No saved field is added, renamed or reshaped: `DB_SCHEMA` stays. The entities are those of
`specs/004-public-channel-sync/data-model.md`; this feature changes one value set.

## The refusal flag (`Exchange/Channel.lua`, file-local `refused`)

| Value | Meaning | Set by | Cleared by |
|---|---|---|---|
| `false` | the channel may be joined | start of a session | — |
| `"game"` | the game refuses the channel itself (Trial account, invalid name; `TRIAL_RESTRICTED`, `INVALID_NAME`, or `JoinTemporaryChannel` returning nothing) | `OnNotice`, `Join` | the next real login |
| `"server"` | the server refuses addon messages in custom channels (two `NOT_ALLOWED_IN_CHANNEL` on the current join, R1) | `Channel.OnRefused("server")` from `Comm.ChannelRefused(true)` | the next real login |

Today the flag is `true` for the first row; the second row is new.

## The session record (`OneKeyFishingCharDB.channelSession`)

Written at `PLAYER_LOGOUT`, read once at the next `PLAYER_ENTERING_WORLD`, restored only after a `/reload`, dropped
at a real login (unchanged). `refused` now holds `false`, `"game"` or `"server"`; a record written by 1.2.0 holds
`true` and is read as `"game"` (it can only exist across a `/reload` from a 1.2.0 session, where the channel was off
and the flag never set). Not a reshape of persistent data: the record lives from one logout to the next load.

## The channel state (`Channel.GetState()`)

Unchanged set: `unavailable`, `off`, `notice`, `paused`, `left`, `locked`, `in`, `noslot`, `waiting`. Both refusal
values give `locked` (the text "Public channel: locked or refused by the game"); `Channel.Describe()` adds
`refused <value>` to the debug line.

## State transitions added

- `in` (or `waiting` after a move) + second `NOT_ALLOWED_IN_CHANNEL` on the current join → leave the current name,
  `refused = "server"` → `locked`; no `Join` until a real login.
- `locked` (server) + `/reload` → `locked` (the record carries it).
- `locked` (server) + real login → `waiting` → join the main channel after the login delay.
