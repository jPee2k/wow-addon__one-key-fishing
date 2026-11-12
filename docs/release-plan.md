# Release plan

What is left after release 1.2.0 (the shared catch database, `specs/002-local-catch-db` to
`specs/005-catch-catalog`, with the fixes of specs 006 to 012) and what the next patch waits for. The generic release
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

## 1.2.1

- [tech-debt.md](tech-debt.md) batch 11: a partner who relogs counts twice for an hour in the status line.
- Whatever the checks above find.
