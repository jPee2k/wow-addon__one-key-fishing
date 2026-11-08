# Research: Exchange Fixes for Forever

The facts come from `docs/forever-api.md` "Verified in game" (2026-11-06/07), `docs/tech-debt.md` batch 1 and the
"1 catches" item, and the verification records of specs 003 and 004. The code was read on `002-shared-db` after
spec 009 (commit `d29145e`).

## R1. Names: "First Last" and the realm

**Facts**:
- Forever names are "First Last" with a space.
- `UnitName("player")` returns "First" and "Last" as two values. `GetUnitName("player", true)` returns
  "First Last".
- `GetNormalizedRealmName()` is an internal name (`CAMWOWEU4Realm4PvP`).
- A whisper to "First Last" arrives, and `CHAT_MSG_ADDON` names the sender "First Last".
- A whisper to "First Last-<internal realm>" fails with "No player named ...".
- In a group the sender is "First Last" (V10, V11).

**Today**:
- `ns.WithRealm` adds `-<GetNormalizedRealmName()>` to any name without a dash.
- `Comm.ForEachFriend` addresses friends as `"w:" .. ns.WithRealm(info.name)`.
- `ns.SameCharacter` compares through `WithRealm`.
- `Channel` `IsMe` and the spike's "WHISPER to self" use `UnitName("player")` (the first name only).
- `Share.HeardInChannel` compares through `SameCharacter`.

**Decision**:
- **`ns.WithRealm` goes.** A name is kept exactly as the game gave it.
- **The friend address** becomes `"w:" .. info.name`. A friend on the own realm is then "First Last", the same
  address as the friend's own messages.
- **`ns.SameCharacter(a, b)`** is true when `a == b`, or when they are equal after a suffix of the player's own
  realm (`"-" .. GetNormalizedRealmName()`) is taken off either side.
  - The game adds a realm only to a player of another realm. "First Last" with no suffix is the own realm, and
    "First Last-OtherRealm" is somebody else with the same name, so a foreign suffix is never ignored.
  - The own-realm suffix appears only in addresses an earlier build made with `WithRealm`; the game never sends it.
  - A space never counts as a realm separator.
- **The own name** is `ns.PlayerName()`, a new helper in `Core/Data.lua` that returns
  `GetUnitName("player", true)`. `Channel` `IsMe` and the spike use it.
- **`VERIFY(V11)`** stays on `Comm.ForEachFriend`, with a new text: the friends list gives the name as messages
  name the friend. The shape of `C_FriendList` names is not seen yet: the list was empty in the test.

**Alternatives considered**:
- Keep `WithRealm` and strip the realm on receipt. That adds an internal name nobody uses. Rejected.
- Compare through `Ambiguate(name, "none")`. Forever's realm name is internal, and `Ambiguate` strips only the
  player's own realm, which never appears. No gain. Rejected.

## R2. The public channel off

**Facts**:
- `SendAddonMessage` to a custom channel returns 0.
- The server answers with `CHAT_MSG_CHANNEL_NOTICE` `NOT_ALLOWED_IN_CHANNEL` (argument: the channel name).
- No echo comes back (V19, full account, level 11).

**Decision**:
- `Channel.AVAILABLE = false`. Spec 004 built this switch for exactly this case (its FR-026):
  - `Gate()` returns `"unavailable"`, so the channel never joins;
  - the settings page, the notice and `ShareGame` already hide the channel parts behind `ns.Channel.AVAILABLE`.
- The code stays, switched off (spec Assumptions). If the server opens custom channels to addon messages, one line
  brings it back.
- **A channel joined by an earlier build** (FR-005): at login with the channel unavailable, any of `Channel.NAMES`
  the client is still in is left once, with no chat line. The `PLAYER_ENTERING_WORLD` handler runs this only while
  the gate is `"unavailable"`. A test checks that it happens and that it happens once.
- **The refusal** (FR-006): `OnNotice` takes `NOT_ALLOWED_IN_CHANNEL` for one of the addon's channel names as a
  channel refusal, the same as `Comm`'s `channelRefusals` path. Today that path only sees send results, and the
  server answers 0 there. A notice therefore counts one refusal and calls `Channel.OnRefused()` at
  `CHANNEL_REFUSALS`. With `AVAILABLE` false, nothing is sent on that path. The rule is tested with the channel
  switched on in the test.
- The `VERIFY(V19)` markers in `Channel.lua` and `Comm.lua` go; V19 is decided ("failed, channel off"). V20-V25 and
  V41 are closed as "not shipped".
  - Their `VERIFY` markers in channel code stay out of `npm run check`'s open list: they are removed with a
    comment "not shipped (V19)", since the code does not run.
  - V22's marker on the late join and V25's marker on the throttle go the same way.

**Tests**:
- The channel tests in `tests/exchange/channel/`, `tests/exchange/comm/channel_path_test.lua` and the channel cases
  in `tests/exchange/share/` and `tests/ui/` switch the channel on in the test.
- A new stub flag `channel_on = true` makes `load_addon` set `ns.Channel.AVAILABLE = true` before the login events.
- The files that test the switched-off state (`notice_nochannel_test.lua`, `shared_page_nochannel_test.lua`) keep
  the default.

## R3. The proof step budget

**Facts**: 64 proof steps took 17.8 to 19.8 ms in the game, about 0.3 ms per step (V26). `PROOF_STEPS = 32` per
frame step gives about 10 ms per frame step.

**Today**: `Node:MergeOne` calls `CatchDB.CheckVersion(held, record, PROOF_STEPS, state)` once per frame step.
`ShareGame` checks the seed chains at login with `PROOF_STEPS` per step. `Node` has `self.env.clock` (debugprofilestop
in the game).

**Decision**:
- **Merges**: a time budget. `MergeOne` calls `CheckVersion` in chunks of `PROOF_CHUNK = 4` links. It loops while
  the result is `"more"` and the elapsed time is under `PROOF_BUDGET_MS = 4`. At least one chunk runs per frame
  step. Without a clock (the protocol tests, a missing `debugprofilestop`), one chunk per frame step.
- **The seed check at login**: the same chunk and budget.
- **Cost**: at 0.3 ms per link a frame step does about 12 links, about 4 ms. A chain of 4096 links takes about
  340 frame steps, about 6 s at 60 fps. The merge queue is local work after the session's messages, so
  `SESSION_TIMEOUT` (15 s without a message) does not cut it (FR-009).
- **Markers**: `VERIFY(V26)` changes to the budget assumption. `debugprofilestop` measures milliseconds in the game,
  as the catalog's `STEP_MS` already relies on. The marker stays until the debug report shows a longest merge step
  under 5 ms.

**Alternatives considered**: a constant `PROOF_STEPS = 8` (about 2.5 ms). It is simpler, but on a slower client it
would again pass 5 ms. The catalog already budgets its frame steps by time. Rejected for consistency and safety.

## R4. The offline whisper

**Facts**:
- A whisper to a player who is not online returns 0, not 12 (`TargetOffline`).
- The game then prints `ERR_CHAT_PLAYER_NOT_FOUND_S` ("No player named '%s' is currently playing.") in
  `CHAT_MSG_SYSTEM` (V12).

**Today**:
- `Deliver` records the expected line text for a whisper's target (`notFound[text] = time`).
- `HideNotFound` hides a matching line.
- The `TargetOffline` branch never runs.

**Decision**:
- `notFound[text]` keeps `{ at, address }`.
- When `HideNotFound` hides a line, it calls `Unreachable` for that address. That drops the queued messages to it
  and runs the offline handlers, which end the session and pause the peer.
- The `TargetOffline` branch stays: it costs nothing, and the code is the game's documented one.
- Comm's `VERIFY(V12)` markers change: the hidden line ends the session. The marker stays until the second-player
  step (`d-offline`) is seen.

## R5. "1 catches"

**Today**, there are three texts with a count:
- `L["%d catches"]` (`Catalog.CatchesText`, used by the catch tab and the catalog);
- `L["%d catches, %s"]` (`UI/StatsFrame.lua`, the zone list);
- `L["Session: %d catches, %s"]` (`UI/Minimap.lua`, the tooltip).

`L["%d catches from %d players"]` is used only from 2 players on (`Catalog.CatchesText`), and one catch always
comes from one player. So "1 players" never shows, and no player key is needed (spec US5 scenario 2 holds by
construction).

**Decision**:
- **New keys**: `L["1 catch"]`, `L["1 catch, %s"]` and `L["Session: 1 catch, %s"]`, with nine translations each.
- **Call sites**: each one picks the key by `catches == 1`.
- **Translations with a neutral form** use the same text for both keys. Ukrainian already reads "catch: %d" (in its own words), so the
  singular key keeps the neutral form with the number written in.
- **Translations with a singular**: German "1 Fang", Spanish "1 captura", French "1 prise", Portuguese "1 captura".
- **Korean and Chinese** have no plural, so their singular keys copy their current text with 1.

**Alternatives considered**: one neutral form for every language ("Catches: %d"). That would change every
language's wording for a one-count edge. Rejected.

## R6. The spike

**State of `docs/checklists/spike.md`**:
- Every solo step is answered.
- Still open: N1 (guild) and N3 (Battle.net), both with a second player.
- C2, C6 and C7 are channel steps: not shipped.

**The next spec needs** (011, batch 2):
- the areas at a position (V34: an ID-based source of the subzone);
- the loot source of the last catch (V3 fallback; no game check needed).

**The 1.2.0 test page uses**:
- `a-lang`: the fold line P4 (V36 partly);
- `a-v5`: the last auction search (V5 partly);
- `b-proof`: the proof step timing (V26).

**Decision**:

| Spike part | Today | After |
|---|---|---|
| Loot, auction search (V1-V7) | V5 partly | **keep** the auction search lines (V5); the loot lines go (V1, V2, V7 closed; V3 decided) |
| Network (V10-V15) | N1, N3 open | **keep** (the WHISPER to self uses `ns.PlayerName()`) |
| Chat channel (V19-V27, V41) | channel not shipped | **remove** the test channel join, checks, notices, password popup and the item lines (V27 seen); **keep** the hash timing lines as a section "Proof steps (V26)" |
| Map pins (P1) | V30, V31 closed | **remove** |
| Areas (P2) | V34 partly, needed by spec 011 | **keep** |
| Item names (P3), templates (P5) | V35, V37 closed | **remove** |
| Folding (P4) | V36 partly (a-lang) | **keep** |
| Error log (E1) | V42 closed | **remove**, with `FailOnPurpose` |

**Test changes in `tests/ui/spike_test.lua`**:
- The channel, pin and error log tests go.
- The section test lists the sections that remain.
- A new case checks that a run hands on no error.

**Checklist**: `docs/checklists/spike.md` marks C2, C6 and C7 "not shipped (V19)" and E1, P1, P3 and P5 "closed,
removed from the spike".

**`/okf debug`**: removing the error stops new entries. The entries already saved (19 in the author's log) stay
until the log's cap drops them. So at load the spike also drops its own test entries from the log: context
`"spike"` with the message `"OneKeyFishing spike test error"`. The log is read-only outside `Core/Core.lua`
(`ns.GetErrors`), so Core gets a small `ns.ForgetErrors(match)` that removes the entries a function matches. Real errors of the spike stay. The cleanup goes
with the spike before the release.
