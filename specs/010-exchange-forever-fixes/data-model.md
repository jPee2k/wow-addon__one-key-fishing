# Data Model: Exchange Fixes for Forever

No saved field changes (`DB_SCHEMA` stays).

## Names

| Item | Before | After |
|---|---|---|
| Own name | `UnitName("player")` (the first name only on Forever) | `ns.PlayerName()` = `GetUnitName("player", true)` ("First Last") |
| Friend address | `"w:" .. ns.WithRealm(info.name)` ("First Last-CAMWOWEU4Realm4PvP") | `"w:" .. info.name` (as the game gives it) |
| Same character | `a == b` or equal after `WithRealm` | `a == b`, or equal after the own realm suffix (`"-" .. GetNormalizedRealmName()`) is taken off either side; a suffix of another realm makes another character |

Rules:
- A realm appears in an address only when the game gave one.
- A space never separates a realm.
- `ns.WithRealm` is removed; no caller remains.

## Paths and refusals (Comm, Channel)

| State | Change |
|---|---|
| `notFound[lineText]` | was `GetTime()`; now `{ at = GetTime(), address = message.address }` |
| channel refusal | also counted from `CHAT_MSG_CHANNEL_NOTICE` `NOT_ALLOWED_IN_CHANNEL` for one of `Channel.NAMES`; at `CHANNEL_REFUSALS` in a row, `Channel.OnRefused()` |
| `Channel.AVAILABLE` | `false` (V19 failed); the gate reads `"unavailable"` |
| leftover channel | at `PLAYER_ENTERING_WORLD` with the gate `"unavailable"`, each of `Channel.NAMES` the client is in is left once, silently |

## Proof steps (Share)

| Constant | Value | Meaning |
|---|---|---|
| `PROOF_CHUNK` | 4 | links per `CatchDB.CheckVersion` call |
| `PROOF_BUDGET_MS` | 4 | a frame step stops calling once this much time has passed (`env.clock`, `debugprofilestop`) |
| `PROOF_STEPS` | removed | was 32 links per frame step |

The rules:
- At least one chunk per frame step.
- Without a clock, exactly one chunk.
- A 4096-link chain takes at most 1024 frame steps (one chunk each), and about 340 at 0.3 ms per link.

## Texts

| Key | Where | When |
|---|---|---|
| `"1 catch"` (new) | `Catalog.CatchesText` | catches == 1 (always fewer than 2 players) |
| `"1 catch, %s"` (new) | `UI/StatsFrame.lua` zone list | data.catches == 1 |
| `"Session: 1 catch, %s"` (new) | `UI/Minimap.lua` tooltip | session.catches == 1 |
| `"%d catches"`, `"%d catches, %s"`, `"Session: %d catches, %s"`, `"%d catches from %d players"` | as today | other counts |

Each new key gets nine translations.
- A language with a neutral form keeps it with the 1 written in (Ukrainian: "catch: 1" in its own words).
- A language without a plural copies its current text with 1.

## Error log

`ns.ForgetErrors(match)`: removes every entry for which `match(entry)` is true; returns the number removed. The spike
calls it once at load for `context == "spike"` and `message` containing `"OneKeyFishing spike test error"`.

## Test stubs (`tests/wow.lua`)

| Stub | Purpose |
|---|---|
| `channel_on = true` (before `load_addon`) | `load_addon` sets `ns.Channel.AVAILABLE = true` before the login events, for the tests of the channel itself |
| `GetUnitName(unit, showServer)` | `"player"` returns `player_full_name` (default `"First Last"`); other units as today |
| `friends[i] = { name, connected }` | exists; names now "First Last" |
