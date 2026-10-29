# Verification debt: Catch Data Exchange in the Guild, the Group and with Friends

The game cannot be played before its launch on 2026-11-04, so part 2 is built on the assumptions below and verified
afterwards, as part 1 is (`specs/002-local-catch-db/verification.md`, V1-V9; the IDs continue from there because the
markers share the code). The code that depends on an item carries a `-- VERIFY(Vn): ...` comment; `npm run check`
lists the open markers and `npm run build` (release) refuses to package while any is left.

Closing an item: run the step in game (`/okf spike` prints the facts; the exchange steps need a second player or a
second account), record the answer in CLAUDE.md "Known API facts", adjust the code if the answer differs from the
assumption, remove its markers, and tick it here.

| ID | Assumption we build on | Evidence before launch | If it turns out wrong | How to verify | Status |
| --- | --- | --- | --- | --- | --- |
| V10 | `C_ChatInfo.SendAddonMessage` works for `GUILD`, `PARTY`, `RAID` and `WHISPER` in the open world, returns `Success`, shows nothing in chat, and throttles as on Retail (10 per prefix, +1 per s; whispers outside instances not throttled) | Function, result enum and `CHAT_MSG_ADDON` in the 1.60.1 dump; throttle rules from Retail docs; Trial and Veteran accounts cannot send addon messages | Pace and budget are constants: lower them; a path that fails is left out and the others keep working | Spike step N1; feature steps 1-3 | Built, waiting for launch |
| V11 | The `CHAT_MSG_ADDON` sender is a `Name-Realm` string that works as the `WHISPER` target | Retail behaviour; `Ambiguate` and `GetNormalizedRealmName` in the dump; nothing Forever-specific | Normalize with `Ambiguate(sender, "none")` before whispering | Spike step N1 (sender pattern) | Built, waiting for launch |
| V12 | A whisper to a player who just went offline returns `TargetOffline`; a system line "No player named ..." that may appear is hidden by a `CHAT_MSG_SYSTEM` filter through `ChatFrameUtil.AddMessageEventFilter` | `TargetOffline` (12.0) and `ChatFrameUtil.AddMessageEventFilter` in the dump; `CHAT_MSG_SYSTEM` is secret in chat lockdown | Whisper only peers heard in the last 30 min and friends shown `connected`; drop the filter if no line appears | Spike step N2 | Built, waiting for launch |
| V13 | Battle.net friends playing Forever have `clientProgram == BNET_CLIENT_WOW` and `wowProjectID == WOW_PROJECT_ID`; `C_BattleNet.SendGameData` and `BN_CHAT_MSG_ADDON` carry `OKF1` messages between Forever clients | Functions, fields and event in the dump; the Forever friends frame uses the same test | Battle.net friends are left out; character friends, guild and group keep working | Spike steps N3, N6; feature step 3 | Built, waiting for launch |
| V14 | The open world out of combat has no active add-on restriction (`Chat`, `Encounter`, `ChallengeMode`, `PvPMatch`), `InChatMessagingLockdown()` is false there, and they turn true where Midnight blocks addon chat (`AreOutgoingAddonChatMessagesRestricted()` is not used: by its API doc it is about chat messages sent by addons, true on a normal realm) | All in the dump; when they apply is known only from community reports for Midnight | If one is always true in the open world, the exchange cannot run: it says so in the status, and the release waits for a way around it | Spike step N4 | Built, waiting for launch |
| V15 | `C_EncodingUtil.SerializeCBOR` / `DeserializeCBOR` round-trip a record (string keys, integer item IDs, nested `{ catches, pieces }` pairs), and `CompressString` (Deflate) + `EncodeBase64` give text of Base64 characters only | All ten functions in the Forever dump (`EncodingUtilDocumentation.lua`) | Switch to an own text format for records (research R4 fallback) | Spike step N5 | Built, waiting for launch |
| V16 | Receiving a full session, holding 20,000 places of other records and opening the tab stay smooth; login takes no noticeable extra time (SC-006) | None | Lower the place limit; spread the merge over more frames | Feature step 9 with records from a synthetic load | Built, waiting for launch |
| V17 | The whole in-game checklist of the feature passes, with a second player | None | Fix and re-run | quickstart.md "In game: the feature" | Built, waiting for launch |

Evidence found before launch (research.md) lowers the risk but does not close an item: only the game does.
