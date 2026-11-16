# Contract: Module Behaviour Changed by Spec 016

No message is added or changed; no visible text is added; the exchange format and the saved schema do not change.
The rest of the channel's contract is `specs/004-public-channel-sync/contracts/channel.md` and `api.md`, and
`specs/010-exchange-forever-fixes/contracts/exchange.md` C1-C4 as amended below.

## `Exchange/Channel.lua`

- S1: `Channel.AVAILABLE` is `true`. With it `false` (the kill switch) the behaviour of spec 010 stays: no join, a
  leftover channel of the addon's names left once at login, silently.
- S2: `Channel.OnRefused(reason)`. `reason == "server"`: leave the current name if joined or joining, set
  `refused = "server"`, lock nothing, fire `CHANNEL_STATE`, join nothing until a real login. `reason == nil`: today's
  behaviour, `Lock(current)` and the next fallback.
- S3: `Channel.GetState()` gives `locked` while `refused` is set (either value), as today.
- S4: the session record (`PLAYER_LOGOUT`) stores `refused` as its value; `Restore` after a `/reload` reads
  `"game"`, `"server"`, and `true` (a 1.2.0 record) as `"game"`; anything else as `false`.
- S5: `Channel.Describe()` adds `, refused <false|game|server>` to its line.
- S6: notices, unchanged and now pinned by tests: `CHANNEL_PASSWORD_REQUEST` for one of the names closes the popup and
  locks that index; the following `WRONG_PASSWORD` for it leaves nothing else and moves no further; `OWNER_CHANGED` /
  `CHANNEL_OWNER` set `owner` from argument 2 ("First Last"); `SET_MODERATOR` changes nothing.
- S7: the comments "(not shipped, V19)" become `-- VERIFY(Vn): ...` markers (research R5); the file's header says
  the channel ships.

## `Exchange/CommReceive.lua`

- R1: the comment "(not shipped, V19)" on the check of a channel message's name becomes
  `-- VERIFY(V53): a channel message names its channel in the name argument (or in target), as on Retail`; the code
  does not change. V53 is the one row of `specs/016-public-channel-return/verification.md` (research R5).

## `Exchange/Comm.lua`

- C4 (amended, spec 010): `Comm.ChannelRefused(true)` (a `NOT_ALLOWED_IN_CHANNEL` notice) counts notices on the
  current join; at `CHANNEL_REFUSALS` it calls `Channel.OnRefused("server")`. `Comm.ChannelRefused()` (a refused
  send) counts send refusals; at `CHANNEL_REFUSALS` it calls `Channel.OnRefused()`. The two counts stay separate and
  reset as today.
- C5: the throttle comment "(not shipped, V19)" becomes `-- VERIFY(V25): ...`.

## `tests/wow.lua`

- T1: the flag `channel_on` is removed; a new flag `channel_off = true` (before loading) sets `Channel.AVAILABLE =
  false` right after `Channel.lua` loads. Every test that set `channel_on` drops the line; `off_test.lua`,
  `notice_nochannel_test.lua` and `shared_page_nochannel_test.lua` set `channel_off` (the latter two instead of their
  own `load_addon` hook where that is simpler).

## Documents (FR-014)

- `specs/016-public-channel-return/verification.md`: the row V53 (research R5); `CLAUDE.md` lists 016 among the
  features with a `verification.md`.
- `OneKeyFishing/README.md`: "Shared catch database" names the public channel again (with whom, the setting "Use the
  public channel", what the Chat Channels window shows, leaving it by hand), from the text removed in `984eed2`.
- `CHANGELOG.md` `[Unreleased]` Added: the public channel is back.
- `CLAUDE.md`: the module table and the Forever API bullet say the channel is on; `docs/architecture/exchange.md`,
  `docs/architecture/ui.md`: the "off since spec 010" paragraphs go; `docs/checklists/catch-exchange.md` step 1 no
  longer says the addon joins no chat channel; `specs/004-public-channel-sync/verification.md` keeps its rows open
  until the checklist.
