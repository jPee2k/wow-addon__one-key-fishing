# Release plan

What the next releases wait for and in which order things happen. The generic release steps (version, changelog,
pull request, tag) are in [publishing.md](publishing.md); this page is about the checks left after 1.1.0 and
about 1.2.0, which is built but not verified in game yet. It is deleted once 1.2.0 is out.

## 1.1.x: in-game checks left after 1.1.0

1.1.0 went out with the steps below still open in the checklists; a finding goes into a 1.1.x patch.

- [checklists/fishing-mode.md](checklists/fishing-mode.md): leaving the mode when attacked, the best of two
  poles, a lure on cooldown, clams and locked containers, the rank notices from character level 10.
- [checklists/interface-language.md](checklists/interface-language.md) section 10: the Journeyman notice and the
  map pin (level 10), Old Man Heming and the book (level 20), Nat Pagle and the quest ID (level 35, quest 6607
  has no title on Forever yet); their results go into `specs/001-interface-language/research.md` R11 / R12 and
  remove the remaining `VERIFY` marks.
- Korean and Chinese on a client in another language: deferred until a player reports it
  (`specs/007-launch-day-fixes/research.md` R9).

## 1.2.0: the shared catch database

Built on `002-shared-db` (`specs/002-local-catch-db` to `specs/005-catch-catalog`), waiting for the game, for a
character that can fish, and for a second player. The four parts ship together; the design is recorded in
[history/shared-db-plan.md](history/shared-db-plan.md). The branch is rebased onto `develop` after 1.1.0: the
interface-language entries of `CHANGELOG.md` sit under `## [1.1.0]`, `[Unreleased]` keeps the shared catch
database.

Technical debt from `001-interface-language` to settle before 1.2.0 (spec 001 research R15):

- Move the older game data into `GameData/` (data only, like `GameData/FishingRanks.lua`): the lures and the
  fished containers (`Fishing/Bags.lua`), the pole bonuses (`Fishing/Gear.lua`), the Fishing spell IDs and the
  bobber ID (`Core/Data.lua`).
- Switch the catch catalog's pin (`Catalog.PinTarget`, `CatalogTab.Pin`) to `ns.MapPin` (`UI/MapPin.lua`), which
  took that code over with the same saved field (`charDB.pin`) and texts; `ns.Toast` already has the `always`
  argument on both branches.

The steps:

1. Run [checklists/spike.md](checklists/spike.md) once, in one session, with a second player: the game facts of all
   four parts (`/okf spike`). Paste the reports.
2. Record the answers in [forever-api.md](forever-api.md) "Verified in game"; fix the code where an assumption was
   wrong, with tests; remove the `VERIFY` markers of the closed ids and tick them in the four `verification.md`
   files. If V19 failed, set `Channel.AVAILABLE = false` in `OneKeyFishing/Channel.lua` and close V20-V25 as "not
   shipped" (`specs/004-public-channel-sync/verification.md`).
3. Run the feature checklists: [catch-database.md](checklists/catch-database.md),
   [catch-exchange.md](checklists/catch-exchange.md), [public-channel.md](checklists/public-channel.md) (a week of
   play for its step 10), [catch-catalog.md](checklists/catch-catalog.md). Fix, test, remove the remaining markers.
4. Remove the spike: `OneKeyFishing/Spike.lua`, its TOC line, the `spike` entry in `OneKeyFishing/Commands.lua`,
   `tests/ui/spike_test.lua`, the "Spike.lua" section of `docs/architecture/ui.md` and its row in `CLAUDE.md`.
5. Fish, then `npm run harvest` for the first real seed (the author's accounts, the records the exchange collected,
   saved files friends sent); check the report and `git diff OneKeyFishing/SeedData.lua`; commit
   `OneKeyFishing/SeedData.lua` with `seed/contributions.json`.
6. Version 1.2.0 in `package.json`, the `[Unreleased]` entries become `## [1.2.0] - <date>`; `npm run build` must
   pass with no `VERIFY` marker left.
7. Merge `002-shared-db` into `develop`, pull request `develop` -> `main`, tag `1.2.0` ([publishing.md](publishing.md)).
8. Delete this page; the open ideas stay in [ROADMAP.md](ROADMAP.md).
