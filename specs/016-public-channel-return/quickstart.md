# Quickstart: The Public Channel Returns

The rules being checked are in [contracts/module-api.md](contracts/module-api.md); the state is in
[data-model.md](data-model.md).

## Automated

```sh
npm run check
npm test
```

Each new or changed test fails on the code before this spec (spec FR-011):

| Test | Proves | Fails without |
|---|---|---|
| every test under `tests/exchange/channel/`, `tests/exchange/comm/channel_path_test.lua`, `tests/exchange/share/channel_*_test.lua`, `tests/ui/notice_channel*_test.lua`, `notice_test.lua`, `shared_page_test.lua` (the `channel_on` line removed) | S1, T1: the channel runs as shipped, with no test-only switch | `AVAILABLE = true` |
| `tests/exchange/channel/off_test.lua`, `tests/ui/notice_nochannel_test.lua`, `tests/ui/shared_page_nochannel_test.lua` (`channel_off`) | S1: the kill switch still gives the spec 010 behaviour | the `channel_off` stub |
| `tests/exchange/channel/not_allowed_test.lua` (changed) | S2, C4, SC-004: two notices leave the main channel and join no fallback in the next hour; the state is `locked`; the debug line says `refused server`; one notice alone changes nothing | `OnRefused("server")` |
| `tests/exchange/channel/not_allowed_test.lua` (changed, its last step) | S4: the logout after a server refusal writes `channelSession.refused = "server"` | the session value |
| `tests/exchange/channel/server_refusal_reload_test.lua` (new) | S4: a `/reload` with that record stays `locked` and joins nothing for an hour | `Restore` of `"server"` |
| `tests/exchange/channel/server_refusal_login_test.lua` (new) | FR-009: a real login with that record joins the main channel after the login delay | (the record is dropped at a real login today; pins it) |
| `tests/exchange/channel/server_refusal_old_record_test.lua` (new) | S4: a 1.2.0 record `{ refused = true }` after a `/reload` reads as `refused game` | the mapping of `true` |
| `tests/exchange/comm/channel_path_test.lua` (extended) | C4: two refused sends still lock the current name and move to the next fallback (FR-010) | the split of the two counts |
| `tests/exchange/channel/password_order_test.lua` (new) | S6, FR-005: a join answered by `CHANNEL_PASSWORD_REQUEST` and then `WRONG_PASSWORD` hides the popup once, locks index 1 once and joins index 2 once | (pins today's behaviour; written to fail if the second notice locks or moves again) |
| `tests/exchange/channel/owner_notices_test.lua` (new) | S6, FR-006, FR-007: `OWNER_CHANGED` with the player's "First Last" makes it the owner and clears a stranger's password; `SET_MODERATOR` with the first name only changes nothing | (pins today's behaviour) |

## In game

`docs/checklists/public-channel.md` on a build of this branch (`npm run link`, or `npm run install-addon` on every
client; a game restart if the TOC changed). Steps 1-11; step 2 needs two accounts that are not Battle.net friends,
step 4 a third account. The facts of the `/run` tests of 2026-11-16 are not checked again (spike C3, C6, C7). Each
step closes the rows of `specs/004-public-channel-sync/verification.md` it names and removes their markers.
