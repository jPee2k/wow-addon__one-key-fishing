# Release plan

What the next releases wait for and in which order things happen. The generic release steps (version, changelog,
pull request, tag) are in [publishing.md](publishing.md); this page is about the two releases that are built but
cannot be verified before WoW Forever opens on 2026-11-04. It is deleted once both are out.

## 1.1.0: interface languages

Built on `001-interface-language` (`specs/001-interface-language`), waiting for the game.

1. After the launch: run [checklists/fishing-mode.md](checklists/fishing-mode.md) (the 1.0.0 features still
   work) and [checklists/interface-language.md](checklists/interface-language.md); report the results.
2. Fix what the checklists found, with tests; record the font results in
   `specs/001-interface-language/research.md` R6 and `docs/forever-api.md`.
3. Merge `001-interface-language` into `develop`.
4. Release 1.1.0 by the steps of [publishing.md](publishing.md): version 1.1.0 in `package.json`, the
   `[Unreleased]` entries become `## [1.1.0] - <date>`, pull request `develop` -> `main`, tag `1.1.0`.

## 1.2.0: the shared catch database

Built on `002-shared-db` (`specs/002-local-catch-db` to `specs/005-catch-catalog`), waiting for the game, for a
character that can fish, and for a second player. The four parts ship together; the design is recorded in
[history/shared-db-plan.md](history/shared-db-plan.md).

1. After 1.1.0 is out: merge `develop` into `002-shared-db`. In `CHANGELOG.md` the interface-language entries then
   sit under `## [1.1.0]`; `[Unreleased]` keeps the shared catch database.
2. Run [checklists/spike.md](checklists/spike.md) once, in one session, with a second player: the game facts of all
   four parts (`/okf spike`). Paste the reports.
3. Record the answers in [forever-api.md](forever-api.md) "Verified in game"; fix the code where an assumption was
   wrong, with tests; remove the `VERIFY` markers of the closed ids and tick them in the four `verification.md`
   files. If V19 failed, set `Channel.AVAILABLE = false` in `OneKeyFishing/Channel.lua` and close V20-V25 as "not
   shipped" (`specs/004-public-channel-sync/verification.md`).
4. Run the feature checklists: [catch-database.md](checklists/catch-database.md),
   [catch-exchange.md](checklists/catch-exchange.md), [public-channel.md](checklists/public-channel.md) (a week of
   play for its step 10), [catch-catalog.md](checklists/catch-catalog.md). Fix, test, remove the remaining markers.
5. Remove the spike: `OneKeyFishing/Spike.lua`, its TOC line, the `spike` entry in `OneKeyFishing/Commands.lua`,
   `tests/ui/spike_test.lua`, the "Spike.lua" section of `docs/architecture/ui.md` and its row in `CLAUDE.md`.
6. Fish, then `npm run harvest` for the first real seed (the author's accounts, the records the exchange collected,
   saved files friends sent); check the report and `git diff OneKeyFishing/SeedData.lua`; commit
   `OneKeyFishing/SeedData.lua` with `seed/contributions.json`.
7. Version 1.2.0 in `package.json`, the `[Unreleased]` entries become `## [1.2.0] - <date>`; `npm run build` must
   pass with no `VERIFY` marker left.
8. Merge `002-shared-db` into `develop`, pull request `develop` -> `main`, tag `1.2.0` ([publishing.md](publishing.md)).
9. Delete this page; the open ideas stay in [ROADMAP.md](ROADMAP.md).
