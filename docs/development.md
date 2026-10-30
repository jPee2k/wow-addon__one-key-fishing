# Development

The tools, the tests and the packaging in detail. `CLAUDE.md` has the short list; release steps are in
[publishing.md](publishing.md).

## Layout

The addon lives in `OneKeyFishing/`: exactly what goes into `Interface/AddOns` (the TOC, Lua files,
`Bindings.xml`, `Locales/`, `UI/`). `tools/`, `tests/`, `docs/` and project files stay in the repository root.
The tools need Node.js 18+ (`npm install` once).

## `npm run check`

Run it after every change. It checks:

- the addon folder holds only packaged files (TOC-listed + `Bindings.xml`);
- Lua 5.1 syntax;
- undeclared **and unused** globals against `.luacheckrc` (a new WoW API global goes into `read_globals`);
- lines up to 120 characters;
- ASCII-only Lua/TOC/XML files, except the translation files `Locales/<code>.lua` other than `enUS.lua`;
- no `SetFont` call in the addon (the game's font objects pick a Korean, Chinese or Cyrillic font when needed);
- Lua files only in `OneKeyFishing/` and `tests/` (test files get the syntax and line-length checks);
- every repository root entry is either packaged or listed in the `.pkgmeta` `ignore` list;
- every Lua file is listed in the TOC;
- locale keys in sync;
- the bundled seed `SeedData.lua`: at most 1 MB, the `ns.SeedData` fields, place keys;
- no packager keywords in addon Lua and XML (see Packaging);
- `package.json` version == newest `CHANGELOG.md` entry.

It also lists the open `VERIFY` markers.

## `npm test`

Runs the Lua tests in `tests/` and the Node tests `tests/*_test.mjs` (they export `tests`, a list of
`{ name, fn }`; used for `tools/harvest.mjs`). `npm test -- lures` runs only matching files.

- `tests/run.mjs` runs every `tests/*_test.lua` in a fresh fengari state after `tests/wow.lua`.
- `tests/wow.lua` holds the WoW API stubs: frames, events, a controllable clock and timers, configurable bag item
  counts, cooldowns, prices, loot. Unknown globals are permissive stubs.
- Helpers: `test`, `eq`, `near`, `fire`, `advance`, `tick`, `click`, `load_addon` (with an optional step before
  the login), `load_files`, `fish_cast`, `catch_cell`.
- Run it after every change. Add or extend a test when changing logic that can run without the game: Core, Bags,
  Catch, Stats, Prices, CatchDB, Comm, Share, the statistics window and "What can be caught here".
- fengari is Lua 5.3, the game is 5.1: keep the addon free of 5.1/5.3 differences, and fix a test that fails only
  because of 5.3 in the test or the stub.

## Verification debt (`VERIFY` markers)

Code built on an assumption that only the game can confirm (while the game cannot be played) carries
`-- VERIFY(<id>): <what>`. The assumption, its fallback and the way to check it are in the feature's
`verification.md`. `npm run check` lists the open markers and `npm run build` refuses them; a marker is removed
only after the author confirms the behaviour in game.

## Building and installing

- `npm run dev`: packages the working folder into `dist/OneKeyFishing/` and `dist/OneKeyFishing-<version>.zip`
  (version `x.y.z-dev+<commit>`; the zip name has `-` in place of the `+`).
- `npm run build`: refuses uncommitted changes, runs check and test, then packages the last commit; it also
  refuses while any `VERIFY` marker is left.
- `npm run link` / `npm run unlink`: link `Interface/AddOns/OneKeyFishing` to `OneKeyFishing/` (a junction on
  Windows) for development without building; the unbuilt version shows as `dev`.
- `npm run install-addon`: `dev`, then copy into the game's AddOns folder.
- `link`, `unlink`, `install-addon` and `harvest` read `WOW_ADDONS_DIR` from the environment or a git-ignored
  `.env` (see `.env.example`; `harvest` given only saved files may go without it) and refuse anything that is
  not `.../Interface/AddOns`; `link`, `unlink` and `install-addon` also refuse a target that is or contains the
  repository.
- A new file or a TOC change needs a game restart, not just `/reload`.

## `npm run harvest`

Before a release, turns the catch data of every account under `WOW_ADDONS_DIR` (plus saved files given as
arguments; they are parsed, never executed) into `OneKeyFishing/SeedData.lua`, the seed bundled with the release.

- Accepted contributions are kept in `seed/contributions.json` (repository only) by `<id>@<epoch>`, so the same
  input never counts twice, and a run without new sums leaves the seed and its epoch alone.
- `-- --reset <mapID>` counts a map only from the newest game version on (after a patch that changed its catch).
- `-- --synthetic 3000` writes a random seed for a load test (never commit it).
- Format and rules: `specs/002-local-catch-db/contracts/`.

## Packaging

- The package contains only the TOC, the files it lists and `Bindings.xml` from `OneKeyFishing/`, plus
  `LICENSE`, `README.md` and `CHANGELOG.md` from the root (`tools/addon.mjs`).
- `## Version: @project-version@` is filled in at build time; `package.json` holds the version. An unbuilt addon
  is recognised by the version starting with `@` and shows `dev`.
- The release packager replaces such keywords (and strips `--@debug@`-style blocks) in **every** packaged file,
  so addon Lua and XML must not contain them (`npm run check`).
- The release workflow uses BigWigsMods/packager with `.pkgmeta`, whose `move-folders` makes `OneKeyFishing/`
  the package; the root files land in the same folder, so `ignore` leaves out everything but `LICENSE`,
  `README.md` and `CHANGELOG.md`.

## In game

- `/okf` lists commands; `/okf debug` shows the state report used in bug reports; `/okf share` shows the state of
  the catch exchange.
- Claude cannot run the game, so in-game testing is always handed to the user with a checklist
  (`docs/checklists/`).
