# Release plan

What the next releases wait for and in which order things happen. The generic release steps (version, changelog,
pull request, tag) are in [publishing.md](publishing.md); this page is about the two releases that are built but
cannot be verified before WoW Forever opens on 2026-11-04. It is deleted once both are out.

## 1.1.0: interface languages

Built on `001-interface-language` (`specs/001-interface-language`), waiting for the game.
Status 2026-11-05: the launch day fixes are done (`specs/007-launch-day-fixes`); the checklists run on a new
character, the steps from character level 10 (rank notices, map pin) and the containers are still open.

1. After the launch: run [checklists/fishing-mode.md](checklists/fishing-mode.md) (the 1.0.0 features still
   work) and [checklists/interface-language.md](checklists/interface-language.md); report the results.
2. Fix what the checklists found, with tests; record the font results in
   `specs/001-interface-language/research.md` R6 and the API facts in `CLAUDE.md` (`docs/forever-api.md` is on
   `002-shared-db`, see below).
3. Merge `001-interface-language` into `develop`.
4. Release 1.1.0 by the steps of [publishing.md](publishing.md): version 1.1.0 in `package.json`, the
   `[Unreleased]` entries become `## [1.1.0] - <date>`, pull request `develop` -> `main`, tag `1.1.0`.

## 1.2.0: the shared catch database

Built on `002-shared-db` (`specs/002-local-catch-db` to `specs/005-catch-catalog`), waiting for the game and for
a second player. Its steps are written on that branch once this page is merged there.

Technical debt to settle when `001-interface-language` is merged into `002-shared-db` (spec 001 research R15):

- Move the older game data into `GameData/` (data only, like `GameData/FishingRanks.lua`): the lures and the
  fished containers (`Fishing/Bags.lua`), the pole bonuses (`Fishing/Gear.lua`), the Fishing spell IDs and the
  bobber ID (`Core/Data.lua`).
- Switch the catch catalog's pin (`Catalog.PinTarget`, `CatalogTab.Pin`) to `ns.MapPin` (`UI/MapPin.lua`), which
  took that code over with the same saved field (`charDB.pin`) and texts; `ns.Toast` already has the `always`
  argument on both branches.
- `docs/forever-api.md` exists only on `002-shared-db`: move the in-game facts that `001-interface-language` keeps
  in `CLAUDE.md` ("Known API facts for Forever") there.
