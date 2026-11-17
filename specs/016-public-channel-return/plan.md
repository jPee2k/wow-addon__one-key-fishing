# Implementation Plan: The Public Channel Returns

**Branch**: `016-public-channel-return` | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/016-public-channel-return/spec.md`

## Summary

Addon messages in a custom chat channel pass again (V19, 2026-11-16), so the hidden public channel of spec 004 ships
in release 1.3.0: `Channel.AVAILABLE` becomes `true`, and the tests run the channel as shipped (the stub flag flips
from `channel_on` to `channel_off`). The code already fits the notices seen in game (join, password, owner); one
behaviour changes: a refusal by the server (`NOT_ALLOWED_IN_CHANNEL`) stops the channel for the session instead of
walking all six names (research R1). The "not shipped" comments become `VERIFY` markers again, so the release waits
for `docs/checklists/public-channel.md`. The player manual and the docs say the channel is back.

## Technical Context

**Language/Version**: Lua 5.1 (WoW Forever client, Interface `16001`); tests in fengari (Lua 5.3), Node.js 18+ tools

**Primary Dependencies**: WoW Mainline API (`JoinTemporaryChannel`, `C_ChatInfo.SendAddonMessage`, channel notices);
no library

**Storage**: no change; `OneKeyFishingCharDB.channelSession.refused` takes a reason instead of `true`
([data-model.md](data-model.md))

**Testing**: `npm test` (fengari harness, stubs in `tests/wow.lua`), `npm run check`

**Target Platform**: WoW Forever 1.60.1 (`WOW_PROJECT_ID = 18`)

**Project Type**: game addon

**Performance Goals**: unchanged from spec 004 (longest exchange step under 5 ms, SC-003)

**Constraints**: Blizzard UI Add-On Policy (the channel is joined by addon code without a key press, as Total RP 3
does; no game action); no 5.1/5.3 differences

**Scale/Scope**: three addon files (`Exchange/Channel.lua`, `Exchange/Comm.lua`, one comment of
`Exchange/CommReceive.lua`); `tests/wow.lua` and 26 test files (one line each), two tests changed or extended, five
new; a `verification.md` with V53; docs and the manual

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Policy | joining a chat channel and sending addon messages are not game actions; the exchange keeps its paced queue and hourly budget; a server refusal now sends less (no fallback walk) | Pass |
| II. Language-independent data | notices are matched by token and channel name (the addon's own names), not by localized text; no new text; the limit line is the client's own `ERR_TOO_MANY_CHAT_CHANNELS` | Pass |
| III. Safe, restorable state | no game setting changed; the channel is left at logout by the game; the session record is unchanged in shape | Pass |
| IV. Verified Forever API | the notices and sends were seen in game on 2026-11-16 (`docs/forever-api.md`); what was not seen carries `VERIFY` markers with their rows (V21-V25, V41), so `npm run build` refuses the release until the checklist or the author's acceptance | Pass |
| V. Checked and tested | the refusal change gets tests that fail without it; the switch is tested as shipped (no test-only override) | Pass |
| VI. Module boundaries | changes inside `Exchange/` (layer 2); no new message, module, command, setting or saved field | Pass |

Post-design re-check (after research, data model, contract): still Pass.

## Project Structure

### Documentation (this feature)

```text
specs/016-public-channel-return/
├── plan.md              # This file
├── research.md          # R1-R7
├── data-model.md        # the refusal flag, the session record
├── quickstart.md        # the tests and the in-game checklist
├── verification.md      # V53 (the channel's name in CHAT_MSG_ADDON); V21-V25, V41 stay in spec 004
├── contracts/
│   └── module-api.md    # S1-S7, C4-C5, T1, documents
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── Exchange/Channel.lua          # AVAILABLE true; OnRefused(reason); refused as a reason; Describe; VERIFY markers
├── Exchange/Comm.lua             # ChannelRefused(true) -> OnRefused("server"); VERIFY(V25)
└── Exchange/CommReceive.lua      # VERIFY(V53): the channel's name in CHAT_MSG_ADDON

tests/
├── wow.lua                                       # channel_on -> channel_off
├── exchange/channel/*.lua                        # the channel_on line removed
├── exchange/channel/not_allowed_test.lua         # changed: no fallback after a server refusal
├── exchange/channel/server_refusal_reload_test.lua  # new: a /reload keeps the refusal
├── exchange/channel/server_refusal_login_test.lua   # new: a real login tries again
├── exchange/channel/server_refusal_old_record_test.lua  # new: a 1.2.0 record reads as "game"
├── exchange/channel/password_order_test.lua      # new
├── exchange/channel/owner_notices_test.lua       # new
├── exchange/comm/channel_path_test.lua           # extended: send refusals still move on
├── exchange/share/channel_*_test.lua             # the channel_on line removed
└── ui/notice*_test.lua, ui/shared_page*_test.lua # channel_on removed / channel_off set

docs/
├── architecture/exchange.md      # the channel ships; the server refusal; the stub flag
├── architecture/ui.md            # the "without the channel" paragraphs
└── checklists/catch-exchange.md  # step 1: no "joins no chat channel"

OneKeyFishing/README.md           # "Shared catch database" names the public channel again
CHANGELOG.md                      # [Unreleased] Added: the public channel
CLAUDE.md                         # module table, Forever API bullet
```

**Structure Decision**: no new addon file or folder; the channel stays one module in `Exchange/`.

## Implementation notes

1. **Channel.lua**: `Channel.AVAILABLE = true` with a comment naming V19 (2026-11-16) and the kill switch. `refused`
   becomes `false | "game" | "server"`: `Join` and the `TRIAL_RESTRICTED` / `INVALID_NAME` branch set `"game"`.
   `Channel.OnRefused(reason)`: `"server"` → `Leave()`, `refused = "server"`, `Notify()`; otherwise `Lock(current)`.
   `PLAYER_LOGOUT` stores `refused`; `Restore` maps `true` → `"game"`. `Describe` adds `refused %s`. The
   `NOT_ALLOWED_IN_CHANNEL` branch comment drops "seen in game, V19" for the 2026-11-06 fact. The "(not shipped, V19)"
   comments become markers: V21 (`RemoveFromWindows` and the filters; the popup hide), V22 (the login join),
   V23 (`OnLimit`), V24 (`OnNotice` kick / ban / mute tokens), V41 (`LeaveName` echo order). The header comment says
   the channel ships.
2. **CommReceive.lua**: the "(not shipped, V19)" comment becomes `VERIFY(V53)` (research R5).
3. **Comm.lua**: in `Comm.ChannelRefused`, reaching the count by notices calls `ns.Channel.OnRefused("server")`, by
   send refusals `ns.Channel.OnRefused()`; the throttle comment becomes `VERIFY(V25)`.
4. **tests/wow.lua**: replace the `channel_on` block with `channel_off` (and in `NIL_GAME_DATA`); update the header
   comment at line 78. Remove `channel_on = true` from every test; add `channel_off = true` to the three tests of the
   switched-off release.
5. **Tests** as in [quickstart.md](quickstart.md).
6. **Docs** as in the contract's "Documents"; the README text from `git show 984eed2 -- OneKeyFishing/README.md`
   (the removed lines), checked against today's settings page and `/okf share` texts.
7. **Review** (FR-012): before the hand-over, `Exchange/Channel.lua`, `Exchange/Comm.lua` (the channel path) and the
   channel part of `Exchange/CommReceive.lua` are read against `docs/forever-api.md`; a real hole is fixed with a
   test that fails without it, a low item goes to `docs/tech-debt.md`.

## Complexity Tracking

No violation; nothing to justify.
