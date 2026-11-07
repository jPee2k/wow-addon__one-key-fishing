# Release plan

What the next releases wait for and in which order things happen. The generic release steps (version, changelog,
pull request, tag) are in [publishing.md](publishing.md); this page is about the checks left after 1.1.0 and
about 1.2.0, which is built but not verified in game yet. It is deleted once 1.2.0 is out.

## 1.1.x: in-game checks left after 1.1.0

1.1.0 went out with the steps below still open in the checklists; a finding goes into a 1.1.x patch.

- The map pin and fishing mode in a fight (former tech-debt batches 3 and 4): fixed by spec 009 on `002-shared-db`,
  shipped in 1.2.0, not as a 1.1.x patch.
- [checklists/fishing-mode.md](checklists/fishing-mode.md) (2026-11-06: the rank notices of level 10 and a fished
  chest are done; Nightcrawlers and Shiny Bauble have no cooldown): the best of two poles, a lure that has a
  cooldown, a locked container, a clam with full bags. Combat raised three items, fixed by spec 009.
- [checklists/interface-language.md](checklists/interface-language.md) section 10 (2026-11-06: level 10, the notice,
  the pin, the replace popup, the chat map link, Heming's place and merchant list are done): the map that the Pin
  button opens fails in a later fight (fix in `tech-debt.md`, then re-check); that the book teaches Expert from skill
  125 and level 20, the debug report after Expert, Nat Pagle and the quest ID (level 35, quest 6607 has no title on
  Forever yet), the German Heming name. Their results go into `specs/001-interface-language/research.md` R11 / R12 /
  R14 and remove the remaining `VERIFY` marks.
- Korean and Chinese on a client in another language: deferred until a player reports it
  (`specs/007-launch-day-fixes/research.md` R9).

## 1.2.0: the shared catch database

Built on `002-shared-db` (`specs/002-local-catch-db` to `specs/005-catch-catalog`, and the error log
`specs/006-error-log`), waiting for the game, for a character that can fish, and for a second player. The four parts
and the error log ship together; the design is recorded in
[history/shared-db-plan.md](history/shared-db-plan.md). The branch is rebased onto `develop` after 1.1.0: the
interface-language entries of `CHANGELOG.md` sit under `## [1.1.0]`, `[Unreleased]` keeps the shared catch
database.

The technical debt from `001-interface-language` (spec 001 research R15: the older game data into `GameData/`, the
catalog's pin through `ns.MapPin`) is settled by `specs/008-architecture-alignment`.

The steps:

1. Run [checklists/spike.md](checklists/spike.md) once, in one session, with a second player: the game facts of all
   four parts and the error log (`/okf spike`). Paste the reports. **2026-11-06/07: the solo parts are done** (the
   answers in `forever-api.md` and the five `verification.md`; V19, V11, V3 failed, V26 too slow, V34 partly);
   left for a second player: N1 (guild), N3, C2 (B's view), C6, C7. The findings are grouped in
   [tech-debt.md](tech-debt.md) "Fix batches": batches 1 and 2 are built here (next spec 010) before the feature
   checklists with a second player; batches 3 and 4 are built here by spec 009 and ship in 1.2.0 (no 1.1.x patch).
2. Record the answers in [forever-api.md](forever-api.md) "Verified in game"; fix the code where an assumption was
   wrong, with tests; remove the `VERIFY` markers of the closed ids and tick them in the five `verification.md`
   files (002 to 006). If V19 failed, set `Channel.AVAILABLE = false` in `OneKeyFishing/Exchange/Channel.lua` and
   close V20-V25 as "not shipped" (`specs/004-public-channel-sync/verification.md`).
3. Run the feature checklists: [catch-database.md](checklists/catch-database.md),
   [catch-exchange.md](checklists/catch-exchange.md), [public-channel.md](checklists/public-channel.md) (a week of
   play for its step 10), [catch-catalog.md](checklists/catch-catalog.md). Fix, test, remove the remaining markers.
4. Remove the spike: `OneKeyFishing/Core/Spike.lua`, its TOC line, the `spike` entry in `OneKeyFishing/Core/Commands.lua`,
   `tests/ui/spike_test.lua`, the "Spike.lua" section of `docs/architecture/ui.md` and its row in `CLAUDE.md`, and
   `ns.ReportSection` in `OneKeyFishing/Core/Debug.lua` (only the spike uses it).
5. Fish, then `npm run harvest` for the first real seed (the author's accounts, the records the exchange collected,
   saved files friends sent); check the report and `git diff OneKeyFishing/CatchDB/SeedData.lua`; commit
   `OneKeyFishing/CatchDB/SeedData.lua` with `seed/contributions.json`.
6. Version 1.2.0 in `package.json`, the `[Unreleased]` entries become `## [1.2.0] - <date>`; `npm run build` must
   pass with no `VERIFY` marker left.
7. Merge `002-shared-db` into `develop`, pull request `develop` -> `main`, tag `1.2.0` ([publishing.md](publishing.md)).
8. Delete this page; the open ideas stay in [ROADMAP.md](ROADMAP.md).
