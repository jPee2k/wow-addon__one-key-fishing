# Developer documentation

| Read | For |
|---|---|
| [`../CLAUDE.md`](../CLAUDE.md) | the rules that always apply, the module map, the messages, the Forever API traps: the entry point |
| [`../.specify/memory/constitution.md`](../.specify/memory/constitution.md) | the project principles the rules come from |
| [development.md](development.md) | the tools (`npm run check`, `npm test`, build, link, harvest), the test suite, packaging, the definition of done |
| [forever-api.md](forever-api.md) | what is known about the WoW Forever API, how to check a call, the facts verified in game, the open questions for the spike |
| [architecture/](architecture/) | the modules in detail: [core](architecture/core.md), [fishing mode](architecture/fishing-mode.md), [catches and statistics](architecture/catch-and-stats.md), [catch database](architecture/catch-db.md), [catalog](architecture/catalog.md), [exchange](architecture/exchange.md), [UI](architecture/ui.md) |
| [languages.md](languages.md) | the interface languages, how one is chosen, the rules for translation files |
| [publishing.md](publishing.md) | branches, release steps, Blizzard's add-on policy and the CurseForge requirements |
| [release-plan.md](release-plan.md) | what 1.1.0 and 1.2.0 wait for (in-game checks after the launch) and in which order |
| [checklists/](checklists/README.md) | the in-game checklists, one per feature, with the template and the order |
| [ROADMAP.md](ROADMAP.md) | what is not built yet |
| [tech-debt.md](tech-debt.md) | known low-severity issues and the review history |
| [history/](history/) | finished plans kept as a record: the MVP, the 1.0.0 publication, the shared catch database design |
| `../specs/<nnn>-<name>/` | one folder per feature (Spec Kit): spec, plan, research, data model, contracts, tasks, `verification.md` (the `VERIFY` ids), `quickstart.md` (what the tests prove) |

The player manual is [`../OneKeyFishing/README.md`](../OneKeyFishing/README.md); it ships inside the addon.
