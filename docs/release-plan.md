# Release plan

What is left to check after releases 1.2.0 (the shared catch database, `specs/002-local-catch-db` to
`specs/005-catch-catalog`, with the fixes of specs 006 to 012) and 1.3.0 (specs 013 to 016), and what the next patch
waits for. The generic release
steps (version, changelog, pull request, tag) are in [publishing.md](publishing.md).

1.2.0 went out before every in-game check had run: the author accepted the assumptions below without one (each
`verification.md` row says "Accepted 2026-11-12" and what happens if it is wrong), so the release build has no
`VERIFY` marker. They are checked in play after the release, with the larger data the release brings; a finding
goes into [tech-debt.md](tech-debt.md) and a 1.2.x patch.

## Accepted assumptions to confirm in game

| ID | What was assumed | How to check | Row |
| --- | --- | --- | --- |
| V5 | An auction's `buyoutAmount` is for all its pieces | Scan prices, then compare a stacked non-commodity auction with the addon's unit price | `specs/002-local-catch-db/verification.md` |
| V10 | `RAID` sends as `PARTY` does; the game throttles as on Retail | `/okf debug` in a raid with an addon user: heard by the group, send results 0, no refusals | `specs/003-guild-group-sync/verification.md` |
| V11 | A character friend is named as their messages name them | Exchange with a player who is only a character friend (no guild, group or Battle.net): `/okf share` "friends 1" | `specs/003-guild-group-sync/verification.md` |
| V12 | The "No player named" line of an exchange whisper is hidden | That character friend logs out during an exchange: no line in chat | `specs/003-guild-group-sync/verification.md` |
| V16 | 20,000 stored places stay smooth | Watch the frame rate as stored places grow (`/okf share` "records, places") | `specs/003-guild-group-sync/verification.md` |
| V18 | 500 busy places encode in about 24 KB (56 bytes a place at 15 places) | `/okf debug` "own record offered: N bytes encoded for P places" at 50+ places: N / P x 500 | `specs/003-guild-group-sync/verification.md` |
| V27 | The loot link of an item the client does not know carries its ID | When such an item is fished: it shows in the statistics and the catalog | `specs/004-public-channel-sync/verification.md` |
| V33 | A Micro map converts to its parent zone for a pin | Fish in a place whose map is Micro (`/okf debug` current place), press its pin button | `specs/005-catch-catalog/verification.md` |
| V36 | Search folds accents on deDE / frFR clients | Search a name with an accent typed without it on such a client | `specs/005-catch-catalog/verification.md` |
| V44 | Lure and pole requirements read the base Fishing skill | A character whose base skill is below a lure's requirement but above it with the pole's bonus | `specs/008-architecture-alignment/verification.md` |
| R11 | Journeyman from skill 50; Artisan from skill 225 and level 35 | At Nat Pagle with skill 225 and level 35: the quest is offered | `specs/001-interface-language/verification.md` |
| R12 | The German name of Old Man Heming | A deDE client at Heming before his tooltip loaded | `specs/001-interface-language/verification.md` |

## Checklist steps still open

- [checklists/catch-exchange.md](checklists/catch-exchange.md): the popup on a fresh account (step 1); the group path
  and the character-friends path each alone (steps 2, 3: every partner so far was also on a Battle.net list); the
  relay (7); an offline peer (8); the debug sizes at 50+ places (9); performance (10); a Trial account (12).
- [checklists/catch-database.md](checklists/catch-database.md): a fresh character with the seed (step 2, V9), now
  that the seed holds 26 places.
- [checklists/catch-catalog.md](checklists/catch-catalog.md): the list (V35-V37), another client language (V34, V40),
  smooth after an hour of fishing (V39), the ways in (FR-024, FR-025).
- [checklists/fishing-mode.md](checklists/fishing-mode.md): "Find fishing items" (needs a fishing item that is not a
  pole), a lure on cooldown, a lure above the skill (V44), a clam, an unknown or locked container, a clam with full
  bags; the toast at a capped rank and the popup on a fresh account.
- [checklists/interface-language.md](checklists/interface-language.md): the rank notices at skill 225 and level 35
  (Nat Pagle); Korean and Chinese on a client in another language (deferred until a player reports it).

## 1.3.1 (prepared 2026-11-17)

- Spec 017 (`specs/017-catalog-sort`): the catalog's Sort button (name, price, chance), merged into `develop`; its
  checklist `checklists/catalog-sort.md` passed in game (steps 1 to 7 and 9; step 8 skipped: the catalog loads too
  fast). No `VERIFY` marker.
- The harvest made seed epoch 4 with 307 places (235 new) from 71 contributions; one outlier reported (`6bujtjq6@1`,
  the only report of 6351 Dented Crate, a real fished container), not blocked. The 26 new items got their kind in
  `GameData/ItemKinds.lua` from the new `/okf debug` section "Seed items without a kind" (names and classes read in
  game): 11 fish, 4 bloated fish as containers, 4 potions, 1 reagent, 6 other.
- Left: the pull request `develop` -> `main`, the tag `1.3.1`.

## 1.3.0 (released 2026-11-17)

**Released 2026-11-17**: pull request #6 merged into `main`, tag `1.3.0`, GitHub release and CurseForge upload
(`OneKeyFishing-1.3.0-forever.zip`). No `VERIFY` marker was left: V21, V22, V23, V41 and V53 were confirmed in game;
V24, V25 and V51 were accepted by the author without a check and are checked after the release:

| ID | To check later | How |
| --- | --- | --- |
| V24 | A kick, ban or mute from a custom channel is noticed | When a way to kick in Forever is found: `checklists/public-channel.md` step 8 |
| V25 | Channel messages throttle as on Retail | `checklists/public-channel.md` step 10 (a week with the channel on) |
| V51 | The rare sound plays for an Uncommon catch | `checklists/sounds.md` step 3 |

Decided by the author on 2026-11-16 (it replaces a 1.2.1 patch): the fishing sounds (spec 013), the catch kinds
(spec 014), the tech-debt fixes (spec 015) and the public channel back (spec 016,
`specs/016-public-channel-return`), released together.

- Prepared on 2026-11-17: `016-public-channel-return` merged into `develop`; the harvest (`checklists/public-channel.md`
  step 11) made seed epoch 3 with 72 places from 6 contributions (outliers reported, none blocked); 21 new items got their kind in `GameData/ItemKinds.lua` (names and classes read in game); version 1.3.0.
  The in-game checks it waited for were done or accepted (status above); V20, the other faction, stays open on a
  PvE realm.
- `npm run build` passed without `--force`; the release package was checked against its TOC (98 files: 63 listed,
  5 at the root, 30 sounds; nothing else).
- Already checked for spec 016 (2026-11-16, `/run`, not repeated): addon messages between players in a custom
  channel, in `OneKeyFishingShare`, from level 4, ten in a frame, 255 bytes; the password, wrong password and owner
  notices (`forever-api.md` "Verified in game").
- Checked on 2026-11-17 with the spec 016 build and a stranger (`checklists/public-channel.md` "Results"): V53 (the
  channel's name in `CHAT_MSG_ADDON`), the exchange through the channel (step 2), hiding and channel numbers (1),
  locks and the owner's self-heal (4), the give-way at the 20-channel limit (5, V23 closed), the notice again (9);
  the kick cannot be done in Forever. A bug found there (a join at the limit stopped the channel for the session) is
  fixed. Later the same night: V21, V22 and V41 confirmed. Still open after the release: steps 6, the rest of 7,
  5's way back, the slow join (8), a week (10).
- Whatever these checks find goes into [tech-debt.md](tech-debt.md) and a 1.3.x patch.
