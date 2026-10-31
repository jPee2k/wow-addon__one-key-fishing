# Development

The tools, the tests, the packaging and the definition of done. `CLAUDE.md` has the short list; release steps are
in [publishing.md](publishing.md).

## Layout

The addon lives in `OneKeyFishing/`: exactly what goes into `Interface/AddOns` (the TOC, Lua files,
`Bindings.xml`, `Locales/`, `UI/` and the player manual `README.md`). `tools/`, `tests/`, `docs/`, `specs/` and
project files stay in the repository root; the root `README.md` is the developer page.
The tools need Node.js 18+ (`npm install` once).

## `npm run check`

Run it after every change. It checks:

- the addon folder holds only packaged files (TOC-listed + `Bindings.xml` + `README.md`);
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
- the TOC has `Interface`, `Title`, `Notes`, `Author` and `Version: @project-version@`;
- `package.json` version == newest `CHANGELOG.md` entry;
- every slash command (`ns.COMMANDS`, except a declaration marked `VERIFY`) is in the player manual
  `OneKeyFishing/README.md`;
- no Cyrillic in Markdown files, except the language name in the language setting.

It also lists the open `VERIFY` markers.

## `npm test`

Runs the Lua tests (every `*_test.lua` under `tests/`, any depth) and the Node tests (every `*_test.mjs`; they
export `tests`, a list of `{ name, fn }`; used for `tools/harvest.mjs`). `npm test -- lures` runs only the files
whose path relative to `tests/` contains the text, so `npm test -- exchange/channel` runs one folder and
`npm test -- share/load` one file. `OKF_SIM_NODES=1000 npm test -- sim_test` runs the public channel simulation at
that size (the global `SIM_NODES`); the default size (60 clients, about 15 s) keeps `npm test` fast, the full sizes
run by hand before a release. The run time grows with the square of the size (every client hears every
announcement), so 120 clients take about 45 s and 500 about 25 minutes.

The tests are grouped like `docs/architecture/`, one folder per area; the harness (`run.mjs`, `lua.mjs`, `wow.lua`)
stays at the root of `tests/`:

| Folder | Area | Examples |
|---|---|---|
| `core/` | [core.md](architecture/core.md): loading, migrations, locales, commands, text folding, SHA-256 | `load_test.lua`, `migrations_test.lua`, `locale_test.lua`, `proof_test.lua` |
| `fishing/` | [fishing-mode.md](architecture/fishing-mode.md), [catch-and-stats.md](architecture/catch-and-stats.md) | `lures_test.lua`, `prices_test.lua`, `stats_test.lua` |
| `catchdb/` | [catch-db.md](architecture/catch-db.md), including the own record's version chain | `recording_test.lua`, `views_test.lua`, `seed_test.lua`, `proof_chain_test.lua` |
| `catalog/` | [catalog.md](architecture/catalog.md) | `index_test.lua`, `pin_test.lua`, `load_test.lua` |
| `exchange/comm/`, `exchange/channel/`, `exchange/share/` | [exchange.md](architecture/exchange.md), one folder per module | `comm/transport_test.lua`, `channel/joining_test.lua`, `channel/sim_test.lua`, `share/protocol_test.lua` |
| `ui/` | [ui.md](architecture/ui.md): the statistics window's tabs, settings, tooltips, the spike | `catchhere_test.lua`, `catalogtab_test.lua`, `settings_test.lua` |
| `tools/` | the Node tests of `tools/` | `harvest_test.mjs` |

A new test goes into the folder of its area. The folder names the module, so the file names only what it tests
(`exchange/channel/lock_test.lua`, not `channel_lock_test.lua`); the same short name in two folders is fine, the
filter takes the path. A file about the module as a whole is named after its subject (`catchdb/recording_test.lua`,
`exchange/comm/transport_test.lua`), not `<module>_test.lua`.

- `tests/run.mjs` runs every `*_test.lua` in a fresh fengari state (`tests/lua.mjs` is the fengari wrapper) after
  `tests/wow.lua`, and then every `*_test.mjs`; the chunk name of a test is its path (`tests/core/load_test.lua`).
- `tests/wow.lua` holds the WoW API stubs: frames, events, a controllable clock and timers, configurable bag item
  counts, cooldowns, prices, loot, maps and positions, chat and addon messages. Unknown globals are permissive
  stubs. The game data a test can set and the helpers (`test`, `eq`, `fire`, `advance`, `tick`, `click`,
  `load_addon`, `fish_cast`, `receive_addon`, ...) are listed in the file's header comment.
- Run it after every change. Add or extend a test when changing logic that can run without the game: every
  module but the pure frame code has tests (Core, Bags, Catch, Stats, Prices, CatchDB, Comm, Channel, Share,
  Catalog, the statistics window and its tabs, settings, tooltips, locales).
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
- `-- --block <id> "why"` leaves a contribution ID out of the seed and tells every client to drop it (the seed's
  `blocked`); `-- --unblock <id>` takes it back. The outlier report of a run says which IDs to look at.
- `-- --synthetic 3000` writes a random seed for a load test (never commit it).
- Format and rules: `specs/002-local-catch-db/contracts/`.

## Packaging

- The package contains only the TOC, the files it lists, `Bindings.xml` and the player manual `README.md` from
  `OneKeyFishing/`, plus `LICENSE` and `CHANGELOG.md` from the root (`tools/addon.mjs`); the root `README.md`
  stays out (`.pkgmeta` `ignore`).
- `## Version: @project-version@` is filled in at build time; `package.json` holds the version. An unbuilt addon
  is recognised by the version starting with `@` and shows `dev`.
- The release packager replaces such keywords (and strips `--@debug@`-style blocks) in **every** packaged file,
  so addon Lua and XML must not contain them (`npm run check`).
- The release workflow uses BigWigsMods/packager with `.pkgmeta`, whose `move-folders` makes `OneKeyFishing/`
  the package; the root files land in the same folder, so `ignore` leaves out everything but `LICENSE` and
  `CHANGELOG.md`.

## Definition of done

A change is done when:

- `npm run check` and `npm test` pass, and logic that runs without the game has a test;
- a change a player can see or use is in `CHANGELOG.md` under `[Unreleased]` and in the player manual
  `OneKeyFishing/README.md`, in the same commit (fixes of an unreleased feature need no changelog line);
- a new message, module, saved field or cross-module rule is in `CLAUDE.md` and in the area document of
  `docs/architecture/`;
- an assumption only the game can confirm carries a `VERIFY` marker, a row in the feature's `verification.md` and
  a step in its checklist (`docs/checklists/`);
- a finished feature leaves `docs/ROADMAP.md`; a fixed item leaves `docs/tech-debt.md`.

## In game

- `/okf` lists commands; `/okf debug` shows the state report used in bug reports; `/okf share` shows the state of
  the catch exchange.
- Claude cannot run the game, so in-game testing is always handed to the user with a checklist
  (`docs/checklists/`, template and order in its `README.md`).
