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

Built on `002-shared-db` (`specs/002-local-catch-db` to `specs/005-catch-catalog`), waiting for the game and for
a second player. Its steps are written on that branch once this page is merged there.
