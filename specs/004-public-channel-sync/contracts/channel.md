# Contract: the hidden public channel

What the addon does with the chat channel, what the player sees of it, and what goes through it. Values are
starting values; they live as constants in `Channel.lua` and `Share.lua` (research R2-R5). The game API calls behind
each rule are in research R2.

## Names

| Index | Name | Used when |
| --- | --- | --- |
| 1 | `OneKeyFishingShare` | always first |
| 2-6 | `OneKeyFishingShare2` ... `OneKeyFishingShare6` | the ones before were found locked (a password) or banned this session |

The names say whom the channel belongs to, so a player who meets one in a list knows what it is (FR-003 fallback).
They are fixed: names that change with the date would be just as predictable from the open code and would move
everybody at the boundary (research R4). Every client walks the list in the same order, so clients that leave a
locked channel meet again in the next one without any coordination (FR-005a).

## Joining

- Only while `Channel.AVAILABLE`, both settings on, the notice that names the channel closed, the exchange not
  paused, and at least **two** chat channel slots free (`MaxChatChannels` is 20 in Forever; FR-005).
- After a login: `JOIN_DELAY_MIN`-`JOIN_DELAY_MAX` (30-60 s) after `PLAYER_ENTERING_WORLD`, once the game has
  put the player's own channels in place (research R2), so General, Trade and the player's channels keep their
  numbers (FR-002). After turning the setting on, or after two slots free up: at once. After a `/reload` the client
  is still in the channel: it is taken as joined. What lasts until the next login (left by hand, locked names, kicks,
  a slot given up) is saved at `PLAYER_LOGOUT`, which a `/reload` fires too, and read back on the `/reload`.
- `JoinTemporaryChannel(name)` with no password and no window: left at logout, never saved with the window settings,
  never rejoined by the client, so the next login places the player's channels first (research R2).
- On the game's confirmation (the join notice for our name, or `GetChannelName(name) > 0` at one of three checks 5 s
  apart): the channel is removed from every chat window that lists it; the filters below are active from the file
  load on. A join with neither by the third check counts as locked (a password or a ban without a notice).

## Hiding (FR-003, FR-004)

| What | How |
| --- | --- |
| The channel in chat windows | `RemoveChannel(name)` on every chat window that `ContainsChannel(name)`, after each join and on `UPDATE_CHAT_WINDOWS`; a window drops the lines and notices of channels it does not list (research R2) |
| Join, leave, owner, password, kick, ban and member notices of the channel | `CHAT_MSG_CHANNEL_NOTICE`, `CHAT_MSG_CHANNEL_NOTICE_USER`, `CHAT_MSG_CHANNEL_JOIN`, `CHAT_MSG_CHANNEL_LEAVE` filters (`ChatFrameUtil.AddMessageEventFilter`) that drop every line whose arg9 (the channel name) is one of `Channel.NAMES` |
| Text typed into the channel by anyone | a `CHAT_MSG_CHANNEL` filter, same test |
| The game's password popup when a joined name is locked | hidden in the same frame (`StaticPopup_Hide("CHAT_CHANNEL_PASSWORD")` on `CHANNEL_PASSWORD_REQUEST` for one of our names) |
| The Chat Channels window and Chat Settings > Channels | not hidden: they have no filter, and a hook into Blizzard's list is too fragile; the channel shows there under its own name, and the README says so (FR-003) |
| Secret values (chat lockdown) | the filters do not run then; the window removal still hides everything, and the exchange is paused anyway |

The addon's own `OKF1` addon messages never reach a chat window (part 2, V10).

## Locks, kicks, bans (FR-005a)

| The game reports | The addon |
| --- | --- |
| `WRONG_PASSWORD` or `CHANNEL_PASSWORD_REQUEST` on join (the popup is hidden), `BANNED`, `WRONG_FACTION` | marks the index locked for the session, joins the next index |
| `TRIAL_RESTRICTED`, `INVALID_NAME`, or a nil result from the join | state `locked`: the game refuses the channel itself, no fallback is tried |
| `PASSWORD_CHANGED` or `MODERATION_ON` by a player not heard announcing in the channel, while in | a password, as the owner: undoes it at once (`SetChannelPassword(name, "")`; whether this client owns the channel comes from `OWNER_CHANGED` or from the `CHANNEL_OWNER` notice that `DisplayChannelOwner(name)` asks for, only after a lock). Otherwise, and for moderation (Forever's interface code has no call that turns it off): waits 10-20 s (random); stays if a change by a player heard announcing follows (an addon owner undid it), else leaves, marks the index locked and joins the next |
| the same by a player heard announcing | nothing (an addon owner's own clear) |
| `OWNER_CHANGED` naming this client after it saw a lock there | clears the password (the self-heal, V24) |
| `PLAYER_KICKED` naming this player | joins the same channel again after 60 s; the third kick in a session counts as a ban |
| `PLAYER_BANNED` naming this player, or `MUTED` | leaves, marks the index locked, joins the next index |
| two refusals in a row on the channel path (`InvalidChannel`, `GeneralError`, or any other result but a success, a throttle or a lockdown) after a join | marks the index locked, joins the next index; the count starts again, and at every join (a move, a rejoin). The channel path never counts toward the part 2 rule "every path left out": it carries `HELLO` only, and sessions go by whisper |
| every index locked | state `locked` until logout; guild, group and friends go on |

"Heard announcing" is a player whose channel HELLO came this session (`Share.HeardInChannel(name)`, kept apart from
the peer bound), matched by the name with or without the realm: a name without one is a player of the own realm, as
the game names them (the same holds for this client's own name in the notices).

## Slots and the player (FR-005)

- `Channel.FreeSlots()` counts the channels the player is in against `MaxChatChannels`.
- While in, when the game refuses a channel the player tried to join because of the limit (the formatted
  `ERR_TOO_MANY_CHAT_CHANNELS` text on `CHAT_MSG_SYSTEM` or `UI_ERROR_MESSAGE`, research R3): the addon leaves at once
  and prints one line, `L["OneKeyFishing left its hidden channel to free a chat channel slot. Try
  joining again."]`. It joins again only when two slots are free (checked on `CHANNEL_UI_UPDATE` and at every channel
  HELLO round), or at the next login. A second refusal in the same session finds the addon out of the way: no line.
- The player leaves the channel by hand (`/leave`, another addon): state `left` until the next login; the setting is
  not changed.

## What goes through the channel

- Only `HELLO` (`H <node> <epoch> <count> <hash>`, part 2 form), as `SendAddonMessage("OKF1", text, "CHANNEL", n)`.
- Received from the channel: an `OKF1` addon message whose channel is one of `Channel.NAMES`; anything but a whole
  `H` message is dropped (no parts, no session messages). The sender becomes a peer with `via = "channel"`; a
  session with it goes by whisper as in part 2.
- Rounds (research R5): the first channel `HELLO` 30-90 s after joining, then every 30-50 min (random), and 5-30 s
  after a move to a fallback channel. A hearer starts a session only with the chance of research R5.

## Texts (FR-022, FR-023, FR-024)

New English keys, each with nine translations; none is looked up at file load.

| Key | Where |
| --- | --- |
| `Use the public channel` | the second setting on the "Shared database" page |
| `With the public channel on, they also go to every other addon user, through a hidden chat channel.` | the page's short text |
| `Anyone who joins that channel by its name can see which characters in it use the addon.` | the page's short text (Q11: not in the notice) |
| `OneKeyFishing now shares your catches under a random ID with other players who use it.` and `It reaches your guild, group and friends, and anyone else through a hidden chat channel.` | the notice's first two sentences while `Channel.AVAILABLE`, in place of the part 2 first sentence (two keys, so each fits a line of the code) |
| `Public channel: in use` / `Public channel: in use (fallback channel %d)` / `Public channel: off` / `Public channel: no free chat channel slot` / `Public channel: locked or refused by the game` / `Public channel: you left it, back at the next login` / `Public channel: waiting` | `/okf share`, and below the setting on the page. States map one to one (data-model.md "State of the channel"); `notice` and `paused` also show `Public channel: waiting` (the exchange's own status line says why); `unavailable` shows no channel line |
| `Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d, channel %d` | `/okf share` while `Channel.AVAILABLE` (the part 2 line otherwise) |
| `OneKeyFishing left its hidden channel to free a chat channel slot. Try joining again.` | the one chat line (FR-005) |
| `Unknown item` / `The game has not shown this item yet.` / `Reported by %d players on this map` / `In the bundled data` / `Item ID: %d` | the "Unknown item" row and its tooltip (FR-017a) |

The tab's quiet status line is unchanged (Q13). The `/okf debug` lines stay English.
