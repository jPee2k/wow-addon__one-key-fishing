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
| V54 | A bound item (bind on pickup, quest) cannot be listed at auction, so the scan leaves it out | `C_AuctionHouse.IsSellItemValid` on a bound item in the bags with the auction house open (the line of `docs/checklists/auction-scan.md`, step 8, with the item's slot) | `specs/018-auction-scan/verification.md` |
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

## 1.5.0 (planned)

- Spec 020 (`specs/020-camp-buffs`): the camp bonuses of a Fishing Rack and a Fishing Hut, built on `020-camp-buffs`
  (implemented 2026-11-20). Three `VERIFY` markers are open after the in-game checks of 2026-11-20: V62 (both
  auras at once: needs a second player), V63 (the cast in which a buff ends: rare) and V67 (the own record's size
  with many bonus parts; 1448 bytes for 18 places, 2 with a part, so far) (`specs/020-camp-buffs/verification.md`,
  checklist [checklists/camp-buffs.md](checklists/camp-buffs.md)); V61 and V68 were accepted on 63 catches
  without a buff at one water, V60, V64, V65, V66 and V69 confirmed. What stays open the author accepts or
  releases with `--force`.
- **Before the release**: read the size of the own record with bonus parts (V67, the checklist's size step): if a
  place with a part costs twice a place without or more, the roll before a 501st place counts such a place as two
  (research R16) before the release, not after.
- At the release (publishing.md): the version 1.5.0, the harvest (the seed then carries the bonus parts), the
  changelog's `[Unreleased]` under its version.

## 1.4.0 (released 2026-11-18)

**Released 2026-11-18**: pull request #11 (`019-auctionator-prices`) merged into `develop`, pull request #12 merged
into `main`, tag `1.4.0`, GitHub release and CurseForge upload (`OneKeyFishing-1.4.0-forever.zip`). No `VERIFY` marker.

- Spec 019 (`specs/019-auctionator-prices`): Auctionator as a price source, built on `019-auctionator-prices`. Its
  checklist `checklists/auctionator-prices.md` passed in game on 2026-11-18 (steps 1 to 9); V59 confirmed. No
  `VERIFY` marker. Three review rounds and a tester run before; the low items left are in `tech-debt.md`.
- The window fixes merged into `develop` before (pull request #10): the debug window's close button and the
  minimap menu in a fight, the two windows' order.
- The harvest made seed epoch 6 with 525 places (79 new) and 2 new items from 82 contributions. Four records
  reported as outliers (one item nobody else reports): 2977 Veteran Armor, 3870 Plans: Green Iron Shoulders, 21243
  Bloated Glossy Mightfish, 3873 Plans: Golden Scale Cuirass. None blocked: they are real items, and gear and
  recipes are fished in Forever. The new items got their kind in `GameData/ItemKinds.lua` (3873 Plans: Golden
  Scale Cuirass and 6718 Electropeller, both other; names read from Wowhead's classic database).
- The author's scan with the release build, the Auctionator switch off (the new seed items join every player's scan
  list): 107 items (43 own, 64 bundled), 107 requests in 73 s, 78 prices, nothing left unanswered.

## 1.3.2 (released 2026-11-18)

**Released 2026-11-18**: pull request #8 (`018-auction-scan`) merged into `develop`, pull request #9 merged into
`main`, tag `1.3.2`, GitHub release and CurseForge upload (`OneKeyFishing-1.3.2-forever.zip`). No `VERIFY` marker.

- Spec 018 (`specs/018-auction-scan`): the rebuilt auction scan. Its checklist `checklists/auction-scan.md` passed in
  game on 2026-11-18 (steps 1 to 9); V55 to V58 confirmed (V58, Plated Armorfish, with the release build), V54
  (bound items) accepted (the table above). Found on the way and fixed: the unit price of non-commodity items (V5 of spec 002 was wrong);
  grey items can be listed.
- The harvest made seed epoch 5 with 446 places (139 new) and 31 new items from 109 contributions. Five records
  reported as outliers (one item nobody else reports): 21243 Bloated Glossy Mightfish, 4377 Heavy Blasting Powder,
  6539 Willow Belt, 6363 26 Pound Catfish, 19805 Keefer's Angelfish. None blocked: they are real items, and gear
  and trade goods are fished in Forever (other players report the same kinds). The new items got their kind in
  `GameData/ItemKinds.lua` (names and classes read in game: 7 fish, 4 bloated fish as containers, 12 reagents,
  8 other).
- Plated Armorfish (13890) is in the seed now, so every player's scan searches it: the author's scan with the
  release build (`npm run build`) answered it, only the start and finish lines in chat (V58 confirmed).

## 1.3.1 (released 2026-11-17)

**Released 2026-11-17**: pull request #7 merged into `main`, tag `1.3.1`, GitHub release and CurseForge upload
(`OneKeyFishing-1.3.1-forever.zip`). No `VERIFY` marker; `npm run build` passed without `--force` (98 files).

- Spec 017 (`specs/017-catalog-sort`): the catalog's Sort button (name, price, chance), merged into `develop`; its
  checklist `checklists/catalog-sort.md` passed in game (steps 1 to 7 and 9; step 8 skipped: the catalog loads too
  fast). No `VERIFY` marker.
- The harvest made seed epoch 4 with 307 places (235 new) from 71 contributions; one outlier reported (`6bujtjq6@1`,
  the only report of 6351 Dented Crate, a real fished container), not blocked. The 26 new items got their kind in
  `GameData/ItemKinds.lua` from the new `/okf debug` section "Seed items without a kind" (names and classes read in
  game): 11 fish, 4 bloated fish as containers, 4 potions, 1 reagent, 6 other.
- Nothing of 1.3.1 waits for a check in game. An idea seen on the way: the bloated fish (6643, 8366, 13881, 21162)
  are opened by hand; they are not in `GameData/FishedContainers.lua`, so the addon does not open them.

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
