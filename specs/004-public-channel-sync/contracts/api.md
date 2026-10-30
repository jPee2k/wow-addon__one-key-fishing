# Contract: module functions added or changed in part 3

Functions used by the UI, the debug report, the slash command, the harvest and the tests. Nothing here is called at
file load. TOC order: `Data.lua` ... `SeedData.lua`, `CatchDB.lua`, `Comm.lua`, **`Channel.lua` (new)**,
`Share.lua`, then the UI files; `Commands.lua` stays last. Everything not listed keeps the contract of part 2
(`specs/003-guild-group-sync/contracts/share-api.md`).

## `Data.lua`

| Function | Does / returns |
| --- | --- |
| `ns.SHA256(text)` | the SHA-256 digest of a byte string as 64 lowercase hex characters; built on the game's `bit` library, every result taken modulo 2^32, so signed or unsigned results give the same digest (research R9; a test stub in fengari) |
| `ns.ProofStep(link)` | one link down the chain: the first 80 bits of `SHA256(link)` as 16 base32 characters (`ns.BASE32`) |

## `ns.Channel` (`Channel.lua`, new)

The hidden public channel: joining, hiding, slots, locks, fallbacks. It knows nothing about records; Comm sends
through it and Share listens to its state.

| Function | Does / returns |
| --- | --- |
| `Channel.AVAILABLE` | `true`; set to `false` before the release if the spike shows that addon messages in a custom channel do not work (FR-026): nothing is joined, the setting is hidden, the texts drop the channel |
| `Channel.NAMES` | the main channel name and the five fallback names (contracts/channel.md) |
| `Channel.IsEnabled()` / `Channel.SetEnabled(on)` | the setting `settings.shareChannel` / sets it, joins or leaves at once, fires `SETTINGS_CHANGED` (`"shareChannel"`) |
| `Channel.GetState()` | `state, index`: data-model.md "State of the channel" (`unavailable`, `off`, `notice`, `paused`, `left`, `noslot`, `locked`, `waiting`, `in`) and the index (1 main, 2..6 fallback) |
| `Channel.GetNumber()` | the chat channel number while `in`, else nil (Comm's `CHANNEL` target) |
| `Channel.IsOurs(name)` | true for any of `Channel.NAMES` (the chat filters and Comm's receive check) |
| `Channel.FreeSlots()` | `Constants.ChatFrameConstants.MaxChatChannels` (20) minus the channels the player is in |
| `Channel.Describe()` | English lines for `/okf debug`: state, index, free slots, locks seen, kicks, owner self-heal tried |
| `Channel.OnRefused()` | Comm reports two refusals in a row on the channel path: the index is marked locked and the next one is joined (research R4) |

Message (listed in `CLAUDE.md`): `CHANNEL_STATE` (state, index) when the state or the index changes; Share starts or
stops its channel HELLO rounds on it, the settings page and the tab refresh.

## `ns.Comm` additions

| Function | Does / returns |
| --- | --- |
| `Comm.ChannelBroadcast(text)` | queues a `HELLO` to the channel (`SendAddonMessage(PREFIX, text, "CHANNEL", Channel.GetNumber())`), only while `Channel.GetState()` is `in`; broadcast pace, path `channel` |
| `Comm.OnReceive(fn)` | unchanged signature; `via` gains `"channel"` (an `OKF1` addon message from one of `Channel.NAMES`) |
| `Comm.SetPartFilter(fn)` | `fn(address)` true when parts of a long message are taken from that address (Share: the session peer, or the session that just ended); parts from anyone else are dropped before they are buffered (FR-010) |
| `Comm.OnFlood(fn)` | `fn(address)` once when a sender's dropped parts pass `PART_FLOOD_LIMIT` within 10 minutes (402: more than an honest client's whole hourly budget carries in parts, so the leftovers of a session that ended never count as a flood); Comm drops every later message from it until logout, and Share ignores it (FR-010) |
| `Comm.GetPaths()` | gains `channel` |

Rules: from the channel only whole messages are taken (no parts) and only `H` messages reach Share; the total of
part buffers over all senders is capped at 128 KB (FR-010). The channel path counts refusals per channel: two in a
row call `Channel.OnRefused()` and start the count again. The path is left out only when `Channel.GetState()` is
`locked`, not by part 2's rule of five refusals (research R6).

## `ns.Share` additions

| Function | Does / returns |
| --- | --- |
| `Share.GetStatus()` | `heard` gains `channel`; new fields `channel` (`Channel.GetState()`), `channelIndex`, `channelPeers` (peers whose only path is the channel), `blocked` (other records refused or dropped as blocked this session), `ownBlocked` |
| `Share.PrintStatus()` | gains the channel line (contracts/channel.md "Texts") and the channel count in the "players heard" line, both only while `Channel.AVAILABLE` |
| `Share.Describe()` | gains the channel, the population estimate, the channel peers kept, blocked counts, `own record offered: no, blocked by the bundled data` when it is, and the chain state (`seq of top`, marks ready; never the secret) |
| `node:ChannelHello()` | sends a `HELLO` to the channel (rounds of research R5) |
| `Share.HeardInChannel(name)` | true when a player of that name (with or without the realm) announced in the channel this session; Channel.lua tells an addon owner's clear from a lock with it (research R4) |
| `Share.Store.Accept(store, record, now, absorbed, verified)` | returns as in part 2 without the third value (unknown items are accepted); refuses `"blocked"` (no blame). A newer version must pass `CatchDB.CheckVersion`: the merge walks the chain in steps and passes `verified = true`; without it (tests, the cleanup) `Accept` runs the check to the end at once. A failing one is `"refused"` with reason `"invalid"`, and the merge ignores its sender |
| `Share.Store.Evict(store)` | the eviction order of data-model.md |

## `ns.CatchDB` additions and changes

| Function | Returns |
| --- | --- |
| `CatchDB.CheckRecord(record)` | `true` or `false, reason`; no third value any more: an unknown item is accepted (FR-017a); `proof` must be 16 base32 characters; item IDs at most 2,147,483,647; the casting of all cells at most `STEP_SECONDS` (180) times the seq |
| `CatchDB.CheckVersion(held, incoming, steps, state)` | a resumable check that a newer version continues the held one's chain (data-model.md "Rules"): returns `"ok"`, `"invalid", reason`, or `"more"` with its state when `steps` links were walked and the chain goes on (the merge calls it again on the next frame step) |
| `CatchDB.SeedProof(id, epoch)` | the seed's proof of the absorbed version of a unit, or nil |
| `CatchDB.IsBlocked(id)` | true when the seed's `blocked` list names the ID |
| `CatchDB.OwnProofReady()` | false while the chain's marks are still being built after a roll or a login (the own record is not offered then) |
| `CatchDB.Query(mapID, cell, filter)` | unchanged arguments; the view of data-model.md "Views": weights, items shown, `missRate`, `reporters`, `inSeed` |

## `tools/harvest.mjs`

| Command | Does |
| --- | --- |
| `npm run harvest` | as in part 1, plus: checks each newer version against the stored one (the chain, research R9; a version that fails is rejected and reported) and every record against the casting limit; leaves blocked IDs out of the sums and of `absorbed`; applies the weight limit per cell (research R7); writes `proofs` and `blocked` into the seed; prints the outlier report (research R11) |
| `npm run harvest -- --block <id> [note]` | adds the ID to `blocked` in `seed/contributions.json` with the note, then harvests |
| `npm run harvest -- --unblock <id>` | removes it, then harvests |

`seedProblems` (used by `npm run check`) also checks `proofs` (`{ [id] = { [epoch] = 16 base32 } }`) and
`blocked` (`{ [id] = true }`).

## `/okf share` and `/okf debug`

No new command. `/okf share` gains the channel line and count (localized); `/okf debug` gains the lines of
`Channel.Describe()` and the new `Share.Describe()` lines (English, no names, no IDs, never the secret).
