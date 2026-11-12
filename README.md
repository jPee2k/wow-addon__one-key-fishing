# OneKeyFishing

A World of Warcraft addon for **WoW Forever**: fish with one key (cast, hook, loot), with fishing mode, gear
swap, statistics and auction prices. Every game action is a real key press; the addon never reacts to the bobber
by itself. MIT licensed.

- **Players**: install it from [CurseForge](https://www.curseforge.com/wow/addons/onekeyfishing); the manual is
  [`OneKeyFishing/README.md`](OneKeyFishing/README.md), which ships inside the addon folder. Changes per version:
  [`CHANGELOG.md`](CHANGELOG.md).
- **This page** is for working on the code.

## Repository layout

```
OneKeyFishing/          the addon: exactly what goes into Interface/AddOns
  OneKeyFishing.toc  Bindings.xml  README.md (the player manual)
  Core/  Locales/  GameData/  Fishing/  Catch/  CatchDB/  Exchange/  Catalog/  UI/   one folder per area
tools/                  check, build, install and link scripts (Node.js)
tests/                  tests of the addon code, run in fengari with WoW API stubs, and Node tests; one folder per area
seed/                   the contributions behind the bundled catch database (written by npm run harvest)
docs/                   developer documentation (below)
specs/                  feature specifications, plans and tasks (Spec Kit)
.specify/               Spec Kit: the project constitution, templates and scripts
```

## Tools

The tools need [Node.js](https://nodejs.org/) 18 or newer and work on Windows, macOS and Linux.

| Command | What it does |
|---|---|
| `npm install` | install the development tools (once) |
| `npm run check` | Lua syntax, globals, line length, the layers, data-only `GameData/`, private tables, test names, locale keys, TOC, packaging, seed, docs and version checks; lists open `VERIFY` markers |
| `npm test` | run the tests in `tests/` (`npm test -- lures` runs only the matching files) |
| `npm run harvest` | before a release: build the bundled catch database `OneKeyFishing/CatchDB/SeedData.lua` from the saved catch data of your accounts (and saved files given as arguments) |
| `npm run link` | link the game's `AddOns/OneKeyFishing` to the `OneKeyFishing/` folder, deleting an installed copy there first (`prelink`): restart the game once, then changes show up after a `/reload` (a new file or a TOC change needs a restart) |
| `npm run unlink` | remove that link |
| `npm run dev` | package the working folder into `dist/` (folder + zip) |
| `npm run build` | refuse uncommitted changes and open `VERIFY` markers, run the checks and tests, then package the last commit |
| `npm run install-addon` | `npm run dev`, then copy the package into the game |

`link`, `unlink`, `install-addon` and `harvest` need the path of the game's `Interface/AddOns` folder: copy
`.env.example` to `.env` (not committed) and fill in `WOW_ADDONS_DIR`, or set the same environment variable.

Run `npm run check` and `npm test` after every change. A change a player can see also updates `CHANGELOG.md`
(under `[Unreleased]`) and the manual `OneKeyFishing/README.md` in the same commit; `npm run check` fails when
a slash command is missing from the manual.

## Documentation

| Read | For |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | the rules that always apply, the module map, the messages; the entry point for Claude Code and for a new contributor |
| [`.specify/memory/constitution.md`](.specify/memory/constitution.md) | the project principles the rules come from |
| [`docs/README.md`](docs/README.md) | the index of the developer documentation |
| [`docs/development.md`](docs/development.md) | the tools, the test suite, packaging, the definition of done |
| [`docs/architecture/`](docs/architecture/) | the modules in detail, one page per area (the game data model in `game-data.md`) |
| [`docs/forever-api.md`](docs/forever-api.md) | the WoW Forever API: the facts verified in game, how to check a call, the open questions |
| [`docs/tech-debt.md`](docs/tech-debt.md) | the known issues with their severity |
| [`docs/publishing.md`](docs/publishing.md) | branches, release steps, Blizzard's add-on policy and CurseForge requirements |
| [`docs/release-plan.md`](docs/release-plan.md) | what the next releases wait for (in-game checks after the launch of WoW Forever) |
| [`docs/checklists/`](docs/checklists/README.md) | in-game checklists: the addon cannot be tested outside the game, so each feature has one |
| [`docs/languages.md`](docs/languages.md) | the interface languages and the rules for translation files |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | what is not built yet |
| [`docs/history/`](docs/history/) | finished plans, kept as a record |
| `specs/<nnn>-<name>/` | one folder per feature: specification, plan, research, data model, contracts, tasks, `verification.md` (the `VERIFY` ids) |

## Rules in short

- Blizzard's UI Add-On Policy: every game action happens on a real key press through secure buttons and
  override bindings; nothing reacts to the bobber splash.
- Game data is matched by ID, never by name; every visible text goes through `ns.L` with its translations.
- English is the development language for code, comments, docs, commits and branches.
- The game cannot be run by tools: in-game behaviour is confirmed with the checklists in `docs/checklists/`.
- Work happens on `develop` and feature branches; `main` holds released code and changes only by merging
  `develop`. Releases are built from version tags by GitHub Actions ([`docs/publishing.md`](docs/publishing.md)).

## License

[MIT](LICENSE)
