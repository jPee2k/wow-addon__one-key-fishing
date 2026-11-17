# Verification debt: The Public Channel Returns

Claude cannot run the game. The channel's assumptions from spec 004 keep their rows in
`specs/004-public-channel-sync/verification.md` (V21-V25, V41, reopened on 2026-11-16, their markers back in
`Exchange/Channel.lua` and `Exchange/Comm.lua`). This file holds the one assumption spec 004 never listed: V19 failed
before it could be seen. The ID continues the V series (V52 was spec 015's, withdrawn). The code carries
`-- VERIFY(V53): ...`; `npm run check` lists it, and `npm run build` refuses to package while it is open (unless the
author releases with `--force`, `docs/publishing.md`).

To close an item:
1. Run its step in game.
2. Record the answer in `docs/forever-api.md`.
3. Adjust the code if the game differs.
4. Remove the marker and tick the item here.

| ID | Assumption we build on | Evidence before the change | If it turns out wrong | How to verify | Status |
| --- | --- | --- | --- | --- | --- |
| V53 | `CHAT_MSG_ADDON` for a message in a custom channel names that channel in argument 8 (`name`) or, failing that, argument 5 (`target`), so `Exchange/CommReceive.lua` can keep the messages of the addon's own channel and drop the others (research R5) | Retail docs of `CHAT_MSG_ADDON`; on 2026-11-16 the `/run` listener printed only prefix, text, chat type `CHANNEL` and the sender "First Last", not arguments 5 and 8 | Every channel message is dropped and the channel exchanges nothing (`docs/checklists/public-channel.md` step 2 shows it): the check then reads the channel's number in `target` and compares it with `Channel.GetNumber()` | The `/run` listener of `docs/forever-api.md` (2026-11-16) printing `select(5, ...)` and `select(8, ...)` of `CHAT_MSG_ADDON` for a message sent to the channel by another player, or checklist step 2 | **Confirmed** 2026-11-17 (`/run`, two players who are not friends in game or on Battle.net, one at level 1): a message from the other player arrives with argument 5 `target` = "8. OkfTest42" and argument 8 `name` = "OkfTest42", the channel's base name, which `CommReceive.lua` reads; marker removed |
